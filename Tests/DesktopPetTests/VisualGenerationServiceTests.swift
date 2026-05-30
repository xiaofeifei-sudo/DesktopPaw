import Foundation
import DesktopPet

@MainActor
func runVisualGenerationServiceTests() async throws {
    let tests = VisualGenerationServiceTests()
    try await tests.generateUsesSelectedProvider()
    await tests.generateThrowsNotConfigured()
    await tests.generateMapsUnknownErrors()
    await tests.generatePassesThroughVisualGenerationErrors()
    try await tests.quotaSnapshotReturnsResult()
    try await tests.quotaSnapshotReturnsNilWhenNotConfigured()
    tests.currentProviderIdReturnsSelected()
    try await tests.selectProviderSwitches()
    tests.selectProviderFailsForUnknown()
    tests.availableProvidersReturnsAll()
    tests.currentCapabilitiesReturnsProviderCapabilities()
    tests.currentCapabilitiesReturnsNilWhenNoProvider()
    await tests.generateWithEmptyRegistryReturnsNotConfigured()
}

@MainActor
private struct VisualGenerationServiceTests {
    private func makeRequest(actionId: String = "act-1") -> VisualGenerationRequest {
        VisualGenerationRequest(
            actionId: actionId,
            petId: "pet-1",
            prompt: "a happy cat wearing a hat",
            referenceImageURL: nil,
            aspectRatio: "1:1",
            outputDirectory: URL(fileURLWithPath: "/tmp/test-output"),
            outputPrefix: "act-1"
        )
    }

    func generateUsesSelectedProvider() async throws {
        let registry = VisualGenerationProviderRegistry()
        let mock = MockImageGenerator()
        registry.register(mock)
        let service = VisualGenerationService(registry: registry)

        let request = makeRequest()
        let result = try await service.generate(request)
        expect(result.providerId == "mock", "should use mock provider")
        expect(result.actionId == "act-1", "should return correct actionId")
        expect(mock.generateCallCount == 1, "should call generate once")
    }

    func generateThrowsNotConfigured() async {
        let registry = VisualGenerationProviderRegistry()
        let mock = MockImageGenerator(isConfigured: false)
        registry.register(mock)
        let service = VisualGenerationService(registry: registry)

        let request = makeRequest()
        do {
            _ = try await service.generate(request)
            fail("should throw notConfigured")
        } catch let error as VisualGenerationError {
            if case .notConfigured(let id) = error {
                expect(id == "mock", "should identify unconfigured provider")
            } else {
                fail("expected notConfigured, got \(error)")
            }
        } catch {
            fail("unexpected error type: \(error)")
        }
    }

    func generateMapsUnknownErrors() async {
        let registry = VisualGenerationProviderRegistry()
        let mock = MockImageGenerator()
        mock.stubResult(.failure(NSError(domain: "test", code: 42, userInfo: nil)))
        registry.register(mock)
        let service = VisualGenerationService(registry: registry)

        do {
            _ = try await service.generate(makeRequest())
            fail("should throw")
        } catch let error as VisualGenerationError {
            if case .unknown(let id, _) = error {
                expect(id == "mock", "should wrap error with provider id")
            } else {
                fail("expected unknown error, got \(error)")
            }
        } catch {
            fail("unexpected error type: \(error)")
        }
    }

    func generatePassesThroughVisualGenerationErrors() async {
        let registry = VisualGenerationProviderRegistry()
        let mock = MockImageGenerator()
        mock.stubResult(.failure(VisualGenerationError.timeout(providerId: "mock")))
        registry.register(mock)
        let service = VisualGenerationService(registry: registry)

        do {
            _ = try await service.generate(makeRequest())
            fail("should throw")
        } catch let error as VisualGenerationError {
            if case .timeout(let id) = error {
                expect(id == "mock", "should pass through timeout error")
            } else {
                fail("expected timeout, got \(error)")
            }
        } catch {
            fail("unexpected error type: \(error)")
        }
    }

