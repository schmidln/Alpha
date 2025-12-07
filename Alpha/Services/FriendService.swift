//
//  FriendsService.swift
//  Alpha
//
// https://firebase.google.com/docs/firestore/query-data/listen#detach_a_listener
// https://firebase.google.com/docs/firestore/manage-data/add-data#custom_objects
// https://firebase.google.com/docs/firestore/manage-data/transactions#batched-writes
// https://firebase.google.com/docs/firestore/query-data/queries
// https://firebase.google.com/docs/firestore/query-data/listen

import Foundation
import Combine
import FirebaseFirestore

@MainActor
class FriendsService: ObservableObject {
    @Published var friends: [Friendship] = []
    @Published var incomingRequests: [FriendRequest] = []
    @Published var outgoingRequests: [FriendRequest] = []
    @Published var searchResults: [UserSearchResult] = []
    @Published var isLoading = false
    @Published var isSearching = false
    
    private let db = Firestore.firestore()
    private var friendsListener: ListenerRegistration?
    private var incomingListener: ListenerRegistration?
    private var outgoingListener: ListenerRegistration?
    private var userId: String?
    
    func configure(userId: String) {
        self.userId = userId
        startListening()
    }
    
    // MARK: - Listeners
    
    func startListening() {
        guard let userId = userId else { return }
        
        // Listen to friendships
        friendsListener?.remove()
        friendsListener = db.collection("friendships")
            .whereField("users", arrayContains: userId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self, let documents = snapshot?.documents else { return }
                self.friends = documents.compactMap { try? $0.data(as: Friendship.self) }
            }
        
        // Listen to incoming friend requests
        incomingListener?.remove()
        incomingListener = db.collection("friendRequests")
            .whereField("toUserId", isEqualTo: userId)
            .whereField("status", isEqualTo: FriendRequestStatus.pending.rawValue)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self, let documents = snapshot?.documents else { return }
                self.incomingRequests = documents.compactMap { try? $0.data(as: FriendRequest.self) }
            }
        
