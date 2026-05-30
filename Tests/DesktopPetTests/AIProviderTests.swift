import Foundation
import DesktopPet

@MainActor
func runAIProviderTests() async throws {
    let tests = AIProviderTests()
    await tests.mockProviderReturnsStubbedResponse()
    await tests.mockProviderTracksCallCount()
    await tests.mockProviderTracksLastMessages()
    await tests.mockProviderTracksLastContext()
    tests.mockProviderIsConfiguredByDefault()
    try await tests.mockProviderStreamingYieldsChunk()
    tests.mockProviderEstimatesTokenCount()
    await tests.mockProviderCanBeReconfigured()
    tests.httpProviderReportsNotConfiguredWithoutKey()
    tests.httpProviderEstimatesTokenCount()
    tests.httpProviderBuildsCorrectRequest()
    tests.providerConfigEquality()
    tests.providerErrorDescriptions()
}

@MainActor
private struct AIProviderTests {
    func mockProviderReturnsStubbedResponse() async {
        let provider = MockAIProvider(stubbedResponse: "hello from mock")
        let messages = [AIChatMessage(role: .user, content: "hi")]
        let context = AIChatContext(systemPrompt: "you are a pet")

        let response = try? await provider.complete(messages: messages, context: context)
        expect(response != nil, "mock provider should return a response")
        expect(response?.content == "hello from mock", "mock provider should return stubbed content")
        expect(response?.role == .assistant, "response role should be assistant")
    }

    func mockProviderTracksCallCount() async {
        let provider = MockAIProvider()
        let messages = [AIChatMessage(role: .user, content: "hi")]
        let context = AIChatContext()

        expect(provider.completeCallCount == 0, "initial call count should be 0")
        _ = try? await provider.complete(messages: messages, context: context)
        expect(provider.completeCallCount == 1, "call count should be 1 after one call")
        _ = try? await provider.complete(messages: messages, context: context)
        expect(provider.completeCallCount == 2, "call count should be 2 after two calls")
    }

    func mockProviderTracksLastMessages() async {
        let provider = MockAIProvider()
        let messages = [
            AIChatMessage(role: .system, content: "system prompt"),
            AIChatMessage(role: .user, content: "hello")
        ]
        _ = try? await provider.complete(messages: messages, context: AIChatContext())

        expect(provider.lastMessages?.count == 2, "should track last messages")
        expect(provider.lastMessages?[0].role == .system, "first message should be system")
        expect(provider.lastMessages?[1].content == "hello", "second message should be hello")
    }

    func mockProviderTracksLastContext() async {
        let provider = MockAIProvider()
        let context = AIChatContext(systemPrompt: "be friendly", temperature: 0.5, maxTokens: 100)
        _ = try? await provider.complete(messages: [], context: context)

        expect(provider.lastContext?.systemPrompt == "be friendly", "should track system prompt")
        expect(provider.lastContext?.temperature == 0.5, "should track temperature override")
        expect(provider.lastContext?.maxTokens == 100, "should track maxTokens override")
    }

    func mockProviderIsConfiguredByDefault() {
        let provider = MockAIProvider()
        expect(provider.isConfigured, "mock provider should be configured by default")
        expect(provider.providerId == "mock", "mock provider id should be 'mock'")
        expect(provider.displayName == "Mock Provider", "mock provider display name should be correct")
    }

    func mockProviderStreamingYieldsChunk() async throws {
        let provider = MockAIProvider(stubbedResponse: "stream test")
        let stream = provider.completeStreaming(messages: [], context: AIChatContext())
        var chunks: [AIChatMessageChunk] = []
        for try await chunk in stream {
            chunks.append(chunk)
        }
        expect(!chunks.isEmpty, "streaming should yield at least one chunk")
        expect(chunks.last?.isFinished == true, "last chunk should be finished")
    }

    func mockProviderEstimatesTokenCount() {
        let provider = MockAIProvider()
        let count = provider.estimateTokenCount(for: "hello world test")
        expect(count > 0, "token estimate should be positive")
        expect(count == 4, "4-char-per-token estimate for 16 chars should be 4")
    }

    func mockProviderCanBeReconfigured() async {
        let provider = MockAIProvider(stubbedResponse: "first")
        expect(provider.stubbedResponse == "first", "initial response should be 'first'")

        provider.stubbedResponse = "second"
        let response = try? await provider.complete(messages: [], context: AIChatContext())
        expect(response?.content == "second", "should return updated stubbed response")
    }

    func httpProviderReportsNotConfiguredWithoutKey() {
        let config = AIProviderConfig(endpoint: URL(string: "https://api.example.com/v1/chat/completions")!)
        let isolatedKeychain = KeychainStore(service: "com.desktoppet.test.isolated.\(UUID().uuidString)")
        let provider = HTTPAIProvider(config: config, keychainStore: isolatedKeychain)
        expect(!provider.isConfigured, "HTTP provider should not be configured without API key")
        expect(provider.providerId == "http-openai", "default provider id should be 'http-openai'")
    }

    func httpProviderEstimatesTokenCount() {
        let config = AIProviderConfig(endpoint: URL(string: "https://api.example.com/v1/chat/completions")!)
        let provider = HTTPAIProvider(config: config)
        let count = provider.estimateTokenCount(for: "hello world")
        expect(count > 0, "token estimate should be positive")
    }

    func httpProviderBuildsCorrectRequest() {
        let config = AIProviderConfig(
            endpoint: URL(string: "https://api.example.com/v1/chat/completions")!,
            model: "gpt-4",
            temperature: 0.8,
            maxTokens: 512
        )
        expect(config.model == "gpt-4", "model should be gpt-4")
        expect(config.temperature == 0.8, "temperature should be 0.8")
        expect(config.maxTokens == 512, "maxTokens should be 512")
    }

    func providerConfigEquality() {
        let url = URL(string: "https://api.example.com/v1/chat/completions")!
        let config1 = AIProviderConfig(endpoint: url, model: "gpt-4", temperature: 0.7, maxTokens: 256)
        let config2 = AIProviderConfig(endpoint: url, model: "gpt-4", temperature: 0.7, maxTokens: 256)
        let config3 = AIProviderConfig(endpoint: url, model: "gpt-4o", temperature: 0.7, maxTokens: 256)
        expect(config1 == config2, "identical configs should be equal")
        expect(config1 != config3, "different configs should not be equal")
    }

    func providerErrorDescriptions() {
        let errors: [AIProviderError] = [
            .notConfigured,
            .invalidEndpoint,
            .timeout,
            .rateLimited,
            .invalidResponse,
            .apiKeyNotFound
        ]
        for error in errors {
            expect(error.errorDescription != nil, "\(error) should have a description")
        }

        let networkError = AIProviderError.networkError("connection lost")
        expect(networkError.errorDescription?.contains("connection lost") == true, "network error should include detail")

        let apiError = AIProviderError.apiError("bad request")
        expect(apiError.errorDescription?.contains("bad request") == true, "API error should include detail")
    }
}
