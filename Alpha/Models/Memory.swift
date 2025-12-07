//
//  Memory.swift
//  Alpha
//

import Foundation

struct ConversationMemory: Codable, Identifiable {
    let id: String
    let userId: String
    let timestamp: Date
    let summary: String
    let keyFacts: [String]
    let topics: [String]
}

struct MemoryStore: Codable {
    var memories: [ConversationMemory]
    var keyFacts: [String]  // Accumulated important facts
    var lastUpdated: Date
    
    init() {
        self.memories = []
        self.keyFacts = []
        self.lastUpdated = Date()
    }
}
