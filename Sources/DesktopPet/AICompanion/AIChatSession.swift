import Foundation

public struct AIChatSession: Identifiable, Sendable {
    public let id: String
    public let petId: String
    public let startedAt: Date
    public var messages: [AIChatMessage]
    public var endedAt: Date?
    public let maxContextMessages: Int

    public init(
        id: String = UUID().uuidString,
        petId: String,
        startedAt: Date = Date(),
        messages: [AIChatMessage] = [],
        endedAt: Date? = nil,
        maxContextMessages: Int = 20
    ) {
        self.id = id
        self.petId = petId
        self.startedAt = startedAt
        self.messages = messages
        self.endedAt = endedAt
        self.maxContextMessages = maxContextMessages
    }

    public var isActive: Bool {
        endedAt == nil
    }

    public func contextMessages() -> [AIChatMessage] {
        let nonSystem = messages.filter { $0.role != .system }
        guard nonSystem.count > maxContextMessages else { return messages }

        let systemMessages = messages.filter { $0.role == .system }
        let trimmed = nonSystem.suffix(maxContextMessages)
        return systemMessages + trimmed
    }
}

public struct AIChatResponse: Sendable, Equatable {
    public let message: AIChatMessage
    public let bubbleText: String?
    public let panelText: String
    public let safetyLevel: AIRiskLevel
    public let memoryUpdates: [AIMemory]
    public let visualActionCandidates: [AIVisualActionCandidate]

    public init(
        message: AIChatMessage,
        bubbleText: String?,
        panelText: String,
        safetyLevel: AIRiskLevel,
        memoryUpdates: [AIMemory] = [],
        visualActionCandidates: [AIVisualActionCandidate] = []
    ) {
        self.message = message
        self.bubbleText = bubbleText
        self.panelText = panelText
        self.safetyLevel = safetyLevel
        self.memoryUpdates = memoryUpdates
        self.visualActionCandidates = visualActionCandidates
    }
}

public protocol AIChatEngining: Sendable {
    func sendMessage(_ text: String, petId: String) async throws -> AIChatResponse
    func sendMessageStreaming(_ text: String, petId: String) -> AsyncThrowingStream<AIChatStreamEvent, Error>
    func getActiveSession(petId: String) -> AIChatSession?
    func startSession(petId: String) -> AIChatSession
    func endSession(petId: String)
    func getRecentMessages(petId: String, limit: Int) -> [AIChatMessage]
    func updateProvider(_ provider: AIProviding)
}

public enum AIChatStreamEvent: Sendable {
    case token(String)
    case completed(AIChatResponse)
}
