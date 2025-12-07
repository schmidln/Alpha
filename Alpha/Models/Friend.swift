//
//  Friend.swift
//  Alpha
//

import Foundation
import FirebaseFirestore

// MARK: - Friend Request Status

enum FriendRequestStatus: String, Codable {
    case pending = "pending"
    case accepted = "accepted"
    case declined = "declined"
}

// MARK: - Friend Request Model

struct FriendRequest: Identifiable, Codable {
    @DocumentID var id: String?
    let fromUserId: String
    let toUserId: String
    let fromUserName: String
    let fromUserEmail: String
    let toUserName: String
    let toUserEmail: String
    var status: FriendRequestStatus
    let createdAt: Date
    var updatedAt: Date?
}

// MARK: - Friendship Model (confirmed connection)

struct Friendship: Identifiable, Codable {
    @DocumentID var id: String?
    let users: [String]  // Array of two user IDs
    let userNames: [String: String]  // userId -> displayName
    let userEmails: [String: String]  // userId -> email
    let createdAt: Date
    
    // Get the friend's info (not the current user)
    func friendId(currentUserId: String) -> String? {
        users.first { $0 != currentUserId }
    }
    
    func friendName(currentUserId: String) -> String? {
        guard let friendId = friendId(currentUserId: currentUserId) else { return nil }
        return userNames[friendId]
    }
    
    func friendEmail(currentUserId: String) -> String? {
        guard let friendId = friendId(currentUserId: currentUserId) else { return nil }
        return userEmails[friendId]
    }
}

// MARK: - User Search Result

struct UserSearchResult: Identifiable {
    var id: String
    let displayName: String
    let email: String
    
    // Status relative to current user (not stored, computed locally)
    var friendshipStatus: FriendshipStatusType = .none
}

enum FriendshipStatusType {
    case none
    case pendingSent      // Current user sent request
    case pendingReceived  // Current user received request
    case friends          // Already friends
}
