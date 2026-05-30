import Foundation
import DesktopPet

@MainActor
func runInteractiveBubbleSchedulerTests() {
    let tests = InteractiveBubbleSchedulerTests()
    tests.startSetsRunningAndSchedulesNext()
    tests.stopClearsNextTriggerTime()
    tests.scheduleNextSetsTriggerWithinRange()
    tests.firstTriggerWaitsFullInterval()
    tests.checkTriggerReturnsFalseBeforeTriggerTime()
    tests.checkTriggerReturnsTrueAtTriggerTime()
    tests.checkTriggerReturnsFalseWhenDisabled()
    tests.checkTriggerReturnsFalseInSilentPeriod()
    tests.checkTriggerReturnsFalseWhenChatPanelOpen()
    tests.checkTriggerReturnsFalseWhenHigherPriorityBubble()
    tests.checkTriggerReturnsFalseWhenGlobalMinIntervalNotElapsed()
    tests.onBubbleDismissedIncrementsNoResponse()
    tests.onUserRespondedResetsNoResponse()
    tests.silentPeriodSameDayRange()
    tests.silentPeriodCrossMidnight()
    tests.silentPeriodNoHourReturnsFalse()
    tests.gateFailurePostponesBy60Seconds()
    tests.currentIntervalRangeReflectsSettings()
    tests.urgentPetNeedShortensIntervalButKeepsUserMinimum()
    tests.lowEnergyShortensIntervalButKeepsUserMinimum()
    tests.lowMoodShortensIntervalButKeepsUserMinimum()
    tests.ownerBusyExtendsInterval()
    tests.consecutiveNoResponseExtendsInterval()
    tests.acquaintanceRelationshipExtendsInterval()
    tests.frequencyCorrectionsStack()
    tests.frequencyCorrectionsClampFinalIntervalToDoubleUserMaximum()
    tests.silentPeriodFailurePostponesToSilentEnd()
    tests.crossMidnightSilentPeriodFailurePostponesToNextEnd()
}

@MainActor
private struct InteractiveBubbleSchedulerTests {
    private func makeScheduler(
        minInterval: TimeInterval = 600,
        maxInterval: TimeInterval = 3600,
        isEnabled: Bool = true,
        silentStart: DateComponents = DateComponents(hour: 0, minute: 0),
        silentEnd: DateComponents = DateComponents(hour: 9, minute: 0)
    ) -> InteractiveBubbleScheduler {
        let settings = MockSettings(
            isEnabled: isEnabled,
            minInterval: minInterval,
            maxInterval: maxInterval,
            silentPeriodStart: silentStart,
            silentEnd: silentEnd
        )
        return InteractiveBubbleScheduler(settings: settings)
    }

    func startSetsRunningAndSchedulesNext() {
        let scheduler = makeScheduler()
        scheduler.start()

        let range = scheduler.currentIntervalRange()
        let now = Date.now
        let next = scheduler.nextTriggerTimeForTesting!
        let interval = next.timeIntervalSince(now)
        expect(interval >= range.lowerBound && interval <= range.upperBound,
               "start should schedule next trigger within interval range")
    }

    func stopClearsNextTriggerTime() {
        let scheduler = makeScheduler()
        scheduler.start()
        scheduler.stop()
        expect(scheduler.nextTriggerTimeForTesting == nil,
               "stop should clear nextTriggerTime")
    }

    func scheduleNextSetsTriggerWithinRange() {
        let scheduler = makeScheduler(minInterval: 60, maxInterval: 120)
        scheduler.scheduleNext()

        let range = scheduler.currentIntervalRange()
        let interval = scheduler.nextTriggerTimeForTesting!.timeIntervalSinceNow
        expect(interval >= range.lowerBound - 1 && interval <= range.upperBound + 1,
               "scheduleNext should set trigger within range")
    }

    func firstTriggerWaitsFullInterval() {
        let scheduler = makeScheduler(minInterval: 600, maxInterval: 600)
        scheduler.start()

        let justAfter = Date.now.addingTimeInterval(1)
        expect(!scheduler.checkTrigger(at: justAfter),
               "should not trigger immediately after start")
    }

    func checkTriggerReturnsFalseBeforeTriggerTime() {
        let scheduler = makeScheduler()
        scheduler.start()

        let before = scheduler.nextTriggerTimeForTesting!.addingTimeInterval(-1)
        expect(!scheduler.checkTrigger(at: before),
               "should not trigger before nextTriggerTime")
    }

