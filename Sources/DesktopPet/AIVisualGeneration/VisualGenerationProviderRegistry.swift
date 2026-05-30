import Foundation

public final class VisualGenerationProviderRegistry: @unchecked Sendable {
    private let lock = NSLock()
    private var providers: [String: VisualImageGenerating] = [:]
    private var _defaultProviderId: String?

    public var defaultProviderId: String? {
        lock.lock()
        defer { lock.unlock() }
        return _defaultProviderId
    }

    public init() {}

    public func register(_ provider: VisualImageGenerating) {
        lock.lock()
        defer { lock.unlock() }
        providers[provider.providerId] = provider
        if _defaultProviderId == nil {
            _defaultProviderId = provider.providerId
        }
    }

    public func unregister(providerId: String) {
        lock.lock()
        defer { lock.unlock() }
        providers.removeValue(forKey: providerId)
        if _defaultProviderId == providerId {
            _defaultProviderId = providers.keys.sorted().first
        }
    }

    public func provider(for id: String) -> VisualImageGenerating? {
        lock.lock()
        defer { lock.unlock() }
        return providers[id]
    }

    public func setDefaultProviderId(_ id: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard providers[id] != nil else { return false }
        _defaultProviderId = id
        return true
    }

    public func allProviderInfos() -> [ProviderInfo] {
        lock.lock()
        defer { lock.unlock() }
        return providers.values.map { provider in
            ProviderInfo(
                providerId: provider.providerId,
                displayName: provider.displayName,
                isConfigured: provider.isConfigured,
                capabilities: provider.capabilities
            )
        }.sorted { $0.providerId < $1.providerId }
    }

    public var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return providers.count
    }
}
