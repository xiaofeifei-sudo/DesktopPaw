import Foundation
import DesktopPet

@MainActor
func runVisualGenerationProviderRegistryTests() {
    let tests = VisualGenerationProviderRegistryTests()
    tests.registerSetsDefaultProvider()
    tests.unregisterRemovesProvider()
    tests.unregisterResetsDefaultToNext()
    tests.providerReturnsRegistered()
    tests.providerReturnsNilForUnknown()
    tests.setDefaultProviderIdSucceedsForRegistered()
    tests.setDefaultProviderIdFailsForUnknown()
    tests.allProviderInfosReturnsSorted()
    tests.countTracksProviders()
    tests.allProviderInfosReflectsCapabilities()
}

@MainActor
private struct VisualGenerationProviderRegistryTests {
    func registerSetsDefaultProvider() {
        let registry = VisualGenerationProviderRegistry()
        let mock = MockImageGenerator()
        registry.register(mock)

        expect(registry.defaultProviderId == "mock", "first registered provider should be default")
    }

    func unregisterRemovesProvider() {
        let registry = VisualGenerationProviderRegistry()
        let mock = MockImageGenerator()
        registry.register(mock)
        registry.unregister(providerId: "mock")

        expect(registry.defaultProviderId == nil, "default should be nil after unregistering only provider")
        expect(registry.provider(for: "mock") == nil, "provider should be nil after unregister")
    }

    func unregisterResetsDefaultToNext() {
        let registry = VisualGenerationProviderRegistry()
        registry.register(MockImageGenerator())
        let second = AnotherMockProvider()
        registry.register(second)

        registry.unregister(providerId: "mock")
        expect(registry.defaultProviderId == "another", "default should fall back to next sorted provider")
    }

    func providerReturnsRegistered() {
        let registry = VisualGenerationProviderRegistry()
        let mock = MockImageGenerator()
        registry.register(mock)

        let found = registry.provider(for: "mock")
        expect(found != nil, "should find registered provider")
        expect(found?.providerId == "mock", "found provider should have correct id")
    }

    func providerReturnsNilForUnknown() {
        let registry = VisualGenerationProviderRegistry()
        let found = registry.provider(for: "nonexistent")
        expect(found == nil, "should return nil for unregistered provider")
    }

    func setDefaultProviderIdSucceedsForRegistered() {
        let registry = VisualGenerationProviderRegistry()
        registry.register(MockImageGenerator())
        registry.register(AnotherMockProvider())

        let result = registry.setDefaultProviderId("another")
        expect(result == true, "should succeed setting registered provider as default")
        expect(registry.defaultProviderId == "another", "default should be updated")
    }

    func setDefaultProviderIdFailsForUnknown() {
        let registry = VisualGenerationProviderRegistry()
        registry.register(MockImageGenerator())

        let result = registry.setDefaultProviderId("nonexistent")
        expect(result == false, "should fail setting unknown provider as default")
        expect(registry.defaultProviderId == "mock", "default should remain unchanged")
    }

    func allProviderInfosReturnsSorted() {
        let registry = VisualGenerationProviderRegistry()
        registry.register(AnotherMockProvider())
        registry.register(MockImageGenerator())

        let infos = registry.allProviderInfos()
        expect(infos.count == 2, "should have 2 providers")
        expect(infos[0].providerId == "another", "first should be 'another' (sorted)")
        expect(infos[1].providerId == "mock", "second should be 'mock' (sorted)")
    }

    func countTracksProviders() {
        let registry = VisualGenerationProviderRegistry()
        expect(registry.count == 0, "should start empty")

        registry.register(MockImageGenerator())
        expect(registry.count == 1, "should have 1 after register")

        registry.unregister(providerId: "mock")
        expect(registry.count == 0, "should have 0 after unregister")
    }

    func allProviderInfosReflectsCapabilities() {
        let registry = VisualGenerationProviderRegistry()
        let cap = VisualGenerationCapabilities(
            supportsReferenceImage: true,
            supportsImageEdit: false,
            supportsTransparentBackground: true,
            supportsQuotaSnapshot: true
        )
        let mock = MockImageGenerator(isConfigured: false, capabilities: cap)
        registry.register(mock)

        let infos = registry.allProviderInfos()
        expect(infos.count == 1, "should have 1 provider")
        expect(infos[0].isConfigured == false, "should reflect isConfigured")
        expect(infos[0].capabilities == cap, "should reflect capabilities")
    }
}

private final class AnotherMockProvider: VisualImageGenerating, @unchecked Sendable {
    let providerId = "another"
    let displayName = "Another Mock"
    let capabilities = VisualGenerationCapabilities.basic
    let isConfigured = true

    func generate(_ request: VisualGenerationRequest) async throws -> VisualGenerationResult {
        VisualGenerationResult(actionId: request.actionId, imageURL: request.outputDirectory.appendingPathComponent("out.png"), providerId: providerId)
    }

    func quotaSnapshot() async throws -> VisualProviderQuotaSnapshot? { nil }
}
