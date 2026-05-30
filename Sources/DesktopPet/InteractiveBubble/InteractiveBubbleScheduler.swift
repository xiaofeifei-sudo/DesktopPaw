import Foundation

@MainActor
public final class InteractiveBubbleScheduler: InteractiveBubbleScheduling, Sendable {
    private let settings: any InteractiveBubbleSettingsProviding

    public var isChatPanelOpen: @Sendable @MainActor () -> Bool = { false }
    public var hasHigherPriorityBubble: @Sendable @MainActor () -> Bool = { false }
    public var globalMinInterval: @Sendable @MainActor () -> TimeInterval = { 30 }
    public var onTrigger: (@Sendable @MainActor () -> Void)?

    private var nextTriggerTime: Date?
    private(set) var consecutiveNoResponse: Int = 0
    private var lastTriggerTime: Date?
    private var isRunning = false
    private var runtimeState: PetRuntimeState?
    private var emotionalModel: AIEmotionalModel?
    private var relationshipLevel: RelationshipLevel?

    #if DEBUG
    public var nextTriggerTimeForTesting: Date? { nextTriggerTime }
    public var consecutiveNoResponseForTesting: Int { consecutiveNoResponse }
    public func isInSilentPeriodForTesting(at date: Date) -> Bool {
        isInSilentPeriod(at: date)
    }
    public func setNextTriggerTimeForTesting(_ date: Date) {
        nextTriggerTime = date
    }
    #endif

    public init(settings: any InteractiveBubbleSettingsProviding) {
        self.settings = settings
    }

    // MARK: - InteractiveBubbleScheduling

    public func start() {
        isRunning = true
        scheduleNext()
    }

    public func stop() {
        isRunning = false
        nextTriggerTime = nil
    }

    public func scheduleNext() {
        let range = currentIntervalRange()
        let interval = Double.random(in: range)
        nextTriggerTime = .now + interval
    }

    public func onBubbleDismissed() {
        consecutiveNoResponse += 1
        scheduleNext()
    }

    public func onUserResponded() {
        consecutiveNoResponse = 0
        scheduleNext()
    }

    public func currentIntervalRange() -> ClosedRange<TimeInterval> {
        let multiplier = correctionMultiplier()
        let minInterval = clamp(settings.minInterval * multiplier)
        let maxInterval = clamp(settings.maxInterval * multiplier)
        return minInterval...max(maxInterval, minInterval)
    }

    public func updateFrequencyContext(
        runtimeState: PetRuntimeState? = nil,
        emotionalModel: AIEmotionalModel? = nil,
        relationshipLevel: RelationshipLevel? = nil
    ) {
        if let runtimeState {
            self.runtimeState = runtimeState
        }
        if let emotionalModel {
            self.emotionalModel = emotionalModel
        }
        if let relationshipLevel {
            self.relationshipLevel = relationshipLevel
        }
    }

    // MARK: - Tick Integration

    public func checkTrigger(at date: Date) -> Bool {
        guard isRunning else { return false }
        guard let next = nextTriggerTime, date >= next else { return false }

        guard settings.isEnabled else {
            nextTriggerTime = date + 60
            return false
        }

        if isInSilentPeriod(at: date) {
            nextTriggerTime = silentPeriodEndDate(after: date) ?? date + 60
            return false
        }

        if canTrigger(at: date) {
            lastTriggerTime = date
            return true
        } else {
            nextTriggerTime = date + 60
            return false
        }
    }

    // MARK: - Gating

    private func canTrigger(at date: Date) -> Bool {
        guard settings.isEnabled else { return false }

        if let last = lastTriggerTime {
            let min = globalMinInterval()
            guard date.timeIntervalSince(last) >= min else { return false }
        }

        guard !hasHigherPriorityBubble() else { return false }
        guard !isChatPanelOpen() else { return false }
        return true
    }

    // MARK: - Silent Period

    private func isInSilentPeriod(at date: Date) -> Bool {
        let start = settings.silentPeriodStart
        let end = settings.silentPeriodEnd

        guard let sh = start.hour, let sm = start.minute,
              let eh = end.hour, let em = end.minute else { return false }

        let cal = Calendar.current
        let current = cal.component(.hour, from: date) * 60 + cal.component(.minute, from: date)
        let startMins = sh * 60 + sm
        let endMins = eh * 60 + em

        if startMins <= endMins {
            return current >= startMins && current < endMins
        } else {
            return current >= startMins || current < endMins
        }
    }

    private func silentPeriodEndDate(after date: Date) -> Date? {
        let start = settings.silentPeriodStart
        let end = settings.silentPeriodEnd

        guard let sh = start.hour, let sm = start.minute,
              let eh = end.hour, let em = end.minute else { return nil }

        let cal = Calendar.current
        let current = cal.component(.hour, from: date) * 60 + cal.component(.minute, from: date)
        let startMins = sh * 60 + sm
        let endMins = eh * 60 + em

        var components = cal.dateComponents([.year, .month, .day], from: date)
        components.hour = eh
        components.minute = em
        components.second = 0

        guard let sameDayEnd = cal.date(from: components) else { return nil }

        if startMins <= endMins {
            return sameDayEnd > date ? sameDayEnd : nil
        }

        if current >= startMins {
            return cal.date(byAdding: .day, value: 1, to: sameDayEnd)
        }

        return sameDayEnd
    }

    // MARK: - Frequency Corrections

    private func correctionMultiplier() -> Double {
        var multiplier = 1.0

        if let state = runtimeState {
            if state.hunger > 0.8 || state.energy < 0.2 {
                multiplier *= 0.5
            }
            if state.mood < 0.3 {
                multiplier *= 0.7
            }
        }

        if emotionalModel?.indicatesBusyOwner == true {
            multiplier *= 1.5
        }

        if consecutiveNoResponse >= 3 {
            multiplier *= 1.5
        }

        if relationshipLevel == .acquaintance {
            multiplier *= 1.3
        }

        return min(max(multiplier, 0.33), 3.0)
    }

    private func clamp(_ interval: TimeInterval) -> TimeInterval {
        min(max(interval, settings.minInterval), settings.maxInterval * 2)
    }
}

private extension AIEmotionalModel {
    var indicatesBusyOwner: Bool {
        if currentMood == .tired || currentMood == .stressed || currentMood == .anxious {
            return true
        }

        return emotionalPatterns.contains { pattern in
            guard pattern.confidence >= 0.6, pattern.evidence > 0 else { return false }
            let text = pattern.pattern.localizedLowercase
            return text.contains("busy")
                || text.contains("workload")
                || text.contains("忙")
                || text.contains("加班")
                || text.contains("工作")
        }
    }
}
