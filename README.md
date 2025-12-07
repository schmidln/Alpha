# Alpha - AI Personal Assistant

An intelligent iOS personal assistant that integrates with WhatsApp, providing natural language interaction for managing reminders for yourself and others on the go!

## Overview

Alpha is a comprehensive AI assistant built with SwiftUI and Firebase, featuring both in-app chat and WhatsApp integration. Users can interact with their personal assistant through natural conversation to manage their daily tasks and stay organized. Please note only the SwiftUI code is included in this repo; my Node.js backend code is not included. If you'd like to have a peek at my backend, simply reach out at schmidln@bc.edu.

## Features

### Core Capabilities
- **Natural Language Processing** - Powered by OpenAI GPT-4o for intelligent conversation
- **Voice Transcription** - Speech-to-text using OpenAI Whisper
- **WhatsApp Integration** - Send messages via WhatsApp and receive AI responses

### Reminders System
- Create, edit, and complete reminders through natural language
- Priority levels (high, medium, low) with smart urgency scoring
- Categories (work, personal, health, finance, etc.)
- Recurring reminders (daily, weekly, monthly)
- Archive system for completed tasks
- **Shared Reminders** - Collaborative lists with friends

### Social Features
- **Friends System** - Add friends, send/accept requests
- **Shared Lists** - Create collaborative reminder lists
- **Real-time Sync** - Changes sync instantly across devices

### Additional Features
- **Memory System** - AI remembers context from past conversations
- **Web Search** - Real-time information via Perplexity AI
- **Activity Feed** - Track all AI actions and updates

## Architecture

### iOS App (Swift/SwiftUI)
- MVVM architecture pattern
- Firebase Authentication (Email/Password, Google Sign-In)
- Cloud Firestore for real-time data sync
- Local notifications for reminders

### Backend (Node.js/Firebase Functions)
- Twilio webhooks for WhatsApp/SMS
- OpenAI API integration
- Conversation history management
- Tool execution (reminders, etc.)

## Tech Stack
ios Frontend = SwiftUI
Backend = Node.js, Firebase Functions
Database = Cloud Firestore
Authentication = Firebase Auth
AI/NLP = OpenAI GPT-4o
Voice = OpenAI Whisper
Search = Perplexity AI
Messaging = Twilio (WhatsApp Sandbox)



## Setup

### Prerequisites
- Xcode 26+
- Node.js 18+
- Firebase account
- API keys for: OpenAI, Twilio, Perplexity (optional)

### iOS App Setup
1. Clone the repository
2. Open `Alpha.xcodeproj` in Xcode
3. Create `Alpha/Config.swift` with your API keys:
```swift
struct Config {
    static let openAIKey = "your-openai-key"
    static let perplexityKey = "your-perplexity-key"
}
```
4. Add your `GoogleService-Info.plist` from Firebase
5. Build and run

### Backend Setup
1. Navigate to `AlphaBackend/functions`
2. Create `.env` file:
```
OPENAI_API_KEY=your-key
TWILIO_ACCOUNT_SID=your-sid
TWILIO_AUTH_TOKEN=your-token
SENDGRID_API_KEY=your-key
```
3. Install dependencies: `npm install`
4. Deploy: `firebase deploy --only functions`

## Demo

[Watch the demo video](https://youtube.com/shorts/ytMRI7Ui0uI)

## Author

**Lucas Schmidt**  
Boston College  
Mobile App Development - Fall 2025
https://www.linkedin.com/in/lucasschmidt33/

