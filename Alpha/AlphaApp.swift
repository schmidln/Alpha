//
//  AlphaApp.swift
//  Alpha
//
// Used to have FirebaseService in this app for Email and SMS sends - I removed it for now

import SwiftUI
import FirebaseCore

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()
        return true
    }
}

@main
struct AlphaApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    @StateObject private var authService = AuthService()
    @StateObject private var permissionsService = PermissionsService()
    @StateObject private var openAIService = OpenAIService()
    @StateObject private var perplexityService = PerplexityService()
    @StateObject private var remindersService = RemindersService()
    @StateObject private var calendarService = CalendarService()
    @StateObject private var memoryService = MemoryService()
    @StateObject private var activityService = ActivityService()
    @StateObject private var friendsService = FriendsService()
    @StateObject private var sharedRemindersService = SharedRemindersService()
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authService)
                .environmentObject(permissionsService)
                .environmentObject(openAIService)
                .environmentObject(perplexityService)
                .environmentObject(remindersService)
                .environmentObject(calendarService)
                .environmentObject(memoryService)
                .environmentObject(activityService)
                .environmentObject(friendsService)
                .environmentObject(sharedRemindersService)
                .onAppear {
                    wireServices()
                }
                .onChange(of: authService.googleAccessToken) { _, token in
                    if let token = token {
                        Task {
                            calendarService.configureGoogle(accessToken: token)
                        }
                    }
                }
                .onChange(of: authService.currentUser?.id) { _, userId in
                    if let userId = userId {
                        let userName = authService.currentUser?.displayName ?? "Unknown"
                        memoryService.configure(userId: userId)
                        activityService.configure(userId: userId)
                        remindersService.configure(userId: userId)
                        friendsService.configure(userId: userId)
                        sharedRemindersService.configure(userId: userId, userName: userName)
                    }
                }
        }
    }
    
    private func wireServices() {
        let openAI = openAIService
        openAI.remindersService = remindersService
        openAI.calendarService = calendarService
        openAI.perplexityService = perplexityService
        openAI.authService = authService
        openAI.memoryService = memoryService
        
        if let userId = authService.currentUser?.id {
            let userName = authService.currentUser?.displayName ?? "Unknown"
            memoryService.configure(userId: userId)
            activityService.configure(userId: userId)
            remindersService.configure(userId: userId)
            friendsService.configure(userId: userId)
            sharedRemindersService.configure(userId: userId, userName: userName)
        }
    }
}

struct RootView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var permissionsService: PermissionsService
    
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    
    var body: some View {
        Group {
            if authService.isLoading {
                ProgressView("Loading...")
            } else if !authService.isAuthenticated || !hasCompletedOnboarding {
                OnboardingView()
            } else {
                MainTabView()
            }
        }
    }
}
