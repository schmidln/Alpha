//
//  OnboardingView.swift
//  Alpha
//
// Multi-step onboarding flow when a user first signs up.
// https://developer.apple.com/documentation/swiftui/appstorage
// https://docs.swift.org/swift-book/documentation/the-swift-programming-language/enumerations/
// https://firebase.google.com/docs/auth/ios/start
// https://developer.apple.com/documentation/swiftui/picker
// https://developer.apple.com/documentation/swiftui/securefield


import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var permissionsService: PermissionsService
    
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var currentStep: OnboardingStep = .welcome
    
    var body: some View {
        NavigationStack {
            Group {
                switch currentStep {
                case .welcome:
                    WelcomeStepView(onContinue: { currentStep = .auth })
                case .auth:
                    AuthStepView(onComplete: { currentStep = .userInfo })
                case .userInfo:
                    UserInfoStepView(onComplete: { currentStep = .personalization })
                case .personalization:
                    PersonalizationStepView(onComplete: { currentStep = .permissions })
                case .permissions:
                    PermissionsStepView(onComplete: { completeOnboarding() })
                case .complete:
                    // This shouldn't show, but just in case
                    ProgressView("Loading...")
                        .onAppear { completeOnboarding() }
                }
            }
        }
    }
    
    private func completeOnboarding() {
        hasCompletedOnboarding = true
    }
}

// MARK: - Onboarding Steps

enum OnboardingStep {
    case welcome
    case auth
    case userInfo
    case personalization
    case permissions
    case complete
}

// MARK: - Welcome Step

struct WelcomeStepView: View {
    let onContinue: () -> Void
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            Image(systemName: "sparkles")
                .font(.system(size: 80))
                .foregroundStyle(.blue)
            
            Text("Welcome to Alpha")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Your personal AI assistant that can send messages, manage your calendar, set reminders, and more.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Spacer()
            
            Button {
                onContinue()
            } label: {
                Text("Get Started")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }
}

// MARK: - Auth Step

struct AuthStepView: View {
    @EnvironmentObject var authService: AuthService
    let onComplete: () -> Void
    
    @State private var isSignUp = true
    @State private var email = ""
    @State private var password = ""
    @State private var displayName = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text(isSignUp ? "Create Account" : "Sign In")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                // Google Sign-In Button
                Button {
                    signInWithGoogle()
                } label: {
                    HStack {
                        Image(systemName: "g.circle.fill")
                            .font(.title2)
                        Text("Continue with Google")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGray6))
                    .foregroundStyle(.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, 24)
                
                // Divider
                HStack {
                    Rectangle()
                        .frame(height: 1)
                        .foregroundStyle(Color(.systemGray4))
                    
                    Text("or")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    Rectangle()
                        .frame(height: 1)
                        .foregroundStyle(Color(.systemGray4))
                }
                .padding(.horizontal, 24)
                
                // Email/Password Fields
                VStack(spacing: 16) {
                    if isSignUp {
                        TextField("Name", text: $displayName)
                            .textFieldStyle(.roundedBorder)
                            .textContentType(.name)
                    }
                    
                    TextField("Email", text: $email)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                    
                    SecureField("Password", text: $password)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(isSignUp ? .newPassword : .password)
                }
                .padding(.horizontal, 24)
                
                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal, 24)
                }
                
                Button {
                    authenticate()
                } label: {
                    if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding()
                    } else {
                        Text(isSignUp ? "Create Account" : "Sign In")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                }
                .background(Color.blue)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .disabled(isLoading || email.isEmpty || password.isEmpty)
                .padding(.horizontal, 24)
                
                Button {
                    isSignUp.toggle()
                    errorMessage = nil
                } label: {
                    Text(isSignUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up")
                        .font(.subheadline)
                }
                
                Spacer()
            }
            .padding(.top, 40)
        }
    }
    
    private func authenticate() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                if isSignUp {
                    try await authService.signUp(email: email, password: password, displayName: displayName.isEmpty ? nil : displayName)
                } else {
                    try await authService.signIn(email: email, password: password)
                }
                onComplete()
            } catch let error as NSError {
                print("Auth error: \(error)")
                
                switch error.code {
                case 17007:
                    errorMessage = "This email is already in use."
                case 17008:
                    errorMessage = "Invalid email address."
                case 17026:
                    errorMessage = "Password must be at least 6 characters."
                case 17009:
                    errorMessage = "Incorrect password."
                case 17011:
                    errorMessage = "No account found with this email."
                default:
                    errorMessage = error.localizedDescription
                }
            }
            isLoading = false
        }
    }
    
    private func signInWithGoogle() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                try await authService.signInWithGoogle()
                onComplete()
            } catch {
                print("Google sign-in error: \(error)")
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}

