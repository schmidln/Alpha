//
//  AuthService.swift
//  Alpha
//

import Foundation
import Combine
import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
import GoogleSignIn

@MainActor
class AuthService: ObservableObject {
    @Published var currentUser: AppUser?
    @Published var isAuthenticated = false
    @Published var isLoading = true
    @Published var errorMessage: String?
    @Published var googleAccessToken: String?
    
    private let auth = Auth.auth()
    private let db = Firestore.firestore()
    private var authStateListener: AuthStateDidChangeListenerHandle?
    
    init() {
        setupAuthListener()
    }
    
    deinit {
        if let listener = authStateListener {
            auth.removeStateDidChangeListener(listener)
        }
    }
    
    // MARK: - Auth State Listener
    
    private func setupAuthListener() {
        authStateListener = auth.addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor [weak self] in
                if let user = user {
                    await self?.fetchUserData(userId: user.uid)
                    self?.isAuthenticated = true
                } else {
                    self?.currentUser = nil
                    self?.isAuthenticated = false
                }
                self?.isLoading = false
            }
        }
    }
    
    // MARK: - Email/Password Sign Up
    
    func signUp(email: String, password: String, displayName: String?) async throws {
        errorMessage = nil
        
        let result = try await auth.createUser(withEmail: email, password: password)
        
        let newUser = AppUser(
            id: result.user.uid,
            email: email,
            displayName: displayName
        )
        
        try await saveUserData(newUser)
        currentUser = newUser
        isAuthenticated = true
    }
    
    // MARK: - Email/Password Sign In
    
    func signIn(email: String, password: String) async throws {
        errorMessage = nil
        
        let result = try await auth.signIn(withEmail: email, password: password)
        await fetchUserData(userId: result.user.uid)
        isAuthenticated = true
    }
    
    // MARK: - Google Sign In - I added google sign in after realizing that I needed a paid Apple Developer account for Apple Sign In
    // This one was a little harder to integrate
    
    func signInWithGoogle() async throws {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            throw AuthError.missingClientID
        }
        
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            throw AuthError.missingRootViewController
        }
        
        let result = try await GIDSignIn.sharedInstance.signIn(
            withPresenting: rootViewController,
            hint: nil,
            additionalScopes: [
                "https://www.googleapis.com/auth/contacts.readonly",
                "https://www.googleapis.com/auth/calendar",
                "https://www.googleapis.com/auth/calendar.events"
            ]
        )
        
        guard let idToken = result.user.idToken?.tokenString else {
            throw AuthError.missingIDToken
        }
        
        googleAccessToken = result.user.accessToken.tokenString
        
        let credential = GoogleAuthProvider.credential(
            withIDToken: idToken,
            accessToken: result.user.accessToken.tokenString
        )
        
        let authResult = try await auth.signIn(with: credential)
        
        let newUser = AppUser(
            id: authResult.user.uid,
            email: authResult.user.email ?? "",
            displayName: authResult.user.displayName
        )
        
        try await saveUserData(newUser)
        currentUser = newUser
        isAuthenticated = true
    }
    
    // MARK: - Sign Out
    
    func signOut() throws {
        try auth.signOut()
        GIDSignIn.sharedInstance.signOut()
        currentUser = nil
        isAuthenticated = false
        googleAccessToken = nil
    }
    
    // MARK: - Update User Info
    
    func updatePhoneNumber(_ phoneNumber: String) async throws {
        guard var user = currentUser else { return }
        
        user.phoneNumber = phoneNumber
        try await saveUserData(user)
        currentUser = user
    }
    
    func updateDisplayName(_ displayName: String) async throws {
        guard var user = currentUser else { return }
        
        user.displayName = displayName
        try await saveUserData(user)
        currentUser = user
    }
    
    func updatePreferences(_ preferences: UserPreferences) async throws {
        guard var user = currentUser else { return }
        
        user.preferences = preferences
        try await saveUserData(user)
        currentUser = user
    }
    
    // MARK: - Firestore Operations
    
    private func saveUserData(_ user: AppUser) async throws {
        var data: [String: Any] = [
            "id": user.id,
            "email": user.email,
            "phoneNumber": user.phoneNumber ?? "",
            "displayName": user.displayName ?? "",
            "createdAt": Timestamp(date: user.createdAt)
        ]
        
        if let preferences = user.preferences,
           let prefsData = try? JSONEncoder().encode(preferences),
           let prefsDict = try? JSONSerialization.jsonObject(with: prefsData) as? [String: Any] {
            data["preferences"] = prefsDict
        }
        
        try await db.collection("users").document(user.id).setData(data, merge: true)
    }
    
    private func fetchUserData(userId: String) async {
        do {
            let document = try await db.collection("users").document(userId).getDocument()
            
            if let data = document.data() {
                var preferences: UserPreferences? = nil
                
                if let prefsData = data["preferences"] as? [String: Any],
                   let jsonData = try? JSONSerialization.data(withJSONObject: prefsData),
                   let prefs = try? JSONDecoder().decode(UserPreferences.self, from: jsonData) {
                    preferences = prefs
                }
                
                currentUser = AppUser(
                    id: userId,
                    email: data["email"] as? String ?? "",
                    phoneNumber: data["phoneNumber"] as? String,
                    displayName: data["displayName"] as? String,
                    preferences: preferences
                )
            }
        } catch {
            print("Error fetching user data: \(error)")
        }
    }
}

// MARK: - Errors

enum AuthError: LocalizedError {
    case missingClientID
    case missingRootViewController
    case missingIDToken
    
    var errorDescription: String? {
        switch self {
        case .missingClientID:
            return "Google Sign-In configuration error."
        case .missingRootViewController:
            return "Unable to present sign-in screen."
        case .missingIDToken:
            return "Failed to get ID token from Google."
        }
    }
}
