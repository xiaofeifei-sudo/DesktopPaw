import Foundation

@MainActor
public protocol BubbleProducing: AnyObject {
    func handle(event: PetEvent, state: PetRuntimeState, at date: Date) -> PetBubble?
    func tick(state: PetRuntimeState, at date: Date) -> PetBubble?
}

@MainActor
public protocol CompanionBubbleProducing: AnyObject {
    func handle(trigger: BubbleTrigger, context: CompanionContext, at date: Date) -> PetBubble?
    func tick(context: CompanionContext, at date: Date) -> PetBubble?
}

private let companionAmbientQuietTriggers: Set<BubbleTrigger> = [
    .idle, .walking, .sleeping, .dailyGreeting, .longAbsenceReturn,
    .relationshipLevelUp, .microDialogPrompt,
]

@MainActor
public final class BubbleEngine: BubbleProducing, CompanionBubbleProducing {
    public static let hungerHighThreshold: Double = 0.7
    public static let energyLowThreshold: Double = 0.3
    public static let idleAmbientSeconds: TimeInterval = 120

    public var isEnabled: Bool {
        didSet {
            if !isEnabled {
                scheduler.clearCurrent()
            }
        }
    }
    public var frequency: BubbleFrequency
    public var profile: BubbleProfile

    public var currentBubble: PetBubble? { scheduler.currentBubble }

    private let phraseProvider: BubblePhraseProviding
    private var contextualPhraseProvider: ContextualBubblePhraseProviding?
    private let quietModePolicy: (any QuietModeEvaluating)?
    private let microDialogService: (any MicroDialogServicing)?
    private let scheduler: BubbleScheduler
    private let idGenerator: @MainActor () -> UUID

    public init(
        profile: BubbleProfile,
        isEnabled: Bool = true,
        frequency: BubbleFrequency = .normal,
        phraseProvider: BubblePhraseProviding,
        contextualPhraseProvider: ContextualBubblePhraseProviding? = nil,
        quietModePolicy: (any QuietModeEvaluating)? = nil,
        microDialogService: (any MicroDialogServicing)? = nil,
        scheduler: BubbleScheduler = BubbleScheduler(),
        idGenerator: @escaping @MainActor () -> UUID = { UUID() }
    ) {
        self.profile = profile
        self.isEnabled = isEnabled
        self.frequency = frequency
        self.phraseProvider = phraseProvider
        self.contextualPhraseProvider = contextualPhraseProvider
        self.quietModePolicy = quietModePolicy
        self.microDialogService = microDialogService
        self.scheduler = scheduler
        self.idGenerator = idGenerator
    }

    public func updateContextualPhraseProvider(_ provider: ContextualBubblePhraseProviding?) {
        contextualPhraseProvider = provider
    }

    // MARK: - BubbleProducing (legacy entry points)

    public func handle(event: PetEvent, state: PetRuntimeState, at date: Date) -> PetBubble? {
        guard isEnabled else { return nil }
        scheduler.expireIfNeeded(at: date)

        let trigger: BubbleTrigger
        switch event {
        case .clicked:
            trigger = .clicked
        case .pet:
            trigger = .pet
        case .feed:
            trigger = .feed
        default:
            return nil
        }

        return emit(trigger: trigger, priority: .interaction, state: state, at: date)
    }

    public func tick(state: PetRuntimeState, at date: Date) -> PetBubble? {
        guard isEnabled else { return nil }
        scheduler.expireIfNeeded(at: date)

        if state.isDragging {
            return nil
        }

        if state.hunger >= Self.hungerHighThreshold {
            return emit(trigger: .hungry, priority: .state, state: state, at: date)
        }

        if state.energy <= Self.energyLowThreshold {
            return emit(trigger: .tired, priority: .state, state: state, at: date)
        }

        switch state.currentState {
        case .happy:
            return emit(trigger: .happy, priority: .state, state: state, at: date)
        case .walking:
            return emit(trigger: .walking, priority: .ambient, state: state, at: date)
        case .sleeping:
            return emit(trigger: .sleeping, priority: .ambient, state: state, at: date)
        case .idle:
            let idleSeconds = date.timeIntervalSince(state.lastInteractionAt)
            if idleSeconds >= Self.idleAmbientSeconds {
                return emit(trigger: .idle, priority: .ambient, state: state, at: date)
            }
            return nil
        case .eating, .jumping, .dragging:
            return nil
        }
    }

