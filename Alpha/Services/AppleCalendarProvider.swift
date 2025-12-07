//
//  AppleCalendarProvider.swift
//  Alpha
//
// TODO: I added this because I wanted the AI to look forward and schedule reminders based on a users current schedule. Same goes for scheduling calendar events. I will have to revise this module and look into how I envision integrating this into the app.
// https://developer.apple.com/documentation/eventkit


import Foundation
import EventKit

class AppleCalendarProvider: CalendarProvider {
    private let eventStore = EKEventStore()
    
    var isAuthorized: Bool {
        get async {
            let status = EKEventStore.authorizationStatus(for: .event)
            return status == .fullAccess
        }
    }
    
    func requestAccess() async -> Bool {
        do {
            if #available(iOS 17.0, *) {
                return try await eventStore.requestFullAccessToEvents()
            } else {
                return try await eventStore.requestAccess(to: .event)
            }
        } catch {
            print("Apple Calendar access error: \(error)")
            return false
        }
    }
    
    func createEvent(
        title: String,
        startDate: Date,
        endDate: Date?,
        location: String?,
        notes: String?
    ) async throws {
        if !(await isAuthorized) {
            let granted = await requestAccess()
            if !granted {
                throw CalendarError.notAuthorized
            }
        }
        
        let eventStore = EKEventStore()
        let event = EKEvent(eventStore: eventStore)
        event.title = title
        event.startDate = startDate
        event.endDate = endDate ?? startDate.addingTimeInterval(3600)
        event.location = location
        event.notes = notes
        event.calendar = eventStore.defaultCalendarForNewEvents
        
        // Add 15-minute reminder
        let alarm = EKAlarm(relativeOffset: -900)
        event.addAlarm(alarm)
        
        try eventStore.save(event, span: .thisEvent)
    }
    
    func fetchUpcomingEvents(days: Int = 7) async throws -> [CalendarEvent] {
        guard await isAuthorized else {
            throw CalendarError.notAuthorized
        }
        
        let startDate = Date()
        let endDate = Calendar.current.date(byAdding: .day, value: days, to: startDate) ?? startDate
        
        let predicate = eventStore.predicateForEvents(
            withStart: startDate,
            end: endDate,
            calendars: nil
        )
        
        let ekEvents = eventStore.events(matching: predicate)
        
        return ekEvents.map { event in
            CalendarEvent(
                id: event.eventIdentifier,
                title: event.title ?? "Untitled",
                startDate: event.startDate,
                endDate: event.endDate,
                location: event.location,
                notes: event.notes,
                provider: .apple
            )
        }.sorted { $0.startDate < $1.startDate }
    }
    
    func deleteEvent(id: String) async throws {
        guard await isAuthorized else {
            throw CalendarError.notAuthorized
        }
        
        guard let event = eventStore.event(withIdentifier: id) else {
            throw CalendarError.eventNotFound
        }
        
        try eventStore.remove(event, span: .thisEvent)
    }
}
