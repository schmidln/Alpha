//
//  SharedRemindersService.swift
//  Alpha
//
// The collaborative/shared reminder manager. This enables multiple users to share reminder lists, invite friends, and collaborate in real-time.
// https://firebase.google.com/docs/firestore/query-data/listen
// https://firebase.google.com/docs/firestore/manage-data/add-data#update_elements_in_an_array
// https://firebase.google.com/docs/firestore/manage-data/transactions#batched-writes
// https://firebase.google.com/docs/firestore/manage-data/delete-data#fields

import Foundation
import Combine
import FirebaseFirestore

@MainActor
class SharedRemindersService: ObservableObject {
    @Published var sharedLists: [SharedReminderList] = []
    @Published var pendingInvitations: [ShareInvitation] = []
    @Published var isLoading = false
    
    private let db = Firestore.firestore()
    private var listsListener: ListenerRegistration?
    private var invitationsListener: ListenerRegistration?
    private var reminderListeners: [String: ListenerRegistration] = [:]
    
    // Cache of reminders per list
    @Published var remindersByList: [String: [SharedReminder]] = [:]
    
    private var userId: String?
    private var userName: String?
    
    func configure(userId: String, userName: String) {
        self.userId = userId
        self.userName = userName
        startListening()
    }
    
    // MARK: - Listeners
    
