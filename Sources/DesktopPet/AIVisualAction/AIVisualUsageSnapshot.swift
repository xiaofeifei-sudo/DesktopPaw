import Foundation

public enum AIVisualUsageStatus: String, Codable, Sendable, Equatable {
    case reserved
    case succeeded
    case failed
}

public struct AIVisualUsageRecord: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let source: AIVisualActionSource
    public let petId: String
    public let reservedAt: Date
    public var status: AIVisualUsageStatus
    public var providerId: String?
    public var assetId: String?
    public var errorCode: String?
    public var completedAt: Date?

    public init(
        id: String,
        source: AIVisualActionSource,
        petId: String,
        reservedAt: Date = Date(),
        status: AIVisualUsageStatus = .reserved
    ) {
        self.id = id
        self.source = source
        self.petId = petId
        self.reservedAt = reservedAt
        self.status = status
    }
}

public struct AIVisualQuotaConfig: Sendable, Equatable {
    public let dailyAutonomousLimit: Int
    public let dailyUserRequestLimit: Int
    public let dailyTotalLimit: Int
    public let monthlyTotalLimit: Int

    public static let `default` = AIVisualQuotaConfig(
        dailyAutonomousLimit: 2,
        dailyUserRequestLimit: 3,
        dailyTotalLimit: 5,
        monthlyTotalLimit: 80
    )

    public init(
        dailyAutonomousLimit: Int = 2,
        dailyUserRequestLimit: Int = 3,
        dailyTotalLimit: Int = 5,
        monthlyTotalLimit: Int = 80
    ) {
        self.dailyAutonomousLimit = dailyAutonomousLimit
        self.dailyUserRequestLimit = dailyUserRequestLimit
        self.dailyTotalLimit = dailyTotalLimit
        self.monthlyTotalLimit = monthlyTotalLimit
    }
}

public enum AIVisualQuotaDecision: Sendable, Equatable {
    case allowed
    case dailyAutonomousExceeded
    case dailyUserRequestExceeded
    case dailyTotalExceeded
    case monthlyTotalExceeded
}

public struct AIVisualUsageSnapshot: Sendable, Equatable {
    public let petId: String
    public let date: Date
    public let dailyAutonomousCount: Int
    public let dailyUserRequestCount: Int
    public let dailyTotalCount: Int
    public let monthlyTotalCount: Int
    public let lastAutonomousAt: Date?
    public let pendingCount: Int

    public init(
        petId: String,
        date: Date,
        dailyAutonomousCount: Int,
        dailyUserRequestCount: Int,
        dailyTotalCount: Int,
        monthlyTotalCount: Int,
        lastAutonomousAt: Date? = nil,
        pendingCount: Int = 0
    ) {
        self.petId = petId
        self.date = date
        self.dailyAutonomousCount = dailyAutonomousCount
        self.dailyUserRequestCount = dailyUserRequestCount
        self.dailyTotalCount = dailyTotalCount
        self.monthlyTotalCount = monthlyTotalCount
        self.lastAutonomousAt = lastAutonomousAt
        self.pendingCount = pendingCount
    }

    public func remaining(for config: AIVisualQuotaConfig) -> Int {
        max(config.dailyTotalLimit - dailyTotalCount, 0)
    }

    public func monthlyRemaining(for config: AIVisualQuotaConfig) -> Int {
        max(config.monthlyTotalLimit - monthlyTotalCount, 0)
    }
}
