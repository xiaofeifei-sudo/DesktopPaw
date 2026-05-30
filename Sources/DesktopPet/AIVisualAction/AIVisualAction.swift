import Foundation

public enum AIVisualActionKind: String, Codable, Sendable, CaseIterable {
    case expression
    case pose
    case accessory
    case ambience
    case theme
    case scene

    public static let phase1Allowed: Set<AIVisualActionKind> = [.expression, .pose, .accessory, .ambience]

    public var isPhase1Allowed: Bool { Self.phase1Allowed.contains(self) }
}

public enum AIVisualActionSource: String, Codable, Sendable {
    case chat
    case smartBubble
    case relationshipEvent
    case userRequest
}

public enum AIVisualActionImpact: String, Codable, Sendable, CaseIterable {
    case low
    case medium
    case high
}

public enum PetVisualRenderMode: String, Codable, Sendable {
    case replaceWholeImage
    case overlayImage
}

public struct AIVisualActionCandidate: Identifiable, Codable, Sendable, Equatable {
    public let id: String
    public let petId: String
    public let source: AIVisualActionSource
    public let kind: AIVisualActionKind
    public let description: String
    public let promptHint: String?
    public let renderMode: PetVisualRenderMode
    public let requestedDurationSeconds: TimeInterval
    public let impact: AIVisualActionImpact
    public let createdAt: Date

    public static let minDurationSeconds: TimeInterval = 30
    public static let maxDurationSeconds: TimeInterval = 600

    public init(
        id: String,
        petId: String,
        source: AIVisualActionSource,
        kind: AIVisualActionKind,
        description: String,
        promptHint: String? = nil,
        renderMode: PetVisualRenderMode,
        requestedDurationSeconds: TimeInterval,
        impact: AIVisualActionImpact,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.petId = petId
        self.source = source
        self.kind = kind
        self.description = description
        self.promptHint = promptHint
        self.renderMode = renderMode
        self.requestedDurationSeconds = Self.clampDuration(requestedDurationSeconds)
        self.impact = impact
        self.createdAt = createdAt
    }

    public static func clampDuration(_ seconds: TimeInterval) -> TimeInterval {
        min(max(seconds, minDurationSeconds), maxDurationSeconds)
    }
}
