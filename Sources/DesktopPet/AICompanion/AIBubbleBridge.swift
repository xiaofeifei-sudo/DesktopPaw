import Foundation

@MainActor
public protocol AIBubbleBridging: AnyObject, Sendable {
    func emitBubble(from response: AIChatResponse, petId: String) -> Bool
    func canEmitBubble(petId: String) -> Bool
}

@MainActor
public final class AIBubbleBridge: AIBubbleBridging {
    public static let defaultInitiativeInterval: TimeInterval = 1800
    public static let bubbleDisplayDuration: TimeInterval = 5.0

    public var isAIBubbleEnabled: Bool
    public var initiativeBubbleMinInterval: TimeInterval
    public private(set) var lastInitiativeBubbleAt: Date?
    public private(set) var lastProactiveTriggerDateByType: [ProactiveTriggerType: Date] = [:]

    private let quietModePolicy: QuietModeEvaluating?
    private let scheduler: BubbleScheduler
    private let getPreferences: @MainActor () -> CompanionPreferences
    private let globalMinimumInterval: @MainActor () -> TimeInterval
    private let onBubbleEmitted: @MainActor (PetBubble) -> Void
    private let idGenerator: @MainActor () -> UUID
    public var proactiveMemoryProducer: ProactiveMemoryProducing?
    public var memoryStore: AIMemoryStoring?
    public var emotionalModelStore: EmotionalModelStoring?

    public init(
        quietModePolicy: QuietModeEvaluating? = nil,
        scheduler: BubbleScheduler,
        getPreferences: @escaping @MainActor () -> CompanionPreferences,
        globalMinimumInterval: @escaping @MainActor () -> TimeInterval,
        onBubbleEmitted: @escaping @MainActor (PetBubble) -> Void,
        isAIBubbleEnabled: Bool = true,
        initiativeBubbleMinInterval: TimeInterval = defaultInitiativeInterval,
        idGenerator: @escaping @MainActor () -> UUID = { UUID() }
    ) {
        self.quietModePolicy = quietModePolicy
        self.scheduler = scheduler
        self.getPreferences = getPreferences
        self.globalMinimumInterval = globalMinimumInterval
        self.onBubbleEmitted = onBubbleEmitted
        self.isAIBubbleEnabled = isAIBubbleEnabled
        self.initiativeBubbleMinInterval = initiativeBubbleMinInterval
        self.idGenerator = idGenerator
    }

    public func emitBubble(from response: AIChatResponse, petId: String) -> Bool {
        guard isAIBubbleEnabled else { return false }
        guard !isQuietModeActive() else { return false }

        let adaptedText = AIChatBubbleAdapter.adapt(response.bubbleText)
        guard let text = adaptedText else { return false }

        let now = Date()
        let interval = globalMinimumInterval()
        guard scheduler.canEmit(priority: .relationship, at: now, minimumInterval: interval) else {
            return false
        }

        let bubble = PetBubble(
            id: idGenerator(),
            text: text,
            priority: .relationship,
            createdAt: now,
            expiresAt: now.addingTimeInterval(Self.bubbleDisplayDuration)
        )
        scheduler.register(bubble)
        onBubbleEmitted(bubble)
        return true
    }

    public func canEmitBubble(petId: String) -> Bool {
        guard isAIBubbleEnabled else { return false }
        guard !isQuietModeActive() else { return false }

        let now = Date()
        if let last = lastInitiativeBubbleAt {
            guard now.timeIntervalSince(last) >= initiativeBubbleMinInterval else {
                return false
            }
        }

        let interval = globalMinimumInterval()
        return scheduler.canEmit(priority: .relationship, at: now, minimumInterval: interval)
    }

    public func emitInitiativeBubble(text: String, petId: String) -> Bool {
        guard canEmitBubble(petId: petId) else { return false }

        let adaptedText = AIChatBubbleAdapter.adapt(text)
        guard let adapted = adaptedText else { return false }

        let now = Date()
        let bubble = PetBubble(
            id: idGenerator(),
            text: adapted,
            priority: .relationship,
            createdAt: now,
            expiresAt: now.addingTimeInterval(Self.bubbleDisplayDuration)
        )
        scheduler.register(bubble)
        lastInitiativeBubbleAt = now
        onBubbleEmitted(bubble)
        return true
    }

    public func checkAndEmitProactiveBubble(petId: String) -> ProactiveTrigger? {
        guard isAIBubbleEnabled else { return nil }
        guard !isQuietModeActive() else { return nil }

        guard let producer = proactiveMemoryProducer,
              let store = memoryStore else { return nil }

        let memories = store.loadAll(petId: petId)

        let model = try? emotionalModelStore?.loadModel(petId: petId)

        let trigger = producer.checkTrigger(
            memories: memories,
            emotionalModel: model,
            lastProactiveDate: lastInitiativeBubbleAt
        )

        guard let trigger else { return nil }

        let phase = model?.relationshipPhase ?? .stranger
        let limitSeconds = producer.frequencyLimit(for: phase)
        if let lastTypeDate = lastProactiveTriggerDateByType[trigger.type] {
            guard Date().timeIntervalSince(lastTypeDate) >= Double(limitSeconds) else { return nil }
        }

        let prompt = producer.composePrompt(for: trigger)
        let emitted = emitInitiativeBubble(text: prompt, petId: petId)
        if emitted {
            lastProactiveTriggerDateByType[trigger.type] = Date()
        }

        return emitted ? trigger : nil
    }

    private func isQuietModeActive() -> Bool {
        let prefs = getPreferences()
        if let policy = quietModePolicy {
            return policy.quietState(preferences: prefs, at: Date()) != .inactive
        }
        if let quietUntil = prefs.quietUntil, quietUntil > Date() {
            return true
        }
        return false
    }
}
