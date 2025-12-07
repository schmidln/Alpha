//
//  RemindersService.swift
//  Alpha
//
// This is the core of the reminders manager, handling all CRUD operations for reminders, syncs with Firestore in real-time, schedules local notifications, manages recurring reminders, and provides filtered/sorted views for the UI
// https://firebase.google.com/docs/firestore/query-data/listen
// https://firebase.google.com/docs/firestore/manage-data/add-data
// https://developer.apple.com/documentation/usernotifications
// https://developer.apple.com/documentation/foundation/calendar
// https://developer.apple.com/documentation/swift/array



import Foundation
import Combine
import FirebaseFirestore
import UserNotifications

@MainActor
class RemindersService: ObservableObject {
    @Published var reminders: [Reminder] = []
    @Published var isLoading = false
    
    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    private var userId: String?
    
    func configure(userId: String) {
        self.userId = userId
        startListening()
    }
    
    // MARK: - Real-time Listener
    
    func startListening() {
        guard let userId = userId else {
            print("😡 RemindersService: No userId set")
            return
        }
        
        print("😎 RemindersService: Starting listener for userId: \(userId)")
        
        listener?.remove()
        isLoading = true
        
        listener = db.collection("reminders")
            .whereField("userId", isEqualTo: userId)
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                self.isLoading = false
                
                if let error = error {
                    print("😡 Reminders listener error: \(error)")
                    return
                }
                
                guard let documents = snapshot?.documents else { return }
                
                self.reminders = documents.compactMap { doc in
                    try? doc.data(as: Reminder.self)
                }
                
                print("😎 Loaded \(self.reminders.count) reminders")
            }
    }
    
    func stopListening() {
        listener?.remove()
        listener = nil
    }
    
    // MARK: - Manual Refresh
    
    func refresh() async {
        guard let userId = userId else { return }
        
        isLoading = true
        
        do {
            let snapshot = try await db.collection("reminders")
                .whereField("userId", isEqualTo: userId)
                .order(by: "createdAt", descending: true)
                .getDocuments()
            
            self.reminders = snapshot.documents.compactMap { doc in
                try? doc.data(as: Reminder.self)
            }
            
            print("😎 Refreshed \(self.reminders.count) reminders")
        } catch {
            print("😡 Refresh error: \(error)")
        }
        
        isLoading = false
    }
    
    // MARK: - CRUD Operations
    
    func createReminder(
        title: String,
        notes: String? = nil,
        dueDate: Date? = nil,
        isRecurring: Bool = false,
        recurrenceInterval: String? = nil,
        priority: ReminderPriority? = nil,
        category: ReminderCategory? = nil,
        subcategory: String? = nil
    ) async throws {
        guard let userId = userId else { return }
        
        let reminder = Reminder(
            userId: userId,
            title: title,
            notes: notes,
            dueDate: dueDate,
            isCompleted: false,
            createdAt: Date(),
            source: "app",
            isRecurring: isRecurring,
            recurrenceInterval: recurrenceInterval,
            priority: priority,
            category: category,
            subcategory: subcategory
        )
        
        let docRef = try db.collection("reminders").addDocument(from: reminder)
        
        // Schedule local notification if due date is set
        if let dueDate = dueDate {
            await scheduleNotification(id: docRef.documentID, title: title, body: notes, date: dueDate, priority: priority)
        }
    }
    
    func updateReminder(
        _ reminder: Reminder,
        title: String? = nil,
        notes: String? = nil,
        dueDate: Date? = nil,
        priority: ReminderPriority? = nil,
        category: ReminderCategory? = nil,
        subcategory: String? = nil
    ) async throws {
        guard let id = reminder.id else { return }
        
        var updates: [String: Any] = [:]
        
        if let title = title {
            updates["title"] = title
        }
        if let notes = notes {
            updates["notes"] = notes
        }
        if let dueDate = dueDate {
            updates["dueDate"] = Timestamp(date: dueDate)
            await scheduleNotification(id: id, title: title ?? reminder.title, body: notes ?? reminder.notes, date: dueDate, priority: priority ?? reminder.priority)
        }
        if let priority = priority {
            updates["priority"] = priority.rawValue
        }
        if let category = category {
            updates["category"] = category.rawValue
        }
        if let subcategory = subcategory {
            updates["subcategory"] = subcategory
        }
        
        if !updates.isEmpty {
            try await db.collection("reminders").document(id).updateData(updates)
        }
    }
    
    func completeReminder(_ reminder: Reminder) async throws {
        guard let id = reminder.id else { return }
        
        try await db.collection("reminders").document(id).updateData([
            "isCompleted": true
        ])
        
        // Cancel notification
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
        
        // Handle recurring reminders
        if reminder.isRecurring == true, let interval = reminder.recurrenceInterval {
            try await createNextRecurrence(from: reminder, interval: interval)
        }
    }
    
    func uncompleteReminder(_ reminder: Reminder) async throws {
        guard let id = reminder.id else { return }
        
        try await db.collection("reminders").document(id).updateData([
            "isCompleted": false
        ])
        
        // Reschedule notification if due date exists and is in the future
        if let dueDate = reminder.dueDate, dueDate > Date() {
            await scheduleNotification(id: id, title: reminder.title, body: reminder.notes, date: dueDate, priority: reminder.priority)
        }
    }
    
    func deleteReminder(_ reminder: Reminder) async throws {
        guard let id = reminder.id else { return }
        
        try await db.collection("reminders").document(id).delete()
        
        // Cancel notification
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
    }
    
    // MARK: - Archive Operations
    
    func archiveReminder(_ reminder: Reminder) async throws {
        guard let id = reminder.id else { return }
        
        try await db.collection("reminders").document(id).updateData([
            "isArchived": true
        ])
        
        // Cancel notification since it's archived
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
    }
    
    func unarchiveReminder(_ reminder: Reminder) async throws {
        guard let id = reminder.id else { return }
        
        try await db.collection("reminders").document(id).updateData([
            "isArchived": false
        ])
        
        // Reschedule notification if due date exists and is in the future
        if let dueDate = reminder.dueDate, dueDate > Date(), !reminder.isCompleted {
            await scheduleNotification(id: id, title: reminder.title, body: reminder.notes, date: dueDate, priority: reminder.priority)
        }
    }
    
    // MARK: - Bulk Operations
    
    func deleteMultipleReminders(_ reminders: [Reminder]) async throws {
        for reminder in reminders {
            try await deleteReminder(reminder)
        }
    }
    
    func archiveMultipleReminders(_ reminders: [Reminder]) async throws {
        for reminder in reminders {
            try await archiveReminder(reminder)
        }
    }
    
    func archiveAllCompleted() async throws {
        let completed = completedReminders
        for reminder in completed {
            try await archiveReminder(reminder)
        }
    }
    
    func deleteAllArchived() async throws {
        let archived = archivedReminders
        for reminder in archived {
            try await deleteReminder(reminder)
        }
    }
    
    // MARK: - Recurring Reminders
    
    private func createNextRecurrence(from reminder: Reminder, interval: String) async throws {
        guard let currentDueDate = reminder.dueDate, let userId = userId else { return }
        
        let nextDate: Date?
        switch interval {
        case "daily":
            nextDate = Calendar.current.date(byAdding: .day, value: 1, to: currentDueDate)
        case "weekly":
            nextDate = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: currentDueDate)
        case "monthly":
            nextDate = Calendar.current.date(byAdding: .month, value: 1, to: currentDueDate)
        default:
            nextDate = nil
        }
        
        guard let nextDueDate = nextDate else { return }
        
        let newReminder = Reminder(
            userId: userId,
            title: reminder.title,
            notes: reminder.notes,
            dueDate: nextDueDate,
            isCompleted: false,
            createdAt: Date(),
            source: reminder.source,
            isRecurring: true,
            recurrenceInterval: interval,
            priority: reminder.priority,
            category: reminder.category,
            subcategory: reminder.subcategory
        )
        
        let docRef = try db.collection("reminders").addDocument(from: newReminder)
        await scheduleNotification(id: docRef.documentID, title: reminder.title, body: reminder.notes, date: nextDueDate, priority: reminder.priority)
    }
    
    // TODO: - I want to carry out some notification testing - debugging needed
    
    private func scheduleNotification(id: String, title: String, body: String?, date: Date, priority: ReminderPriority? = nil) async {
        let content = UNMutableNotificationContent()
        content.title = "Reminder"
        content.body = title
        content.sound = .default
        
        if let body = body {
            content.subtitle = body
        }
        
        // Set interruption level based on priority
        if #available(iOS 15.0, *) {
            switch priority {
            case .high:
                content.interruptionLevel = .timeSensitive
            case .medium:
                content.interruptionLevel = .active
            default:
                content.interruptionLevel = .passive
            }
        }
        
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        
        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            print("Error scheduling notification: \(error)")
        }
    }
    
    // MARK: - Sorted & Filtered Reminders
    
    /// All active reminders sorted by urgency (most urgent first) - excludes completed and archived
    var activeReminders: [Reminder] {
        reminders
            .filter { !$0.isCompleted && !($0.isArchived ?? false) }
            .sorted { $0.urgencyScore < $1.urgencyScore }
    }
    
    /// Completed reminders that are not archived
    var completedReminders: [Reminder] {
        reminders.filter { $0.isCompleted && !($0.isArchived ?? false) }
    }
    
    /// All archived reminders (both completed and incomplete)
    var archivedReminders: [Reminder] {
        reminders.filter { $0.isArchived ?? false }
    }
    
    var overdueReminders: [Reminder] {
        reminders.filter { $0.isOverdue }
    }
    
    var dueSoonReminders: [Reminder] {
        reminders.filter { $0.isDueSoon }
    }
    
    // MARK: - Grouped by Category
    
    /// Reminders grouped by category, each group sorted by urgency
    var groupedReminders: [ReminderGroup] {
        let active = activeReminders
        
        // Group by category and subcategory
        var groups: [String: ReminderGroup] = [:]
        
        for reminder in active {
            let category = reminder.category ?? .other
            let subcategory = reminder.subcategory
            let key = "\(category.rawValue)-\(subcategory ?? "")"
            
            if var group = groups[key] {
                group.reminders.append(reminder)
                groups[key] = group
            } else {
                groups[key] = ReminderGroup(
                    id: key,
                    category: category,
                    subcategory: subcategory,
                    reminders: [reminder]
                )
            }
        }
        
        // Sort groups: school first, then by category name
        // Sort reminders within each group by urgency
        return groups.values
            .map { group in
                var sortedGroup = group
                sortedGroup.reminders.sort { $0.urgencyScore < $1.urgencyScore }
                return sortedGroup
            }
            .sorted { group1, group2 in
                // Prioritize school category
                if group1.category == .school && group2.category != .school {
                    return true
                }
                if group2.category == .school && group1.category != .school {
                    return false
                }
                // Then sort alphabetically
                return group1.displayName < group2.displayName
            }
    }
    
    /// Flat list of reminders sorted purely by urgency (ignoring categories)
    var urgencySortedReminders: [Reminder] {
        activeReminders
    }
    
    // MARK: - Filter by Priority
    
    func reminders(withPriority priority: ReminderPriority) -> [Reminder] {
        activeReminders.filter { $0.priority == priority }
    }
    
    // MARK: - Filter by Category
    
    func reminders(inCategory category: ReminderCategory) -> [Reminder] {
        activeReminders.filter { $0.category == category }
    }
}
