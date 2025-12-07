//
//  MemoryService.swift
//  Alpha
//
// Goal of this file is to allow for context to be passed into the AI across different conversations.
// https://firebase.google.com/docs/firestore/query-data/get-data#get_a_document
// https://developer.apple.com/documentation/foundation/jsonencoder
// https://developer.apple.com/documentation/swift/array
// https://platform.openai.com/docs/guides/conversation-state?api-mode=responses
// https://developer.apple.com/documentation/foundation/date/formatted(date:time:)

import Foundation
import Combine
import FirebaseFirestore

@MainActor
class MemoryService: ObservableObject {
    @Published var memoryStore: MemoryStore = MemoryStore()
    @Published var isLoading = false
    
    private let db = Firestore.firestore()
    private var userId: String?
    
    // Keep last N conversation summaries
    private let maxMemories = 50
    
    func configure(userId: String) {
        self.userId = userId
        Task {
            await loadMemories()
        }
    }
    
    // MARK: - Load Memories
    
    func loadMemories() async {
        guard let userId = userId else { return }
        isLoading = true
        defer { isLoading = false }
        
        do {
            let document = try await db.collection("memories").document(userId).getDocument()
            
            if let data = document.data(),
               let jsonData = try? JSONSerialization.data(withJSONObject: data),
               let store = try? JSONDecoder().decode(MemoryStore.self, from: jsonData) {
                memoryStore = store
            }
        } catch {
            print("Error loading memories: \(error)")
        }
    }
    
    // MARK: - Save Conversation Summary
    
    func saveConversationSummary(summary: String, keyFacts: [String], topics: [String]) async {
        guard let userId = userId else { return }
        
        let memory = ConversationMemory(
            id: UUID().uuidString,
            userId: userId,
            timestamp: Date(),
            summary: summary,
            keyFacts: keyFacts,
            topics: topics
        )
        
        // Add new memory
        memoryStore.memories.append(memory)
        
        // Add new key facts (avoid duplicates)
        for fact in keyFacts {
            if !memoryStore.keyFacts.contains(fact) {
                memoryStore.keyFacts.append(fact)
            }
        }
        
        // Trim old memories if needed
        if memoryStore.memories.count > maxMemories {
            memoryStore.memories = Array(memoryStore.memories.suffix(maxMemories))
        }
        
        // Limit key facts
        if memoryStore.keyFacts.count > 100 {
            memoryStore.keyFacts = Array(memoryStore.keyFacts.suffix(100))
        }
        
        memoryStore.lastUpdated = Date()
        
        await saveToFirestore()
    }
    
    // MARK: - Add Key Fact
    
    func addKeyFact(_ fact: String) async {
        guard !memoryStore.keyFacts.contains(fact) else { return }
        memoryStore.keyFacts.append(fact)
        await saveToFirestore()
    }
    
    // MARK: - Save to Firestore
    
    private func saveToFirestore() async {
        guard let userId = userId else { return }
        
        do {
            let data = try JSONEncoder().encode(memoryStore)
            let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
            try await db.collection("memories").document(userId).setData(dict)
        } catch {
            print("Error saving memories: \(error)")
        }
    }
    
    // MARK: - Get Context for Prompt
    
    func getMemoryContext() -> String {
        var context = ""
        
        // Add key facts
        if !memoryStore.keyFacts.isEmpty {
            context += "Key facts about the user:\n"
            for fact in memoryStore.keyFacts.suffix(20) {
                context += "- \(fact)\n"
            }
            context += "\n"
        }
        
        // Add recent conversation summaries
        let recentMemories = memoryStore.memories.suffix(5)
        if !recentMemories.isEmpty {
            context += "Recent conversation summaries:\n"
            for memory in recentMemories {
                let dateStr = memory.timestamp.formatted(date: .abbreviated, time: .omitted)
                context += "[\(dateStr)] \(memory.summary)\n"
            }
        }
        
        return context
    }
}
