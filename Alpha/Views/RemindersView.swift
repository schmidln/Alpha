//
//  RemindersView.swift
//  Alpha
//
// Main view/core of the app - where all reminders are displayed.
// https://developer.apple.com/documentation/swiftui/picker
// https://developer.apple.com/documentation/swiftui/view/contextmenu(menuitems:)


import SwiftUI

struct RemindersView: View {
    @EnvironmentObject var remindersService: RemindersService
    @EnvironmentObject var sharedRemindersService: SharedRemindersService
    @EnvironmentObject var friendsService: FriendsService
    @EnvironmentObject var authService: AuthService
    
    @State private var selectedTab: ReminderTab = .active
    @State private var showingAddReminder = false
    @State private var reminderToEdit: Reminder?
    @State private var showingDeleteConfirmation = false
    @State private var reminderToDelete: Reminder?
    @State private var viewMode: ViewMode = .list
    @State private var selectedFolder: ReminderGroup?
    @State private var showingShareSheet = false
    @State private var folderToShare: ReminderGroup?
    
    enum ReminderTab: String, CaseIterable {
        case active = "Active"
        case shared = "Shared"
        case completed = "Completed"
        case archived = "Archived"
    }
    
    enum ViewMode: String, CaseIterable {
        case list = "List"
        case folders = "Folders"
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Tab Picker
                Picker("Tab", selection: $selectedTab) {
                    ForEach(ReminderTab.allCases, id: \.self) { tab in
                        if tab == .shared {
                            // Show badge for pending invitations
                            if sharedRemindersService.pendingInvitations.isEmpty {
                                Text(tab.rawValue).tag(tab)
                            } else {
                                Text("\(tab.rawValue) (\(sharedRemindersService.pendingInvitations.count))").tag(tab)
                            }
                        } else {
                            Text(tab.rawValue).tag(tab)
                        }
                    }
                }
                .pickerStyle(.segmented)
                .padding()
                
