//
//  VoiceView.swift
//  Alpha
//
// TODO: I had AI code out this SpeechService to test the Whisper's AI transcription before I began working on integrating everything with Twilio. While I could delete the module now, I'm considering reintegrating it into the app, as an alternative to SMS/WhatsApp.

import SwiftUI

struct VoiceView: View {
    @EnvironmentObject var openAIService: OpenAIService
    @StateObject private var speechService = SpeechService()
    
    @State private var isListening = false
    @State private var transcribedText = ""
    @State private var responseText = ""
    @State private var isProcessing = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()
                
                // Status display
                VStack(spacing: 16) {
                    if isListening {
                        Text("Listening...")
                            .font(.headline)
                            .foregroundStyle(.blue)
                    } else if isProcessing {
                        Text("Thinking...")
                            .font(.headline)
                            .foregroundStyle(.orange)
                    } else if !responseText.isEmpty {
                        Text("Alpha")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Tap to speak")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                    
                    // Transcribed user input
                    if !transcribedText.isEmpty {
                        Text(transcribedText)
                            .font(.body)
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    
                    // Assistant response
                    if !responseText.isEmpty && !isListening {
                        ScrollView {
                            Text(responseText)
                                .font(.body)
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        .frame(maxHeight: 200)
                    }
                }
                .frame(minHeight: 150)
                
                Spacer()
                
                // Microphone button
                Button {
                    toggleListening()
                } label: {
                    ZStack {
                        Circle()
                            .fill(isListening ? Color.red : Color.blue)
                            .frame(width: 80, height: 80)
                            .shadow(color: isListening ? .red.opacity(0.4) : .blue.opacity(0.4), radius: isListening ? 20 : 10)
                        
                        Image(systemName: isListening ? "stop.fill" : "mic.fill")
                            .font(.system(size: 30))
                            .foregroundStyle(.white)
                    }
                }
                .disabled(isProcessing)
                .animation(.easeInOut(duration: 0.2), value: isListening)
                
                // Pulsing rings when listening
                if isListening {
                    PulsingRings()
                        .frame(height: 40)
                } else {
                    Spacer()
                        .frame(height: 40)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Alpha")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private func toggleListening() {
        if isListening {
            stopListening()
        } else {
            startListening()
        }
    }
    
    private func startListening() {
        transcribedText = ""
        responseText = ""
        isListening = true
        
        speechService.startListening { result in
            transcribedText = result
        }
    }
    
    private func stopListening() {
        isListening = false
        speechService.stopListening()
        
        guard !transcribedText.isEmpty else { return }
        
        isProcessing = true
        
        Task {
            do {
                let response = try await openAIService.sendMessage(transcribedText, conversationHistory: [])
                responseText = response
                speechService.speak(response)
            } catch {
                responseText = "Sorry, something went wrong."
            }
            isProcessing = false
        }
    }
}

// MARK: - Pulsing Rings Animation

struct PulsingRings: View {
    @State private var animate = false
    
    var body: some View {
        ZStack {
            ForEach(0..<3) { index in
                Circle()
                    .stroke(Color.blue.opacity(0.3), lineWidth: 2)
                    .scaleEffect(animate ? 1.5 + CGFloat(index) * 0.3 : 1)
                    .opacity(animate ? 0 : 0.5)
                    .animation(
                        .easeOut(duration: 1.5)
                        .repeatForever(autoreverses: false)
                        .delay(Double(index) * 0.3),
                        value: animate
                    )
            }
        }
        .frame(width: 40, height: 40)
        .onAppear { animate = true }
        .onDisappear { animate = false }
    }
}

#Preview {
    VoiceView()
        .environmentObject(OpenAIService())
}