    func checkTriggerReturnsTrueAtTriggerTime() {
        let scheduler = makeScheduler()
        scheduler.start()

        let triggerAt = scheduler.nextTriggerTimeForTesting!
        expect(scheduler.checkTrigger(at: triggerAt),
               "should trigger at nextTriggerTime when all gates pass")
    }

    func checkTriggerReturnsFalseWhenDisabled() {
        let scheduler = makeScheduler(isEnabled: false)
        scheduler.start()

        let triggerAt = scheduler.nextTriggerTimeForTesting!
        expect(!scheduler.checkTrigger(at: triggerAt),
               "should not trigger when disabled")
    }

    func checkTriggerReturnsFalseInSilentPeriod() {
        let scheduler = makeScheduler(
            silentStart: DateComponents(hour: 0, minute: 0),
            silentEnd: DateComponents(hour: 23, minute: 59)
        )
        scheduler.start()

        let triggerAt = scheduler.nextTriggerTimeForTesting!
        expect(!scheduler.checkTrigger(at: triggerAt),
               "should not trigger during silent period")
    }

    func checkTriggerReturnsFalseWhenChatPanelOpen() {
        let scheduler = makeScheduler()
        scheduler.isChatPanelOpen = { true }
        scheduler.start()

        let triggerAt = scheduler.nextTriggerTimeForTesting!
        expect(!scheduler.checkTrigger(at: triggerAt),
               "should not trigger when chat panel is open")
    }

    func checkTriggerReturnsFalseWhenHigherPriorityBubble() {
        let scheduler = makeScheduler()
        scheduler.hasHigherPriorityBubble = { true }
        scheduler.start()

        let triggerAt = scheduler.nextTriggerTimeForTesting!
        expect(!scheduler.checkTrigger(at: triggerAt),
               "should not trigger when higher priority bubble is showing")
    }

    func checkTriggerReturnsFalseWhenGlobalMinIntervalNotElapsed() {
        let scheduler = makeScheduler()
        scheduler.start()

        let firstTrigger = scheduler.nextTriggerTimeForTesting!
        expect(scheduler.checkTrigger(at: firstTrigger),
               "first trigger should pass (no lastTriggerTime)")

        scheduler.scheduleNext()
        scheduler.globalMinInterval = { 9999 }

        let secondTrigger = scheduler.nextTriggerTimeForTesting!
        expect(!scheduler.checkTrigger(at: secondTrigger),
               "should not trigger when global min interval not elapsed since last trigger")
    }

    func onBubbleDismissedIncrementsNoResponse() {
        let scheduler = makeScheduler()
        scheduler.start()
        expect(scheduler.consecutiveNoResponseForTesting == 0, "initial count should be 0")

        scheduler.onBubbleDismissed()
        expect(scheduler.consecutiveNoResponseForTesting == 1, "dismissed should increment to 1")

        scheduler.onBubbleDismissed()
        expect(scheduler.consecutiveNoResponseForTesting == 2, "dismissed should increment to 2")
    }

    func onUserRespondedResetsNoResponse() {
        let scheduler = makeScheduler()
        scheduler.start()

        scheduler.onBubbleDismissed()
        scheduler.onBubbleDismissed()
        scheduler.onBubbleDismissed()
        expect(scheduler.consecutiveNoResponseForTesting == 3, "should be 3 after 3 dismissals")

        scheduler.onUserResponded()
        expect(scheduler.consecutiveNoResponseForTesting == 0, "responded should reset to 0")
    }

    func silentPeriodSameDayRange() {
        let scheduler = makeScheduler(
            silentStart: DateComponents(hour: 0, minute: 0),
            silentEnd: DateComponents(hour: 9, minute: 0)
        )

        let inRange = dateAt(hour: 5, minute: 30)
        expect(scheduler.isInSilentPeriodForTesting(at: inRange),
               "5:30 should be in 0:00-9:00 silent period")

        let outOfRange = dateAt(hour: 10, minute: 0)
        expect(!scheduler.isInSilentPeriodForTesting(at: outOfRange),
               "10:00 should not be in 0:00-9:00 silent period")
    }

    func silentPeriodCrossMidnight() {
        let scheduler = makeScheduler(
            silentStart: DateComponents(hour: 23, minute: 0),
            silentEnd: DateComponents(hour: 6, minute: 0)
        )

        let before = dateAt(hour: 23, minute: 30)
        expect(scheduler.isInSilentPeriodForTesting(at: before),
               "23:30 should be in 23:00-6:00 cross-midnight silent period")

        let after = dateAt(hour: 2, minute: 0)
        expect(scheduler.isInSilentPeriodForTesting(at: after),
               "2:00 should be in 23:00-6:00 cross-midnight silent period")

        let middle = dateAt(hour: 12, minute: 0)
        expect(!scheduler.isInSilentPeriodForTesting(at: middle),
               "12:00 should not be in 23:00-6:00 silent period")
    }

