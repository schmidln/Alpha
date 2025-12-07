//
//  ActivityFeedView.swift
//  Alpha
//
// A View that shows all past conversations with AI - loading more, as we learned in class, when needed
// https://developer.apple.com/documentation/swiftui/list
// https://developer.apple.com/documentation/swiftui/view/refreshable(action:)
// https://developer.apple.com/documentation/swiftui/text/init(_:style:)
// https://developer.apple.com/documentation/swiftui/view/sheet(ispresented:ondismiss:content:)


import SwiftUI

struct ActivityFeedView: View {
    @EnvironmentObject var activityService: ActivityService
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var openAIService: OpenAIService
    @State private var showingChat = false
    
    var body: some View {
        NavigationStack {
            Group {
                if activityService.activities.isEmpty && !activityService.isLoading {
                    EmptyActivityView(showingChat: $showingChat)
                } else {
                    List {
                        ForEach(activityService.activities) { activity in
                            ActivityRow(activity: activity)
                                .onAppear {
                                    // Load more when reaching the last 3 items
                                    if activity.id == activityService.activities.suffix(3).first?.id {
                                        Task {
                                            await activityService.loadMore()
                                        }
                                    }
                                }
                        }
                        
                        // Loading indicator at bottom
                        if activityService.isLoadingMore {
                            HStack {
                                Spacer()
                                ProgressView()
                                    .padding()
                                Spacer()
                            }
                            .listRowSeparator(.hidden)
                        }
                        
                        // End of list indicator
                        if !activityService.hasMoreActivities && !activityService.activities.isEmpty {
                            HStack {
                                Spacer()
                                Text("You've reached the beginning")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .padding()
                                Spacer()
                            }
                            .listRowSeparator(.hidden)
                        }
                    }
                    .listStyle(.insetGrouped)
                    .refreshable {
                        await activityService.refresh()
                    }
                    .overlay {
                        // Floating chat button - only when there are activities
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                Button {
                                    showingChat = true
                                } label: {
                                    Image(systemName: "message.fill")
                                        .font(.title2)
                                        .foregroundStyle(.white)
                                        .frame(width: 60, height: 60)
                                        .background(Color.blue)
                                        .clipShape(Circle())
                                        .shadow(radius: 4)
                                }
                                .padding()
                            }
                        }
                    }
                }
            }
            .navigationTitle("Activity")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(destination: SettingsView()
                        .environmentObject(authService)
                        .environmentObject(openAIService)
                    ) {
                        Image(systemName: "gearshape.fill")
                            .foregroundStyle(.gray)
                    }
                }
            }
            .sheet(isPresented: $showingChat) {
                NavigationStack {
                    ChatView()
                        .environmentObject(openAIService)
                        .navigationTitle("Chat with Alpha")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                Button("Done") {
                                    showingChat = false
                                }
                            }
                        }
                }
            }
        }
    }
}

// MARK: - Empty State

struct EmptyActivityView: View {
    @Binding var showingChat: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.system(size: 70))
                .foregroundStyle(.blue.opacity(0.5))
            
            Text("No Activity Yet")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Message Alpha on WhatsApp to get started!")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            Button {
                showingChat = true
            } label: {
                Label("Chat with Alpha", systemImage: "message.fill")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .clipShape(Capsule())
            }
            .padding(.top, 8)
            
            Spacer()
        }
        .padding()
    }
}

// MARK: - Activity Row

struct ActivityRow: View {
    let activity: Activity
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: activity.icon)
                    .foregroundStyle(.blue)
                    .frame(width: 24)
                
                Text(activity.title)
                    .font(.headline)
                
                Spacer()
                
                Text(activity.timestamp, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            if let userMessage = activity.userMessage, !userMessage.isEmpty {
                HStack(alignment: .top, spacing: 4) {
                    Text("You:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 40, alignment: .leading)
                    Text(userMessage)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                }
            }
            
            if let response = activity.assistantResponse, !response.isEmpty {
                HStack(alignment: .top, spacing: 4) {
                    Text("Alpha:")
                        .font(.caption)
                        .foregroundStyle(.blue)
                        .frame(width: 40, alignment: .leading)
                    Text(response)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                }
            }
            
            // Source badge
            HStack {
                Image(systemName: activity.sourceIcon)
                    .font(.caption2)
                Text(activity.source.capitalized)
                    .font(.caption2)
            }
            .foregroundStyle(.secondary)
            .padding(.top, 4)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ActivityFeedView()
        .environmentObject(ActivityService())
}
