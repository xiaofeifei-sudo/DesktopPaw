import Foundation
import DesktopPet

@MainActor
func runAIChatEngineTests() async throws {
    let tests = AIChatEngineTests()
    try await tests.sendMessageReturnsResponse()
    try await tests.sendMessageBlocksHighRiskInput()
    try await tests.sendMessageBlocksHighRiskOutput()
    try await tests.sendMessageFallsBackOnError()
    try await tests.sendMessageExtractsMemory()
    try await tests.sendMessageFallsBackWhenMemoryDisabled()
    try await tests.sendMessageTruncatesLongBubble()
    try await tests.getActiveSessionReturnsNilWhenNone()
    tests.startSessionCreatesNew()
    try await tests.endSessionMarksInactive()
    try await tests.getRecentMessagesReturnsLastN()
    tests.contextMessagesTrimsOldMessages()
    try await tests.sendMessageMaintainsSessionHistory()
    try await tests.sendMessageParsesVisualAction()
    try await tests.sendMessageCleansVisualActionFromDisplay()
    try await tests.sendMessageWithInvalidVisualAction()
    try await tests.sendMessageWithoutParserSkipsVisualAction()
}

@MainActor
func runAIChatSessionTests() {
    let tests = AIChatSessionTests()
    tests.sessionIsActiveWhenNotEnded()
    tests.sessionIsNotActiveWhenEnded()
    tests.contextMessagesReturnsAllWhenUnderLimit()
    tests.contextMessagesTrimsNonSystemMessages()
    tests.contextMessagesPreservesSystemMessages()
}

@MainActor
func runAIChatContextBuilderTests() {
    let tests = AIChatContextBuilderTests()
    tests.buildReturnsContextWithSystemPrompt()
    tests.buildIncludesMemoryContent()
    tests.buildUsesDynamicPersonalityProvider()
}

// MARK: - AIChatEngine Tests

@MainActor
private struct AIChatEngineTests {
    private func makeEngine(
        stubbedResponse: String = "[BUBBLE]我在呢[/BUBBLE]\n[PANEL]我一直在这里陪你[/PANEL]",
        withVisualParser: Bool = false
    ) -> (engine: AIChatEngine, mockProvider: MockAIProvider, mockMemoryStore: MockMemoryStoreForChat) {
        let mockProvider = MockAIProvider(stubbedResponse: stubbedResponse)
        let mockMemory = MockMemoryStoreForChat()
        let safety = AISafetyService()
        let personality = AIPersonalityEngine()
        let parser: AIVisualActionParser? = withVisualParser ? AIVisualActionParser() : nil
        let engine = AIChatEngine(
            provider: mockProvider,
            memoryStore: mockMemory,
            safetyService: safety,
            personalityEngine: personality,
            visualActionParser: parser
        )
        return (engine, mockProvider, mockMemory)
    }

    func sendMessageReturnsResponse() async throws {
        let (engine, _, _) = makeEngine()
        let response = try await engine.sendMessage("你好", petId: "test-pet")
        expect(response.bubbleText == "我在呢", "should extract bubble text")
        expect(response.panelText == "我一直在这里陪你", "should extract panel text")
        expect(response.safetyLevel == .safe, "should be safe")
        expect(response.message.role == .assistant, "response should be from assistant")
    }

    func sendMessageBlocksHighRiskInput() async throws {
        let (engine, _, _) = makeEngine()
        let response = try await engine.sendMessage("我不想活了", petId: "test-pet")
        expect(response.safetyLevel >= .critical, "should be critical or higher")
        expect(response.bubbleText != nil, "should have fallback bubble text")
    }

    func sendMessageBlocksHighRiskOutput() async throws {
        let (engine, _, _) = makeEngine(stubbedResponse: "别和别人说，只跟我说")
        let _ = try await engine.sendMessage("你好", petId: "test-pet")
        let safety = AISafetyService()
        let risk = safety.classifyRisk(content: "别和别人说，只跟我说")
        expect(risk >= .medium, "possessive/exclusive content should be detected")
    }

    func sendMessageFallsBackOnError() async throws {
        let mockProvider = FailingMockProvider()
        let mockMemory = MockMemoryStoreForChat()
        let safety = AISafetyService()
        let personality = AIPersonalityEngine()
        let engine = AIChatEngine(
            provider: mockProvider,
            memoryStore: mockMemory,
            safetyService: safety,
            personalityEngine: personality
        )
        let response = try await engine.sendMessage("你好", petId: "test-pet")
        expect(response.panelText == "暂时无法回复", "should show fallback text")
        expect(response.bubbleText == "暂时无法回复", "fallback should also be in bubble")
    }