    func silentPeriodNoHourReturnsFalse() {
        let scheduler = makeScheduler(
            silentStart: DateComponents(),
            silentEnd: DateComponents(hour: 6, minute: 0)
        )

        let anyDate = Date.now
        expect(!scheduler.isInSilentPeriodForTesting(at: anyDate),
               "missing hour component should not be in silent period")
    }

    func gateFailurePostponesBy60Seconds() {
        let scheduler = makeScheduler()
        scheduler.isChatPanelOpen = { true }
        scheduler.start()

        let triggerAt = scheduler.nextTriggerTimeForTesting!
        _ = scheduler.checkTrigger(at: triggerAt)

        let postponed = scheduler.nextTriggerTimeForTesting!
        let diff = postponed.timeIntervalSince(triggerAt)
        expect(diff == 60, "gate failure should postpone by 60 seconds, got \(diff)")
    }

    func currentIntervalRangeReflectsSettings() {
        let scheduler = makeScheduler(minInterval: 300, maxInterval: 1800)
        let range = scheduler.currentIntervalRange()
        expect(range.lowerBound == 300, "min should be 300")
        expect(range.upperBound == 1800, "max should be 1800")
    }

    func urgentPetNeedShortensIntervalButKeepsUserMinimum() {
        let scheduler = makeScheduler(minInterval: 600, maxInterval: 3600)
        var state = PetRuntimeState.defaultState()
        state.hunger = 0.85
        scheduler.updateFrequencyContext(runtimeState: state)

        let range = scheduler.currentIntervalRange()

        expect(range.lowerBound == 600, "urgent need should not reduce interval below user minimum")
        expect(range.upperBound == 1800, "urgent need should shorten max interval by 50%")
    }

    func lowEnergyShortensIntervalButKeepsUserMinimum() {
        let scheduler = makeScheduler(minInterval: 600, maxInterval: 3600)
        var state = PetRuntimeState.defaultState()
        state.energy = 0.15
        scheduler.updateFrequencyContext(runtimeState: state)

        let range = scheduler.currentIntervalRange()

        expect(range.lowerBound == 600, "low energy should not reduce interval below user minimum")
        expect(range.upperBound == 1800, "low energy should shorten max interval by 50%")
    }

    func lowMoodShortensIntervalButKeepsUserMinimum() {
        let scheduler = makeScheduler(minInterval: 600, maxInterval: 3600)
        var state = PetRuntimeState.defaultState()
        state.mood = 0.25
        scheduler.updateFrequencyContext(runtimeState: state)

        let range = scheduler.currentIntervalRange()

        expect(range.lowerBound == 600, "low mood should not reduce interval below user minimum")
        expect(range.upperBound == 2520, "low mood should shorten max interval by 30%")
    }

    func ownerBusyExtendsInterval() {
        let scheduler = makeScheduler(minInterval: 600, maxInterval: 3600)
        let model = AIEmotionalModel(
            emotionalPatterns: [
                EmotionalPattern(pattern: "用户最近工作忙碌", confidence: 0.9, evidence: 3)
            ]
        )
        scheduler.updateFrequencyContext(emotionalModel: model)

        let range = scheduler.currentIntervalRange()

        expect(range.lowerBound == 900, "owner busy should extend min interval by 50%")
        expect(range.upperBound == 5400, "owner busy should extend max interval by 50%")
    }

    func consecutiveNoResponseExtendsInterval() {
        let scheduler = makeScheduler(minInterval: 600, maxInterval: 3600)
        scheduler.onBubbleDismissed()
        scheduler.onBubbleDismissed()
        scheduler.onBubbleDismissed()

        let range = scheduler.currentIntervalRange()

        expect(range.lowerBound == 900, "3 no responses should extend min interval by 50%")
        expect(range.upperBound == 5400, "3 no responses should extend max interval by 50%")
    }

    func acquaintanceRelationshipExtendsInterval() {
        let scheduler = makeScheduler(minInterval: 600, maxInterval: 3600)
        scheduler.updateFrequencyContext(relationshipLevel: .acquaintance)

        let range = scheduler.currentIntervalRange()

        expect(range.lowerBound == 780, "acquaintance relationship should extend min interval by 30%")
        expect(range.upperBound == 4680, "acquaintance relationship should extend max interval by 30%")
    }

