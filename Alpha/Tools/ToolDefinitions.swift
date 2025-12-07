//
//  ToolDefinitions.swift
//  Alpha
//
// The tools defined in this document are sent to the AIs, thereby returning JSON structured to my liking, while only performing actions within the parameters specified.
// https://platform.openai.com/docs/guides/function-calling
// https://json-schema.org/understanding-json-schema/


import Foundation

struct ToolDefinitions {
    
    static let allTools: [[String: Any]] = [
        sendSMS,
        sendEmail,
        searchWeb,
        createReminder,
        createCalendarEvent,
        getCalendarEvents,
        updateCalendarEvent,
        deleteCalendarEvent,
        getContacts
    ]

    // TODO: Calendar event handling - need more time to fully integrate this feature into the app.

    static let getCalendarEvents: [String: Any] = [
        "type": "function",
        "function": [
            "name": "get_calendar_events",
            "description": "Get upcoming calendar events or search for specific events",
            "parameters": [
                "type": "object",
                "properties": [
                    "search_query": [
                        "type": "string",
                        "description": "Optional search term to find specific events (e.g., 'meeting with John', 'dentist')"
                    ],
                    "days_ahead": [
                        "type": "integer",
                        "description": "Number of days ahead to look for events (default 7)"
                    ]
                ],
                "required": []
            ]
        ]
    ]

    static let updateCalendarEvent: [String: Any] = [
        "type": "function",
        "function": [
            "name": "update_calendar_event",
            "description": "Update an existing calendar event. First use get_calendar_events to find the event ID.",
            "parameters": [
                "type": "object",
                "properties": [
                    "event_id": [
                        "type": "string",
                        "description": "The ID of the event to update"
                    ],
                    "title": [
                        "type": "string",
                        "description": "New title for the event (optional)"
                    ],
                    "start_date": [
                        "type": "string",
                        "description": "New start date/time in ISO 8601 format (optional)"
                    ],
                    "end_date": [
                        "type": "string",
                        "description": "New end date/time in ISO 8601 format (optional)"
                    ],
                    "location": [
                        "type": "string",
                        "description": "New location (optional)"
                    ],
                    "notes": [
                        "type": "string",
                        "description": "New notes/description (optional)"
                    ]
                ],
                "required": ["event_id"]
            ]
        ]
    ]

    static let deleteCalendarEvent: [String: Any] = [
        "type": "function",
        "function": [
            "name": "delete_calendar_event",
            "description": "Delete a calendar event. First use get_calendar_events to find the event ID.",
            "parameters": [
                "type": "object",
                "properties": [
                    "event_id": [
                        "type": "string",
                        "description": "The ID of the event to delete"
                    ]
                ],
                "required": ["event_id"]
            ]
        ]
    ]
    
    // MARK: - Send SMS
    
    static let sendSMS: [String: Any] = [
        "type": "function",
        "function": [
            "name": "send_sms",
            "description": "Send a text message (SMS) to one of the user's contacts. Use this when the user wants to text someone.",
            "parameters": [
                "type": "object",
                "properties": [
                    "recipient_name": [
                        "type": "string",
                        "description": "The name of the contact to send the message to (e.g., 'Mom', 'John Smith')"
                    ],
                    "message": [
                        "type": "string",
                        "description": "The text message content to send"
                    ]
                ],
                "required": ["recipient_name", "message"]
            ]
        ]
    ]
    
    // TODO: - Send Email - needs to be fully integrated into the app - still buggy and need more time to learn how to properly integrate it
    
    static let sendEmail: [String: Any] = [
        "type": "function",
        "function": [
            "name": "send_email",
            "description": "Send an email. You can either specify a contact name (to look up their email) OR provide a direct email address.",
            "parameters": [
                "type": "object",
                "properties": [
                    "recipient_name": [
                        "type": "string",
                        "description": "The name of the contact to send the email to (optional if email is provided)"
                    ],
                    "recipient_email": [
                        "type": "string",
                        "description": "The direct email address to send to (optional if recipient_name is provided)"
                    ],
                    "subject": [
                        "type": "string",
                        "description": "The email subject line"
                    ],
                    "body": [
                        "type": "string",
                        "description": "The email body content"
                    ]
                ],
                "required": ["subject", "body"]
            ]
        ]
    ]
    
    // TODO: - Search Web - part of my vision for the app in the future. I played around with this, but ended up deciding more time was needed to learn how to integrate this properly into the app.
    
    static let searchWeb: [String: Any] = [
        "type": "function",
        "function": [
            "name": "search_web",
            "description": "Search the web for current information. Use this for finding flights, restaurants, products, news, weather, or any real-time information.",
            "parameters": [
                "type": "object",
                "properties": [
                    "query": [
                        "type": "string",
                        "description": "The search query (e.g., 'flights from NYC to LA on December 15', 'best Italian restaurants in Boston')"
                    ]
                ],
                "required": ["query"]
            ]
        ]
    ]
    
    // MARK: - Create Reminder
    
    static let createReminder: [String: Any] = [
        "type": "function",
        "function": [
            "name": "create_reminder",
            "description": "Create a reminder for the user. Use this when the user wants to be reminded about something.",
            "parameters": [
                "type": "object",
                "properties": [
                    "title": [
                        "type": "string",
                        "description": "The reminder title/content"
                    ],
                    "notes": [
                        "type": "string",
                        "description": "Optional additional notes for the reminder"
                    ],
                    "due_date": [
                        "type": "string",
                        "description": "Optional due date in ISO 8601 format (e.g., '2024-12-25T10:00:00Z')"
                    ],
                    "is_recurring": [
                        "type": "boolean",
                        "description": "Whether this reminder should repeat"
                    ],
                    "recurrence_interval": [
                        "type": "string",
                        "enum": ["daily", "weekly", "monthly"],
                        "description": "How often the reminder should repeat"
                    ]
                ],
                "required": ["title"]
            ]
        ]
    ]
    
    // TODO: Create Calendar Event needs to be integrated with the rest of the app
    
    static let createCalendarEvent: [String: Any] = [
        "type": "function",
        "function": [
            "name": "create_calendar_event",
            "description": "Create a calendar event. Use this when the user wants to schedule something on their calendar.",
            "parameters": [
                "type": "object",
                "properties": [
                    "title": [
                        "type": "string",
                        "description": "The event title"
                    ],
                    "start_date": [
                        "type": "string",
                        "description": "Event start date/time in ISO 8601 format"
                    ],
                    "end_date": [
                        "type": "string",
                        "description": "Optional event end date/time in ISO 8601 format. Defaults to 1 hour after start."
                    ],
                    "location": [
                        "type": "string",
                        "description": "Optional event location"
                    ],
                    "notes": [
                        "type": "string",
                        "description": "Optional event notes/description"
                    ]
                ],
                "required": ["title", "start_date"]
            ]
        ]
    ]
    
    // MARK: - Retrieve Contacts
    static let getContacts: [String: Any] = [
        "type": "function",
        "function": [
            "name": "get_contacts",
            "description": "Retrieve the user's contacts list. Use this when you need to look up contact information or verify a contact exists.",
            "parameters": [
                "type": "object",
                "properties": [
                    "search_name": [
                        "type": "string",
                        "description": "Optional name to search for in contacts"
                    ]
                ],
                "required": []
            ]
        ]
    ]
}
