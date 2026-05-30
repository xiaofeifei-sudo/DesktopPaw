import Foundation

public struct AIProviderConfig: Codable, Equatable, Sendable {
    public var endpoint: URL
    public var model: String
    public var temperature: Double
    public var maxTokens: Int

    public init(
        endpoint: URL,
        model: String = "gpt-4o-mini",
        temperature: Double = 0.7,
        maxTokens: Int = 256
    ) {
        self.endpoint = endpoint
        self.model = model
        self.temperature = temperature
        self.maxTokens = maxTokens
    }
}

public enum AIProviderError: Error, Sendable, Equatable, LocalizedError {
    case notConfigured
    case invalidEndpoint
    case networkError(String)
    case timeout
    case rateLimited
    case invalidResponse
    case apiError(String)
    case apiKeyNotFound
    case apiKeySaveFailed(String)

    public var errorDescription: String? {
        switch self {
        case .notConfigured: "AI provider is not configured"
        case .invalidEndpoint: "Invalid API endpoint"
        case .networkError(let detail): "Network error: \(detail)"
        case .timeout: "Request timed out"
        case .rateLimited: "Rate limited by API"
        case .invalidResponse: "Invalid response from API"
        case .apiError(let detail): "API error: \(detail)"
        case .apiKeyNotFound: "API key not found"
        case .apiKeySaveFailed(let detail): "Failed to save API key: \(detail)"
        }
    }
}

public final class KeychainStore: @unchecked Sendable {
    private let service: String

    public init(service: String = "com.desktoppet.aiprovider") {
        self.service = service
    }

    func saveAPIKey(_ key: String, for providerId: String) -> Bool {
        let query = baseQuery(providerId: providerId)
        SecItemDelete(query as CFDictionary)

        var addQuery = query
        addQuery[kSecValueData as String] = Data(key.utf8)
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        return status == errSecSuccess
    }

    func loadAPIKey(for providerId: String) -> String? {
        var query = baseQuery(providerId: providerId)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    func deleteAPIKey(for providerId: String) -> Bool {
        let query = baseQuery(providerId: providerId)
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    private func baseQuery(providerId: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "apikey-\(providerId)"
        ]
    }
}