    func frequencyCorrectionsStack() {
        let scheduler = makeScheduler(minInterval: 600, maxInterval: 3600)
        var state = PetRuntimeState.defaultState()
        state.hunger = 0.9
        state.energy = 0.1
        state.mood = 0.2
        scheduler.updateFrequencyContext(
            runtimeState: state,
            relationshipLevel: .close
        )

        let range = scheduler.currentIntervalRange()

        expect(range.lowerBound == 600, "stacked shortening should keep user minimum")
        expect(range.upperBound == 1260, "stacked shortening should multiply urgent and low mood factors")
    }

    func frequencyCorrectionsClampFinalIntervalToDoubleUserMaximum() {
        let scheduler = makeScheduler(minInterval: 600, maxInterval: 3600)
        let model = AIEmotionalModel(
            emotionalPatterns: [
                EmotionalPattern(pattern: "busy", confidence: 0.9, evidence: 3)
            ]
        )
        scheduler.updateFrequencyContext(
            emotionalModel: model,
            relationshipLevel: .acquaintance
        )
        scheduler.onBubbleDismissed()
        scheduler.onBubbleDismissed()
        scheduler.onBubbleDismissed()

        let range = scheduler.currentIntervalRange()

        expectClose(range.lowerBound, 1755, "stacked extending should apply combined multiplier")
        expect(range.upperBound == 7200, "final interval should not exceed user maximum × 2")
    }

    func silentPeriodFailurePostponesToSilentEnd() {
        let scheduler = makeScheduler(
            minInterval: 1,
            maxInterval: 1,
            silentStart: DateComponents(hour: 0, minute: 0),
            silentEnd: DateComponents(hour: 9, minute: 0)
        )
        scheduler.start()
        let triggerAt = dateAt(hour: 5, minute: 30)
        scheduler.setNextTriggerTimeForTesting(triggerAt)

        expect(!scheduler.checkTrigger(at: triggerAt),
               "should not trigger during silent period")

        let postponed = scheduler.nextTriggerTimeForTesting!
        expect(minutesOfDay(postponed) == 9 * 60,
               "silent period failure should postpone to silent period end")
    }

    func crossMidnightSilentPeriodFailurePostponesToNextEnd() {
        let scheduler = makeScheduler(
            minInterval: 1,
            maxInterval: 1,
            silentStart: DateComponents(hour: 23, minute: 0),
            silentEnd: DateComponents(hour: 6, minute: 0)
        )
        scheduler.start()
        let triggerAt = dateAt(hour: 23, minute: 30)
        scheduler.setNextTriggerTimeForTesting(triggerAt)

        expect(!scheduler.checkTrigger(at: triggerAt),
               "should not trigger during cross-midnight silent period")

        let postponed = scheduler.nextTriggerTimeForTesting!
        expect(minutesOfDay(postponed) == 6 * 60,
               "cross-midnight silent failure should postpone to end hour")
        expect(postponed > triggerAt,
               "cross-midnight silent failure should postpone to the next end date")
    }

    private func dateAt(hour: Int, minute: Int) -> Date {
        let cal = Calendar.current
        let now = Date.now
        var components = cal.dateComponents([.year, .month, .day], from: now)
        components.hour = hour
        components.minute = minute
        return cal.date(from: components)!
    }

    private func minutesOfDay(_ date: Date) -> Int {
        let cal = Calendar.current
        return cal.component(.hour, from: date) * 60 + cal.component(.minute, from: date)
    }

    private func expectClose(_ actual: TimeInterval, _ expected: TimeInterval, _ message: String) {
        expect(abs(actual - expected) < 0.0001, "\(message), got \(actual)")
    }
}

@MainActor
private final class MockSettings: InteractiveBubbleSettingsProviding {
    var isEnabled: Bool
    var activityLevel: ActivityLevel = .medium
    var minInterval: TimeInterval
    var maxInterval: TimeInterval
    var optionWaitDuration: TimeInterval = 15
    var silentPeriodStart: DateComponents
    var silentPeriodEnd: DateComponents
    var isAdvancedMode: Bool = false

    init(
        isEnabled: Bool = true,
        minInterval: TimeInterval = 600,
        maxInterval: TimeInterval = 3600,
        silentPeriodStart: DateComponents = DateComponents(hour: 0, minute: 0),
        silentEnd: DateComponents = DateComponents(hour: 9, minute: 0)
    ) {
        self.isEnabled = isEnabled
        self.minInterval = minInterval
        self.maxInterval = maxInterval
        self.silentPeriodStart = silentPeriodStart
        self.silentPeriodEnd = silentEnd
    }
}