        // Listen to outgoing friend requests
        outgoingListener?.remove()
        outgoingListener = db.collection("friendRequests")
            .whereField("fromUserId", isEqualTo: userId)
            .whereField("status", isEqualTo: FriendRequestStatus.pending.rawValue)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self, let documents = snapshot?.documents else { return }
                self.outgoingRequests = documents.compactMap { try? $0.data(as: FriendRequest.self) }
            }
    }
    
    func stopListening() {
        friendsListener?.remove()
        incomingListener?.remove()
        outgoingListener?.remove()
    }
    
    // MARK: - Search Users
    
    func searchUsers(query: String) async {
        guard let userId = userId, !query.isEmpty else {
            searchResults = []
            return
        }
        
        isSearching = true
        defer { isSearching = false }
        
        do {
            // Get all users and filter locally (for small user bases)
            // For larger apps, you'd want to use Cloud Functions or Algolia
            let snapshot = try await db.collection("users")
                .limit(to: 50)
                .getDocuments()
            
            let lowercaseQuery = query.lowercased()
            
            var results: [UserSearchResult] = []
            
            for doc in snapshot.documents {
                let data = doc.data()
                let id = doc.documentID
                
                // Skip current user
                if id == userId { continue }
                
                let email = data["email"] as? String ?? ""
                let displayName = data["displayName"] as? String ?? ""
                
                // Check if query matches email or display name
                if email.lowercased().contains(lowercaseQuery) ||
                   displayName.lowercased().contains(lowercaseQuery) {
                    let result = UserSearchResult(
                        id: id,
                        displayName: displayName.isEmpty ? "Unknown" : displayName,
                        email: email,
                        friendshipStatus: getFriendshipStatus(for: id)
                    )
                    results.append(result)
                }
            }
            
            searchResults = results
        } catch {
            print("😡 Search error: \(error)")
            searchResults = []
        }
    }
    
    private func getFriendshipStatus(for otherUserId: String) -> FriendshipStatusType {
        // Check if already friends
        if friends.contains(where: { $0.users.contains(otherUserId) }) {
            return .friends
        }
        
        // Check if there's a pending outgoing request
        if outgoingRequests.contains(where: { $0.toUserId == otherUserId }) {
            return .pendingSent
        }
        
        // Check if there's a pending incoming request
        if incomingRequests.contains(where: { $0.fromUserId == otherUserId }) {
            return .pendingReceived
        }
        
        return .none
    }
    
    // MARK: - Send Friend Request
    
    func sendFriendRequest(to user: UserSearchResult, fromUser: (id: String, name: String, email: String)) async throws {
        let request = FriendRequest(
            fromUserId: fromUser.id,
            toUserId: user.id,
            fromUserName: fromUser.name,
            fromUserEmail: fromUser.email,
            toUserName: user.displayName,
            toUserEmail: user.email,
            status: .pending,
            createdAt: Date()
        )
        
        try db.collection("friendRequests").addDocument(from: request)
        
        // Update local search results
        if let index = searchResults.firstIndex(where: { $0.id == user.id }) {
            searchResults[index].friendshipStatus = .pendingSent
        }
    }
    
    // MARK: - Accept Friend Request
    
    func acceptRequest(_ request: FriendRequest) async throws {
        guard let requestId = request.id, let _ = userId else { return }
        
        let batch = db.batch()
        
        // Update request status
        let requestRef = db.collection("friendRequests").document(requestId)
        batch.updateData([
            "status": FriendRequestStatus.accepted.rawValue,
            "updatedAt": Date()
        ], forDocument: requestRef)
        
        // Create friendship
        let friendship = Friendship(
            users: [request.fromUserId, request.toUserId],
            userNames: [
                request.fromUserId: request.fromUserName,
                request.toUserId: request.toUserName
            ],
            userEmails: [
                request.fromUserId: request.fromUserEmail,
                request.toUserId: request.toUserEmail
            ],
            createdAt: Date()
        )
        
        let friendshipRef = db.collection("friendships").document()
        try batch.setData(from: friendship, forDocument: friendshipRef)
        
        try await batch.commit()
    }
    
    // MARK: - Decline Friend Request
    
    func declineRequest(_ request: FriendRequest) async throws {
        guard let requestId = request.id else { return }
        
        try await db.collection("friendRequests").document(requestId).updateData([
            "status": FriendRequestStatus.declined.rawValue,
            "updatedAt": Date()
        ])
    }
    
    // MARK: - Cancel Outgoing Request
    
    func cancelRequest(_ request: FriendRequest) async throws {
        guard let requestId = request.id else { return }
        
        try await db.collection("friendRequests").document(requestId).delete()
        
        // Update local search results
        if let index = searchResults.firstIndex(where: { $0.id == request.toUserId }) {
            searchResults[index].friendshipStatus = .none
        }
    }
    
    // MARK: - Remove Friend
    
    func removeFriend(_ friendship: Friendship) async throws {
        guard let friendshipId = friendship.id else { return }
        
        try await db.collection("friendships").document(friendshipId).delete()
    }
    
    // MARK: - Refresh
    
    func refresh() async {
        guard let userId = userId else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Refresh friends
            let friendsSnapshot = try await db.collection("friendships")
                .whereField("users", arrayContains: userId)
                .getDocuments()
            friends = friendsSnapshot.documents.compactMap { try? $0.data(as: Friendship.self) }
            
            // Refresh incoming requests
            let incomingSnapshot = try await db.collection("friendRequests")
                .whereField("toUserId", isEqualTo: userId)
                .whereField("status", isEqualTo: FriendRequestStatus.pending.rawValue)
                .getDocuments()
            incomingRequests = incomingSnapshot.documents.compactMap { try? $0.data(as: FriendRequest.self) }
            
            // Refresh outgoing requests
            let outgoingSnapshot = try await db.collection("friendRequests")
                .whereField("fromUserId", isEqualTo: userId)
                .whereField("status", isEqualTo: FriendRequestStatus.pending.rawValue)
                .getDocuments()
            outgoingRequests = outgoingSnapshot.documents.compactMap { try? $0.data(as: FriendRequest.self) }
        } catch {
            print("😡 Refresh error: \(error)")
        }
    }
    
    deinit {
        friendsListener?.remove()
        incomingListener?.remove()
        outgoingListener?.remove()
    }
}
