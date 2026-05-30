import Foundation
import DesktopPet

@MainActor
func runAIProviderConfigTests() {
    let tests = AIProviderConfigTests()
    tests.defaultConfigValues()
    tests.customConfigValues()
    tests.configCodableRoundTrip()
    tests.configEquality()
    tests.configInequality()
    tests.errorEquality()
    tests.chatMessageDefaultId()
    tests.chatMessageEquality()
    tests.chatRoleRawValues()
    tests.chatContextDefaults()
    tests.chatContextEquality()
    tests.chatContextOverrides()
    tests.chatMessageChunk()
}

@MainActor
private struct AIProviderConfigTests {
    func defaultConfigValues() {
        let url = URL(string: "https://api.example.com/v1/chat/completions")!
        let config = AIProviderConfig(endpoint: url)
        expect(config.model == "gpt-4o-mini", "default model should be gpt-4o-mini")
        expect(config.temperature == 0.7, "default temperature should be 0.7")
        expect(config.maxTokens == 256, "default maxTokens should be 256")
        expect(config.endpoint == url, "endpoint should match")
    }

    func customConfigValues() {
        let url = URL(string: "https://custom.api.com/v1/chat/completions")!
        let config = AIProviderConfig(endpoint: url, model: "gpt-4", temperature: 0.3, maxTokens: 1024)
        expect(config.model == "gpt-4", "model should be gpt-4")
        expect(config.temperature == 0.3, "temperature should be 0.3")
        expect(config.maxTokens == 1024, "maxTokens should be 1024")
    }

    func configCodableRoundTrip() {
        let url = URL(string: "https://api.example.com/v1/chat/completions")!
        let config = AIProviderConfig(endpoint: url, model: "gpt-4", temperature: 0.5, maxTokens: 512)

        let encoder = JSONEncoder()
        let data = try? encoder.encode(config)
        expect(data != nil, "config should encode to JSON")

        let decoder = JSONDecoder()
        let decoded = try? decoder.decode(AIProviderConfig.self, from: data!)
        expect(decoded == config, "decoded config should equal original")
    }

    func configEquality() {
        let url = URL(string: "https://api.example.com/v1/chat/completions")!
        let a = AIProviderConfig(endpoint: url)
        let b = AIProviderConfig(endpoint: url)
        expect(a == b, "identical configs should be equal")
    }

    func configInequality() {
        let url1 = URL(string: "https://api1.example.com/v1/chat/completions")!
        let url2 = URL(string: "https://api2.example.com/v1/chat/completions")!
        let a = AIProviderConfig(endpoint: url1)
        let b = AIProviderConfig(endpoint: url2)
        expect(a != b, "different configs should not be equal")
    }

    func errorEquality() {
        let a = AIProviderError.timeout
        let b = AIProviderError.timeout
        expect(a == b, "identical errors should be equal")

        let c = AIProviderError.rateLimited
        expect(a != c, "different errors should not be equal")

        let d = AIProviderError.networkError("lost")
        let e = AIProviderError.networkError("lost")
        expect(d == e, "errors with same associated value should be equal")

        let f = AIProviderError.networkError("reset")
        expect(d != f, "errors with different associated values should not be equal")
    }

    func chatMessageDefaultId() {
        let msg = AIChatMessage(role: .user, content: "hi")
        expect(!msg.id.isEmpty, "message should have a default UUID id")
        expect(msg.role == .user, "role should be user")
        expect(msg.content == "hi", "content should match")
    }

    func chatMessageEquality() {
        let id = "test-id"
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let a = AIChatMessage(id: id, role: .user, content: "hi", createdAt: date)
        let b = AIChatMessage(id: id, role: .user, content: "hi", createdAt: date)
        expect(a == b, "identical messages should be equal")

        let c = AIChatMessage(id: id, role: .assistant, content: "hi", createdAt: date)
        expect(a != c, "messages with different roles should not be equal")
    }

    func chatRoleRawValues() {
        expect(AIChatRole.user.rawValue == "user", "user raw value should be 'user'")
        expect(AIChatRole.assistant.rawValue == "assistant", "assistant raw value should be 'assistant'")
        expect(AIChatRole.system.rawValue == "system", "system raw value should be 'system'")
    }

    func chatContextDefaults() {
        let context = AIChatContext()
        expect(context.systemPrompt.isEmpty, "default system prompt should be empty")
        expect(context.temperature == nil, "default temperature override should be nil")
        expect(context.maxTokens == nil, "default maxTokens override should be nil")
    }

    func chatContextEquality() {
        let a = AIChatContext(systemPrompt: "hello", temperature: 0.5, maxTokens: 100)
        let b = AIChatContext(systemPrompt: "hello", temperature: 0.5, maxTokens: 100)
        expect(a == b, "identical contexts should be equal")

        let c = AIChatContext(systemPrompt: "world", temperature: 0.5, maxTokens: 100)
        expect(a != c, "different contexts should not be equal")
    }

    func chatContextOverrides() {
        let context = AIChatContext(systemPrompt: "be nice", temperature: 0.3, maxTokens: 50)
        expect(context.systemPrompt == "be nice", "systemPrompt should match")
        expect(context.temperature == 0.3, "temperature should match")
        expect(context.maxTokens == 50, "maxTokens should match")
    }

    func chatMessageChunk() {
        let chunk = AIChatMessageChunk(content: "hello", isFinished: false)
        expect(chunk.content == "hello", "chunk content should match")
        expect(!chunk.isFinished, "chunk should not be finished")

        let finalChunk = AIChatMessageChunk(content: "", isFinished: true)
        expect(finalChunk.isFinished, "final chunk should be finished")

        let a = AIChatMessageChunk(content: "hi", isFinished: false)
        let b = AIChatMessageChunk(content: "hi", isFinished: false)
        expect(a == b, "identical chunks should be equal")
    }
}