    func startListening() {
        guard let userId = userId else { return }
        
        // Listen to shared lists where user is a member
        listsListener?.remove()
        listsListener = db.collection("sharedLists")
            .whereField("memberUserIds", arrayContains: userId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self, let documents = snapshot?.documents else { return }
                
                let lists = documents.compactMap { try? $0.data(as: SharedReminderList.self) }
                self.sharedLists = lists
                
                // Start listening to reminders for each list
                for list in lists {
                    if let listId = list.id {
                        self.startListeningToReminders(for: listId)
                    }
                }
            }
        
        // Listen to pending invitations
        invitationsListener?.remove()
        invitationsListener = db.collection("shareInvitations")
            .whereField("toUserId", isEqualTo: userId)
            .whereField("status", isEqualTo: ShareInvitationStatus.pending.rawValue)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self, let documents = snapshot?.documents else { return }
                self.pendingInvitations = documents.compactMap { try? $0.data(as: ShareInvitation.self) }
            }
    }
    
    private func startListeningToReminders(for listId: String) {
        // Remove existing listener if any
        reminderListeners[listId]?.remove()
        
        reminderListeners[listId] = db.collection("sharedReminders")
            .whereField("listId", isEqualTo: listId)
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self, let documents = snapshot?.documents else { return }
                let reminders = documents.compactMap { try? $0.data(as: SharedReminder.self) }
                self.remindersByList[listId] = reminders
            }
    }
    
    func stopListening() {
        listsListener?.remove()
        invitationsListener?.remove()
        for listener in reminderListeners.values {
            listener.remove()
        }
        reminderListeners.removeAll()
    }
    
    // MARK: - Create Shared List
    
    func createSharedList(
        name: String,
        category: ReminderCategory,
        subcategory: String? = nil
    ) async throws -> String {
        guard let userId = userId, let userName = userName else {
            throw NSError(domain: "SharedRemindersService", code: 1, userInfo: [NSLocalizedDescriptionKey: "User not configured"])
        }
        
        let list = SharedReminderList(
            name: name,
            category: category,
            subcategory: subcategory,
            ownerUserId: userId,
            ownerName: userName,
            memberUserIds: [userId],
            memberNames: [userId: userName],
            createdAt: Date()
        )
        
        let docRef = try db.collection("sharedLists").addDocument(from: list)
        return docRef.documentID
    }
    
    // MARK: - Create Shared List from Existing Reminders
    
    func createSharedListFromReminders(
        name: String,
        category: ReminderCategory,
        subcategory: String? = nil,
        reminders: [Reminder]
    ) async throws -> String {
        guard let userId = userId, let userName = userName else {
            throw NSError(domain: "SharedRemindersService", code: 1, userInfo: [NSLocalizedDescriptionKey: "User not configured"])
        }
        
        // Create the shared list
        let listId = try await createSharedList(name: name, category: category, subcategory: subcategory)
        
        // Convert and add reminders to the shared list
        for reminder in reminders {
            let sharedReminder = SharedReminder(
                listId: listId,
                title: reminder.title,
                notes: reminder.notes,
                dueDate: reminder.dueDate,
                isCompleted: reminder.isCompleted,
                createdAt: reminder.createdAt,
                createdByUserId: userId,
                createdByName: userName,
                priority: reminder.priority
            )
            _ = try db.collection("sharedReminders").addDocument(from: sharedReminder)
        }
        
        // Start listening to reminders for this list immediately
        startListeningToReminders(for: listId)
        
        return listId
    }
    
    // MARK: - Invite Friend to List
    
    func inviteFriend(
        friendId: String,
        friendName: String,
        toList list: SharedReminderList
    ) async throws {
        guard let userId = userId, let userName = userName, let listId = list.id else { return }
        
        // Check if already a member
        if list.memberUserIds.contains(friendId) {
            throw NSError(domain: "SharedRemindersService", code: 2, userInfo: [NSLocalizedDescriptionKey: "User is already a member"])
        }
        
        // Check for existing pending invitation
        let existingInvites = try await db.collection("shareInvitations")
            .whereField("listId", isEqualTo: listId)
            .whereField("toUserId", isEqualTo: friendId)
            .whereField("status", isEqualTo: ShareInvitationStatus.pending.rawValue)
            .getDocuments()
        
        if !existingInvites.documents.isEmpty {
            throw NSError(domain: "SharedRemindersService", code: 3, userInfo: [NSLocalizedDescriptionKey: "Invitation already sent"])
        }
        
        let invitation = ShareInvitation(
            listId: listId,
            listName: list.displayName,
            fromUserId: userId,
            fromUserName: userName,
            toUserId: friendId,
            toUserName: friendName,
            status: .pending,
            createdAt: Date()
        )
        
        try db.collection("shareInvitations").addDocument(from: invitation)
    }
    
    // MARK: - Accept Invitation
    
    func acceptInvitation(_ invitation: ShareInvitation) async throws {
        guard let invitationId = invitation.id, let userId = userId, let userName = userName else { return }
        
        let batch = db.batch()
        
        // Update invitation status
        let invitationRef = db.collection("shareInvitations").document(invitationId)
        batch.updateData([
            "status": ShareInvitationStatus.accepted.rawValue,
            "respondedAt": Date()
        ], forDocument: invitationRef)
        
        // Add user to the shared list
        let listRef = db.collection("sharedLists").document(invitation.listId)
        batch.updateData([
            "memberUserIds": FieldValue.arrayUnion([userId]),
            "memberNames.\(userId)": userName,
            "updatedAt": Date()
        ], forDocument: listRef)
        
        try await batch.commit()
    }
    
    // MARK: - Decline Invitation
    
    func declineInvitation(_ invitation: ShareInvitation) async throws {
        guard let invitationId = invitation.id else { return }
        
        try await db.collection("shareInvitations").document(invitationId).updateData([
            "status": ShareInvitationStatus.declined.rawValue,
            "respondedAt": Date()
        ])
    }
    
    // MARK: - Leave Shared List
    
    func leaveList(_ list: SharedReminderList) async throws {
        guard let listId = list.id, let userId = userId else { return }
        
        // If owner, must transfer ownership or delete
        if list.ownerUserId == userId {
            if list.memberUserIds.count > 1 {
                // Transfer to next member
                let newOwnerId = list.memberUserIds.first { $0 != userId } ?? ""
                let newOwnerName = list.memberNames[newOwnerId] ?? "Unknown"
                
                try await db.collection("sharedLists").document(listId).updateData([
                    "ownerUserId": newOwnerId,
                    "ownerName": newOwnerName,
                    "memberUserIds": FieldValue.arrayRemove([userId]),
                    "memberNames.\(userId)": FieldValue.delete(),
                    "updatedAt": Date()
                ])
            } else {
                // Delete the list and all its reminders
                try await deleteList(list)
            }
        } else {
            // Just remove from members
            try await db.collection("sharedLists").document(listId).updateData([
                "memberUserIds": FieldValue.arrayRemove([userId]),
                "memberNames.\(userId)": FieldValue.delete(),
                "updatedAt": Date()
            ])
        }
    }
    
    // MARK: - Update Shared List
    
    func updateList(_ list: SharedReminderList, name: String, category: ReminderCategory) async throws {
        guard let listId = list.id else { return }
        
        try await db.collection("sharedLists").document(listId).updateData([
            "name": name,
            "category": category.rawValue,
            "updatedAt": Date()
        ])
    }
    
    // MARK: - Delete Shared List
    
    func deleteList(_ list: SharedReminderList) async throws {
        guard let listId = list.id else { return }
        
        // Delete all reminders in the list
        let reminders = try await db.collection("sharedReminders")
            .whereField("listId", isEqualTo: listId)
            .getDocuments()
        
        let batch = db.batch()
        for doc in reminders.documents {
            batch.deleteDocument(doc.reference)
        }
        
        // Delete the list
        batch.deleteDocument(db.collection("sharedLists").document(listId))
        
        try await batch.commit()
    }
    
    // MARK: - Reminder CRUD
    
    func addReminder(
        toList listId: String,
        title: String,
        notes: String? = nil,
        dueDate: Date? = nil,
        priority: ReminderPriority? = nil
    ) async throws {
        guard let userId = userId, let userName = userName else { return }
        
        let reminder = SharedReminder(
            listId: listId,
            title: title,
            notes: notes,
            dueDate: dueDate,
            isCompleted: false,
            createdAt: Date(),
            createdByUserId: userId,
            createdByName: userName,
            priority: priority
        )
        
        try db.collection("sharedReminders").addDocument(from: reminder)
        
        // Update list's updatedAt
        try await db.collection("sharedLists").document(listId).updateData([
            "updatedAt": Date()
        ])
    }
    
    func updateReminder(
        _ reminder: SharedReminder,
        title: String? = nil,
        notes: String? = nil,
        dueDate: Date? = nil,
        priority: ReminderPriority? = nil
    ) async throws {
        guard let reminderId = reminder.id else { return }
        
        var updates: [String: Any] = [:]
        if let title = title { updates["title"] = title }
        if let notes = notes { updates["notes"] = notes }
        if let dueDate = dueDate { updates["dueDate"] = Timestamp(date: dueDate) }
        if let priority = priority { updates["priority"] = priority.rawValue }
        
        if !updates.isEmpty {
            try await db.collection("sharedReminders").document(reminderId).updateData(updates)
        }
    }
    
    func completeReminder(_ reminder: SharedReminder) async throws {
        guard let reminderId = reminder.id, let userId = userId, let userName = userName else { return }
        
        try await db.collection("sharedReminders").document(reminderId).updateData([
            "isCompleted": true,
            "completedByUserId": userId,
            "completedByName": userName
        ])
    }
    
    func uncompleteReminder(_ reminder: SharedReminder) async throws {
        guard let reminderId = reminder.id else { return }
        
        try await db.collection("sharedReminders").document(reminderId).updateData([
            "isCompleted": false,
            "completedByUserId": FieldValue.delete(),
            "completedByName": FieldValue.delete()
        ])
    }
    
    func deleteReminder(_ reminder: SharedReminder) async throws {
        guard let reminderId = reminder.id else { return }
        try await db.collection("sharedReminders").document(reminderId).delete()
    }
    
    // MARK: - Get Reminders for List
    
    func reminders(for listId: String) -> [SharedReminder] {
        let reminders = remindersByList[listId] ?? []
        return reminders.sorted { r1, r2 in
            // Sort: incomplete first, then by due date, then by created date
            if r1.isCompleted != r2.isCompleted {
                return !r1.isCompleted
            }
            if let d1 = r1.dueDate, let d2 = r2.dueDate {
                return d1 < d2
            }
            if r1.dueDate != nil { return true }
            if r2.dueDate != nil { return false }
            return r1.createdAt > r2.createdAt
        }
    }
    
    // MARK: - Refresh
    
    func refresh() async {
        guard let userId = userId else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Refresh lists
            let listsSnapshot = try await db.collection("sharedLists")
                .whereField("memberUserIds", arrayContains: userId)
                .getDocuments()
            sharedLists = listsSnapshot.documents.compactMap { try? $0.data(as: SharedReminderList.self) }
            
            // Refresh invitations
            let invitationsSnapshot = try await db.collection("shareInvitations")
                .whereField("toUserId", isEqualTo: userId)
                .whereField("status", isEqualTo: ShareInvitationStatus.pending.rawValue)
                .getDocuments()
            pendingInvitations = invitationsSnapshot.documents.compactMap { try? $0.data(as: ShareInvitation.self) }
            
            // Refresh reminders for each list
            for list in sharedLists {
                if let listId = list.id {
                    let remindersSnapshot = try await db.collection("sharedReminders")
                        .whereField("listId", isEqualTo: listId)
                        .getDocuments()
                    remindersByList[listId] = remindersSnapshot.documents.compactMap { try? $0.data(as: SharedReminder.self) }
                }
            }
        } catch {
            print("😡 Refresh error: \(error)")
        }
    }
    
    deinit {
        listsListener?.remove()
        invitationsListener?.remove()
        for listener in reminderListeners.values {
            listener.remove()
        }
    }
}
