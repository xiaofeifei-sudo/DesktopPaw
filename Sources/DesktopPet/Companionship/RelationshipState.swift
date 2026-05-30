import Foundation

public struct RelationshipDailyCounters: Codable, Equatable, Sendable {
    public var dateKey: String?
    public var dailyFirstVisitCount: Int
    public var longAbsenceReturnCount: Int
    public var clickCount: Int
    public var petCount: Int
    public var feedCount: Int
    public var actionPlayedCount: Int
    public var careCount: Int
    public var microDialogCount: Int

    public init(
        dateKey: String? = nil,
        dailyFirstVisitCount: Int = 0,
        longAbsenceReturnCount: Int = 0,
        clickCount: Int = 0,
        petCount: Int = 0,
        feedCount: Int = 0,
        actionPlayedCount: Int = 0,
        careCount: Int = 0,
        microDialogCount: Int = 0
    ) {
        self.dateKey = dateKey
        self.dailyFirstVisitCount = dailyFirstVisitCount
        self.longAbsenceReturnCount = longAbsenceReturnCount
        self.clickCount = clickCount
        self.petCount = petCount
        self.feedCount = feedCount
        self.actionPlayedCount = actionPlayedCount
        self.careCount = careCount
        self.microDialogCount = microDialogCount
    }
}

public struct RelationshipCooldowns: Codable, Equatable, Sendable {
    public var lastClickAt: Date?
    public var lastPetAt: Date?
    public var lastFeedAt: Date?
    public var lastActionPlayedAt: Date?
    public var lastSleepCareAt: Date?
    public var lastWakeCareAt: Date?
    public var lastMicroDialogAt: Date?

    public init(
        lastClickAt: Date? = nil,
        lastPetAt: Date? = nil,
        lastFeedAt: Date? = nil,
        lastActionPlayedAt: Date? = nil,
        lastSleepCareAt: Date? = nil,
        lastWakeCareAt: Date? = nil,
        lastMicroDialogAt: Date? = nil
    ) {
        self.lastClickAt = lastClickAt
        self.lastPetAt = lastPetAt
        self.lastFeedAt = lastFeedAt
        self.lastActionPlayedAt = lastActionPlayedAt
        self.lastSleepCareAt = lastSleepCareAt
        self.lastWakeCareAt = lastWakeCareAt
        self.lastMicroDialogAt = lastMicroDialogAt
    }
}

public struct RelationshipSnapshot: Codable, Equatable, Sendable {
    public let intimacyPoints: Int
    public let currentLevel: RelationshipLevel
    public let levelNumber: Int
    public let levelName: String
    public let currentLevelMinimumPoints: Int
    public let nextLevelMinimumPoints: Int?

    public init(
        intimacyPoints: Int,
        currentLevel: RelationshipLevel
    ) {
        self.intimacyPoints = max(0, intimacyPoints)
        self.currentLevel = currentLevel
        self.levelNumber = currentLevel.levelNumber
        self.levelName = currentLevel.displayName
        self.currentLevelMinimumPoints = currentLevel.minimumPoints
        self.nextLevelMinimumPoints = currentLevel.nextLevelMinimumPoints
    }
}

public struct RelationshipState: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var intimacyPoints: Int
    public var lastVisitDate: Date?
    public var lastSeenAt: Date?
    public var consecutiveVisitDays: Int
    public var unlockedMilestoneIds: Set<String>
    public var dailyCounters: RelationshipDailyCounters
    public var cooldowns: RelationshipCooldowns
    public var summary: InteractionSummary

    public init(
        schemaVersion: Int = RelationshipState.currentSchemaVersion,
        intimacyPoints: Int = 0,
        lastVisitDate: Date? = nil,
        lastSeenAt: Date? = nil,
        consecutiveVisitDays: Int = 0,
        unlockedMilestoneIds: Set<String> = [],
        dailyCounters: RelationshipDailyCounters = RelationshipDailyCounters(),
        cooldowns: RelationshipCooldowns = RelationshipCooldowns(),
        summary: InteractionSummary = InteractionSummary()
    ) {
        self.schemaVersion = schemaVersion
        self.intimacyPoints = max(0, intimacyPoints)
        self.lastVisitDate = lastVisitDate
        self.lastSeenAt = lastSeenAt
        self.consecutiveVisitDays = max(0, consecutiveVisitDays)
        self.unlockedMilestoneIds = unlockedMilestoneIds
        self.dailyCounters = dailyCounters
        self.cooldowns = cooldowns
        self.summary = summary
    }

    public var currentLevel: RelationshipLevel {
        RelationshipLevel.level(for: intimacyPoints)
    }

    public var snapshot: RelationshipSnapshot {
        RelationshipSnapshot(intimacyPoints: intimacyPoints, currentLevel: currentLevel)
    }
}