// MARK: - User Info Step

struct UserInfoStepView: View {
    @EnvironmentObject var authService: AuthService
    let onComplete: () -> Void
    
    @State private var phoneNumber = ""
    @State private var isLoading = false
    
    var body: some View {
        VStack(spacing: 24) {
            Text("Your Information")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Add your phone number so Alpha can send messages on your behalf.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Phone Number")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                TextField("+1 (555) 123-4567", text: $phoneNumber)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.telephoneNumber)
                    .keyboardType(.phonePad)
            }
            .padding(.horizontal, 24)
            
            Spacer()
            
            VStack(spacing: 12) {
                Button {
                    saveAndContinue()
                } label: {
                    if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding()
                    } else {
                        Text("Continue")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                }
                .background(Color.blue)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .disabled(isLoading)
                
                Button {
                    onComplete()
                } label: {
                    Text("Skip for now")
                        .font(.subheadline)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .padding(.top, 40)
    }
    
    private func saveAndContinue() {
        guard !phoneNumber.isEmpty else {
            onComplete()
            return
        }
        
        isLoading = true
        
        Task {
            try? await authService.updatePhoneNumber(phoneNumber)
            isLoading = false
            onComplete()
        }
    }
}

// MARK: - Permissions Step

struct PermissionsStepView: View {
    @EnvironmentObject var permissionsService: PermissionsService
    let onComplete: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Text("Permissions")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Alpha needs a few permissions to work its magic.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            VStack(spacing: 16) {
                
                PermissionRow(
                    icon: "bell",
                    title: "Notifications",
                    description: "To remind you of important things",
                    isGranted: permissionsService.notificationsGranted
                ) {
                    Task { await permissionsService.requestNotificationsPermission() }
                }
                
                PermissionRow(
                    icon: "mic",
                    title: "Microphone",
                    description: "To hear your voice commands",
                    isGranted: permissionsService.microphoneGranted
                ) {
                    Task { await permissionsService.requestMicrophonePermission() }
                }
                
                PermissionRow(
                    icon: "waveform",
                    title: "Speech Recognition",
                    description: "To understand what you say",
                    isGranted: permissionsService.speechRecognitionGranted
                ) {
                    Task { await permissionsService.requestSpeechRecognitionPermission() }
                }
                
                PermissionRow(
                    icon: "location",
                    title: "Location",
                    description: "For location-based assistance",
                    isGranted: permissionsService.locationGranted
                ) {
                    permissionsService.requestLocationPermission()
                }
            }
            .padding(.horizontal, 24)
            
            Spacer()
            
            Button {
                onComplete()
            } label: {
                Text("Continue")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .padding(.top, 40)
    }
}


// MARK: - Personalization Step

struct PersonalizationStepView: View {
    @EnvironmentObject var authService: AuthService
    let onComplete: () -> Void
    
    @State private var nickname = ""
    @State private var occupation = ""
    @State private var communicationStyle: CommunicationStyle = .casual
    @State private var aiPersonality: AIPersonality = .friendly
    @State private var verbosity: Verbosity = .balanced
    @State private var emailSignOff = "Best,"
    @State private var emailSignature = ""
    @State private var importantFact = ""
    @State private var importantFacts: [String] = []
    @State private var isLoading = false
    
    let signOffOptions = ["Best,", "Thanks,", "Cheers,", "Regards,", "Sincerely,", "Talk soon,"]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text("Personalize Alpha")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Help Alpha understand how you like to communicate.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                
                VStack(spacing: 20) {
                    // Nickname
                    VStack(alignment: .leading, spacing: 8) {
                        Text("What should Alpha call you?")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        TextField("Nickname (optional)", text: $nickname)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    // Occupation
                    VStack(alignment: .leading, spacing: 8) {
                        Text("What do you do?")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        TextField("e.g., Student, Software Engineer", text: $occupation)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    // Communication Style
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Communication Style")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        Picker("Style", selection: $communicationStyle) {
                            ForEach(CommunicationStyle.allCases, id: \.self) { style in
                                Text(style.rawValue).tag(style)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    
                    // AI Personality
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Alpha's Personality")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        Picker("Personality", selection: $aiPersonality) {
                            ForEach(AIPersonality.allCases, id: \.self) { personality in
                                Text(personality.rawValue).tag(personality)
                            }
                        }
                        .pickerStyle(.menu)
                        
                        Text(aiPersonality.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    // Verbosity
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Response Length")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        Picker("Verbosity", selection: $verbosity) {
                            ForEach(Verbosity.allCases, id: \.self) { v in
                                Text(v.rawValue).tag(v)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    
                    // Email Sign Off
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Email Sign-Off")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        Picker("Sign Off", selection: $emailSignOff) {
                            ForEach(signOffOptions, id: \.self) { option in
                                Text(option).tag(option)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    
                    // Email Signature
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Email Signature (optional)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        TextField("e.g., John Smith | Acme Corp", text: $emailSignature)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    // Important Facts
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Things Alpha should know about you")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        HStack {
                            TextField("e.g., I'm allergic to shellfish", text: $importantFact)
                                .textFieldStyle(.roundedBorder)
                            
                            Button {
                                if !importantFact.isEmpty {
                                    importantFacts.append(importantFact)
                                    importantFact = ""
                                }
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title2)
                            }
                            .disabled(importantFact.isEmpty)
                        }
                        
                        ForEach(importantFacts, id: \.self) { fact in
                            HStack {
                                Text("• \(fact)")
                                    .font(.caption)
                                
                                Spacer()
                                
                                Button {
                                    importantFacts.removeAll { $0 == fact }
                                } label: {
                                    Image(systemName: "xmark.circle")
                                        .foregroundStyle(.red)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
                
                Spacer().frame(height: 20)
                
                VStack(spacing: 12) {
                    Button {
                        saveAndContinue()
                    } label: {
                        if isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding()
                        } else {
                            Text("Continue")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                        }
                    }
                    .background(Color.blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    
                    Button {
                        onComplete()
                    } label: {
                        Text("Skip for now")
                            .font(.subheadline)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
            .padding(.top, 20)
        }
    }
    
    private func saveAndContinue() {
        isLoading = true
        
        var preferences = UserPreferences()
        preferences.nickname = nickname.isEmpty ? nil : nickname
        preferences.occupation = occupation.isEmpty ? nil : occupation
        preferences.communicationStyle = communicationStyle
        preferences.emailSignature = emailSignature.isEmpty ? nil : emailSignature
        preferences.emailSignOff = emailSignOff
        preferences.aiPersonality = aiPersonality
        preferences.verbosity = verbosity
        preferences.importantFacts = importantFacts
        
        Task {
            try? await authService.updatePreferences(preferences)
            isLoading = false
            onComplete()
        }
    }
}



// MARK: - Permission Row

struct PermissionRow: View {
    let icon: String
    let title: String
    let description: String
    let isGranted: Bool
    let onRequest: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .frame(width: 32)
                .foregroundStyle(isGranted ? .green : .blue)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            if isGranted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                Button("Allow") {
                    onRequest()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    OnboardingView()
        .environmentObject(AuthService())
        .environmentObject(PermissionsService())
}