                // View Mode Toggle (only for active tab)
                if selectedTab == .active {
                    Picker("View", selection: $viewMode) {
                        ForEach(ViewMode.allCases, id: \.self) { mode in
                            Image(systemName: mode == .list ? "list.bullet" : "folder.fill").tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }
                
                // Content
                Group {
                    switch selectedTab {
                    case .active:
                        if viewMode == .folders {
                            folderGridView
                        } else {
                            activeRemindersListView
                        }
                    case .shared:
                        SharedRemindersTabView()
                    case .completed:
                        completedRemindersView
                    case .archived:
                        archivedRemindersView
                    }
                }
            }
            .navigationTitle("Reminders")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddReminder = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    if (selectedTab == .completed && !remindersService.completedReminders.isEmpty) ||
                       (selectedTab == .archived && !remindersService.archivedReminders.isEmpty) {
                        Menu {
                            if selectedTab == .completed && !remindersService.completedReminders.isEmpty {
                                Button("Archive All Completed") {
                                    Task {
                                        try? await remindersService.archiveAllCompleted()
                                    }
                                }
                            }
                            if selectedTab == .archived && !remindersService.archivedReminders.isEmpty {
                                Button("Delete All Archived", role: .destructive) {
                                    Task {
                                        try? await remindersService.deleteAllArchived()
                                    }
                                }
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingAddReminder) {
                AddEditReminderView(reminder: nil)
                    .environmentObject(remindersService)
            }
            .sheet(item: $reminderToEdit) { reminder in
                AddEditReminderView(reminder: reminder)
                    .environmentObject(remindersService)
            }
            .sheet(item: $selectedFolder) { folder in
                FolderDetailView(folder: folder)
                    .environmentObject(remindersService)
            }
            .sheet(isPresented: $showingShareSheet) {
                if let folder = folderToShare {
                    ShareFolderView(folder: folder)
                        .environmentObject(sharedRemindersService)
                        .environmentObject(friendsService)
                        .environmentObject(authService)
                        .environmentObject(remindersService)
                }
            }
            .confirmationDialog(
                "Delete Reminder",
                isPresented: $showingDeleteConfirmation,
                presenting: reminderToDelete
            ) { reminder in
                Button("Delete", role: .destructive) {
                    Task {
                        try? await remindersService.deleteReminder(reminder)
                    }
                }
            } message: { reminder in
                Text("Are you sure you want to delete '\(reminder.title)'?")
            }
        }
    }
    
    // MARK: - Active Reminders List View
    
    private var activeRemindersListView: some View {
        List {
            if !remindersService.overdueReminders.isEmpty {
                Section("Overdue") {
                    ForEach(remindersService.overdueReminders) { reminder in
                        ReminderRow(
                            reminder: reminder,
                            onComplete: { completeReminder(reminder) },
                            onEdit: { reminderToEdit = reminder },
                            onArchive: { archiveReminder(reminder) },
                            onDelete: { confirmDelete(reminder) }
                        )
                    }
                }
            }
            
            if !remindersService.dueSoonReminders.isEmpty {
                Section("Due Soon") {
                    ForEach(remindersService.dueSoonReminders) { reminder in
                        ReminderRow(
                            reminder: reminder,
                            onComplete: { completeReminder(reminder) },
                            onEdit: { reminderToEdit = reminder },
                            onArchive: { archiveReminder(reminder) },
                            onDelete: { confirmDelete(reminder) }
                        )
                    }
                }
            }
            
            let otherReminders = remindersService.activeReminders.filter { !$0.isOverdue && !$0.isDueSoon }
            if !otherReminders.isEmpty {
                Section("Upcoming") {
                    ForEach(otherReminders) { reminder in
                        ReminderRow(
                            reminder: reminder,
                            onComplete: { completeReminder(reminder) },
                            onEdit: { reminderToEdit = reminder },
                            onArchive: { archiveReminder(reminder) },
                            onDelete: { confirmDelete(reminder) }
                        )
                    }
                }
            }
            
            if remindersService.activeReminders.isEmpty {
                ContentUnavailableView(
                    "No Reminders",
                    systemImage: "checkmark.circle",
                    description: Text("You're all caught up!")
                )
            }
        }
        .listStyle(.insetGrouped)
        .refreshable {
            await remindersService.refresh()
        }
    }
    
    // MARK: - Folder Grid View
    
    private var folderGridView: some View {
        ScrollView {
            if remindersService.groupedReminders.isEmpty {
                ContentUnavailableView(
                    "No Reminders",
                    systemImage: "checkmark.circle",
                    description: Text("You're all caught up!")
                )
                .padding(.top, 100)
            } else {
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 16),
                    GridItem(.flexible(), spacing: 16)
                ], spacing: 16) {
                    ForEach(remindersService.groupedReminders) { group in
                        FolderCard(
                            group: group,
                            onTap: { selectedFolder = group },
                            onShare: {
                                folderToShare = group
                                showingShareSheet = true
                            }
                        )
                    }
                }
                .padding()
            }
        }
        .background(Color(.systemGroupedBackground))
        .refreshable {
            await remindersService.refresh()
        }
    }
    
    // MARK: - Completed Reminders View
    
    private var completedRemindersView: some View {
        List {
            ForEach(remindersService.completedReminders) { reminder in
                ReminderRow(
                    reminder: reminder,
                    onComplete: { uncompleteReminder(reminder) },
                    onEdit: { reminderToEdit = reminder },
                    onArchive: { archiveReminder(reminder) },
                    onDelete: { confirmDelete(reminder) },
                    isCompleted: true
                )
            }
            
            if remindersService.completedReminders.isEmpty {
                ContentUnavailableView(
                    "No Completed Reminders",
                    systemImage: "tray",
                    description: Text("Completed reminders will appear here")
                )
            }
        }
        .listStyle(.insetGrouped)
        .refreshable {
            await remindersService.refresh()
        }
    }
    
    // MARK: - Archived Reminders View
    
    private var archivedRemindersView: some View {
        List {
            ForEach(remindersService.archivedReminders) { reminder in
                ReminderRow(
                    reminder: reminder,
                    onComplete: nil,
                    onEdit: { reminderToEdit = reminder },
                    onArchive: { unarchiveReminder(reminder) },
                    onDelete: { confirmDelete(reminder) },
                    isArchived: true
                )
            }
            
            if remindersService.archivedReminders.isEmpty {
                ContentUnavailableView(
                    "No Archived Reminders",
                    systemImage: "archivebox",
                    description: Text("Archived reminders will appear here")
                )
            }
        }
        .listStyle(.insetGrouped)
        .refreshable {
            await remindersService.refresh()
        }
    }
    
    // MARK: - Actions
    
    private func completeReminder(_ reminder: Reminder) {
        Task {
            try? await remindersService.completeReminder(reminder)
        }
    }
    
    private func uncompleteReminder(_ reminder: Reminder) {
        Task {
            try? await remindersService.uncompleteReminder(reminder)
        }
    }
    
    private func archiveReminder(_ reminder: Reminder) {
        Task {
            try? await remindersService.archiveReminder(reminder)
        }
    }
    
    private func unarchiveReminder(_ reminder: Reminder) {
        Task {
            try? await remindersService.unarchiveReminder(reminder)
        }
    }
    
    private func confirmDelete(_ reminder: Reminder) {
        reminderToDelete = reminder
        showingDeleteConfirmation = true
    }
}

// MARK: - Shared Reminders Tab View

struct SharedRemindersTabView: View {
    @EnvironmentObject var sharedRemindersService: SharedRemindersService
    @EnvironmentObject var friendsService: FriendsService
    @EnvironmentObject var authService: AuthService
    
    @State private var selectedList: SharedReminderList?
    @State private var showingCreateList = false
    
