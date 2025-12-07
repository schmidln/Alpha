//
//  OpenAIService.swift
//  Alpha
//
// This is the brain of the app in essence. This is where messages are sent to OpenAI. Additionally, this portion of the app handles the AI's decision to call tools, execute those tools locally, and return the final response to the user. This file is designed for the IOS in-app chat. It does the same thing as my Node.js backend which handles these functions for the WhatsApp integration.
// https://platform.openai.com/docs/api-reference/chat/create
// https://platform.openai.com/docs/guides/function-calling
// https://developer.apple.com/documentation/foundation/urlsession
// https://developer.apple.com/documentation/foundation/jsonserialization
// https://developer.apple.com/documentation/foundation/iso8601dateformatter


import Foundation
import Combine

@MainActor
class OpenAIService: ObservableObject {
    @Published var isProcessing = false
    
    private let apiKey: String
    private let baseURL = "https://api.openai.com/v1/chat/completions"
    private let model = "gpt-4o"
    
    // Reference to other services for tool execution
    var remindersService: RemindersService?
    var calendarService: CalendarService?
    var perplexityService: PerplexityService?
    var authService: AuthService?
    var memoryService: MemoryService?
    
    init() {
        self.apiKey = Config.openAIAPIKey
    }
    
    // MARK: - Main Send Message
    
    func sendMessage(_ userMessage: String, conversationHistory: [Message]) async throws -> String {
        isProcessing = true
        defer { isProcessing = false }
        
        var messages = buildMessages(userMessage: userMessage, history: conversationHistory)
        
        // Loop to handle multiple tool calls if needed
        var iterations = 0
        let maxIterations = 5 // Prevent infinite loops
        
        while iterations < maxIterations {
            let response = try await makeAPICall(messages: messages)
            
            // Check if the model wants to use tools
            if let toolCalls = response.toolCalls, !toolCalls.isEmpty {
                // Add assistant's response with tool calls
                messages.append([
                    "role": "assistant",
                    "content": response.content ?? "",
                    "tool_calls": toolCalls.map { $0.asDictionary }
                ])
                
                // Execute each tool and add results
                for toolCall in toolCalls {
                    let result = await executeToolCall(toolCall)
                    messages.append([
                        "role": "tool",
                        "tool_call_id": toolCall.id,
                        "content": result
                    ])
                }
                
                iterations += 1
            } else {
                // No tool calls, return the final response
                return response.content ?? "I'm not sure how to respond to that."
            }
        }
        
        return "I had trouble completing that request. Please try again."
    }
    
    // MARK: - Build Messages
    
    private func buildMessages(userMessage: String, history: [Message]) -> [[String: Any]] {
        var messages: [[String: Any]] = []
        
        // System prompt
        messages.append([
            "role": "system",
            "content": systemPrompt
        ])
        
        // Conversation history
        for message in history.suffix(20) { // Keep last 20 messages for context
            messages.append([
                "role": message.role.rawValue,
                "content": message.content
            ])
        }
        
        // Current user message
        messages.append([
            "role": "user",
            "content": userMessage
        ])
        
        return messages
    }
    
    // MARK: - API Call
    
    private func makeAPICall(messages: [[String: Any]]) async throws -> OpenAIResponse {
        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "model": model,
            "messages": messages,
            "tools": ToolDefinitions.allTools,
            "tool_choice": "auto"
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw OpenAIError.apiError(statusCode: httpResponse.statusCode, message: errorBody)
        }
        