    func sendMessageExtractsMemory() async throws {
        let (engine, _, mockMemory) = makeEngine(
            stubbedResponse: "[BUBBLE]好的[/BUBBLE]\n[PANEL]记住了[/PANEL]\n[MEMORY]用户喜欢喝咖啡[/MEMORY]"
        )
        let response = try await engine.sendMessage("我喜欢喝咖啡", petId: "test-pet")
        expect(response.memoryUpdates.count == 1, "should extract one memory")
        expect(response.memoryUpdates.first?.content == "用户喜欢喝咖啡", "should extract correct content")
        expect(response.memoryUpdates.first?.source == .aiExtracted, "should be aiExtracted")
        expect(mockMemory.addedMemories.count == 1, "memory should be written to store")
    }

    func sendMessageFallsBackWhenMemoryDisabled() async throws {
        let (engine, _, mockMemory) = makeEngine(
            stubbedResponse: "[BUBBLE]好的[/BUBBLE]\n[PANEL]记住了[/PANEL]\n[MEMORY]用户喜欢喝咖啡[/MEMORY]"
        )
        mockMemory.enabled = false
        let response = try await engine.sendMessage("我喜欢咖啡", petId: "test-pet")
        expect(response.memoryUpdates.isEmpty, "should not extract memory when disabled")
        expect(mockMemory.addedMemories.isEmpty, "should not write to store when disabled")
    }

    func sendMessageTruncatesLongBubble() async throws {
        let longText = String(repeating: "这是一句很长的话", count: 10)
        let (engine, _, _) = makeEngine(stubbedResponse: longText)
        let response = try await engine.sendMessage("你好", petId: "test-pet")
        if let bubble = response.bubbleText {
            expect(bubble.count <= 13, "bubble text should be truncated (12 chars + ellipsis)")
        }
    }

    func getActiveSessionReturnsNilWhenNone() async throws {
        let (engine, _, _) = makeEngine()
        expect(engine.getActiveSession(petId: "test-pet") == nil,
               "should return nil when no session exists")
    }

    func startSessionCreatesNew() {
        let (engine, _, _) = makeEngine()
        let session = engine.startSession(petId: "test-pet")
        expect(session.petId == "test-pet", "session should have correct petId")
        expect(session.isActive, "new session should be active")
        expect(session.messages.isEmpty, "new session should have no messages")
    }

    func endSessionMarksInactive() async throws {
        let (engine, _, _) = makeEngine()
        _ = engine.startSession(petId: "test-pet")
        engine.endSession(petId: "test-pet")
        expect(engine.getActiveSession(petId: "test-pet") == nil,
               "ended session should not be active")
    }

    func getRecentMessagesReturnsLastN() async throws {
        let (engine, _, _) = makeEngine()
        _ = try await engine.sendMessage("msg1", petId: "test-pet")
        _ = try await engine.sendMessage("msg2", petId: "test-pet")
        _ = try await engine.sendMessage("msg3", petId: "test-pet")
        let recent = engine.getRecentMessages(petId: "test-pet", limit: 2)
        expect(recent.count == 2, "should return last 2 messages")
        expect(recent.first?.role == .user, "first recent should be user")
        expect(recent.first?.content == "msg3", "first recent should be msg3 (user)")
    }

    func contextMessagesTrimsOldMessages() {
        var messages: [AIChatMessage] = []
        for i in 0..<25 {
            messages.append(AIChatMessage(role: .user, content: "msg\(i)"))
        }
        let session = AIChatSession(petId: "test", messages: messages, maxContextMessages: 20)
        let context = session.contextMessages()
        expect(context.count == 20, "should trim to maxContextMessages")
    }

    func sendMessageMaintainsSessionHistory() async throws {
        let (engine, _, _) = makeEngine()
        _ = try await engine.sendMessage("hello", petId: "test-pet")
        let recent = engine.getRecentMessages(petId: "test-pet", limit: 10)
        expect(recent.count == 2, "should have user + assistant message")
        expect(recent.first?.role == .user, "first should be user")
        expect(recent.last?.role == .assistant, "last should be assistant")
    }

    func sendMessageParsesVisualAction() async throws {
        let stubbedResponse = """
        [BUBBLE]我来换个造型[/BUBBLE]
        [PANEL]让我给你看看新造型[/PANEL]
        [VISUAL_ACTION]
        {"kind": "accessory", "description": "戴一顶红色圣诞帽", "renderMode": "overlayImage", "durationSeconds": 120, "impact": "low"}
        [/VISUAL_ACTION]
        """
        let (engine, _, _) = makeEngine(stubbedResponse: stubbedResponse, withVisualParser: true)
        let response = try await engine.sendMessage("换个造型", petId: "test-pet")

        expect(response.visualActionCandidates.count == 1, "should have one visual action candidate")
        let candidate = response.visualActionCandidates.first!
        expect(candidate.kind == .accessory, "should be accessory kind")
        expect(candidate.description == "戴一顶红色圣诞帽", "should parse description")
        expect(candidate.renderMode == .overlayImage, "should parse renderMode")
        expect(candidate.source == .chat, "source should be chat")
    }

