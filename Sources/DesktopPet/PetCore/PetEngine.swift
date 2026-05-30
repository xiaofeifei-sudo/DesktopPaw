import Foundation

public final class PetEngine {
    public static let defaultReactionDuration: TimeInterval = 1.2
    public static let defaultWalkingFallbackDuration: TimeInterval = 3.0
    public static let defaultIdleScheduleDelayRange: ClosedRange<Double> = 20...60

    private static let sleepInactivityThreshold: TimeInterval = 10 * 60
    private static let sleepEnergyThreshold = 0.25
    private static let consumableAfterTagRawValues: Set<String> = [
        "after.click",
        "after.feed",
        "after.pet"
    ]

    public private(set) var state: PetRuntimeState
    public var currentActionId: ActionId? {
        state.currentActionId
    }
    public var isRandomWalkingEnabled: Bool {
        didSet {
            if isRandomWalkingEnabled, nextIdleScheduleAt == nil, state.currentState == .idle {
                scheduleNextIdleAction(at: currentDate)
            } else if !isRandomWalkingEnabled {
                nextIdleScheduleAt = nil
            }
        }
    }

    public enum PetActionEvent: Equatable {
        case playAction(ActionId)
    }

    private enum PlaybackSource {
        case user
        case ambient
    }

    private let catalog: PetActionCatalog
    private let fallbackResolver: ActionFallbackResolving
    private let scheduler: IdleBehaviorScheduling
    private let moodSnapshotProvider: MoodSnapshotProviding
    private let afterTagState: AfterTagStateMaintaining
    private let reactionActionSampler: WeightedActionSampling
    private let randomNumberGenerator: RandomNumberGenerating
    private let reactionDuration: TimeInterval
    private let walkingFallbackDuration: TimeInterval
    private let idleScheduleDelayRange: ClosedRange<Double>
    private let now: () -> Date

    private var currentDate: Date
    private var lastTickAt: Date
    private var stateStartedAt: Date
    private var nextIdleScheduleAt: Date?
    private var currentActionExpiresAt: Date?
    private var currentPlaybackSource: PlaybackSource?

    public init(
        catalog: PetActionCatalog,
        fallbackResolver: ActionFallbackResolving = DefaultActionFallbackResolver(),
        scheduler: IdleBehaviorScheduling? = nil,
        moodSnapshotProvider: MoodSnapshotProviding = SystemMoodSnapshot(),
        afterTagState: AfterTagStateMaintaining = DefaultAfterTagState(),
        initialState: PetRuntimeState? = nil,
        initialDate: Date = Date(),
        isRandomWalkingEnabled: Bool = true,
        randomNumberGenerator: RandomNumberGenerating = SystemRandomNumberGenerator(),
        reactionDuration: TimeInterval = PetEngine.defaultReactionDuration,
        walkingFallbackDuration: TimeInterval = PetEngine.defaultWalkingFallbackDuration,
        idleScheduleDelayRange: ClosedRange<Double> = PetEngine.defaultIdleScheduleDelayRange,
        now: @escaping () -> Date = { Date() }
    ) {
        self.catalog = catalog
        self.fallbackResolver = fallbackResolver
        self.scheduler = scheduler ?? WeightedIdleBehaviorScheduler(
            randomNumberGenerator: randomNumberGenerator,
            afterTagState: afterTagState
        )
        self.moodSnapshotProvider = moodSnapshotProvider
        self.afterTagState = afterTagState
        self.reactionActionSampler = DefaultWeightedActionSampler(afterTagState: afterTagState)
        self.currentDate = initialDate
        self.lastTickAt = initialDate
        self.stateStartedAt = initialDate
        self.state = initialState ?? .defaultState(at: initialDate)
        self.isRandomWalkingEnabled = isRandomWalkingEnabled
        self.randomNumberGenerator = randomNumberGenerator
        self.reactionDuration = reactionDuration
        self.walkingFallbackDuration = walkingFallbackDuration
        self.idleScheduleDelayRange = idleScheduleDelayRange
        self.now = now
        self.currentActionExpiresAt = nil
        self.currentPlaybackSource = nil

        if isRandomWalkingEnabled, self.state.currentState == .idle {
            scheduleNextIdleAction(at: initialDate)
        }
    }

