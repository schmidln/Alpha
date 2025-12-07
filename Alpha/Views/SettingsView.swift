//
//  SettingsView.swift
//  Alpha
//


import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var openAIService: OpenAIService
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    
    @State private var showPreferences = false
    @State private var showChat = false
    @State private var showVoice = false
    
    var body: some View {
        List {
            // Profile Section
            Section {
                HStack(spacing: 16) {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(.blue)
                    
                    VStack(alignment: .leading) {
                        Text(authService.currentUser?.displayName ?? "User")
                            .font(.headline)
                        
                        Text(authService.currentUser?.email ?? "")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        if let phone = authService.currentUser?.phoneNumber {
                            Text(phone)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.vertical, 8)
            }
            
            // Alpha Number Section
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Label("WhatsApp Alpha", systemImage: "bubble.left.fill")
                        .font(.headline)
                    
                    Text("+1 (415) 523-8886")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(.blue)
                    
                    Text("Message this number on WhatsApp to interact with Alpha")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            } header: {
                Text("Your Alpha Number")
            }
            
            // Preferences Section
            Section {
                Button {
                    showPreferences = true
                } label: {
                    Label("AI Preferences", systemImage: "slider.horizontal.3")
                        .foregroundStyle(.primary)
                }
                
                Button {
                    showChat = true
                } label: {
                    Label("Chat with Alpha", systemImage: "message")
                        .foregroundStyle(.primary)
                }
            } header: {
                Text("Features")
            }
            
            // Account Section
            Section {
                Button(role: .destructive) {
                    signOut()
                } label: {
                    Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                }
            }
            
            // App Info
            Section {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("1.0.0")
                        .foregroundStyle(.secondary)
                }
            } footer: {
                Text("Alpha - Your AI Assistant")
                    .frame(maxWidth: .infinity)
                    .padding(.top, 20)
            }
        }
        .navigationTitle("Settings")
        .sheet(isPresented: $showPreferences) {
            NavigationStack {
                PreferencesView()
                    .environmentObject(authService)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Done") { showPreferences = false }
                        }
                    }
            }
        }
        .sheet(isPresented: $showChat) {
            NavigationStack {
                ChatView()
                    .environmentObject(openAIService)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Done") { showChat = false }
                        }
                    }
            }
        }
        .sheet(isPresented: $showVoice) {
            NavigationStack {
                VoiceView()
                    .environmentObject(openAIService)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Done") { showVoice = false }
                        }
                    }
            }
        }
    }
    
    private func signOut() {
        try? authService.signOut()
        hasCompletedOnboarding = false
    }
}

// MARK: - Preferences View

struct PreferencesView: View {
    @EnvironmentObject var authService: AuthService
    
    @State private var nickname = ""
    @State private var occupation = ""
    @State private var communicationStyle: CommunicationStyle = .casual
    @State private var aiPersonality: AIPersonality = .friendly
    @State private var verbosity: Verbosity = .balanced
    @State private var emailSignOff = "Best,"
    @State private var isSaving = false
    
    let signOffOptions = ["Best,", "Thanks,", "Cheers,", "Regards,", "Sincerely,", "Talk soon,"]
    
    var body: some View {
        Form {
            Section("About You") {
                TextField("Nickname", text: $nickname)
                TextField("Occupation", text: $occupation)
            }
            
            Section("Communication") {
                Picker("Style", selection: $communicationStyle) {
                    ForEach(CommunicationStyle.allCases, id: \.self) { style in
                        Text(style.rawValue).tag(style)
                    }
                }
                
                Picker("Email Sign-Off", selection: $emailSignOff) {
                    ForEach(signOffOptions, id: \.self) { option in
                        Text(option).tag(option)
                    }
                }
            }
            
            Section("Alpha's Behavior") {
                Picker("Personality", selection: $aiPersonality) {
                    ForEach(AIPersonality.allCases, id: \.self) { p in
                        Text(p.rawValue).tag(p)
                    }
                }
                
                Picker("Response Length", selection: $verbosity) {
                    ForEach(Verbosity.allCases, id: \.self) { v in
                        Text(v.rawValue).tag(v)
                    }
                }
            }
            
            Section {
                Button {
                    savePreferences()
                } label: {
                    if isSaving {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Save Preferences")
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .navigationTitle("Preferences")
        .onAppear {
            loadPreferences()
        }
    }
    
    private func loadPreferences() {
        guard let prefs = authService.currentUser?.preferences else { return }
        
        nickname = prefs.nickname ?? ""
        occupation = prefs.occupation ?? ""
        communicationStyle = prefs.communicationStyle
        aiPersonality = prefs.aiPersonality
        verbosity = prefs.verbosity
        emailSignOff = prefs.emailSignOff ?? "Best,"
    }
    
    private func savePreferences() {
        isSaving = true
        
        var preferences = UserPreferences()
        preferences.nickname = nickname.isEmpty ? nil : nickname
        preferences.occupation = occupation.isEmpty ? nil : occupation
        preferences.communicationStyle = communicationStyle
        preferences.aiPersonality = aiPersonality
        preferences.verbosity = verbosity
        preferences.emailSignOff = emailSignOff
        
        Task {
            try? await authService.updatePreferences(preferences)
            isSaving = false
        }
    }
}

#Preview {
    SettingsView()
}
