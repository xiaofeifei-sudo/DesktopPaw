import Foundation

public enum AIVisualMetricEventType: String, Codable, Sendable, Equatable, CaseIterable {
    case candidateParsed
    case policyDenied
    case confirmationAccepted
    case confirmationRejected
    case generationStarted
    case generationSucceeded
    case generationFailed
    case overlayApplied
    case overlayRestored
    case quotaExceeded
    case safetyRejected
    case favoriteCreated
}

public struct AIVisualMetricEvent: Identifiable, Codable, Sendable, Equatable {
    public let id: String
    public let type: AIVisualMetricEventType
    public let actionId: String
    public let petId: String
    public let timestamp: Date
    public let providerId: String?
    public let errorCode: String?
    public let durationSeconds: Double?
    public let denyReason: String?

    public init(
        id: String = UUID().uuidString,
        type: AIVisualMetricEventType,
        actionId: String,
        petId: String,
        timestamp: Date = Date(),
        providerId: String? = nil,
        errorCode: String? = nil,
        durationSeconds: Double? = nil,
        denyReason: String? = nil
    ) {
        self.id = id
        self.type = type
        self.actionId = actionId
        self.petId = petId
        self.timestamp = timestamp
        self.providerId = providerId
        self.errorCode = errorCode
        self.durationSeconds = durationSeconds
        self.denyReason = denyReason
    }
}

public struct AIVisualDiagnosticsSummary: Codable, Sendable, Equatable {
    public let totalEvents: Int
    public let eventCounts: [String: Int]
    public let generationSuccessCount: Int
    public let generationFailureCount: Int
    public let averageGenerationDurationSeconds: Double?
    public let userRestoreRate: Double
    public let favoriteCount: Int
    public let quotaExceededCount: Int
    public let safetyRejectedCount: Int
    public let providerErrorCounts: [String: Int]

    public init(
        totalEvents: Int,
        eventCounts: [String: Int],
        generationSuccessCount: Int,
        generationFailureCount: Int,
        averageGenerationDurationSeconds: Double?,
        userRestoreRate: Double,
        favoriteCount: Int,
        quotaExceededCount: Int,
        safetyRejectedCount: Int,
        providerErrorCounts: [String: Int]
    ) {
        self.totalEvents = totalEvents
        self.eventCounts = eventCounts
        self.generationSuccessCount = generationSuccessCount
        self.generationFailureCount = generationFailureCount
        self.averageGenerationDurationSeconds = averageGenerationDurationSeconds
        self.userRestoreRate = userRestoreRate
        self.favoriteCount = favoriteCount
        self.quotaExceededCount = quotaExceededCount
        self.safetyRejectedCount = safetyRejectedCount
        self.providerErrorCounts = providerErrorCounts
    }
}