        return try parseResponse(data)
    }
    
    // MARK: - Parse Response
    
    private func parseResponse(_ data: Data) throws -> OpenAIResponse {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any] else {
            throw OpenAIError.parsingError
        }
        
        let content = message["content"] as? String
        
        var toolCalls: [ToolCall]? = nil
        if let toolCallsData = message["tool_calls"] as? [[String: Any]] {
            toolCalls = toolCallsData.compactMap { ToolCall(from: $0) }
        }
        
        return OpenAIResponse(content: content, toolCalls: toolCalls)
    }
    
    // MARK: - Tool Execution
    
    private func executeToolCall(_ toolCall: ToolCall) async -> String {
        switch toolCall.function.name {
        case "search_web":
            return await executeWebSearch(arguments: toolCall.function.arguments)
        case "create_reminder":
            return await executeCreateReminder(arguments: toolCall.function.arguments)
        case "create_calendar_event":
            return await executeCreateCalendarEvent(arguments: toolCall.function.arguments)
        case "get_calendar_events":
            return await executeGetCalendarEvents(arguments: toolCall.function.arguments)
        case "update_calendar_event":
            return await executeUpdateCalendarEvent(arguments: toolCall.function.arguments)
        case "delete_calendar_event":
            return await executeDeleteCalendarEvent(arguments: toolCall.function.arguments)
        default:
            return "Unknown tool: \(toolCall.function.name)"
        }
    }
    
    // MARK: - Tool Implementations
    
    private func executeWebSearch(arguments: [String: Any]) async -> String {
        guard let query = arguments["query"] as? String else {
            return "Error: Missing search query"
        }
        
        guard let perplexityService = perplexityService else {
            return "Error: Search service not configured"
        }
        
        do {
            return try await perplexityService.search(query: query)
        } catch {
            return "Error searching: \(error.localizedDescription)"
        }
    }
    
    
    private func executeCreateReminder(arguments: [String: Any]) async -> String {
        guard let title = arguments["title"] as? String else {
            return "Error: Missing reminder title"
        }
        
        let dueDate = (arguments["due_date"] as? String).flatMap { ISO8601DateFormatter().date(from: $0) }
        let notes = arguments["notes"] as? String
        let isRecurring = arguments["is_recurring"] as? Bool ?? false
        let recurrenceInterval = arguments["recurrence_interval"] as? String  // Now a string
        
        guard let remindersService = remindersService else {
            return "Error: Reminders service not configured"
        }
        
        do {
            try await remindersService.createReminder(
                title: title,
                notes: notes,
                dueDate: dueDate,
                isRecurring: isRecurring,
                recurrenceInterval: recurrenceInterval
            )
            
            var response = "Successfully created reminder: \(title)"
            if let dueDate = dueDate {
                response += " for \(dueDate.formatted())"
            }
            if isRecurring, let interval = recurrenceInterval {
                response += " (recurring \(interval))"
            }
            return response
        } catch {
            return "Error creating reminder: \(error.localizedDescription)"
        }
    }
    
    
    private func executeGetCalendarEvents(arguments: [String: Any]) async -> String {
        guard let calendarService = calendarService else {
            return "Error: Calendar service not configured"
        }
        
        do {
            let events: [CalendarEvent]
            
            if let searchQuery = arguments["search_query"] as? String, !searchQuery.isEmpty {
                events = try await calendarService.searchEvents(query: searchQuery)
            } else {
                await calendarService.refreshEvents()
                events = calendarService.upcomingEvents
            }
            
            if events.isEmpty {
                return "No upcoming events found."
            }
            
            var result = "Upcoming events:\n"
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            dateFormatter.timeStyle = .short
            
            for event in events.prefix(10) {
                result += "\n• \(event.title)"
                result += "\n  ID: \(event.id)"
                result += "\n  When: \(dateFormatter.string(from: event.startDate)) - \(dateFormatter.string(from: event.endDate))"
                if let location = event.location {
                    result += "\n  Where: \(location)"
                }
                result += "\n"
            }
            
            return result
        } catch {
            return "Error fetching calendar events: \(error.localizedDescription)"
        }
    }

    private func executeUpdateCalendarEvent(arguments: [String: Any]) async -> String {
        guard let eventId = arguments["event_id"] as? String else {
            return "Error: Missing event ID"
        }
        
        guard let calendarService = calendarService else {
            return "Error: Calendar service not configured"
        }
        
        let title = arguments["title"] as? String
        let location = arguments["location"] as? String
        let notes = arguments["notes"] as? String
        
        let startDate = (arguments["start_date"] as? String).flatMap { ISO8601DateFormatter().date(from: $0) }
        let endDate = (arguments["end_date"] as? String).flatMap { ISO8601DateFormatter().date(from: $0) }
        
        do {
            try await calendarService.updateEvent(
                id: eventId,
                title: title,
                startDate: startDate,
                endDate: endDate,
                location: location,
                notes: notes
            )
            return "Successfully updated calendar event"
        } catch {
            return "Error updating event: \(error.localizedDescription)"
        }
    }

    
    private func executeDeleteCalendarEvent(arguments: [String: Any]) async -> String {
        guard let eventId = arguments["event_id"] as? String else {
            return "Error: Missing event ID"
        }
        
        guard let calendarService = calendarService else {
            return "Error: Calendar service not configured"
        }
        
        do {
            try await calendarService.deleteEvent(id: eventId)
            return "Successfully deleted calendar event"
        } catch {
            return "Error deleting event: \(error.localizedDescription)"
        }
    }
    
    private func executeCreateCalendarEvent(arguments: [String: Any]) async -> String {
        guard let title = arguments["title"] as? String,
              let startDateString = arguments["start_date"] as? String,
              let startDate = ISO8601DateFormatter().date(from: startDateString) else {
            return "Error: Missing required parameters for calendar event"
        }
        
        let endDateString = arguments["end_date"] as? String
        let endDate = endDateString.flatMap { ISO8601DateFormatter().date(from: $0) } ?? startDate.addingTimeInterval(3600)
        
        guard let calendarService = calendarService else {
            return "Error: Calendar service not configured"
        }
        
        do {
            try await calendarService.createEvent(title: title, startDate: startDate, endDate: endDate)
            return "Successfully created calendar event: \(title)"
        } catch {
            return "Error creating event: \(error.localizedDescription)"
        }
    }
    
    // MARK: - System Prompt
    
    private var systemPrompt: String {
        var prompt = """
        You are Alpha, a personal AI assistant.
        """
        
        // Add user personalization
        if let user = authService?.currentUser {
            if let name = user.preferences?.nickname ?? user.displayName {
                prompt += " You are speaking with \(name)."
            }
            
            if let prefs = user.preferences {
                // AI Personality
                switch prefs.aiPersonality {
                case .friendly:
                    prompt += " Be warm, helpful, and conversational."
                case .professional:
                    prompt += " Be polished, efficient, and business-like."
                case .concise:
                    prompt += " Be brief and direct. Get to the point quickly."
                case .enthusiastic:
                    prompt += " Be energetic, encouraging, and positive."
                }
                
                // Verbosity
                switch prefs.verbosity {
                case .brief:
                    prompt += " Keep responses short and concise."
                case .balanced:
                    prompt += " Provide balanced, moderate-length responses."
                case .detailed:
                    prompt += " Provide thorough, detailed responses."
                }
                
                // TODO: Communication style for emails - bring sending emails on users behalf back eventually
                prompt += """
                
                When writing emails on behalf of the user:
                - Use a \(prefs.communicationStyle.rawValue.lowercased()) tone
                - Sign off with: "\(prefs.emailSignOff ?? "Best,")"
                """
                
                if let signature = prefs.emailSignature {
                    prompt += "\n- Include signature: \"\(signature)\""
                }
                
                // Occupation context
                if let occupation = prefs.occupation {
                    prompt += "\n\nThe user works as: \(occupation)"
                }
                
                // Important facts
                if !prefs.importantFacts.isEmpty {
                    prompt += "\n\nImportant things to remember about the user:"
                    for fact in prefs.importantFacts {
                        prompt += "\n- \(fact)"
                    }
                }
            }
        }
        
        // Add memory context
        if let memoryContext = memoryService?.getMemoryContext(), !memoryContext.isEmpty {
            prompt += "\n\n--- Memory from past conversations ---\n\(memoryContext)"
        }
        
        prompt += """
        
        
        You can help with:
        - Searching the web for information
        - Creating reminders
        - Creating calendar events
        
        When you complete an action, confirm what you did. Be concise and helpful.
        
        Current date and time: \(Date().formatted())
        """
        
        return prompt
    }
}