    var body: some View {
        List {
            // Pending Invitations
            if !sharedRemindersService.pendingInvitations.isEmpty {
                Section("Invitations") {
                    ForEach(sharedRemindersService.pendingInvitations) { invitation in
                        InvitationRow(invitation: invitation)
                    }
                }
            }
            
            // Shared Lists
            if !sharedRemindersService.sharedLists.isEmpty {
                Section("Shared Lists") {
                    ForEach(sharedRemindersService.sharedLists) { list in
                        SharedListRow(list: list) {
                            selectedList = list
                        }
                    }
                }
            }
            
            // Empty state
            if sharedRemindersService.sharedLists.isEmpty && sharedRemindersService.pendingInvitations.isEmpty {
                ContentUnavailableView(
                    "No Shared Lists",
                    systemImage: "person.2.circle",
                    description: Text("Create a shared list to collaborate with friends")
                )
            }
        }
        .listStyle(.insetGrouped)
        .refreshable {
            await sharedRemindersService.refresh()
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingCreateList = true
                } label: {
                    Image(systemName: "folder.badge.plus")
                }
            }
        }
        .sheet(item: $selectedList) { list in
            SharedListDetailView(list: list)
                .environmentObject(sharedRemindersService)
                .environmentObject(friendsService)
                .environmentObject(authService)
        }
        .sheet(isPresented: $showingCreateList) {
            CreateSharedListView()
                .environmentObject(sharedRemindersService)
                .environmentObject(friendsService)
                .environmentObject(authService)
        }
    }
}

// MARK: - Create Shared List View

