import Foundation

public protocol VisualGenerationServicing: Sendable {
    func generate(_ request: VisualGenerationRequest) async throws -> VisualGenerationResult
    func quotaSnapshot() async throws -> VisualProviderQuotaSnapshot?
    func currentProviderId() -> String?
    func availableProviders() -> [ProviderInfo]
    func selectProvider(_ providerId: String) -> Bool
    func currentCapabilities() -> VisualGenerationCapabilities?
}

public final class VisualGenerationService: VisualGenerationServicing, @unchecked Sendable {
    private let registry: VisualGenerationProviderRegistry
    private let queue = DispatchQueue(label: "visual-generation-service")
    private var _selectedProviderId: String?

    public init(registry: VisualGenerationProviderRegistry) {
        self.registry = registry
        self._selectedProviderId = registry.defaultProviderId
    }

    public func generate(_ request: VisualGenerationRequest) async throws -> VisualGenerationResult {
        let provider = resolveProvider()
        guard provider.isConfigured else {
            throw VisualGenerationError.notConfigured(providerId: provider.providerId)
        }
        do {
            return try await provider.generate(request)
        } catch let error as VisualGenerationError {
            throw error
        } catch {
            throw VisualGenerationError.unknown(providerId: provider.providerId, underlying: String(describing: error))
        }
    }

    public func quotaSnapshot() async throws -> VisualProviderQuotaSnapshot? {
        let provider = resolveProvider()
        guard provider.isConfigured else {
            return nil
        }
        return try await provider.quotaSnapshot()
    }

    public func currentProviderId() -> String? {
        queue.sync { _selectedProviderId }
    }

    public func availableProviders() -> [ProviderInfo] {
        registry.allProviderInfos()
    }

    public func selectProvider(_ providerId: String) -> Bool {
        guard registry.provider(for: providerId) != nil else { return false }
        queue.sync { _selectedProviderId = providerId }
        return true
    }

    public func currentCapabilities() -> VisualGenerationCapabilities? {
        let id = queue.sync { _selectedProviderId }
        guard let id = id, let provider = registry.provider(for: id) else { return nil }
        return provider.capabilities
    }

    private func resolveProvider() -> VisualImageGenerating {
        let id = queue.sync { _selectedProviderId }

        if let id = id, let provider = registry.provider(for: id) {
            return provider
        }
        if let fallback = registry.defaultProviderId, let provider = registry.provider(for: fallback) {
            return provider
        }
        let all = registry.allProviderInfos()
        if let first = all.first, let provider = registry.provider(for: first.providerId) {
            return provider
        }
        return UnconfiguredProvider()
    }
}

private final class UnconfiguredProvider: VisualImageGenerating, @unchecked Sendable {
    let providerId = "unconfigured"
    let displayName = "No Provider"
    let capabilities = VisualGenerationCapabilities.basic
    let isConfigured = false

    func generate(_ request: VisualGenerationRequest) async throws -> VisualGenerationResult {
        throw VisualGenerationError.notConfigured(providerId: providerId)
    }

    func quotaSnapshot() async throws -> VisualProviderQuotaSnapshot? {
        nil
    }
}
