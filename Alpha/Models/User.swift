//
//  User.swift
//  Alpha
//


import Foundation

struct AppUser: Codable {
    let id: String
    var email: String
    var phoneNumber: String?
    var displayName: String?
    var createdAt: Date
    var preferences: UserPreferences?
    
    init(
        id: String,
        email: String,
        phoneNumber: String? = nil,
        displayName: String? = nil,
        createdAt: Date = Date(),
        preferences: UserPreferences? = nil
    ) {
        self.id = id
        self.email = email
        self.phoneNumber = phoneNumber
        self.displayName = displayName
        self.createdAt = createdAt
        self.preferences = preferences
    }
}

struct UserPreferences: Codable {
    // Basic Info
    var nickname: String?
    var occupation: String?
    var location: String?
    
    // Communication Style
    var communicationStyle: CommunicationStyle
    var emailSignature: String?
    var emailSignOff: String?
    
    // AI Behavior
    var aiPersonality: AIPersonality
    var verbosity: Verbosity
    
    // Important Facts
    var importantFacts: [String]
    
    // Interests & Context
    var interests: [String]
    var workContext: String?
    
    init(
        nickname: String? = nil,
        occupation: String? = nil,
        location: String? = nil,
        communicationStyle: CommunicationStyle = .casual,
        emailSignature: String? = nil,
        emailSignOff: String? = "Best,",
        aiPersonality: AIPersonality = .friendly,
        verbosity: Verbosity = .balanced,
        importantFacts: [String] = [],
        interests: [String] = [],
        workContext: String? = nil
    ) {
        self.nickname = nickname
        self.occupation = occupation
        self.location = location
        self.communicationStyle = communicationStyle
        self.emailSignature = emailSignature
        self.emailSignOff = emailSignOff
        self.aiPersonality = aiPersonality
        self.verbosity = verbosity
        self.importantFacts = importantFacts
        self.interests = interests
        self.workContext = workContext
    }
}

enum CommunicationStyle: String, Codable, CaseIterable {
    case formal = "Formal"
    case casual = "Casual"
    case professional = "Professional"
    case friendly = "Friendly"
    
    var description: String {
        switch self {
        case .formal: return "Professional and polished language"
        case .casual: return "Relaxed and conversational"
        case .professional: return "Clear and business-appropriate"
        case .friendly: return "Warm and approachable"
        }
    }
}

enum AIPersonality: String, Codable, CaseIterable {
    case friendly = "Friendly Assistant"
    case professional = "Professional Assistant"
    case concise = "Concise & Direct"
    case enthusiastic = "Enthusiastic Helper"
    
    var description: String {
        switch self {
        case .friendly: return "Warm, helpful, and conversational"
        case .professional: return "Polished and business-like"
        case .concise: return "Brief, to-the-point responses"
        case .enthusiastic: return "Energetic and encouraging"
        }
    }
}

enum Verbosity: String, Codable, CaseIterable {
    case brief = "Brief"
    case balanced = "Balanced"
    case detailed = "Detailed"
}
