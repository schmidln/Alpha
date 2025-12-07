//
//  Message.swift
//  Alpha
//

import Foundation

struct Message: Identifiable, Codable {
    let id: UUID
    let role: Role
    let content: String
    let timestamp: Date
    
    init(id: UUID = UUID(), role: Role, content: String, timestamp: Date = Date()) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
    }
    
    enum Role: String, Codable {
        case user
        case assistant
        case system
    }
}

// MARK: - OpenAI API Format

extension Message {
    /// Converts to the format expected by OpenAI's API
    var asOpenAIMessage: [String: String] {
        ["role": role.rawValue, "content": content]
    }
}

extension Array where Element == Message {
    /// Converts conversation history to OpenAI format
    var asOpenAIMessages: [[String: String]] {
        map { $0.asOpenAIMessage }
    }
}
