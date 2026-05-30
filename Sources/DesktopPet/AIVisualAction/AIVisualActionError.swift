import Foundation

public enum AIVisualActionError: Error, Sendable, Equatable {
    case aiDisabled
    case visualExpressionDisabled
    case quietModeActive
    case quotaExceeded
    case rateLimited(retryAfter: TimeInterval)
    case safetyRejected(reason: String)
    case generationInProgress
    case kindNotAllowed(kind: String)
    case generationFailed(underlying: String)
    case providerNotConfigured(providerId: String)
    case invalidCandidate(reason: String)
}
