//
//  SharedReminderList.swift
//  Alpha
//

import Foundation
import FirebaseFirestore

// MARK: - Shared Reminder List

struct SharedReminderList: Identifiable, Codable {
    @DocumentID var id: String?
    var name: String
    var category: ReminderCategory
    var subcategory: String?
    var ownerUserId: String
    var ownerName: String
    var memberUserIds: [String]  // All members including owner
    var memberNames: [String: String]  // userId -> displayName
    var createdAt: Date
    var updatedAt: Date?
    
    var displayName: String {
        if let sub = subcategory, !sub.isEmpty {
            return "\(name) - \(sub)"
        }
        return name
    }
    
    func isOwner(userId: String) -> Bool {
        ownerUserId == userId
    }
    
    func isMember(userId: String) -> Bool {
        memberUserIds.contains(userId)
    }
}

// MARK: - Shared Reminder (belongs to a SharedReminderList)

struct SharedReminder: Identifiable, Codable {
    @DocumentID var id: String?
    let listId: String  // Reference to SharedReminderList
    var title: String
    var notes: String?
    var dueDate: Date?
    var isCompleted: Bool
    var createdAt: Date
    var createdByUserId: String
    var createdByName: String
    var completedByUserId: String?
    var completedByName: String?
    var priority: ReminderPriority?
    
    // Computed properties
    var isOverdue: Bool {
        guard let dueDate = dueDate else { return false }
        return !isCompleted && dueDate < Date()
    }
    
    var isDueSoon: Bool {
        guard let dueDate = dueDate else { return false }
        let hoursUntilDue = dueDate.timeIntervalSinceNow / 3600
        return !isCompleted && hoursUntilDue > 0 && hoursUntilDue <= 24
    }
    
    var dueDateRelative: String? {
        guard let dueDate = dueDate else { return nil }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: dueDate, relativeTo: Date())
    }
    
    var dueDateAbsolute: String? {
        guard let dueDate = dueDate else { return nil }
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mma"
        let timeString = timeFormatter.string(from: dueDate).lowercased()
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEEE MMM d"
        let dateString = dateFormatter.string(from: dueDate)
        
        let day = Calendar.current.component(.day, from: dueDate)
        let suffix: String
        switch day {
        case 1, 21, 31: suffix = "st"
        case 2, 22: suffix = "nd"
        case 3, 23: suffix = "rd"
        default: suffix = "th"
        }
        
        return "\(timeString) \(dateString)\(suffix)"
    }
}

// MARK: - Share Invitation

struct ShareInvitation: Identifiable, Codable {
    @DocumentID var id: String?
    let listId: String
    let listName: String
    let fromUserId: String
    let fromUserName: String
    let toUserId: String
    let toUserName: String
    var status: ShareInvitationStatus
    let createdAt: Date
    var respondedAt: Date?
}

enum ShareInvitationStatus: String, Codable {
    case pending = "pending"
    case accepted = "accepted"
    case declined = "declined"
}
