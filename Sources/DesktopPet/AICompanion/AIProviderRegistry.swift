import Foundation

public final class AIProviderRegistry: @unchecked Sendable {
    private var providers: [String: AIProviding] = [:]

    public init() {}

    public func register(_ provider: AIProviding) {
        providers[provider.providerId] = provider
    }

    public func unregister(providerId: String) {
        providers.removeValue(forKey: providerId)
    }

    public func getProvider(id: String) -> AIProviding? {
        providers[id]
    }

    public func getAllProviders() -> [AIProviding] {
        Array(providers.values)
    }

    public var availableProviderIds: [String] {
        Array(providers.keys)
    }
}
