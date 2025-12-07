//
//  GoogleCalendarProvider.swift
//  Alpha
//
// TODO: I added this because I wanted the AI to look forward and schedule reminders based on a users current schedule. Same goes for scheduling calendar events. I will have to revise this module and look into how I envision integrating this into the app.
// https://developers.google.com/workspace/calendar/api/v3/reference
// https://developers.google.com/workspace/calendar/api/v3/reference/events/list
// https://developers.google.com/workspace/calendar/api/v3/reference/events/insert
// https://developer.apple.com/documentation/foundation/urlsession
// https://developers.google.com/identity/protocols/oauth2
// https://developer.apple.com/documentation/foundation/iso8601dateformatter


import Foundation

class GoogleCalendarProvider: CalendarProvider {
    private var accessToken: String?
    private let baseURL = "https://www.googleapis.com/calendar/v3"
    
    func configure(accessToken: String) {
        self.accessToken = accessToken
    }
    
    var isAuthorized: Bool {
        get async {
            return accessToken != nil
        }
    }
    
    func requestAccess() async -> Bool {
        return accessToken != nil
    }
    
    // MARK: - Create Event
    
    func createEvent(
        title: String,
        startDate: Date,
        endDate: Date?,
        location: String?,
        notes: String?
    ) async throws {
        guard let accessToken = accessToken else {
            throw CalendarError.notAuthorized
        }
        
        let url = URL(string: "\(baseURL)/calendars/primary/events")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        
        var eventBody: [String: Any] = [
            "summary": title,
            "start": ["dateTime": formatter.string(from: startDate), "timeZone": TimeZone.current.identifier],
            "end": ["dateTime": formatter.string(from: endDate ?? startDate.addingTimeInterval(3600)), "timeZone": TimeZone.current.identifier]
        ]
        
        if let location = location {
            eventBody["location"] = location
        }
        
        if let notes = notes {
            eventBody["description"] = notes
        }
        
        eventBody["reminders"] = [
            "useDefault": false,
            "overrides": [
                ["method": "popup", "minutes": 15]
            ]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: eventBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("Google Calendar create error: \(errorBody)")
            throw CalendarError.saveFailed
        }
    }
    
    // MARK: - Fetch Events
    
    func fetchUpcomingEvents(days: Int = 7) async throws -> [CalendarEvent] {
        guard let accessToken = accessToken else {
            throw CalendarError.notAuthorized
        }
        
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        
        let now = Date()
        let future = Calendar.current.date(byAdding: .day, value: days, to: now) ?? now
        
        var components = URLComponents(string: "\(baseURL)/calendars/primary/events")!
        components.queryItems = [
            URLQueryItem(name: "timeMin", value: formatter.string(from: now)),
            URLQueryItem(name: "timeMax", value: formatter.string(from: future)),
            URLQueryItem(name: "singleEvents", value: "true"),
            URLQueryItem(name: "orderBy", value: "startTime"),
            URLQueryItem(name: "maxResults", value: "50")
        ]
        
        var request = URLRequest(url: components.url!)
        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("Google Calendar fetch error: \(errorBody)")
            throw CalendarError.fetchFailed
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let items = json["items"] as? [[String: Any]] else {
            return []
        }
        
        return items.compactMap { item -> CalendarEvent? in
            guard let id = item["id"] as? String,
                  let title = item["summary"] as? String,
                  let start = item["start"] as? [String: Any],
                  let end = item["end"] as? [String: Any] else {
                return nil
            }
            
            let startDate = parseGoogleDate(start)
            let endDate = parseGoogleDate(end)
            
            guard let startDate = startDate, let endDate = endDate else {
                return nil
            }
            
            return CalendarEvent(
                id: id,
                title: title,
                startDate: startDate,
                endDate: endDate,
                location: item["location"] as? String,
                notes: item["description"] as? String,
                provider: .google
            )
        }
    }
    
    // MARK: - Update Event
    
