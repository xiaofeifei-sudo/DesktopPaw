import Foundation
import DesktopPet

@MainActor
func runChatPanelViewModelTests() async {
    let tests = ChatPanelViewModelTests()
    tests.initSetsPetId()
    tests.loadSessionStartsNewSession()
    await tests.loadSessionRestoresExistingMessages()
    await tests.sendMessageAppendsUserAndAssistantMessages()
    await tests.sendMessageClearsInputText()
    await tests.sendMessageSetsIsSendingAfterCompletion()
    await tests.sendMessageHandlesError()
    tests.sendMessageIgnoresEmptyInput()
    tests.sendMessageIgnoresWhitespaceOnlyInput()
    await tests.sendMessageCallsOnBubbleEmitted()
    await tests.refreshMessagesUpdatesFromEngine()
}

@MainActor
private struct ChatPanelViewModelTests {
    private func makeViewModel(
        petId: String = "test-pet",
        stubbedResponse: String = "测试回复"
    ) -> (ChatPanelViewModel, MockAIProvider) {
        let provider = MockAIProvider(stubbedResponse: stubbedResponse)
        let memoryStore = AIMemoryStore()
        let safetyService = AISafetyService()
        let personalityEngine = AIPersonalityEngine()
        let chatEngine = AIChatEngine(
            provider: provider,
            memoryStore: memoryStore,
            safetyService: safetyService,
            personalityEngine: personalityEngine
        )
        let vm = ChatPanelViewModel(chatEngine: chatEngine, petId: petId)
        return (vm, provider)
    }

    func initSetsPetId() {
        let (vm, _) = makeViewModel(petId: "my-pet")
        expect(vm.messages.isEmpty, "messages should be empty initially")
        expect(vm.isSending == false, "isSending should be false initially")
        expect(vm.inputText.isEmpty, "inputText should be empty initially")
    }

    func loadSessionStartsNewSession() {
        let (vm, _) = makeViewModel()
        vm.loadSession()
        expect(vm.messages.isEmpty, "new session should have no messages")
    }

    func loadSessionRestoresExistingMessages() async {
        let provider = MockAIProvider(stubbedResponse: "回复")
        let chatEngine = AIChatEngine(
            provider: provider,
            memoryStore: AIMemoryStore(),
            safetyService: AISafetyService(),
            personalityEngine: AIPersonalityEngine()
        )

        let vm = ChatPanelViewModel(chatEngine: chatEngine, petId: "test-pet")
        vm.loadSession()
        await vm.sendAndWait(text: "嗨")
        expect(vm.messages.count == 2, "first VM should have 2 messages after sendAndWait")

        let vm2 = ChatPanelViewModel(chatEngine: chatEngine, petId: "test-pet")
        vm2.loadSession()
        expect(vm2.messages.count == 2, "second VM should restore 2 messages from engine session")
    }

    func sendMessageAppendsUserAndAssistantMessages() async {
        let (vm, _) = makeViewModel()
        vm.loadSession()
        await vm.sendAndWait(text: "你好")

        expect(vm.messages.count == 2, "should have user + assistant messages")
        expect(vm.messages[0].role == .user, "first message should be user")
        expect(vm.messages[0].content == "你好", "user message content should match input")
        expect(vm.messages[1].role == .assistant, "second message should be assistant")
    }

    func sendMessageClearsInputText() async {
        let (vm, _) = makeViewModel()
        vm.loadSession()
        vm.inputText = "你好"
        await vm.sendAndWait(text: "你好")
        expect(vm.inputText.isEmpty, "input text should be cleared after sending")
    }

    func sendMessageSetsIsSendingAfterCompletion() async {
        let (vm, _) = makeViewModel()
        vm.loadSession()
        await vm.sendAndWait(text: "你好")
        expect(vm.isSending == false, "isSending should be false after send completes")
    }

    func sendMessageHandlesError() async {
        let provider = FailingAIProvider()
        let chatEngine = AIChatEngine(
            provider: provider,
            memoryStore: AIMemoryStore(),
            safetyService: AISafetyService(),
            personalityEngine: AIPersonalityEngine()
        )
        let vm = ChatPanelViewModel(chatEngine: chatEngine, petId: "test-pet")
        vm.loadSession()
        await vm.sendAndWait(text: "你好")

        expect(vm.messages.count == 2, "should have user + fallback messages")
        expect(vm.messages[1].content == "暂时无法回复", "should show fallback text on error")
    }

    func sendMessageIgnoresEmptyInput() {
        let (vm, _) = makeViewModel()
        vm.loadSession()
        vm.inputText = ""
        vm.sendMessage()
        expect(vm.messages.isEmpty, "should not send empty message")
    }

    func sendMessageIgnoresWhitespaceOnlyInput() {
        let (vm, _) = makeViewModel()
        vm.loadSession()
        vm.inputText = "   \n  "
        vm.sendMessage()
        expect(vm.messages.isEmpty, "should not send whitespace-only message")
    }

    func sendMessageCallsOnBubbleEmitted() async {
        var emittedResponse: AIChatResponse?
        let (vm, _) = makeViewModel()
        vm.onBubbleEmitted = { response in emittedResponse = response }
        vm.loadSession()
        await vm.sendAndWait(text: "你好")

        expect(emittedResponse != nil, "onBubbleEmitted should be called")
    }

    func refreshMessagesUpdatesFromEngine() async {
        let provider = MockAIProvider()
        let chatEngine = AIChatEngine(
            provider: provider,
            memoryStore: AIMemoryStore(),
            safetyService: AISafetyService(),
            personalityEngine: AIPersonalityEngine()
        )

        let vm = ChatPanelViewModel(chatEngine: chatEngine, petId: "test-pet")
        vm.loadSession()
        await vm.sendAndWait(text: "你好")
        expect(vm.messages.count == 2, "first VM should have 2 messages")

        let vm2 = ChatPanelViewModel(chatEngine: chatEngine, petId: "test-pet")
        vm2.refreshMessages()
        expect(vm2.messages.count == 2, "refreshMessages should load messages from shared engine")
    }
}

private final class FailingAIProvider: AIProviding, @unchecked Sendable {
    let providerId = "failing"
    let displayName = "Failing Provider"
    let isConfigured = true

    func complete(messages: [AIChatMessage], context: AIChatContext) async throws -> AIChatMessage {
        throw AIProviderError.networkError("test failure")
    }

    func completeStreaming(messages: [AIChatMessage], context: AIChatContext) -> AsyncThrowingStream<AIChatMessageChunk, Error> {
        AsyncThrowingStream { $0.finish(throwing: AIProviderError.networkError("test failure")) }
    }

    func estimateTokenCount(for text: String) -> Int { 0 }
}
