import Foundation

public struct VisualGenerationResult: Sendable, Equatable {
    public let actionId: String
    public let imageURL: URL
    public let providerId: String

    public init(actionId: String, imageURL: URL, providerId: String) {
        self.actionId = actionId
        self.imageURL = imageURL
        self.providerId = providerId
    }
}

public struct VisualProviderQuotaSnapshot: Sendable, Equatable {
    public let providerId: String
    public let dailyLimit: Int?
    public let dailyUsed: Int?
    public let monthlyLimit: Int?
    public let monthlyUsed: Int?
    public let fetchedAt: Date

    public init(
        providerId: String,
        dailyLimit: Int? = nil,
        dailyUsed: Int? = nil,
        monthlyLimit: Int? = nil,
        monthlyUsed: Int? = nil,
        fetchedAt: Date = Date()
    ) {
        self.providerId = providerId
        self.dailyLimit = dailyLimit
        self.dailyUsed = dailyUsed
        self.monthlyLimit = monthlyLimit
        self.monthlyUsed = monthlyUsed
        self.fetchedAt = fetchedAt
    }

    public var dailyRemaining: Int? {
        guard let limit = dailyLimit, let used = dailyUsed else { return nil }
        return max(limit - used, 0)
    }

    public var monthlyRemaining: Int? {
        guard let limit = monthlyLimit, let used = monthlyUsed else { return nil }
        return max(limit - used, 0)
    }
}
