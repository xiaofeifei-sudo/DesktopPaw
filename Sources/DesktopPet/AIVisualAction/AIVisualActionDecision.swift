import Foundation

public enum AIVisualConfirmationReason: String, Codable, Sendable, Equatable {
    case firstTrigger
    case highImpact
    case sceneOrTheme
    case userRequest
}

public enum AIVisualDenyReason: String, Codable, Sendable, Equatable {
    case aiDisabled
    case visualExpressionDisabled
    case quietMode
    case bubbleDisabled
    case quotaExceeded
    case rateLimited
    case safetyRejected
    case generationInProgress
    case kindNotAllowed
}

public enum AIVisualActionDecision: Equatable, Sendable {
    case allow(AIVisualActionCandidate)
    case needsConfirmation(AIVisualActionCandidate, reason: AIVisualConfirmationReason)
    case deny(reason: AIVisualDenyReason, userFacingText: String?)
    case throttled(until: Date, userFacingText: String?)
}