    @discardableResult
    public func handle(_ event: PetEvent) -> PetRuntimeState {
        switch event {
        case .appLaunched:
            transition(to: .idle, at: currentDate)
        case .tick(let date):
            handleTick(at: date)
        case .clicked:
            let date = currentEventDate()
            handleDirectInteraction(at: date) {
                handleInteractionRequest(preferredRole: nil, at: date)
            }
        case .pet:
            let date = currentEventDate()
            handleDirectInteraction(at: date) {
                state = MoodModel.applyingPet(to: state)
                handleInteractionRequest(preferredRole: .happy, at: date)
            }
        case .feed:
            let date = currentEventDate()
            handleDirectInteraction(at: date) {
                state = MoodModel.applyingFeed(to: state)
                handleInteractionRequest(preferredRole: .eating, at: date)
            }
        case .dragStarted:
            let date = currentEventDate()
            state.isDragging = true
            state.lastInteractionAt = date
            transition(to: .dragging, at: date)
        case .dragEnded:
            let date = currentEventDate()
            state.isDragging = false
            state.lastInteractionAt = date
            transition(to: .idle, at: date)
        case .sleepRequested:
            guard !state.isDragging else {
                break
            }
            transition(to: .sleeping, at: currentEventDate())
        case .wakeRequested:
            let date = currentEventDate()
            state.lastInteractionAt = date
            transition(to: .idle, at: date)
        }

        clampNumericState()
        return state
    }

    @discardableResult
    public func handle(_ event: PetActionEvent) -> PetRuntimeState {
        switch event {
        case .playAction(let actionId):
            if let action = catalog.resolve(actionId: actionId) {
                playAction(action, at: currentEventDate(), source: .user)
            }
            // 未知 actionId：保持当前 state，不抛错（由 ActionTriggerService 在 P2 兜底）。
        }
        clampNumericState()
        return state
    }

    @discardableResult
    public func updateScale(_ scale: Double) -> PetRuntimeState {
        state.scale = scale
        return state
    }

    private func handleTick(at date: Date) {
        let elapsed = date.timeIntervalSince(lastTickAt)
        currentDate = date
        lastTickAt = date
        state = MoodModel.advance(state, elapsedSeconds: elapsed)

        guard !state.isDragging else {
            return
        }

        switch state.currentState {
        case .happy, .eating, .jumping:
            if date.timeIntervalSince(stateStartedAt) >= reactionDuration {
                let completedReaction = state.currentState
                transition(to: .idle, at: date)
                afterTagState.mark(after: completedReaction)
            }
        case .walking:
            handleNonReactionPlaybackTick(at: date, fallbackDuration: walkingFallbackDuration)
        case .idle:
            if handleExpiringIdleActionTick(at: date) {
                return
            }
            applyAmbientTransitions(at: date)
        case .sleeping, .dragging:
            break
        }
    }

    private func currentEventDate() -> Date {
        let date = now()
        guard date > currentDate else {
            return currentDate
        }

        currentDate = date
        return date
    }

    private func handleExpiringIdleActionTick(at date: Date) -> Bool {
        guard let expiresAt = currentActionExpiresAt else {
            return false
        }

        if date >= expiresAt {
            state.currentActionId = nil
            currentActionExpiresAt = nil
            let completedSource = currentPlaybackSource
            currentPlaybackSource = nil
            if completedSource == .ambient, isRandomWalkingEnabled {
                performIdleSchedule(at: date)
                return true
            }
            return false
        }

        return true
    }

    private func handleNonReactionPlaybackTick(at date: Date, fallbackDuration: TimeInterval) {
        if let expiresAt = currentActionExpiresAt {
            if date >= expiresAt {
                transition(to: .idle, at: date)
            }
        } else if date.timeIntervalSince(stateStartedAt) >= fallbackDuration {
            transition(to: .idle, at: date)
        }
    }

    private func applyAmbientTransitions(at date: Date) {
        let inactivity = date.timeIntervalSince(state.lastInteractionAt)
        if inactivity >= Self.sleepInactivityThreshold, state.energy < Self.sleepEnergyThreshold {
            transition(to: .sleeping, at: date)
            return
        }

        if isRandomWalkingEnabled, let nextIdleScheduleAt, date >= nextIdleScheduleAt {
            performIdleSchedule(at: date)
        }
    }

    private func performIdleSchedule(at date: Date) {
        let snapshot = moodSnapshotProvider.snapshot(currentMood: state.mood)
        let timeSlots = TimeOfDayClassifier.slots(for: date)
        let context = IdleScheduleContext(
            now: date,
            mood: snapshot.mood,
            pendingAfterTag: afterTagState.pending,
            moodLevel: snapshot.level,
            timeSlots: timeSlots
        )
        let pool = IdleBehaviorPool.from(catalog: catalog)
        guard let action = scheduler.nextAction(in: pool, context: context) else {
            // 池为空：保持 idle，重新排下一次抽样。
            scheduleNextIdleAction(at: date)
            return
        }
        consumePendingAfterTagIfNeeded(for: action)
        playAction(action, at: date, source: .ambient)
    }