struct CreateSharedListView: View {
    @EnvironmentObject var sharedRemindersService: SharedRemindersService
    @EnvironmentObject var friendsService: FriendsService
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var category: ReminderCategory = .other
    @State private var selectedFriends: Set<String> = []
    @State private var isCreating = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationStack {
            Form {
                Section("List Details") {
                    TextField("List Name", text: $name)
                    
                    Picker("Category", selection: $category) {
                        ForEach(ReminderCategory.allCases, id: \.self) { cat in
                            Label(cat.displayName, systemImage: cat.icon).tag(cat)
                        }
                    }
                }
                
                Section("Share with Friends") {
                    if friendsService.friends.isEmpty {
                        HStack {
                            Image(systemName: "person.2")
                                .foregroundStyle(.secondary)
                            Text("Add friends first to share lists")
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        ForEach(friendsService.friends) { friendship in
                            let friendId = friendship.friendId(currentUserId: authService.currentUser?.id ?? "") ?? ""
                            let friendName = friendship.friendName(currentUserId: authService.currentUser?.id ?? "") ?? "Friend"
                            
                            Button {
                                if selectedFriends.contains(friendId) {
                                    selectedFriends.remove(friendId)
                                } else {
                                    selectedFriends.insert(friendId)
                                }
                            } label: {
                                HStack {
                                    Image(systemName: "person.circle.fill")
                                        .foregroundStyle(.blue)
                                    
                                    Text(friendName)
                                        .foregroundStyle(.primary)
                                    
                                    Spacer()
                                    
                                    if selectedFriends.contains(friendId) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.green)
                                    } else {
                                        Image(systemName: "circle")
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
                
                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("New Folder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createList()
                    }
                    .disabled(name.isEmpty || selectedFriends.isEmpty || isCreating)
                }
            }
        }
    }
    
    private func createList() {
        guard let userId = authService.currentUser?.id,
              let userName = authService.currentUser?.displayName else { return }
        
        isCreating = true
        errorMessage = nil
        
        Task {
            do {
                // Create the shared list
                let listId = try await sharedRemindersService.createSharedList(
                    name: name,
                    category: category
                )
                
                // Small delay to ensure Firestore has updated
                try await Task.sleep(nanoseconds: 500_000_000)
                
                // Invite selected friends
                if let list = sharedRemindersService.sharedLists.first(where: { $0.id == listId }) {
                    for friendId in selectedFriends {
                        if let friendship = friendsService.friends.first(where: { $0.friendId(currentUserId: userId) == friendId }) {
                            let friendName = friendship.friendName(currentUserId: userId) ?? "Friend"
                            try await sharedRemindersService.inviteFriend(
                                friendId: friendId,
                                friendName: friendName,
                                toList: list
                            )
                        }
                    }
                }
                
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            
            isCreating = false
        }
    }
}

// MARK: - Invitation Row

struct InvitationRow: View {
    @EnvironmentObject var sharedRemindersService: SharedRemindersService
    let invitation: ShareInvitation
    
    @State private var isLoading = false
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "envelope.badge")
                .font(.title2)
                .foregroundStyle(.blue)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(invitation.listName)
                    .font(.headline)
                Text("From \(invitation.fromUserName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            if isLoading {
                ProgressView()
            } else {
                HStack(spacing: 8) {
                    Button {
                        declineInvitation()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(.red)
                            .padding(8)
                            .background(Color(.systemGray5))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    
                    Button {
                        acceptInvitation()
                    } label: {
                        Image(systemName: "checkmark")
                            .foregroundStyle(.white)
                            .padding(8)
                            .background(Color.green)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private func acceptInvitation() {
        isLoading = true
        Task {
            try? await sharedRemindersService.acceptInvitation(invitation)
            isLoading = false
        }
    }
    
    private func declineInvitation() {
        isLoading = true
        Task {
            try? await sharedRemindersService.declineInvitation(invitation)
            isLoading = false
        }
    }
}

// MARK: - Shared List Row

struct SharedListRow: View {
    @EnvironmentObject var sharedRemindersService: SharedRemindersService
    let list: SharedReminderList
    let onTap: () -> Void
    
    var body: some View {
        Button {
            onTap()
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(categoryColor.opacity(0.2))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: list.category.icon)
                        .font(.title2)
                        .foregroundStyle(categoryColor)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(list.displayName)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    let reminderCount = sharedRemindersService.reminders(for: list.id ?? "").count
                    Text("\(reminderCount) reminder\(reminderCount == 1 ? "" : "s") • \(list.memberUserIds.count) member\(list.memberUserIds.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
    
    private var categoryColor: Color {
        switch list.category {
        case .school: return .blue
        case .work: return .purple
        case .personal: return .green
        case .health: return .red
        case .finance: return .orange
        case .social: return .pink
        case .errands: return .teal
        case .other: return .gray
        }
    }
}

// MARK: - Shared List Detail View

struct SharedListDetailView: View {
    @EnvironmentObject var sharedRemindersService: SharedRemindersService
    @EnvironmentObject var friendsService: FriendsService
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) private var dismiss
    
    let list: SharedReminderList
    
    @State private var showingAddReminder = false
    @State private var showingEditList = false
    @State private var showingAddMembers = false
    @State private var showingLeaveConfirmation = false
    
    var body: some View {
        NavigationStack {
            List {
                // Reminders
                let reminders = sharedRemindersService.reminders(for: list.id ?? "")
                let activeReminders = reminders.filter { !$0.isCompleted }
                let completedReminders = reminders.filter { $0.isCompleted }
                
                if !activeReminders.isEmpty {
                    Section("Active") {
                        ForEach(activeReminders) { reminder in
                            SharedReminderRow(reminder: reminder)
                        }
                    }
                }
                
                if !completedReminders.isEmpty {
                    Section("Completed") {
                        ForEach(completedReminders) { reminder in
                            SharedReminderRow(reminder: reminder)
                        }
                    }
                }
                
                if reminders.isEmpty {
                    ContentUnavailableView(
                        "No Reminders",
                        systemImage: "checkmark.circle",
                        description: Text("Tap + to add a reminder")
                    )
                }
                
                // Members section
                Section("Members (\(list.memberUserIds.count))") {
                    ForEach(list.memberUserIds, id: \.self) { memberId in
                        HStack {
                            Image(systemName: "person.circle.fill")
                                .foregroundStyle(memberId == list.ownerUserId ? .blue : .secondary)
                            
                            Text(list.memberNames[memberId] ?? "Unknown")
                            
                            Spacer()
                            
                            if memberId == list.ownerUserId {
                                Text("Owner")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    
                    // Add members button (only for owner)
                    if list.isOwner(userId: authService.currentUser?.id ?? "") {
                        Button {
                            showingAddMembers = true
                        } label: {
                            Label("Add Members", systemImage: "person.badge.plus")
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(list.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddReminder = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            showingEditList = true
                        } label: {
                            Label("Edit List", systemImage: "pencil")
                        }
                        
                        if list.isOwner(userId: authService.currentUser?.id ?? "") {
                            Button {
                                showingAddMembers = true
                            } label: {
                                Label("Add Members", systemImage: "person.badge.plus")
                            }
                        }
                        
                        Button(role: .destructive) {
                            showingLeaveConfirmation = true
                        } label: {
                            Label(list.isOwner(userId: authService.currentUser?.id ?? "") ? "Delete List" : "Leave List",
                                  systemImage: "rectangle.portrait.and.arrow.right")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showingAddReminder) {
                AddSharedReminderView(listId: list.id ?? "")
                    .environmentObject(sharedRemindersService)
            }
            .sheet(isPresented: $showingEditList) {
                EditSharedListView(list: list)
                    .environmentObject(sharedRemindersService)
            }
            .sheet(isPresented: $showingAddMembers) {
                AddMembersView(list: list)
                    .environmentObject(sharedRemindersService)
                    .environmentObject(friendsService)
                    .environmentObject(authService)
            }
            .alert(list.isOwner(userId: authService.currentUser?.id ?? "") ? "Delete List" : "Leave List",
                   isPresented: $showingLeaveConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button(list.isOwner(userId: authService.currentUser?.id ?? "") ? "Delete" : "Leave", role: .destructive) {
                    Task {
                        try? await sharedRemindersService.leaveList(list)
                        dismiss()
                    }
                }
            } message: {
                if list.isOwner(userId: authService.currentUser?.id ?? "") {
                    Text("Are you sure you want to delete '\(list.displayName)'? This will remove it for all members.")
                } else {
                    Text("Are you sure you want to leave '\(list.displayName)'?")
                }
            }
        }
    }
}

// MARK: - Edit Shared List View

struct EditSharedListView: View {
    @EnvironmentObject var sharedRemindersService: SharedRemindersService
    @Environment(\.dismiss) private var dismiss
    
    let list: SharedReminderList
    
    @State private var name: String = ""
    @State private var category: ReminderCategory = .other
    @State private var isSaving = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section("List Details") {
                    TextField("List Name", text: $name)
                    
                    Picker("Category", selection: $category) {
                        ForEach(ReminderCategory.allCases, id: \.self) { cat in
                            Label(cat.displayName, systemImage: cat.icon).tag(cat)
                        }
                    }
                }
            }
            .navigationTitle("Edit List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveChanges()
                    }
                    .disabled(name.isEmpty || isSaving)
                }
            }
            .onAppear {
                name = list.name
                category = list.category
            }
        }
    }
    
    private func saveChanges() {
        isSaving = true
        
        Task {
            try? await sharedRemindersService.updateList(list, name: name, category: category)
            dismiss()
        }
    }
}

// MARK: - Add Members View

struct AddMembersView: View {
    @EnvironmentObject var sharedRemindersService: SharedRemindersService
    @EnvironmentObject var friendsService: FriendsService
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) private var dismiss
    
    let list: SharedReminderList
    
    @State private var selectedFriends: Set<String> = []
    @State private var isAdding = false
    
    // Friends who aren't already members
    var availableFriends: [Friendship] {
        friendsService.friends.filter { friendship in
            let friendId = friendship.friendId(currentUserId: authService.currentUser?.id ?? "") ?? ""
            return !list.memberUserIds.contains(friendId)
        }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                if availableFriends.isEmpty {
                    Section {
                        HStack {
                            Image(systemName: "person.2")
                                .foregroundStyle(.secondary)
                            Text("All your friends are already members")
                                .foregroundStyle(.secondary)
                        }
                    }
                } else {
                    Section("Select Friends to Add") {
                        ForEach(availableFriends) { friendship in
                            let friendId = friendship.friendId(currentUserId: authService.currentUser?.id ?? "") ?? ""
                            let friendName = friendship.friendName(currentUserId: authService.currentUser?.id ?? "") ?? "Friend"
                            
                            Button {
                                if selectedFriends.contains(friendId) {
                                    selectedFriends.remove(friendId)
                                } else {
                                    selectedFriends.insert(friendId)
                                }
                            } label: {
                                HStack {
                                    Image(systemName: "person.circle.fill")
                                        .foregroundStyle(.blue)
                                    
                                    Text(friendName)
                                        .foregroundStyle(.primary)
                                    
                                    Spacer()
                                    
                                    if selectedFriends.contains(friendId) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.green)
                                    } else {
                                        Image(systemName: "circle")
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Add Members")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addMembers()
                    }
                    .disabled(selectedFriends.isEmpty || isAdding)
                }
            }
        }
    }
    
    private func addMembers() {
        guard let userId = authService.currentUser?.id else { return }
        
        isAdding = true
        
        Task {
            for friendId in selectedFriends {
                if let friendship = friendsService.friends.first(where: { $0.friendId(currentUserId: userId) == friendId }) {
                    let friendName = friendship.friendName(currentUserId: userId) ?? "Friend"
                    try? await sharedRemindersService.inviteFriend(
                        friendId: friendId,
                        friendName: friendName,
                        toList: list
                    )
                }
            }
            dismiss()
        }
    }
}

// MARK: - Shared Reminder Row

struct SharedReminderRow: View {
    @EnvironmentObject var sharedRemindersService: SharedRemindersService
    let reminder: SharedReminder
    
    var body: some View {
        HStack(spacing: 12) {
            Button {
                Task {
                    if reminder.isCompleted {
                        try? await sharedRemindersService.uncompleteReminder(reminder)
                    } else {
                        try? await sharedRemindersService.completeReminder(reminder)
                    }
                }
            } label: {
                Image(systemName: reminder.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(reminder.isCompleted ? .green : .secondary)
            }
            .buttonStyle(.plain)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(reminder.title)
                        .strikethrough(reminder.isCompleted)
                        .foregroundStyle(reminder.isCompleted ? .secondary : .primary)
                    
                    if let priority = reminder.priority, priority != .none {
                        Image(systemName: "flag.fill")
                            .font(.caption)
                            .foregroundStyle(priorityColor(priority))
                    }
                }
                
                HStack(spacing: 8) {
                    Text("by \(reminder.createdByName)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    
                    if reminder.isCompleted, let completedBy = reminder.completedByName {
                        Text("• ✓ \(completedBy)")
                            .font(.caption2)
                            .foregroundStyle(.green)
                    }
                }
                
                if reminder.dueDate != nil {
                    VStack(alignment: .leading, spacing: 2) {
                        if let relative = reminder.dueDateRelative {
                            Text(relative)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(reminder.isOverdue ? .red : (reminder.isDueSoon ? .orange : .secondary))
                        }
                        if let absolute = reminder.dueDateAbsolute {
                            Text("@ \(absolute)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                Task {
                    try? await sharedRemindersService.deleteReminder(reminder)
                }
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
    
    private func priorityColor(_ priority: ReminderPriority) -> Color {
        switch priority {
        case .high: return .red
        case .medium: return .orange
        case .low: return .blue
        case .none: return .gray
        }
    }
}

// MARK: - Add Shared Reminder View

struct AddSharedReminderView: View {
    @EnvironmentObject var sharedRemindersService: SharedRemindersService
    @Environment(\.dismiss) private var dismiss
    
    let listId: String
    
    @State private var title = ""
    @State private var notes = ""
    @State private var hasDueDate = false
    @State private var dueDate = Date()
    @State private var priority: ReminderPriority = .none
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Title", text: $title)
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section("Due Date") {
                    Toggle("Set Due Date", isOn: $hasDueDate)
                    
                    if hasDueDate {
                        DatePicker("Due", selection: $dueDate, displayedComponents: [.date, .hourAndMinute])
                    }
                }
                
                Section("Priority") {
                    Picker("Priority", selection: $priority) {
                        ForEach(ReminderPriority.allCases, id: \.self) { p in
                            HStack {
                                if p != .none {
                                    Image(systemName: "flag.fill")
                                        .foregroundStyle(flagColor(p))
                                }
                                Text(p.displayName)
                            }
                            .tag(p)
                        }
                    }
                }
            }
            .navigationTitle("New Reminder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        Task {
                            try? await sharedRemindersService.addReminder(
                                toList: listId,
                                title: title,
                                notes: notes.isEmpty ? nil : notes,
                                dueDate: hasDueDate ? dueDate : nil,
                                priority: priority
                            )
                            dismiss()
                        }
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
    }
    
    private func flagColor(_ priority: ReminderPriority) -> Color {
        switch priority {
        case .high: return .red
        case .medium: return .orange
        case .low: return .blue
        case .none: return .gray
        }
    }
}

// MARK: - Updated Share Folder View

struct ShareFolderView: View {
    @EnvironmentObject var sharedRemindersService: SharedRemindersService
    @EnvironmentObject var friendsService: FriendsService
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var remindersService: RemindersService
    @Environment(\.dismiss) private var dismiss
    
    let folder: ReminderGroup
    
    @State private var selectedFriends: Set<String> = []
    @State private var isCreating = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationStack {
            Form {
                // Folder info
                Section {
                    HStack {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.blue.opacity(0.2))
                                .frame(width: 44, height: 44)
                            
                            Image(systemName: folder.category.icon)
                                .font(.title2)
                                .foregroundStyle(.blue)
                        }
                        
                        VStack(alignment: .leading) {
                            Text(folder.displayName)
                                .font(.headline)
                            Text("\(folder.reminders.count) reminders")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                // Select friends
                Section("Share with Friends") {
                    if friendsService.friends.isEmpty {
                        HStack {
                            Image(systemName: "person.2")
                                .foregroundStyle(.secondary)
                            Text("Add friends to share lists")
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        ForEach(friendsService.friends) { friendship in
                            let friendId = friendship.friendId(currentUserId: authService.currentUser?.id ?? "") ?? ""
                            let friendName = friendship.friendName(currentUserId: authService.currentUser?.id ?? "") ?? "Friend"
                            
                            Button {
                                if selectedFriends.contains(friendId) {
                                    selectedFriends.remove(friendId)
                                } else {
                                    selectedFriends.insert(friendId)
                                }
                            } label: {
                                HStack {
                                    Image(systemName: "person.circle.fill")
                                        .foregroundStyle(.blue)
                                    
                                    Text(friendName)
                                        .foregroundStyle(.primary)
                                    
                                    Spacer()
                                    
                                    if selectedFriends.contains(friendId) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.green)
                                    } else {
                                        Image(systemName: "circle")
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
                
                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
                
                // Share button
                Section {
                    Button {
                        createSharedList()
                    } label: {
                        HStack {
                            Spacer()
                            if isCreating {
                                ProgressView()
                            } else {
                                Text("Create Shared List")
                                    .fontWeight(.semibold)
                            }
                            Spacer()
                        }
                    }
                    .disabled(selectedFriends.isEmpty || isCreating)
                }
            }
            .navigationTitle("Share Folder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func createSharedList() {
        guard let userId = authService.currentUser?.id,
              let userName = authService.currentUser?.displayName else { return }
        
        isCreating = true
        errorMessage = nil
        
        Task {
            do {
                // Create the shared list with reminders
                let listId = try await sharedRemindersService.createSharedListFromReminders(
                    name: folder.category.displayName,
                    category: folder.category,
                    subcategory: folder.subcategory,
                    reminders: folder.reminders
                )
                
                // Get the created list
                // Small delay to ensure Firestore has updated
                try await Task.sleep(nanoseconds: 500_000_000)
                
                // Fetch the list we just created
                if let list = sharedRemindersService.sharedLists.first(where: { $0.id == listId }) {
                    // Invite selected friends
                    for friendId in selectedFriends {
                        if let friendship = friendsService.friends.first(where: { $0.friendId(currentUserId: userId) == friendId }) {
                            let friendName = friendship.friendName(currentUserId: userId) ?? "Friend"
                            try await sharedRemindersService.inviteFriend(
                                friendId: friendId,
                                friendName: friendName,
                                toList: list
                            )
                        }
                    }
                }
                
                // Optionally: Delete original reminders or archive them
                // For now, we'll keep them as is
                
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            
            isCreating = false
        }
    }
}

// MARK: - Folder Card

struct FolderCard: View {
    let group: ReminderGroup
    let onTap: () -> Void
    let onShare: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                // Folder icon
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(categoryColor.opacity(0.2))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: group.category.icon)
                        .font(.title2)
                        .foregroundStyle(categoryColor)
                }
                
                Spacer()
                
                // Share button
                Button {
                    onShare()
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(group.displayName)
                    .font(.headline)
                    .lineLimit(1)
                
                Text("\(group.reminders.count) reminder\(group.reminders.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            // Preview of urgent items
            if let urgent = group.reminders.first(where: { $0.isOverdue || $0.isDueSoon }) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(urgent.isOverdue ? .red : .orange)
                        .frame(width: 6, height: 6)
                    Text(urgent.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        .onTapGesture {
            onTap()
        }
    }
    
    private var categoryColor: Color {
        switch group.category {
        case .school: return .blue
        case .work: return .purple
        case .personal: return .green
        case .health: return .red
        case .finance: return .orange
        case .social: return .pink
        case .errands: return .teal
        case .other: return .gray
        }
    }
}

// MARK: - Folder Detail View

struct FolderDetailView: View {
    @EnvironmentObject var remindersService: RemindersService
    @Environment(\.dismiss) private var dismiss
    
    let folder: ReminderGroup
    @State private var reminderToEdit: Reminder?
    @State private var showingDeleteConfirmation = false
    @State private var reminderToDelete: Reminder?
    @State private var showingShareSheet = false
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(folder.reminders) { reminder in
                    ReminderRow(
                        reminder: reminder,
                        onComplete: { completeReminder(reminder) },
                        onEdit: { reminderToEdit = reminder },
                        onArchive: { archiveReminder(reminder) },
                        onDelete: { confirmDelete(reminder) }
                    )
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(folder.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingShareSheet = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
            .sheet(item: $reminderToEdit) { reminder in
                AddEditReminderView(reminder: reminder)
                    .environmentObject(remindersService)
            }
            .sheet(isPresented: $showingShareSheet) {
                ShareFolderView(folder: folder)
            }
            .confirmationDialog(
                "Delete Reminder",
                isPresented: $showingDeleteConfirmation,
                presenting: reminderToDelete
            ) { reminder in
                Button("Delete", role: .destructive) {
                    Task {
                        try? await remindersService.deleteReminder(reminder)
                        if folder.reminders.count <= 1 {
                            dismiss()
                        }
                    }
                }
            } message: { reminder in
                Text("Are you sure you want to delete '\(reminder.title)'?")
            }
        }
    }
    
    private func completeReminder(_ reminder: Reminder) {
        Task {
            try? await remindersService.completeReminder(reminder)
        }
    }
    
    private func archiveReminder(_ reminder: Reminder) {
        Task {
            try? await remindersService.archiveReminder(reminder)
        }
    }
    
    private func confirmDelete(_ reminder: Reminder) {
        reminderToDelete = reminder
        showingDeleteConfirmation = true
    }
}

// MARK: - Reminder Row

struct ReminderRow: View {
    let reminder: Reminder
    let onComplete: (() -> Void)?
    let onEdit: () -> Void
    let onArchive: () -> Void
    let onDelete: () -> Void
    var isCompleted: Bool = false
    var isArchived: Bool = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Completion button
            if let onComplete = onComplete {
                Button {
                    onComplete()
                } label: {
                    Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundStyle(isCompleted ? .green : .secondary)
                }
                .buttonStyle(.plain)
            }
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(reminder.title)
                        .strikethrough(isCompleted)
                        .foregroundStyle(isCompleted ? .secondary : .primary)
                    
                    // Priority flag
                    if let priority = reminder.priority, priority != .none {
                        Image(systemName: "flag.fill")
                            .font(.caption)
                            .foregroundStyle(priorityColor(priority))
                    }
                }
                
                // Category badge
                if let category = reminder.category {
                    Label(reminder.subcategory ?? category.displayName, systemImage: category.icon)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                // Due date - relative and absolute
                if reminder.dueDate != nil {
                    VStack(alignment: .leading, spacing: 2) {
                        if let relative = reminder.dueDateRelative {
                            Text(relative)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(reminder.isOverdue ? .red : (reminder.isDueSoon ? .orange : .secondary))
                        }
                        if let absolute = reminder.dueDateAbsolute {
                            Text("@ \(absolute)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
            
            Button {
                onArchive()
            } label: {
                Label(isArchived ? "Unarchive" : "Archive", systemImage: isArchived ? "tray.and.arrow.up" : "archivebox")
            }
            .tint(.orange)
        }
        .swipeActions(edge: .leading) {
            Button {
                onEdit()
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            .tint(.blue)
        }
        .contextMenu {
            Button {
                onEdit()
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            
            Button {
                onArchive()
            } label: {
                Label(isArchived ? "Unarchive" : "Archive", systemImage: isArchived ? "tray.and.arrow.up" : "archivebox")
            }
            
            Divider()
            
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
    
    private func priorityColor(_ priority: ReminderPriority) -> Color {
        switch priority {
        case .high: return .red
        case .medium: return .orange
        case .low: return .blue
        case .none: return .gray
        }
    }
}

// MARK: - Add/Edit Reminder View

struct AddEditReminderView: View {
    @EnvironmentObject var remindersService: RemindersService
    @Environment(\.dismiss) private var dismiss
    
    let reminder: Reminder?
    
    @State private var title: String = ""
    @State private var notes: String = ""
    @State private var hasDueDate: Bool = false
    @State private var dueDate: Date = Date()
    @State private var priority: ReminderPriority = .none
    @State private var category: ReminderCategory = .other
    @State private var subcategory: String = ""
    @State private var isRecurring: Bool = false
    @State private var recurrenceInterval: String = "daily"
    
    var isEditing: Bool { reminder != nil }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Title", text: $title)
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section("Due Date") {
                    Toggle("Set Due Date", isOn: $hasDueDate)
                    
                    if hasDueDate {
                        DatePicker("Due", selection: $dueDate, displayedComponents: [.date, .hourAndMinute])
                        
                        Toggle("Recurring", isOn: $isRecurring)
                        
                        if isRecurring {
                            Picker("Repeat", selection: $recurrenceInterval) {
                                Text("Daily").tag("daily")
                                Text("Weekly").tag("weekly")
                                Text("Monthly").tag("monthly")
                            }
                        }
                    }
                }
                
                Section("Organization") {
                    Picker("Category", selection: $category) {
                        ForEach(ReminderCategory.allCases, id: \.self) { cat in
                            Label(cat.displayName, systemImage: cat.icon).tag(cat)
                        }
                    }
                    
                    TextField("Subcategory (e.g., class name)", text: $subcategory)
                    
                    Picker("Priority", selection: $priority) {
                        ForEach(ReminderPriority.allCases, id: \.self) { p in
                            HStack {
                                if p != .none {
                                    Image(systemName: "flag.fill")
                                        .foregroundStyle(flagColor(p))
                                }
                                Text(p.displayName)
                            }
                            .tag(p)
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Reminder" : "New Reminder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save" : "Add") {
                        saveReminder()
                    }
                    .disabled(title.isEmpty)
                }
            }
            .onAppear {
                if let reminder = reminder {
                    title = reminder.title
                    notes = reminder.notes ?? ""
                    hasDueDate = reminder.dueDate != nil
                    dueDate = reminder.dueDate ?? Date()
                    priority = reminder.priority ?? .none
                    category = reminder.category ?? .other
                    subcategory = reminder.subcategory ?? ""
                    isRecurring = reminder.isRecurring ?? false
                    recurrenceInterval = reminder.recurrenceInterval ?? "daily"
                }
            }
        }
    }
    
    private func flagColor(_ priority: ReminderPriority) -> Color {
        switch priority {
        case .high: return .red
        case .medium: return .orange
        case .low: return .blue
        case .none: return .gray
        }
    }
    
    private func saveReminder() {
        Task {
            if let reminder = reminder {
                // Update existing
                try? await remindersService.updateReminder(
                    reminder,
                    title: title,
                    notes: notes.isEmpty ? nil : notes,
                    dueDate: hasDueDate ? dueDate : nil,
                    priority: priority,
                    category: category,
                    subcategory: subcategory.isEmpty ? nil : subcategory
                )
            } else {
                // Create new
                try? await remindersService.createReminder(
                    title: title,
                    notes: notes.isEmpty ? nil : notes,
                    dueDate: hasDueDate ? dueDate : nil,
                    isRecurring: isRecurring,
                    recurrenceInterval: isRecurring ? recurrenceInterval : nil,
                    priority: priority,
                    category: category,
                    subcategory: subcategory.isEmpty ? nil : subcategory
                )
            }
            dismiss()
        }
    }
}

#Preview {
    RemindersView()
        .environmentObject(RemindersService())
}
