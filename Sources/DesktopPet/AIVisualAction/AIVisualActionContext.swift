import Foundation

public struct AIVisualActionContext: Codable, Equatable, Sendable {
    public var isAIEnabled: Bool
    public var isVisualExpressionEnabled: Bool
    public var isQuietMode: Bool
    public var isBubbleEnabled: Bool
    public var petId: String
    public var petName: String
    public var petDescriptor: String?
    public var hasActiveOverlay: Bool
    public var hasPreviousVisualAction: Bool
    public var isQuotaExceeded: Bool
    public var rateLimitResetAt: Date?
    public var preferredThemes: Set<AIVisualThemePreference>
    public var dislikedContent: Set<AIVisualDislikedContent>
    public var activeFavoriteId: String?

    public init(
        isAIEnabled: Bool,
        isVisualExpressionEnabled: Bool,
        isQuietMode: Bool,
        isBubbleEnabled: Bool,
        petId: String,
        petName: String,
        petDescriptor: String? = nil,
        hasActiveOverlay: Bool = false,
        hasPreviousVisualAction: Bool = false,
        isQuotaExceeded: Bool = false,
        rateLimitResetAt: Date? = nil,
        preferredThemes: Set<AIVisualThemePreference> = [],
        dislikedContent: Set<AIVisualDislikedContent> = [],
        activeFavoriteId: String? = nil
    ) {
        self.isAIEnabled = isAIEnabled
        self.isVisualExpressionEnabled = isVisualExpressionEnabled
        self.isQuietMode = isQuietMode
        self.isBubbleEnabled = isBubbleEnabled
        self.petId = petId
        self.petName = petName
        self.petDescriptor = petDescriptor
        self.hasActiveOverlay = hasActiveOverlay
        self.hasPreviousVisualAction = hasPreviousVisualAction
        self.isQuotaExceeded = isQuotaExceeded
        self.rateLimitResetAt = rateLimitResetAt
        self.preferredThemes = preferredThemes
        self.dislikedContent = dislikedContent
        self.activeFavoriteId = activeFavoriteId
    }
}
