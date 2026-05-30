import Foundation

@MainActor
public final class ChatPanelViewModel: ObservableObject {
    @Published public private(set) var messages: [AIChatMessage] = []
    @Published public private(set) var isSending = false
    @Published public var inputText = ""
    @Published public private(set) var streamingText: String?

    public var onBubbleEmitted: ((AIChatResponse) -> Void)?
    public var onMessageSent: (() -> Void)?

    private let chatEngine: AIChatEngining
    private let petId: String

    public init(chatEngine: AIChatEngining, petId: String) {
        self.chatEngine = chatEngine
        self.petId = petId
    }

    public func loadSession() {
        if let session = chatEngine.getActiveSession(petId: petId) {
            messages = session.messages
        } else {
            let session = chatEngine.startSession(petId: petId)
            messages = session.messages
        }
    }

    public func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isSending else { return }

        let userMessage = AIChatMessage(role: .user, content: text)
        messages.append(userMessage)
        inputText = ""
        isSending = true

        Task { @MainActor in
            await performSendStream(text: text)
        }
    }

    public func sendAndWait(text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isSending else { return }

        let userMessage = AIChatMessage(role: .user, content: trimmed)
        messages.append(userMessage)
        inputText = ""
        isSending = true
        await performSendStream(text: trimmed)
    }

    private func performSendStream(text: String) async {
        defer { isSending = false; streamingText = nil }

        let stream = chatEngine.sendMessageStreaming(text, petId: petId)
        do {
            for try await event in stream {
                switch event {
                case .token(let token):
                    if streamingText == nil {
                        streamingText = ""
                    }
                    streamingText! += token
                case .completed(let response):
                    streamingText = nil
                    messages.append(response.message)
                    onBubbleEmitted?(response)
                }
            }
        } catch {
            streamingText = nil
            print("[AI] ViewModel caught error: \(error)")
            let fallbackMessage = AIChatMessage(role: .assistant, content: "暂时无法回复")
            messages.append(fallbackMessage)
        }
        onMessageSent?()
    }

    public func refreshMessages() {
        let recent = chatEngine.getRecentMessages(petId: petId, limit: 100)
        if !recent.isEmpty {
            messages = recent
        }
    }
}
