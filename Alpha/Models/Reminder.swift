//
//  Reminder.swift
//  Alpha
//

import Foundation
import FirebaseFirestore

// MARK: - Priority Enum

enum ReminderPriority: String, Codable, CaseIterable, Comparable {
    case high = "high"
    case medium = "medium"
    case low = "low"
    case none = "none"
    
    var displayName: String {
        switch self {
        case .high: return "High"
        case .medium: return "Medium"
        case .low: return "Low"
        case .none: return "None"
        }
    }
    
    var color: String {
        switch self {
        case .high: return "red"
        case .medium: return "orange"
        case .low: return "blue"
        case .none: return "gray"
        }
    }
    
    var sortOrder: Int {
        switch self {
        case .high: return 0
        case .medium: return 1
        case .low: return 2
        case .none: return 3
        }
    }
    
    static func < (lhs: ReminderPriority, rhs: ReminderPriority) -> Bool {
        lhs.sortOrder < rhs.sortOrder
    }
}

// MARK: - Category Enum

enum ReminderCategory: String, Codable, CaseIterable {
    case school = "school"
    case work = "work"
    case personal = "personal"
    case health = "health"
    case finance = "finance"
    case social = "social"
    case errands = "errands"
    case other = "other"
    
    var displayName: String {
        switch self {
        case .school: return "School"
        case .work: return "Work"
        case .personal: return "Personal"
        case .health: return "Health"
        case .finance: return "Finance"
        case .social: return "Social"
        case .errands: return "Errands"
        case .other: return "Other"
        }
    }
    
    var icon: String {
        switch self {
        case .school: return "book.fill"
        case .work: return "briefcase.fill"
        case .personal: return "person.fill"
        case .health: return "heart.fill"
        case .finance: return "dollarsign.circle.fill"
        case .social: return "person.2.fill"
        case .errands: return "cart.fill"
        case .other: return "folder.fill"
        }
    }
}

// MARK: - Reminder Model

struct Reminder: Identifiable, Codable {
    @DocumentID var id: String?
    let userId: String
    var title: String
    var notes: String?
    var dueDate: Date?
    var isCompleted: Bool
    var createdAt: Date
    var source: String
    var isRecurring: Bool?
    var recurrenceInterval: String?
    
    // New fields
    var priority: ReminderPriority?
    var category: ReminderCategory?
    var subcategory: String?  // e.g., specific class name like "CS101"
    var isArchived: Bool?
    
    // Computed property for urgency score (lower = more urgent)
    var urgencyScore: Double {
        var score: Double = 1000 // Base score
        
        // Factor 1: Priority
        let priorityValue = priority ?? .none
        score -= Double((3 - priorityValue.sortOrder) * 100) // High priority = -300, Medium = -200, Low = -100
        
        // Factor 2: Time until due
        if let dueDate = dueDate {
            let hoursUntilDue = dueDate.timeIntervalSinceNow / 3600
            
            if hoursUntilDue < 0 {
                // Overdue - highest urgency
                score -= 500 + abs(hoursUntilDue) // More overdue = lower score
            } else if hoursUntilDue < 24 {
                // Due within 24 hours
                score -= 400
            } else if hoursUntilDue < 72 {
                // Due within 3 days
                score -= 300
            } else if hoursUntilDue < 168 {
                // Due within a week
                score -= 200
            }
        }
        
        return score
    }
    
    // Check if overdue
    var isOverdue: Bool {
        guard let dueDate = dueDate else { return false }
        return !isCompleted && !(isArchived ?? false) && dueDate < Date()
    }
    
    // Check if due soon (within 24 hours)
    var isDueSoon: Bool {
        guard let dueDate = dueDate else { return false }
        let hoursUntilDue = dueDate.timeIntervalSinceNow / 3600
        return !isCompleted && !(isArchived ?? false) && hoursUntilDue > 0 && hoursUntilDue <= 24
    }
    
    // Formatted due date string - relative time
    var dueDateRelative: String? {
        guard let dueDate = dueDate else { return nil }
        
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: dueDate, relativeTo: Date())
    }
    
    // Formatted due date string - absolute time (e.g., "3pm Tuesday Dec 4th")
    var dueDateAbsolute: String? {
        guard let dueDate = dueDate else { return nil }
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mma"
        let timeString = timeFormatter.string(from: dueDate).lowercased()
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEEE MMM d"
        let dateString = dateFormatter.string(from: dueDate)
        
        // Add ordinal suffix (1st, 2nd, 3rd, etc.)
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
    
    // Combined display: "in 1 hr" + "@ 3:00pm Tuesday Dec 4th"
    var dueDateDisplay: String? {
        guard let relative = dueDateRelative else { return nil }
        return relative
    }
}

// MARK: - Grouped Reminders

struct ReminderGroup: Identifiable {
    let id: String
    let category: ReminderCategory
    let subcategory: String?
    var reminders: [Reminder]
    
    var displayName: String {
        if let sub = subcategory, !sub.isEmpty {
            return "\(category.displayName) - \(sub)"
        }
        return category.displayName
    }
}
