//
//  PerplexityService.swift
//  Alpha
//
// This code offers my app the ability to search the web through perplexity. I chose perplexity since at the time of writing their AI API was the preffered choice for web searching.
// https://docs.perplexity.ai/api-reference/chat-completions-post
// https://developer.apple.com/documentation/foundation/urlsession
// https://developer.apple.com/documentation/foundation/localizederror


import Foundation
import Combine

@MainActor
class PerplexityService: ObservableObject {
    @Published var isSearching = false
    
    private let apiKey: String
    private let baseURL = "https://api.perplexity.ai/chat/completions"
    private let model = "sonar"
    
    init() {
        self.apiKey = Config.perplexityAPIKey
    }
    
    // MARK: - Search
    
    func search(query: String) async throws -> String {
        isSearching = true
        defer { isSearching = false }
        
        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "model": model,
            "messages": [
                [
                    "role": "system",
                    "content": searchSystemPrompt
                ],
                [
                    "role": "user",
                    "content": query
                ]
            ],
            "max_tokens": 1024,
            "temperature": 0.2,
            "return_citations": true
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw PerplexityError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw PerplexityError.apiError(statusCode: httpResponse.statusCode, message: errorBody)
        }
        
        return try parseResponse(data)
    }
    
    // MARK: - Specialized Searches
    
    func searchFlights(from origin: String, to destination: String, date: String) async throws -> String {
        let query = "Find flights from \(origin) to \(destination) on \(date). Include airlines, prices, and departure times."
        return try await search(query: query)
    }
    
    func searchRestaurants(cuisine: String?, location: String, priceRange: String? = nil) async throws -> String {
        var query = "Find"
        if let cuisine = cuisine {
            query += " \(cuisine)"
        }
        query += " restaurants in \(location)"
        if let priceRange = priceRange {
            query += " with \(priceRange) price range"
        }
        query += ". Include ratings, addresses, and price estimates."
        return try await search(query: query)
    }
    
    func searchProducts(product: String, requirements: String? = nil) async throws -> String {
        var query = "Find \(product) available for purchase"
        if let requirements = requirements {
            query += " with these requirements: \(requirements)"
        }
        query += ". Include prices, ratings, and where to buy."
        return try await search(query: query)
    }
    
    // MARK: - Parse Response
    
    private func parseResponse(_ data: Data) throws -> String {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw PerplexityError.parsingError
        }
        
        // Optionally append citations if available
        var result = content
        
        if let citations = json["citations"] as? [String] {
            result += "\n\nSources:\n"
            for (index, citation) in citations.prefix(5).enumerated() {
                result += "\(index + 1). \(citation)\n"
            }
        }
        
        return result
    }
    
    // MARK: - System Prompt
    
    private var searchSystemPrompt: String {
        """
        You are a search assistant providing accurate, current information. 
        
        Guidelines:
        - Be concise and factual
        - Include specific details like prices, times, ratings when available
        - Format information clearly for easy reading
        - If information might be outdated, mention that the user should verify
        - Focus on actionable information the user can use
        
        Current date: \(Date().formatted(date: .complete, time: .omitted))
        """
    }
}

// MARK: - Errors

enum PerplexityError: LocalizedError {
    case invalidResponse
    case parsingError
    case apiError(statusCode: Int, message: String)
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from Perplexity"
        case .parsingError:
            return "Failed to parse search results"
        case .apiError(let statusCode, let message):
            return "Search error (\(statusCode)): \(message)"
        }
    }
}
