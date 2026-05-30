import Foundation
import DesktopPet

@MainActor
func runAIProviderRegistryTests() {
    let tests = AIProviderRegistryTests()
    tests.registerAndRetrieve()
    tests.registerReplacesExisting()
    tests.unregisterRemovesProvider()
    tests.getProviderReturnsNilForUnknown()
    tests.getAllProvidersReturnsAll()
    tests.availableProviderIds()
    tests.emptyRegistry()
}

@MainActor
private struct AIProviderRegistryTests {
    func registerAndRetrieve() {
        let registry = AIProviderRegistry()
        let provider = MockAIProvider()
        registry.register(provider)

        let retrieved = registry.getProvider(id: "mock")
        expect(retrieved != nil, "should retrieve registered provider")
        expect(retrieved?.providerId == "mock", "retrieved provider should have correct id")
    }

    func registerReplacesExisting() {
        let registry = AIProviderRegistry()
        let first = MockAIProvider()
        first.stubbedResponse = "first"
        let second = MockAIProvider()
        second.stubbedResponse = "second"

        registry.register(first)
        registry.register(second)

        let retrieved = registry.getProvider(id: "mock")
        expect(retrieved?.providerId == "mock", "should retrieve the latest registered provider")
    }

    func unregisterRemovesProvider() {
        let registry = AIProviderRegistry()
        registry.register(MockAIProvider())
        expect(registry.getProvider(id: "mock") != nil, "provider should be registered")

        registry.unregister(providerId: "mock")
        expect(registry.getProvider(id: "mock") == nil, "provider should be removed after unregister")
    }

    func getProviderReturnsNilForUnknown() {
        let registry = AIProviderRegistry()
        expect(registry.getProvider(id: "nonexistent") == nil, "should return nil for unknown provider")
    }

    func getAllProvidersReturnsAll() {
        let registry = AIProviderRegistry()
        let mockProvider = MockAIProvider()

        let config = AIProviderConfig(endpoint: URL(string: "https://api.example.com/v1/chat/completions")!)
        let httpProvider = HTTPAIProvider(providerId: "custom-http", config: config)

        registry.register(mockProvider)
        registry.register(httpProvider)

        let all = registry.getAllProviders()
        expect(all.count == 2, "should return all registered providers")
    }

    func availableProviderIds() {
        let registry = AIProviderRegistry()
        registry.register(MockAIProvider())

        let config = AIProviderConfig(endpoint: URL(string: "https://api.example.com/v1/chat/completions")!)
        registry.register(HTTPAIProvider(providerId: "my-provider", config: config))

        let ids = registry.availableProviderIds
        expect(ids.count == 2, "should have 2 provider ids")
        expect(ids.contains("mock"), "should contain mock provider id")
        expect(ids.contains("my-provider"), "should contain custom provider id")
    }

    func emptyRegistry() {
        let registry = AIProviderRegistry()
        expect(registry.getAllProviders().isEmpty, "new registry should be empty")
        expect(registry.availableProviderIds.isEmpty, "new registry should have no ids")
    }
}