    func sendMessageCleansVisualActionFromDisplay() async throws {
        let stubbedResponse = """
        [BUBBLE]准备好了[/BUBBLE]
        [PANEL]看看新造型[/PANEL]
        [VISUAL_ACTION]
        {"kind": "expression", "description": "开心", "renderMode": "replaceWholeImage", "impact": "low"}
        [/VISUAL_ACTION]
        """
        let (engine, _, _) = makeEngine(stubbedResponse: stubbedResponse, withVisualParser: true)
        let response = try await engine.sendMessage("你好", petId: "test-pet")

        expect(!response.message.content.contains("[VISUAL_ACTION]"),
               "message content should not contain visual action tags")
        expect(!response.message.content.contains("[/VISUAL_ACTION]"),
               "message content should not contain closing visual action tags")
        expect(response.bubbleText == "准备好了", "bubble text should be clean")
    }

    func sendMessageWithInvalidVisualAction() async throws {
        let stubbedResponse = """
        [BUBBLE]好的[/BUBBLE]
        [PANEL]没问题[/PANEL]
        [VISUAL_ACTION]{bad json}[/VISUAL_ACTION]
        """
        let (engine, _, _) = makeEngine(stubbedResponse: stubbedResponse, withVisualParser: true)
        let response = try await engine.sendMessage("你好", petId: "test-pet")

        expect(response.visualActionCandidates.isEmpty, "invalid JSON should not produce candidates")
        expect(!response.message.content.contains("[VISUAL_ACTION]"),
               "tags should still be cleaned from display")
        expect(response.bubbleText == "好的", "bubble should still work")
    }

    func sendMessageWithoutParserSkipsVisualAction() async throws {
        let stubbedResponse = """
        [BUBBLE]你好[/BUBBLE]
        [PANEL]你好呀[/PANEL]
        [VISUAL_ACTION]
        {"kind": "expression", "description": "开心", "renderMode": "replaceWholeImage", "impact": "low"}
        [/VISUAL_ACTION]
        """
        let (engine, _, _) = makeEngine(stubbedResponse: stubbedResponse, withVisualParser: false)
        let response = try await engine.sendMessage("你好", petId: "test-pet")

        expect(response.visualActionCandidates.isEmpty, "without parser, no candidates should be produced")
        expect(response.message.content.contains("[VISUAL_ACTION]"),
               "without parser, tags remain in message content")
    }
}

// MARK: - AIChatSession Tests

@MainActor
private struct AIChatSessionTests {
    func sessionIsActiveWhenNotEnded() {
        let session = AIChatSession(petId: "test")
        expect(session.isActive, "session without endedAt should be active")
    }

    func sessionIsNotActiveWhenEnded() {
        var session = AIChatSession(petId: "test")
        session.endedAt = Date()
        expect(!session.isActive, "ended session should not be active")
    }

    func contextMessagesReturnsAllWhenUnderLimit() {
        let messages = (0..<5).map { AIChatMessage(role: .user, content: "msg\($0)") }
        let session = AIChatSession(petId: "test", messages: messages, maxContextMessages: 20)
        expect(session.contextMessages().count == 5, "should return all when under limit")
    }

    func contextMessagesTrimsNonSystemMessages() {
        var messages: [AIChatMessage] = [
            AIChatMessage(role: .system, content: "system prompt")
        ]
        for i in 0..<25 {
            messages.append(AIChatMessage(role: .user, content: "msg\(i)"))
        }
        let session = AIChatSession(petId: "test", messages: messages, maxContextMessages: 20)
        let context = session.contextMessages()
        let systemCount = context.filter { $0.role == .system }.count
        expect(systemCount == 1, "system message should be preserved")
        expect(context.count <= 21, "should be system + max 20 non-system messages")
    }

    func contextMessagesPreservesSystemMessages() {
        let messages = (0..<5).map { AIChatMessage(role: .user, content: "msg\($0)") }
        let session = AIChatSession(petId: "test", messages: messages, maxContextMessages: 20)
        let context = session.contextMessages()
        expect(context.count == 5, "all messages should be present")
    }
}

// MARK: - AIChatContextBuilder Tests