    func updateEvent(
        id: String,
        title: String?,
        startDate: Date?,
        endDate: Date?,
        location: String?,
        notes: String?
    ) async throws {
        guard let accessToken = accessToken else {
            throw CalendarError.notAuthorized
        }
        
        // First fetch the existing event
        let existingEvent = try await fetchEvent(id: id)
        
        let url = URL(string: "\(baseURL)/calendars/primary/events/\(id)")!
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        
        let finalStartDate = startDate ?? existingEvent.startDate
        let finalEndDate = endDate ?? existingEvent.endDate
        
        var eventBody: [String: Any] = [
            "summary": title ?? existingEvent.title,
            "start": ["dateTime": formatter.string(from: finalStartDate), "timeZone": TimeZone.current.identifier],
            "end": ["dateTime": formatter.string(from: finalEndDate), "timeZone": TimeZone.current.identifier]
        ]
        
        if let location = location ?? existingEvent.location {
            eventBody["location"] = location
        }
        
        if let notes = notes ?? existingEvent.notes {
            eventBody["description"] = notes
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: eventBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("Google Calendar update error: \(errorBody)")
            throw CalendarError.saveFailed
        }
    }
    
    // MARK: - Fetch Single Event
    
    func fetchEvent(id: String) async throws -> CalendarEvent {
        guard let accessToken = accessToken else {
            throw CalendarError.notAuthorized
        }
        
        let url = URL(string: "\(baseURL)/calendars/primary/events/\(id)")!
        var request = URLRequest(url: url)
        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw CalendarError.eventNotFound
        }
        
        guard let item = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let id = item["id"] as? String,
              let title = item["summary"] as? String,
              let start = item["start"] as? [String: Any],
              let end = item["end"] as? [String: Any],
              let startDate = parseGoogleDate(start),
              let endDate = parseGoogleDate(end) else {
            throw CalendarError.eventNotFound
        }
        
        return CalendarEvent(
            id: id,
            title: title,
            startDate: startDate,
            endDate: endDate,
            location: item["location"] as? String,
            notes: item["description"] as? String,
            provider: .google
        )
    }
    
    // MARK: - Delete Event
    
    func deleteEvent(id: String) async throws {
        guard let accessToken = accessToken else {
            throw CalendarError.notAuthorized
        }
        
        let url = URL(string: "\(baseURL)/calendars/primary/events/\(id)")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 204 || httpResponse.statusCode == 200 else {
            throw CalendarError.deleteFailed
        }
    }
    
    // MARK: - Search Events
    
    func searchEvents(query: String) async throws -> [CalendarEvent] {
        guard let accessToken = accessToken else {
            throw CalendarError.notAuthorized
        }
        
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        
        let now = Date()
        let future = Calendar.current.date(byAdding: .month, value: 3, to: now) ?? now
        
        var components = URLComponents(string: "\(baseURL)/calendars/primary/events")!
        components.queryItems = [
            URLQueryItem(name: "timeMin", value: formatter.string(from: now)),
            URLQueryItem(name: "timeMax", value: formatter.string(from: future)),
            URLQueryItem(name: "singleEvents", value: "true"),
            URLQueryItem(name: "orderBy", value: "startTime"),
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "maxResults", value: "20")
        ]
        
        var request = URLRequest(url: components.url!)
        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw CalendarError.fetchFailed
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let items = json["items"] as? [[String: Any]] else {
            return []
        }
        
        return items.compactMap { item -> CalendarEvent? in
            guard let id = item["id"] as? String,
                  let title = item["summary"] as? String,
                  let start = item["start"] as? [String: Any],
                  let end = item["end"] as? [String: Any],
                  let startDate = parseGoogleDate(start),
                  let endDate = parseGoogleDate(end) else {
                return nil
            }
            
            return CalendarEvent(
                id: id,
                title: title,
                startDate: startDate,
                endDate: endDate,
                location: item["location"] as? String,
                notes: item["description"] as? String,
                provider: .google
            )
        }
    }
    
    // MARK: - Helpers
    
    private func parseGoogleDate(_ dateDict: [String: Any]) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        if let dateTime = dateDict["dateTime"] as? String {
            // Try with fractional seconds first
            if let date = formatter.date(from: dateTime) {
                return date
            }
            // Try without fractional seconds
            formatter.formatOptions = [.withInternetDateTime]
            return formatter.date(from: dateTime)
        } else if let date = dateDict["date"] as? String {
            // All-day event
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            return dateFormatter.date(from: date)
        }
        
        return nil
    }
}
