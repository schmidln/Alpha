//
//  ChatView.swift
//  Alpha
//
// This is an in-app chat UI, to speak with Alpha directly within the app
// Flow:
// User types message → sendMessage()
// Append user message to messages[]
// all openAIService.sendMessage() with history
// Append AI response to messages[]
// ScrollViewReader auto-scrolls to bottom
// https://developer.apple.com/documentation/swiftui/scrollviewreader
// https://developer.apple.com/documentation/swiftui/textfield
// https://developer.apple.com/documentation/swift/task

import SwiftUI

struct ChatView: View {
    @EnvironmentObject var openAIService: OpenAIService
    @State private var inputText = ""
    @State private var messages: [Message] = []
    @State private var isLoading = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Messages list
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(messages) { message in
                                MessageBubble(message: message)
                                    .id(message.id)
                            }
                            
                            if isLoading {
                                HStack {
                                    ProgressView()
                                        .padding(.horizontal)
                                    Spacer()
                                }
                            }
                        }
                        .padding()
                    }
                    .onChange(of: messages.count) {
                        if let lastMessage = messages.last {
                            withAnimation {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                }
                
                Divider()
                
                // Input bar
                HStack(spacing: 12) {
                    TextField("Message Alpha...", text: $inputText, axis: .vertical)
                        .textFieldStyle(.plain)
                        .lineLimit(1...5)
                        .padding(12)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                    
                    Button {
                        sendMessage()
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(inputText.isEmpty ? Color.gray : Color.blue)
                    }
                    .disabled(inputText.isEmpty || isLoading)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
            .navigationTitle("Alpha")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private func sendMessage() {
        let userMessage = Message(role: .user, content: inputText)
        messages.append(userMessage)
        let currentInput = inputText
        inputText = ""
        isLoading = true
        
        Task {
            do {
                let response = try await openAIService.sendMessage(currentInput, conversationHistory: messages)
                let assistantMessage = Message(role: .assistant, content: response)
                messages.append(assistantMessage)
            } catch {
                let errorMessage = Message(role: .assistant, content: "Sorry, something went wrong: \(error.localizedDescription)")
                messages.append(errorMessage)
            }
            isLoading = false
        }
    }
}

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: Message
    
    var body: some View {
        HStack {
            if message.role == .user { Spacer() }
            
            Text(message.content)
                .padding(12)
                .background(message.role == .user ? Color.blue : Color(.systemGray5))
                .foregroundStyle(message.role == .user ? .white : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            
            if message.role == .assistant { Spacer() }
        }
    }
}

#Preview {
    ChatView()
        .environmentObject(OpenAIService())
}