@MainActor
private struct AIChatContextBuilderTests {
    private func makeContext() -> CompanionContext {
        CompanionContext(
            petId: "test-pet",
            petDisplayName: "小猫咪",
            petNickname: nil,
            userNickname: nil,
            runtimeState: .defaultState(),
            relationship: RelationshipSnapshot(intimacyPoints: 100, currentLevel: .familiar),
            preferences: CompanionPreferences(),
            timeSlots: [],
            recentBubbleTexts: [],
            lastCompanionEvent: nil
        )
    }

    func buildReturnsContextWithSystemPrompt() {
        let builder = AIChatContextBuilder(
            personalityEngine: AIPersonalityEngine(),
            personalityProfile: .gentle
        )
        let context = builder.build(context: makeContext(), memoryContext: nil)
        expect(!context.systemPrompt.isEmpty, "system prompt should not be empty")
        expect(context.systemPrompt.contains("温柔"), "should mention personality style")
    }

    func buildIncludesMemoryContent() {
        let builder = AIChatContextBuilder(
            personalityEngine: AIPersonalityEngine(),
            personalityProfile: .gentle
        )
        let memoryContext = "【关于用户】\n- 偏好：喜欢安静"
        let context = builder.build(context: makeContext(), memoryContext: memoryContext)
        expect(context.systemPrompt.contains("喜欢安静"), "should include memory content")
    }

    func buildUsesDynamicPersonalityProvider() {
        let packProfile = AIPersonalityProfile(
            id: "pack.personality",
            name: "内容包人格",
            description: "来自内容包的人格",
            previewPhrases: ["你好"],
            toneGuidelines: "说话要像内容包人格",
            responseMaxLength: 12,
            panelResponseMaxLength: 200,
            canInitiativeBubble: false,
            initiativeBubbleFrequency: 1800
        )
        let builder = AIChatContextBuilder(
            personalityEngine: AIPersonalityEngine(),
            personalityProfileProvider: { packProfile }
        )

        let context = builder.build(context: makeContext(), memoryContext: nil)

        expect(context.systemPrompt.contains("内容包人格"),
               "dynamic personality provider should influence chat context")
    }
}

// MARK: - Test Doubles

final class MockMemoryStoreForChat: AIMemoryStoring, @unchecked Sendable {
    private var memories: [AIMemory] = []
    var enabled = true
    var addedMemories: [AIMemory] = []

    func loadAll(petId: String) -> [AIMemory] {
        guard enabled else { return [] }
        return memories.filter { $0.petId == petId }
    }

    func add(_ memory: AIMemory, petId: String) throws {
        guard enabled else { throw AIMemoryStoreError.memoryDisabled }
        addedMemories.append(memory)
        memories.append(memory)
    }

    func update(_ memory: AIMemory, petId: String) throws {}
    func delete(memoryId: String, petId: String) throws {}
    func clearAll(petId: String) throws { memories.removeAll { $0.petId == petId } }
    func exportMemories(petId: String) throws -> URL { URL(fileURLWithPath: "/tmp/test") }
    func isMemoryEnabled(petId: String) -> Bool { enabled }
    func setMemoryEnabled(_ enabled: Bool, petId: String) { self.enabled = enabled }

    func loadByCategory(_ category: AIMemoryCategory, petId: String) -> [AIMemory] {
        guard enabled else { return [] }
        return memories.filter { $0.petId == petId && $0.category == category }
    }

    func search(keyword: String, petId: String) -> [AIMemory] {
        guard enabled else { return [] }
        return memories.filter { $0.petId == petId && $0.content.localizedCaseInsensitiveContains(keyword) }
    }

    func incrementAccessCount(id: String, petId: String) throws {}

    func deleteByCategory(_ category: AIMemoryCategory, petId: String) throws {
        memories.removeAll { $0.petId == petId && $0.category == category }
    }

    func memoryStatistics(petId: String) -> MemoryStatistics {
        let petMemories = memories.filter { $0.petId == petId }
        var counts: [AIMemoryCategory: Int] = [:]
        for m in petMemories { counts[m.category, default: 0] += 1 }
        return MemoryStatistics(totalCount: petMemories.count, capacity: 1000, categoryCounts: counts)
    }
}

final class FailingMockProvider: AIProviding, @unchecked Sendable {
    let providerId = "failing"
    let displayName = "Failing Provider"
    let isConfigured = true

    func complete(messages: [AIChatMessage], context: AIChatContext) async throws -> AIChatMessage {
        throw AIProviderError.networkError("connection failed")
    }

    func completeStreaming(messages: [AIChatMessage], context: AIChatContext) -> AsyncThrowingStream<AIChatMessageChunk, Error> {
        AsyncThrowingStream { $0.finish(throwing: AIProviderError.networkError("connection failed")) }
    }

    func estimateTokenCount(for text: String) -> Int { 0 }
}