    private func handleInteractionRequest(preferredRole: ActionRole?, at date: Date) {
        guard let action = resolveInteractionAction(preferredRole: preferredRole, at: date) else {
            transition(to: .idle, at: date)
            return
        }
        playAction(action, at: date, source: .user)
    }

    private func resolveInteractionAction(preferredRole: ActionRole?, at date: Date) -> Action? {
        let context = makeTagConditionContext(at: date)

        if let preferredRole {
            var rolesToTry = [preferredRole]
            rolesToTry.append(contentsOf: ActionFallbackChain.chain[preferredRole] ?? [])

            for candidateRole in rolesToTry {
                let candidates = catalog.actions(for: candidateRole)
                guard !candidates.isEmpty else {
                    continue
                }
                if let action = reactionActionSampler.sample(candidates, context: context, rng: randomNumberGenerator) {
                    return action
                }
            }
        }

        let candidates = catalog.interactionActions
        if let sampled = reactionActionSampler.sample(candidates, context: context, rng: randomNumberGenerator) {
            return sampled
        }
        return candidates.first ?? catalog.defaultAction
    }

    private func makeTagConditionContext(at date: Date) -> TagConditionContext {
        let snapshot = moodSnapshotProvider.snapshot(currentMood: state.mood)
        return TagConditionContext(
            moodLevel: snapshot.level,
            timeSlots: TimeOfDayClassifier.slots(for: date),
            pendingAfterTag: afterTagState.pending
        )
    }

    private func consumePendingAfterTagIfNeeded(for action: Action) {
        guard afterTagState.pending != nil else {
            return
        }
        guard action.tags.contains(where: { Self.consumableAfterTagRawValues.contains($0.rawValue) }) else {
            return
        }
        afterTagState.consume()
    }

    private func playAction(_ action: Action, at date: Date, source: PlaybackSource) {
        let targetState = action.role?.legacyState ?? .idle
        transition(to: targetState, at: date, action: action, source: source)
    }

    private func handleDirectInteraction(at date: Date, action: () -> Void) {
        guard !state.isDragging else {
            return
        }

        state.lastInteractionAt = date
        action()
    }

    private func transition(to newState: PetState, at date: Date, action: Action? = nil, source: PlaybackSource? = nil) {
        if state.currentState != newState {
            DesktopPetLog.engine.debug("Pet state transition: \(self.state.currentState.rawValue, privacy: .public) -> \(newState.rawValue, privacy: .public)")
        }
        state.currentState = newState
        state.isDragging = newState == .dragging
        stateStartedAt = date
        nextIdleScheduleAt = nil
        currentActionExpiresAt = nil
        currentPlaybackSource = source

        if let action {
            state.currentActionId = action.id
            if !action.loop {
                let totalMs = action.frames.count * action.frameDurationMs
                if totalMs > 0 {
                    currentActionExpiresAt = date.addingTimeInterval(TimeInterval(totalMs) / 1000.0)
                }
            }
        } else {
            state.currentActionId = nil
            currentPlaybackSource = nil
        }

        if newState == .dragging {
            // dragging 期间不设置 currentActionId（保持 nil）。
            state.currentActionId = nil
            currentPlaybackSource = nil
        }

        if newState == .idle {
            scheduleNextIdleAction(at: date)
        }
    }

    private func scheduleNextIdleAction(at date: Date) {
        guard isRandomWalkingEnabled else {
            nextIdleScheduleAt = nil
            return
        }

        let delay = randomNumberGenerator.nextDouble(in: idleScheduleDelayRange)
        nextIdleScheduleAt = date.addingTimeInterval(delay)
    }

    private func clampNumericState() {
        state.mood = MoodModel.clamp01(state.mood)
        state.hunger = MoodModel.clamp01(state.hunger)
        state.energy = MoodModel.clamp01(state.energy)
    }

    public func applyStateChanges(_ changes: StateChanges) {
        state.mood = MoodModel.clamp01(state.mood + changes.moodDelta)
        state.hunger = MoodModel.clamp01(state.hunger + changes.hungerDelta)
        state.energy = MoodModel.clamp01(state.energy + changes.energyDelta)
    }
}
