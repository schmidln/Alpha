//
//  Activity.swift
//  Alpha
//

import Foundation
import FirebaseFirestore

struct Activity: Identifiable, Codable {
    @DocumentID var id: String?
    let userId: String
    let type: String
    let userMessage: String?
    let assistantResponse: String?
    let timestamp: Date
    let source: String
    
    // Optional details
    var reminderTitle: String?
    var emailRecipient: String?
    var emailSubject: String?
    var wasVoiceMemo: Bool?
    
    var icon: String {
        switch type {
        case "whatsapp_conversation":
            return wasVoiceMemo == true ? "waveform" : "message.fill"
        case "sms_conversation":
            return "message.fill"
        case "reminder_created":
            return "bell.fill"
        case "email_sent":
            return "envelope.fill"
        case "calendar_event":
            return "calendar"
        case "memory_saved":
            return "brain.head.profile"
        default:
            return "sparkles"
        }
    }
    
    var title: String {
        switch type {
        case "whatsapp_conversation":
            return wasVoiceMemo == true ? "Voice Message" : "WhatsApp"
        case "sms_conversation":
            return "SMS"
        case "reminder_created":
            return "Reminder Created"
        case "email_sent":
            return "Email Sent"
        case "calendar_event":
            return "Calendar Event"
        case "memory_saved":
            return "Memory Saved"
        default:
            return "Activity"
        }
    }
    
    var sourceIcon: String {
        switch source {
        case "whatsapp":
            return "bubble.left.fill"
        case "sms":
            return "message.fill"
        case "app":
            return "iphone"
        default:
            return "sparkles"
        }
    }
}
