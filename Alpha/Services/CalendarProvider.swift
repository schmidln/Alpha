//
//  CalendarService.swift
//  Alpha
//
// TODO: I added this because I wanted the AI to look forward and schedule reminders based on a users current schedule. Same goes for scheduling calendar events. I will have to revise this module and look into how I envision integrating this into the app.
// https://developer.apple.com/documentation/eventkit
// https://docs.swift.org/swift-book/documentation/the-swift-programming-language/protocols/
// https://developer.apple.com/documentation/foundation/localizederror
// https://refactoring.guru/design-patterns/strategy

import Foundation

// MARK: - Calendar Provider Protocol

protocol CalendarProvider {
    var isAuthorized: Bool { get async }
    
    func requestAccess() async -> Bool
    
    func createEvent(
        title: String,
        startDate: Date,
        endDate: Date?,
        location: String?,
        notes: String?
    ) async throws
    
    func fetchUpcomingEvents(days: Int) async throws -> [CalendarEvent]
    
    func deleteEvent(id: String) async throws
}

// MARK: - Universal Calendar Event Model

struct CalendarEvent: Identifiable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let location: String?
    let notes: String?
    let provider: CalendarProviderType
    
    var duration: TimeInterval {
        endDate.timeIntervalSince(startDate)
    }
    
    var isAllDay: Bool {
        let calendar = Calendar.current
        let startComponents = calendar.dateComponents([.hour, .minute], from: startDate)
        let endComponents = calendar.dateComponents([.hour, .minute], from: endDate)
        return startComponents.hour == 0 && startComponents.minute == 0 &&
               endComponents.hour == 23 && endComponents.minute == 59
    }
}

// MARK: - Provider Type

enum CalendarProviderType: String, Codable, CaseIterable {
    case apple = "Apple Calendar"
    case google = "Google Calendar"
    
    var icon: String {
        switch self {
        case .apple: return "calendar"
        case .google: return "g.circle.fill"
        }
    }
}

// MARK: - Errors

enum CalendarError: LocalizedError {
    case notAuthorized
    case authenticationFailed
    case saveFailed
    case fetchFailed
    case deleteFailed
    case eventNotFound
    case apiError(message: String)
    
    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Calendar access not authorized"
        case .authenticationFailed:
            return "Failed to authenticate with calendar service"
        case .saveFailed:
            return "Failed to save calendar event"
        case .fetchFailed:
            return "Failed to fetch calendar events"
        case .deleteFailed:
            return "Failed to delete calendar event"
        case .eventNotFound:
            return "Calendar event not found"
        case .apiError(let message):
            return "Calendar API error: \(message)"
        }
    }
}
