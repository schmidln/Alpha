//
//  File.swift
//  Alpha
//
// TODO: Reconfigure how I envision integrating this into the app. I initially had a fully functioning calendar in the app, but I felt it added little value so I removed it. However,  I don't want to remove the code yet, since I have an inkling I may return to this.
// https://developer.apple.com/documentation/combine/observableobject
// https://developer.apple.com/documentation/foundation/userdefaults
// https://refactoring.guru/design-patterns/strategy

import Foundation
import Combine

@MainActor
class CalendarService: ObservableObject {
    @Published var selectedProvider: CalendarProviderType = .google
    @Published var isAuthorized = false
    @Published var upcomingEvents: [CalendarEvent] = []
    @Published var isLoading = false
    
    private let appleProvider = AppleCalendarProvider()
    private let googleProvider = GoogleCalendarProvider()
    
    init() {
        if let savedProvider = UserDefaults.standard.string(forKey: "selectedCalendarProvider"),
           let provider = CalendarProviderType(rawValue: savedProvider) {
            selectedProvider = provider
        }
    }
    
    // MARK: - Configure Google
    
    func configureGoogle(accessToken: String) {
        googleProvider.configure(accessToken: accessToken)
        
        Task {
            isAuthorized = await googleProvider.isAuthorized
            if isAuthorized {
                await refreshEvents()
            }
        }
    }
    
    // MARK: - Current Provider
    
    private var currentProvider: CalendarProvider {
        switch selectedProvider {
        case .apple: return appleProvider
        case .google: return googleProvider
        }
    }
    
    // MARK: - Switch Provider
    
    func switchProvider(to provider: CalendarProviderType) async {
        selectedProvider = provider
        UserDefaults.standard.set(provider.rawValue, forKey: "selectedCalendarProvider")
        
        isAuthorized = await currentProvider.isAuthorized
        if isAuthorized {
            await refreshEvents()
        }
    }
    
    // MARK: - Authorization
    
    func checkAuthorization() async {
        isAuthorized = await currentProvider.isAuthorized
        
        if isAuthorized {
            await refreshEvents()
        }
    }
    
    func requestAccess() async -> Bool {
        let granted = await currentProvider.requestAccess()
        isAuthorized = granted
        
        if granted {
            await refreshEvents()
        }
        
        return granted
    }
    
    // MARK: - Events
    
    func createEvent(
        title: String,
        startDate: Date,
        endDate: Date? = nil,
        location: String? = nil,
        notes: String? = nil
    ) async throws {
        try await currentProvider.createEvent(
            title: title,
            startDate: startDate,
            endDate: endDate,
            location: location,
            notes: notes
        )
        
        await refreshEvents()
    }
    
    func refreshEvents() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            upcomingEvents = try await currentProvider.fetchUpcomingEvents(days: 14)
        } catch {
            print("Error fetching events: \(error)")
            upcomingEvents = []
        }
    }
    
    func deleteEvent(id: String) async throws {
        try await currentProvider.deleteEvent(id: id)
        await refreshEvents()
    }
    
    func updateEvent(
        id: String,
        title: String? = nil,
        startDate: Date? = nil,
        endDate: Date? = nil,
        location: String? = nil,
        notes: String? = nil
    ) async throws {
        if let googleProvider = currentProvider as? GoogleCalendarProvider {
            try await googleProvider.updateEvent(
                id: id,
                title: title,
                startDate: startDate,
                endDate: endDate,
                location: location,
                notes: notes
            )
            await refreshEvents()
        }
    }
    
    func searchEvents(query: String) async throws -> [CalendarEvent] {
        if let googleProvider = currentProvider as? GoogleCalendarProvider {
            return try await googleProvider.searchEvents(query: query)
        }
        return []
    }
    
    // MARK: - Availability
    
    func isAvailable(at date: Date, duration: TimeInterval = 3600) -> Bool {
        let endDate = date.addingTimeInterval(duration)
        
        let conflictingEvents = upcomingEvents.filter { event in
            event.startDate < endDate && event.endDate > date
        }
        
        return conflictingEvents.isEmpty
    }
    
    func getEventsForDate(_ date: Date) -> [CalendarEvent] {
        let calendar = Calendar.current
        return upcomingEvents.filter { event in
            calendar.isDate(event.startDate, inSameDayAs: date)
        }
    }
}