    // MARK: - CompanionBubbleProducing (context-based entry points)

    public func handle(trigger: BubbleTrigger, context: CompanionContext, at date: Date) -> PetBubble? {
        guard isEnabled else { return nil }
        scheduler.expireIfNeeded(at: date)

        let priority = BubblePhraseCatalog.defaultPriority(for: trigger)
        return contextualEmit(trigger: trigger, priority: priority, context: context, at: date)
    }

    public func tick(context: CompanionContext, at date: Date) -> PetBubble? {
        guard isEnabled else { return nil }
        scheduler.expireIfNeeded(at: date)

        if context.runtimeState.isDragging {
            return nil
        }

        let isQuiet = isQuietActive(preferences: context.preferences, at: date)

        if context.runtimeState.hunger >= Self.hungerHighThreshold {
            if isQuiet { return nil }
            return contextualEmit(trigger: .hungry, priority: .state, context: context, at: date)
        }

        if context.runtimeState.energy <= Self.energyLowThreshold {
            if isQuiet { return nil }
            return contextualEmit(trigger: .tired, priority: .state, context: context, at: date)
        }

        if isQuiet {
            return nil
        }

        switch context.runtimeState.currentState {
        case .happy:
            return contextualEmit(trigger: .happy, priority: .state, context: context, at: date)
        case .walking:
            return contextualEmit(trigger: .walking, priority: .ambient, context: context, at: date)
        case .sleeping:
            return contextualEmit(trigger: .sleeping, priority: .ambient, context: context, at: date)
        case .idle:
            let idleSeconds = date.timeIntervalSince(context.runtimeState.lastInteractionAt)
            if idleSeconds >= Self.idleAmbientSeconds {
                return contextualEmit(trigger: .idle, priority: .ambient, context: context, at: date)
            }
            return nil
        case .eating, .jumping, .dragging:
            return nil
        }
    }

    // MARK: - Private

    private func emit(
        trigger: BubbleTrigger,
        priority: BubblePriority,
        state: PetRuntimeState,
        at date: Date
    ) -> PetBubble? {
        let interval = effectiveMinimumInterval()
        guard scheduler.canEmit(priority: priority, at: date, minimumInterval: interval) else {
            return nil
        }
        guard let text = phraseProvider.phrase(for: trigger, state: state) else {
            return nil
        }
        let bubble = PetBubble(
            id: idGenerator(),
            text: text,
            priority: priority,
            createdAt: date,
            expiresAt: date.addingTimeInterval(profile.displayDurationSeconds)
        )
        scheduler.register(bubble)
        return bubble
    }

    private func contextualEmit(
        trigger: BubbleTrigger,
        priority: BubblePriority,
        context: CompanionContext,
        at date: Date
    ) -> PetBubble? {
        guard !companionAmbientQuietTriggers.contains(trigger) || !isQuietActive(preferences: context.preferences, at: date) else {
            return nil
        }

        let interval = effectiveMinimumInterval()
        guard scheduler.canEmit(priority: priority, at: date, minimumInterval: interval) else {
            return nil
        }
        guard let provider = contextualPhraseProvider,
              let selection = provider.phrase(for: trigger, context: context, now: date) else {
            return nil
        }
        var microDialogId: MicroDialogId?
        if selection.phrase.canStartMicroDialog, let service = microDialogService {
            microDialogId = service.dialog(for: selection.phrase, context: context, now: date)?.id
        }
        let bubble = PetBubble(
            id: idGenerator(),
            text: selection.renderedText,
            priority: priority,
            createdAt: date,
            expiresAt: date.addingTimeInterval(selection.phrase.effectiveDisplayDuration),
            microDialogId: microDialogId
        )
        scheduler.register(bubble)
        return bubble
    }

    public func effectiveMinimumInterval() -> TimeInterval {
        let multiplier: Double
        switch frequency {
        case .quiet:
            multiplier = 2.0
        case .normal:
            multiplier = 1.0
        case .expressive:
            multiplier = 0.5
        }
        return profile.minimumIntervalSeconds * multiplier
    }

    private func isQuietActive(preferences: CompanionPreferences, at date: Date) -> Bool {
        if let policy = quietModePolicy {
            return policy.quietState(preferences: preferences, at: date) != .inactive
        }
        if let quietUntil = preferences.quietUntil, quietUntil > date {
            return true
        }
        return false
    }
}
