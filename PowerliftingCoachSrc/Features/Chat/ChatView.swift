import SwiftUI
import SwiftData

struct ChatView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.modelContext) var modelContext
    @Query(sort: \ChatMessage.createdAt) var messages: [ChatMessage]
    @State private var inputText = ""
    @State private var isLoading = false
    @State private var scrollTarget: UUID?
    @FocusState private var inputFocused: Bool

    // Injury/swap keywords for client-side detection
    let injuryKeywords = ["pain", "hurt", "injured", "injury", "strain", "sprain", "pulled", "torn", "shoulder", "knee", "back pain", "wrist"]
    let swapKeywords = ["swap", "replace", "change", "substitute", "instead of", "alternative"]

    var userMessages: [ChatMessage] {
        guard let userId = authManager.currentUser?.id else { return [] }
        return messages.filter { $0.userId == userId }
    }

    var currentProfile: AthleteProfile? { authManager.currentUser?.athleteProfile }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                VStack(spacing: 0) {
                    // Messages
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                if userMessages.isEmpty {
                                    ChatWelcomeCard()
                                        .padding(.top, 24)
                                }

                                ForEach(userMessages) { message in
                                    ChatBubble(message: message)
                                        .id(message.id)
                                }

                                if isLoading {
                                    TypingIndicator()
                                        .id("typing")
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 16)
                            .padding(.bottom, 20)
                        }
                        .onChange(of: userMessages.count) { _, _ in
                            withAnimation {
                                if let last = userMessages.last {
                                    proxy.scrollTo(last.id, anchor: .bottom)
                                }
                            }
                        }
                        .onChange(of: isLoading) { _, loading in
                            if loading {
                                withAnimation { proxy.scrollTo("typing", anchor: .bottom) }
                            }
                        }
                    }

                    // Input bar
                    ChatInputBar(
                        text: $inputText,
                        isFocused: $inputFocused,
                        isLoading: isLoading,
                        onSend: sendMessage
                    )
                }
            }
            .navigationTitle("AI Coach")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    private func sendMessage() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let userId = authManager.currentUser?.id else { return }

        // Client-side keyword detection
        let lowerMsg = trimmed.lowercased()
        let hasInjuryFlag = injuryKeywords.contains { lowerMsg.contains($0) }
        let hasSwapFlag = swapKeywords.contains { lowerMsg.contains($0) }

        // Create user message
        let userMsg = ChatMessage(userId: userId, role: "user", content: trimmed)
        userMsg.flaggedInjury = hasInjuryFlag
        userMsg.flaggedExerciseSwap = hasSwapFlag
        modelContext.insert(userMsg)
        authManager.currentUser?.chatMessages.append(userMsg)

        inputText = ""
        inputFocused = false
        isLoading = true

        Task {
            defer { isLoading = false }

            guard let profile = currentProfile else { return }

            // Build history (last 20 messages per PRD)
            let history = userMessages.suffix(20).map {
                ChatHistoryItem(role: $0.role, content: $0.content)
            }

            do {
                let reply = try await AIService.shared.sendChatMessage(
                    message: trimmed,
                    history: history,
                    profile: profile,
                    currentProgram: nil // Could pass current program here
                )

                let assistantMsg = ChatMessage(userId: userId, role: "assistant", content: reply)
                modelContext.insert(assistantMsg)
                authManager.currentUser?.chatMessages.append(assistantMsg)
                try? modelContext.save()
            } catch {
                let errMsg = ChatMessage(
                    userId: userId,
                    role: "assistant",
                    content: "Sorry, I'm having trouble connecting right now. Please try again."
                )
                modelContext.insert(errMsg)
            }
        }
    }
}

// MARK: - Chat Bubble

struct ChatBubble: View {
    let message: ChatMessage
    let isUser: Bool

