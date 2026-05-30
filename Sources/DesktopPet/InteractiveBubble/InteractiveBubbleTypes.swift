import Foundation

// MARK: - Core Models

public struct InteractiveBubble: Sendable, Identifiable, Equatable {
    public let id: UUID
    public let text: String
    public let type: BubbleType
    public let options: [BubbleOption]
    public let createdAt: Date
    public let expiresAt: Date

    public init(
        id: UUID = UUID(),
        text: String,
        type: BubbleType,
        options: [BubbleOption],
        createdAt: Date = Date(),
        expiresAt: Date
    ) {
        self.id = id
        self.text = text
        self.type = type
        self.options = options
        self.createdAt = createdAt
        self.expiresAt = expiresAt
    }
}

public enum BubbleType: String, Sendable, Codable, CaseIterable {
    case needExpression
    case emotionSharing
    case curiousQuestion
    case gameInvitation
    case caringOwner
    case randomTopic
}

public struct BubbleOption: Sendable, Identifiable, Equatable {
    public let id: UUID
    public let emoji: String
    public let label: String
    public let effect: BubbleEffect
    public let isPrimary: Bool

    public init(
        id: UUID = UUID(),
        emoji: String,
        label: String,
        effect: BubbleEffect,
        isPrimary: Bool
    ) {
        self.id = id
        self.emoji = emoji
        self.label = label
        self.effect = effect
        self.isPrimary = isPrimary
    }
}

public enum BubbleEffect: String, Sendable, Codable, CaseIterable {
    case feed
    case play
    case pet
    case chat
    case positiveResponse
    case none
}

// MARK: - Context & Time

public struct BubbleContext: Sendable, Equatable {
    public let petId: String
    public let petNickname: String
    public let userNickname: String
    public let runtimeState: PetRuntimeState
    public let relationshipLevel: RelationshipLevel
    public let emotionalModel: AIEmotionalModel?
    public let recentBubbleTexts: [String]
    public let consecutiveNoResponse: Int
    public let timeOfDay: TimeOfDay
    public let memorySnippets: [String]

    public init(
        petId: String,
        petNickname: String,
        userNickname: String,
        runtimeState: PetRuntimeState,
        relationshipLevel: RelationshipLevel,
        emotionalModel: AIEmotionalModel? = nil,
        recentBubbleTexts: [String] = [],
        consecutiveNoResponse: Int = 0,
        timeOfDay: TimeOfDay = TimeOfDay.current,
        memorySnippets: [String] = []
    ) {
        self.petId = petId
        self.petNickname = petNickname
        self.userNickname = userNickname
        self.runtimeState = runtimeState
        self.relationshipLevel = relationshipLevel
        self.emotionalModel = emotionalModel
        self.recentBubbleTexts = recentBubbleTexts
        self.consecutiveNoResponse = consecutiveNoResponse
        self.timeOfDay = timeOfDay
        self.memorySnippets = memorySnippets
    }
}

public enum TimeOfDay: String, Sendable, Equatable {
    case morning    // 6:00-12:00
    case afternoon  // 12:00-18:00
    case evening    // 18:00-22:00
    case night      // 22:00-6:00

    public static func from(hour: Int) -> TimeOfDay {
        switch hour {
        case 6..<12: return .morning
        case 12..<18: return .afternoon
        case 18..<22: return .evening
        default: return .night
        }
    }

    public static var current: TimeOfDay {
        from(hour: Calendar.current.component(.hour, from: Date()))
    }
}

// MARK: - Interaction Result

public struct OptionInteractionResult: Sendable, Equatable {
    public let bubble: InteractiveBubble
    public let selectedOption: BubbleOption
    public let responseBubbleText: String?

    public init(
        bubble: InteractiveBubble,
        selectedOption: BubbleOption,
        responseBubbleText: String? = nil
    ) {
        self.bubble = bubble
        self.selectedOption = selectedOption
        self.responseBubbleText = responseBubbleText
    }
}

// MARK: - Effect Outcome

public struct BubbleEffectOutcome: Sendable, Equatable {
    public let stateChanges: StateChanges
    public let shouldShowFeedback: Bool
    public let feedbackText: String?
    public let shouldOpenChat: Bool
    public let animationTrigger: PetState?

    public init(
        stateChanges: StateChanges,
        shouldShowFeedback: Bool,
        feedbackText: String? = nil,
        shouldOpenChat: Bool = false,
        animationTrigger: PetState? = nil
    ) {
        self.stateChanges = stateChanges
        self.shouldShowFeedback = shouldShowFeedback
        self.feedbackText = feedbackText
        self.shouldOpenChat = shouldOpenChat
        self.animationTrigger = animationTrigger
    }
}

public struct StateChanges: Sendable, Equatable {
    public let hungerDelta: Double
    public let moodDelta: Double
    public let energyDelta: Double

    public static let zero = StateChanges(hungerDelta: 0, moodDelta: 0, energyDelta: 0)

    public init(hungerDelta: Double, moodDelta: Double, energyDelta: Double) {
        self.hungerDelta = hungerDelta
        self.moodDelta = moodDelta
        self.energyDelta = energyDelta
    }
}

// MARK: - Activity Level

public enum ActivityLevel: String, Sendable, Codable, CaseIterable {
    case low       // min 30 min, max 120 min
    case medium    // min 10 min, max 60 min
    case high      // min 5 min, max 30 min

    public var intervalRange: ClosedRange<TimeInterval> {
        switch self {
        case .low:    return 1800...7200
        case .medium: return 600...3600
        case .high:   return 300...1800
        }
    }
}

// MARK: - Protocols

@MainActor
public protocol InteractiveBubbleScheduling: Sendable {
    func start()
    func stop()
    func scheduleNext()
    func onBubbleDismissed()
    func onUserResponded()
    func currentIntervalRange() -> ClosedRange<TimeInterval>
}

public protocol InteractiveBubbleContentProviding: Sendable {
    func generate(context: BubbleContext) async -> InteractiveBubble?
    func generateFallback(context: BubbleContext) -> InteractiveBubble
}

@MainActor
public protocol InteractiveBubblePresenting: AnyObject, Sendable {
    var isActive: Bool { get }
    func show(_ bubble: InteractiveBubble)
    func dismiss()
    func dismissWithFeedback(_ text: String)
    var onFeedbackCompleted: (() -> Void)? { get set }
}

public protocol InteractiveBubbleOptionHandling: Sendable {
    func handle(result: OptionInteractionResult, state: inout PetRuntimeState) -> BubbleEffectOutcome
}

@MainActor
public protocol InteractiveBubbleSettingsProviding: AnyObject, Sendable {
    var isEnabled: Bool { get set }
    var activityLevel: ActivityLevel { get set }
    var minInterval: TimeInterval { get set }
    var maxInterval: TimeInterval { get set }
    var optionWaitDuration: TimeInterval { get set }
    var silentPeriodStart: DateComponents { get set }
    var silentPeriodEnd: DateComponents { get set }
    var isAdvancedMode: Bool { get set }
    func enterAdvancedMode()
    func exitAdvancedMode()
}

public extension InteractiveBubbleSettingsProviding {
    func enterAdvancedMode() {}
    func exitAdvancedMode() {}
}
