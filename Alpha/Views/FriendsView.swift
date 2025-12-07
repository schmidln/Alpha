//
//  FriendsView.swift
//  Alpha
//
// https://developer.apple.com/documentation/swiftui/picker
// https://developer.apple.com/documentation/swiftui/tabview
// https://developer.apple.com/documentation/swiftui/view/onsubmit(of:_:)
// https://developer.apple.com/documentation/swiftui/view/swipeactions(edge:allowsfullswipe:content:)
// https://developer.apple.com/documentation/swiftui/view/alert(_:ispresented:actions:message:)
// https://developer.apple.com/documentation/swiftui/group


import SwiftUI

struct FriendsView: View {
    @EnvironmentObject var friendsService: FriendsService
    @EnvironmentObject var authService: AuthService
    
    @State private var searchText = ""
    @State private var selectedTab = 0
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    
                    TextField("Search by name or email...", text: $searchText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onSubmit {
                            Task {
                                await friendsService.searchUsers(query: searchText)
                            }
                        }
                        .onChange(of: searchText) { _, newValue in
                            if newValue.isEmpty {
                                friendsService.searchResults = []
                            }
                        }
                    
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                            friendsService.searchResults = []
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(12)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal)
                .padding(.top, 8)
                
                // Show search results or tabs
                if !searchText.isEmpty {
                    searchResultsView
                } else {
                    // Tab picker
                    Picker("", selection: $selectedTab) {
                        Text("Friends").tag(0)
                        Text("Requests").tag(1)
                        Text("Sent").tag(2)
                    }
                    .pickerStyle(.segmented)
                    .padding()
                    
                    // Tab content
                    TabView(selection: $selectedTab) {
                        friendsListView.tag(0)
                        incomingRequestsView.tag(1)
                        outgoingRequestsView.tag(2)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                }
            }
            .navigationTitle("Friends")
            .refreshable {
                await friendsService.refresh()
            }
        }
    }
    
    // MARK: - Search Results
    
    private var searchResultsView: some View {
        Group {
            if friendsService.isSearching {
                VStack {
                    Spacer()
                    ProgressView("Searching...")
                    Spacer()
                }
            } else if friendsService.searchResults.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "person.crop.circle.badge.questionmark")
                        .font(.system(size: 50))
                        .foregroundStyle(.secondary.opacity(0.5))
                    Text("No users found")
                        .foregroundStyle(.secondary)
                    Text("Try searching by email address")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            } else {
                List(friendsService.searchResults) { user in
                    SearchResultRow(user: user) {
                        await sendRequest(to: user)
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
    }
    
    // MARK: - Friends List
    
    private var friendsListView: some View {
        Group {
            if friendsService.friends.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "person.2")
                        .font(.system(size: 50))
                        .foregroundStyle(.secondary.opacity(0.5))
                    Text("No friends yet")
                        .foregroundStyle(.secondary)
                    Text("Search for friends to connect!")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            } else {
                List {
                    ForEach(friendsService.friends) { friendship in
                        FriendRow(
                            friendship: friendship,
                            currentUserId: authService.currentUser?.id ?? ""
                        ) {
                            await removeFriend(friendship)
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
    }
    
    // MARK: - Incoming Requests
    
    private var incomingRequestsView: some View {
        Group {
            if friendsService.incomingRequests.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "envelope.open")
                        .font(.system(size: 50))
                        .foregroundStyle(.secondary.opacity(0.5))
                    Text("No pending requests")
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            } else {
                List {
                    ForEach(friendsService.incomingRequests) { request in
                        IncomingRequestRow(request: request) {
                            await acceptRequest(request)
                        } onDecline: {
                            await declineRequest(request)
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
    }
    
    // MARK: - Outgoing Requests
    
    private var outgoingRequestsView: some View {
        Group {
            if friendsService.outgoingRequests.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "paperplane")
                        .font(.system(size: 50))
                        .foregroundStyle(.secondary.opacity(0.5))
                    Text("No sent requests")
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            } else {
                List {
                    ForEach(friendsService.outgoingRequests) { request in
                        OutgoingRequestRow(request: request) {
                            await cancelRequest(request)
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
    }
    
    // MARK: - Actions
    
    private func sendRequest(to user: UserSearchResult) async {
        guard let currentUser = authService.currentUser else { return }
        
        do {
            try await friendsService.sendFriendRequest(
                to: user,
                fromUser: (
                    id: currentUser.id,
                    name: currentUser.displayName ?? "Unknown",
                    email: currentUser.email
                )
            )
        } catch {
            print("😡 Failed to send request: \(error)")
        }
    }
    
    private func acceptRequest(_ request: FriendRequest) async {
        do {
            try await friendsService.acceptRequest(request)
        } catch {
            print("😡 Failed to accept request: \(error)")
        }
    }
    
    private func declineRequest(_ request: FriendRequest) async {
        do {
            try await friendsService.declineRequest(request)
        } catch {
            print("😡 Failed to decline request: \(error)")
        }
    }
    
    private func cancelRequest(_ request: FriendRequest) async {
        do {
            try await friendsService.cancelRequest(request)
        } catch {
            print("😡 Failed to cancel request: \(error)")
        }
    }
    
    private func removeFriend(_ friendship: Friendship) async {
        do {
            try await friendsService.removeFriend(friendship)
        } catch {
            print("😡 Failed to remove friend: \(error)")
        }
    }
}

// MARK: - Search Result Row

struct SearchResultRow: View {
    let user: UserSearchResult
    let onAdd: () async -> Void
    
    @State private var isLoading = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            Image(systemName: "person.circle.fill")
                .font(.system(size: 44))
                .foregroundStyle(.blue)
            
            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(user.displayName)
                    .font(.headline)
                Text(user.email)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Action button
            switch user.friendshipStatus {
            case .friends:
                Label("Friends", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
                
            case .pendingSent:
                Text("Pending")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
            case .pendingReceived:
                Text("Respond")
                    .font(.caption)
                    .foregroundStyle(.orange)
                
            case .none:
                Button {
                    isLoading = true
                    Task {
                        await onAdd()
                        isLoading = false
                    }
                } label: {
                    if isLoading {
                        ProgressView()
                            .frame(width: 60)
                    } else {
                        Text("Add")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                            .background(Color.blue)
                            .cornerRadius(16)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Friend Row

struct FriendRow: View {
    let friendship: Friendship
    let currentUserId: String
    let onRemove: () async -> Void
    
    @State private var showingRemoveAlert = false
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.circle.fill")
                .font(.system(size: 44))
                .foregroundStyle(.green)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(friendship.friendName(currentUserId: currentUserId) ?? "Friend")
                    .font(.headline)
                Text(friendship.friendEmail(currentUserId: currentUserId) ?? "")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                showingRemoveAlert = true
            } label: {
                Label("Remove", systemImage: "person.badge.minus")
            }
        }
        .alert("Remove Friend", isPresented: $showingRemoveAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Remove", role: .destructive) {
                Task { await onRemove() }
            }
        } message: {
            Text("Are you sure you want to remove \(friendship.friendName(currentUserId: currentUserId) ?? "this friend")?")
        }
    }
}

// MARK: - Incoming Request Row

struct IncomingRequestRow: View {
    let request: FriendRequest
    let onAccept: () async -> Void
    let onDecline: () async -> Void
    
    @State private var isLoading = false
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.circle.fill")
                .font(.system(size: 44))
                .foregroundStyle(.orange)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(request.fromUserName)
                    .font(.headline)
                Text(request.fromUserEmail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Wants to connect")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
            
            Spacer()
            
            if isLoading {
                ProgressView()
            } else {
                HStack(spacing: 8) {
                    Button {
                        isLoading = true
                        Task {
                            await onDecline()
                            isLoading = false
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.red)
                            .padding(10)
                            .background(Color(.systemGray5))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    
                    Button {
                        isLoading = true
                        Task {
                            await onAccept()
                            isLoading = false
                        }
                    } label: {
                        Image(systemName: "checkmark")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .padding(10)
                            .background(Color.green)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Outgoing Request Row

struct OutgoingRequestRow: View {
    let request: FriendRequest
    let onCancel: () async -> Void
    
    @State private var isLoading = false
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.circle.fill")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(request.toUserName)
                    .font(.headline)
                Text(request.toUserEmail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Pending...")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Button {
                isLoading = true
                Task {
                    await onCancel()
                    isLoading = false
                }
            } label: {
                if isLoading {
                    ProgressView()
                        .frame(width: 60)
                } else {
                    Text("Cancel")
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(.systemGray5))
                        .cornerRadius(12)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    FriendsView()
        .environmentObject(FriendsService())
        .environmentObject(AuthService())
}