    init(message: ChatMessage) {
        self.message = message
        self.isUser = message.role == "user"
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isUser { Spacer(minLength: 60) }

            if !isUser {
                // AI avatar
                Image(systemName: "brain")
                    .font(.caption)
                    .foregroundStyle(Color.appPurple)
                    .frame(width: 28, height: 28)
                    .background(Color.appPurple.opacity(0.15))
                    .clipShape(Circle())
            }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .font(.system(.body))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        isUser
                        ? Color.appAccent
                        : Color.white.opacity(0.08)
                    )
                    .clipShape(ChatBubbleShape(isUser: isUser))

                // Flags
                if message.flaggedInjury {
                    Label("Injury mentioned", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
                if message.flaggedExerciseSwap {
                    Label("Exercise swap requested", systemImage: "arrow.2.squarepath")
                        .font(.caption2)
                        .foregroundStyle(Color.appAccent)
                }
            }

            if isUser {
                // User avatar
                Image(systemName: "person.circle.fill")
                    .font(.title3)
                    .foregroundStyle(Color.appAccent)
            }

            if !isUser { Spacer(minLength: 60) }
        }
    }
}

struct ChatBubbleShape: Shape {
    let isUser: Bool

    func path(in rect: CGRect) -> Path {
        let r: CGFloat = 18
        let tailR: CGFloat = 6
        var path = Path()

        if isUser {
            path.addRoundedRect(in: rect, cornerSize: CGSize(width: r, height: r))
        } else {
            path.addRoundedRect(in: rect, cornerSize: CGSize(width: r, height: r))
        }
        return path
    }
}

// MARK: - Chat Input Bar

struct ChatInputBar: View {
    @Binding var text: String
    @FocusState.Binding var isFocused: Bool
    let isLoading: Bool
    let onSend: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            TextField("Ask your coach...", text: $text, axis: .vertical)
                .lineLimit(1...4)
                .padding(12)
                .background(Color.white.opacity(0.07))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(isFocused ? Color.appAccent.opacity(0.6) : Color.white.opacity(0.1), lineWidth: 1)
                )
                .focused($isFocused)
                .disabled(isLoading)
                .onSubmit { if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { onSend() } }

            Button(action: onSend) {
                if isLoading {
                    ProgressView().tint(.white).frame(width: 44, height: 44)
                } else {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(text.isEmpty ? .secondary : Color.appAccent)
                }
            }
            .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.regularMaterial)
        .overlay(Rectangle().frame(height: 0.5).foregroundStyle(Color.white.opacity(0.1)), alignment: .top)
    }
}

// MARK: - Welcome Card

struct ChatWelcomeCard: View {
    let prompts = [
        "Why is squatting with a wider stance better for me?",
        "I feel pain in my right knee after heavy squats.",
        "Can you swap Romanian Deadlifts for leg curls?",
        "Am I ready to test my max next week?"
    ]

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "brain")
                .font(.system(size: 48))
                .foregroundStyle(Color.appPurple)

            VStack(spacing: 8) {
                Text("Your AI Coach")
                    .font(.system(.title3, design: .rounded).weight(.bold))
                Text("Ask anything about your training, injuries, or technique.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Try asking:").font(.caption).foregroundStyle(.secondary)
                ForEach(prompts, id: \.self) { prompt in
                    Text(""\(prompt)"")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(10)
                        .background(Color.white.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
        .padding(24)
        .glassCard()
    }
}

// MARK: - Typing Indicator

struct TypingIndicator: View {
    @State private var phase = 0

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            Image(systemName: "brain")
                .font(.caption)
                .foregroundStyle(Color.appPurple)
                .frame(width: 28, height: 28)
                .background(Color.appPurple.opacity(0.15))
                .clipShape(Circle())

            HStack(spacing: 4) {
                ForEach(0..<3) { i in
                    Circle()
                        .fill(Color.secondary)
                        .frame(width: 8, height: 8)
                        .offset(y: phase == i ? -4 : 0)
                        .animation(
                            .easeInOut(duration: 0.4).repeatForever().delay(Double(i) * 0.15),
                            value: phase
                        )
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 18))

            Spacer(minLength: 60)
        }
        .onAppear { phase = 2 }
    }
}