// MARK: - Supporting Types

struct OpenAIResponse {
    let content: String?
    let toolCalls: [ToolCall]?
}

struct ToolCall {
    let id: String
    let function: FunctionCall
    
    struct FunctionCall {
        let name: String
        let arguments: [String: Any]
    }
    
    init?(from dictionary: [String: Any]) {
        guard let id = dictionary["id"] as? String,
              let function = dictionary["function"] as? [String: Any],
              let name = function["name"] as? String,
              let argumentsString = function["arguments"] as? String,
              let argumentsData = argumentsString.data(using: .utf8),
              let arguments = try? JSONSerialization.jsonObject(with: argumentsData) as? [String: Any] else {
            return nil
        }
        
        self.id = id
        self.function = FunctionCall(name: name, arguments: arguments)
    }
    
    var asDictionary: [String: Any] {
        [
            "id": id,
            "type": "function",
            "function": [
                "name": function.name,
                "arguments": (try? JSONSerialization.data(withJSONObject: function.arguments))
                    .flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
            ]
        ]
    }
}

enum OpenAIError: LocalizedError {
    case invalidResponse
    case parsingError
    case apiError(statusCode: Int, message: String)
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from server"
        case .parsingError:
            return "Failed to parse response"
        case .apiError(let statusCode, let message):
            return "API error (\(statusCode)): \(message)"
        }
    }
}