    func quotaSnapshotReturnsResult() async throws {
        let registry = VisualGenerationProviderRegistry()
        let mock = MockImageGenerator()
        let quota = VisualProviderQuotaSnapshot(providerId: "mock", dailyLimit: 120, dailyUsed: 10)
        mock.stubQuota(quota)
        registry.register(mock)
        let service = VisualGenerationService(registry: registry)

        let snapshot = try await service.quotaSnapshot()
        expect(snapshot?.dailyLimit == 120, "should return provider quota")
        expect(snapshot?.dailyUsed == 10, "should return provider daily used")
    }

    func quotaSnapshotReturnsNilWhenNotConfigured() async throws {
        let registry = VisualGenerationProviderRegistry()
        let mock = MockImageGenerator(isConfigured: false)
        registry.register(mock)
        let service = VisualGenerationService(registry: registry)

        let snapshot = try await service.quotaSnapshot()
        expect(snapshot == nil, "should return nil when not configured")
    }

    func currentProviderIdReturnsSelected() {
        let registry = VisualGenerationProviderRegistry()
        let mock = MockImageGenerator()
        registry.register(mock)
        let service = VisualGenerationService(registry: registry)

        expect(service.currentProviderId() == "mock", "should return default provider id")
    }

    func selectProviderSwitches() async throws {
        let registry = VisualGenerationProviderRegistry()
        registry.register(MockImageGenerator())
        registry.register(AnotherServiceProvider())
        let service = VisualGenerationService(registry: registry)

        let ok = service.selectProvider("another-service")
        expect(ok == true, "should succeed selecting registered provider")
        expect(service.currentProviderId() == "another-service", "should switch provider")

        let result = try await service.generate(makeRequest())
        expect(result.providerId == "another-service", "should use newly selected provider")
    }

    func selectProviderFailsForUnknown() {
        let registry = VisualGenerationProviderRegistry()
        registry.register(MockImageGenerator())
        let service = VisualGenerationService(registry: registry)

        let ok = service.selectProvider("nonexistent")
        expect(ok == false, "should fail for unknown provider")
        expect(service.currentProviderId() == "mock", "should keep current provider")
    }

    func availableProvidersReturnsAll() {
        let registry = VisualGenerationProviderRegistry()
        registry.register(MockImageGenerator())
        registry.register(AnotherServiceProvider())
        let service = VisualGenerationService(registry: registry)

        let providers = service.availableProviders()
        expect(providers.count == 2, "should return all registered providers")
    }

    func currentCapabilitiesReturnsProviderCapabilities() {
        let registry = VisualGenerationProviderRegistry()
        let cap = VisualGenerationCapabilities(
            supportsReferenceImage: true,
            supportsImageEdit: false,
            supportsTransparentBackground: true,
            supportsQuotaSnapshot: false
        )
        let mock = MockImageGenerator(capabilities: cap)
        registry.register(mock)
        let service = VisualGenerationService(registry: registry)

        let capabilities = service.currentCapabilities()
        expect(capabilities == cap, "should return current provider capabilities")
    }

    func currentCapabilitiesReturnsNilWhenNoProvider() {
        let registry = VisualGenerationProviderRegistry()
        let service = VisualGenerationService(registry: registry)

        let capabilities = service.currentCapabilities()
        expect(capabilities == nil, "should return nil when no provider is selected")
    }

    func generateWithEmptyRegistryReturnsNotConfigured() async {
        let registry = VisualGenerationProviderRegistry()
        let service = VisualGenerationService(registry: registry)

        do {
            _ = try await service.generate(makeRequest())
            fail("should throw notConfigured")
        } catch let error as VisualGenerationError {
            if case .notConfigured(let id) = error {
                expect(id == "unconfigured", "should use unconfigured fallback provider")
            } else {
                fail("expected notConfigured, got \(error)")
            }
        } catch {
            fail("unexpected error type: \(error)")
        }
    }
}

private final class AnotherServiceProvider: VisualImageGenerating, @unchecked Sendable {
    let providerId = "another-service"
    let displayName = "Another Service"
    let capabilities = VisualGenerationCapabilities.basic
    let isConfigured = true

    func generate(_ request: VisualGenerationRequest) async throws -> VisualGenerationResult {
        VisualGenerationResult(actionId: request.actionId, imageURL: request.outputDirectory.appendingPathComponent("out.png"), providerId: providerId)
    }

    func quotaSnapshot() async throws -> VisualProviderQuotaSnapshot? { nil }
}
