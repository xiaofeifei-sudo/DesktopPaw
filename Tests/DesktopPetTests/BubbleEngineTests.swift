import Foundation
import DesktopPet

@MainActor
func runBubbleEngineTests() {
    let tests = BubbleEngineTests()
    tests.clickedProducesInteractionBubble()
    tests.petProducesInteractionBubble()
    tests.feedProducesInteractionBubble()
    tests.disabledEngineProducesNothing()
    tests.disablingEngineClearsCurrentBubble()
    tests.tickEmitsHungryWhenHungerHigh()
    tests.tickEmitsTiredWhenEnergyLow()
    tests.tickEmitsHappyForHappyState()
    tests.tickEmitsAmbientForLongIdle()
    tests.tickIgnoresShortIdle()
    tests.tickSuppressesAmbientWhileDragging()
    tests.tickSuppressesStateWhileDragging()
    tests.ambientThrottledUntilFrequencyIntervalElapses()
    tests.frequencyExpressiveShortensInterval()
    tests.frequencyQuietExtendsInterval()
    tests.interactionOverridesActiveAmbient()
    tests.bubbleExpiresAfterDisplayDuration()
    tests.unknownEventReturnsNil()
}

@MainActor
private struct BubbleEngineTests {
    func clickedProducesInteractionBubble() {
        let engine = makeEngine()
        let now = baseDate
        let bubble = engine.handle(event: .clicked, state: .defaultState(at: now), at: now)
        expect(bubble?.priority == .interaction, "clicked should produce interaction bubble")
        expect(bubble?.text == "你好", "clicked phrase should come from profile")
    }

    func petProducesInteractionBubble() {
        let engine = makeEngine()
        let now = baseDate
        let bubble = engine.handle(event: .pet, state: .defaultState(at: now), at: now)
        expect(bubble?.priority == .interaction, "pet should produce interaction bubble")
        expect(bubble?.text == "开心", "pet phrase should come from profile")
    }

    func feedProducesInteractionBubble() {
        let engine = makeEngine()
        let now = baseDate
        let bubble = engine.handle(event: .feed, state: .defaultState(at: now), at: now)
        expect(bubble?.priority == .interaction, "feed should produce interaction bubble")
        expect(bubble?.text == "好吃", "feed phrase should come from profile")
    }

    func disabledEngineProducesNothing() {
        let engine = makeEngine(isEnabled: false)
        let now = baseDate
        expect(engine.handle(event: .clicked, state: .defaultState(at: now), at: now) == nil,
               "disabled engine should produce no bubble for events")
        expect(engine.tick(state: .defaultState(at: now), at: now.addingTimeInterval(120)) == nil,
               "disabled engine should produce no bubble on tick")
    }

    func disablingEngineClearsCurrentBubble() {
        let engine = makeEngine()
        let now = baseDate
        _ = engine.handle(event: .clicked, state: .defaultState(at: now), at: now)
        expect(engine.currentBubble != nil, "engine should hold current bubble after emit")

        engine.isEnabled = false
        expect(engine.currentBubble == nil, "disabling engine should clear active bubble")
    }

    func tickEmitsHungryWhenHungerHigh() {
        let engine = makeEngine()
        var state = PetRuntimeState.defaultState(at: baseDate)
        state.hunger = 0.8
        state.currentState = .idle

        let bubble = engine.tick(state: state, at: baseDate.addingTimeInterval(10))
        expect(bubble?.text == "有点饿", "high hunger should emit hungry phrase")
        expect(bubble?.priority == .state, "hungry bubble should be state priority")
    }

    func tickEmitsTiredWhenEnergyLow() {
        let engine = makeEngine()
        var state = PetRuntimeState.defaultState(at: baseDate)
        state.energy = 0.2
        state.hunger = 0.1
        state.currentState = .idle

        let bubble = engine.tick(state: state, at: baseDate.addingTimeInterval(10))
        expect(bubble?.text == "困了", "low energy should emit tired phrase")
        expect(bubble?.priority == .state, "tired bubble should be state priority")
    }

    func tickEmitsHappyForHappyState() {
        let engine = makeEngine()
        var state = PetRuntimeState.defaultState(at: baseDate)
        state.currentState = .happy
        state.hunger = 0.1
        state.energy = 0.9

        let bubble = engine.tick(state: state, at: baseDate.addingTimeInterval(10))
        expect(bubble?.text == "开心", "happy state should emit happy phrase")
        expect(bubble?.priority == .state, "happy bubble should be state priority")
    }

    func tickEmitsAmbientForLongIdle() {
        let engine = makeEngine()
        let lastInteraction = baseDate
        let now = baseDate.addingTimeInterval(BubbleEngine.idleAmbientSeconds + 5)
        var state = PetRuntimeState.defaultState(at: lastInteraction)
        state.currentState = .idle
        state.hunger = 0.1
        state.energy = 0.9

        let bubble = engine.tick(state: state, at: now)
        expect(bubble?.text == "陪你一会儿", "long idle should emit idle phrase")
        expect(bubble?.priority == .ambient, "idle ambient should be ambient priority")
    }

    func tickIgnoresShortIdle() {
        let engine = makeEngine()
        let now = baseDate.addingTimeInterval(10)
        var state = PetRuntimeState.defaultState(at: baseDate)
        state.currentState = .idle
        state.hunger = 0.1
        state.energy = 0.9

        let bubble = engine.tick(state: state, at: now)
        expect(bubble == nil, "short idle should not produce ambient bubble")
    }

    func tickSuppressesAmbientWhileDragging() {
        let engine = makeEngine()
        var state = PetRuntimeState.defaultState(at: baseDate)
        state.currentState = .walking
        state.isDragging = true
        state.hunger = 0.1
        state.energy = 0.9

        let bubble = engine.tick(state: state, at: baseDate.addingTimeInterval(10))
        expect(bubble == nil, "dragging should suppress autonomous bubbles")
    }

    func tickSuppressesStateWhileDragging() {
        let engine = makeEngine()
        var state = PetRuntimeState.defaultState(at: baseDate)
        state.currentState = .happy
        state.isDragging = true
        state.hunger = 0.9

        let bubble = engine.tick(state: state, at: baseDate.addingTimeInterval(10))
        expect(bubble == nil, "dragging should suppress state bubbles")
    }

    func ambientThrottledUntilFrequencyIntervalElapses() {
        let engine = makeEngine(profile: customProfile(minimumInterval: 60), frequency: .normal)
        let lastInteraction = baseDate
        var state = PetRuntimeState.defaultState(at: lastInteraction)
        state.currentState = .walking
        state.hunger = 0.1
        state.energy = 0.9

        let firstAt = baseDate.addingTimeInterval(10)
        let first = engine.tick(state: state, at: firstAt)
        expect(first != nil, "first ambient should be allowed")

        let earlyAt = firstAt.addingTimeInterval(30)
        let early = engine.tick(state: state, at: earlyAt)
        expect(early == nil, "second ambient before interval should be throttled")

        let lateAt = firstAt.addingTimeInterval(61)
        let late = engine.tick(state: state, at: lateAt)
        expect(late != nil, "ambient after interval elapses should be allowed")
    }

    func frequencyExpressiveShortensInterval() {
        let engine = makeEngine(profile: customProfile(minimumInterval: 60), frequency: .expressive)
        var state = PetRuntimeState.defaultState(at: baseDate)
        state.currentState = .walking
        state.hunger = 0.1
        state.energy = 0.9

        let firstAt = baseDate.addingTimeInterval(10)
        _ = engine.tick(state: state, at: firstAt)

        let between = engine.tick(state: state, at: firstAt.addingTimeInterval(31))
        expect(between != nil, "expressive should allow re-emission after 30s when base interval is 60s")
    }

    func frequencyQuietExtendsInterval() {
        let engine = makeEngine(profile: customProfile(minimumInterval: 60), frequency: .quiet)
        var state = PetRuntimeState.defaultState(at: baseDate)
        state.currentState = .walking
        state.hunger = 0.1
        state.energy = 0.9

        let firstAt = baseDate.addingTimeInterval(10)
        _ = engine.tick(state: state, at: firstAt)

        let between = engine.tick(state: state, at: firstAt.addingTimeInterval(90))
        expect(between == nil, "quiet should extend interval beyond 90s when base is 60s")

        let later = engine.tick(state: state, at: firstAt.addingTimeInterval(125))
        expect(later != nil, "quiet should allow re-emission after 120s when base is 60s")
    }

    func interactionOverridesActiveAmbient() {
        let engine = makeEngine()
        var state = PetRuntimeState.defaultState(at: baseDate)
        state.currentState = .walking
        state.hunger = 0.1
        state.energy = 0.9

        let ambient = engine.tick(state: state, at: baseDate.addingTimeInterval(10))
        expect(ambient?.priority == .ambient, "ambient should fire first")

        let interaction = engine.handle(event: .pet, state: state, at: baseDate.addingTimeInterval(11))
        expect(interaction?.priority == .interaction, "interaction should override ambient")
        expect(engine.currentBubble?.priority == .interaction, "current bubble should be interaction")
    }

    func bubbleExpiresAfterDisplayDuration() {
        let profile = customProfile(displayDuration: 2)
        let engine = makeEngine(profile: profile)
        let now = baseDate
        let bubble = engine.handle(event: .clicked, state: .defaultState(at: now), at: now)
        expect(bubble != nil, "click should emit bubble")

        _ = engine.tick(state: .defaultState(at: now), at: now.addingTimeInterval(5))
        expect(engine.currentBubble == nil, "bubble should auto-expire after display duration")
    }

    func unknownEventReturnsNil() {
        let engine = makeEngine()
        let now = baseDate
        expect(engine.handle(event: .appLaunched, state: .defaultState(at: now), at: now) == nil,
               "non-interaction events should not produce bubbles")
        expect(engine.handle(event: .dragStarted, state: .defaultState(at: now), at: now) == nil,
               "dragStarted should not produce bubble")
        expect(engine.handle(event: .tick(now), state: .defaultState(at: now), at: now) == nil,
               "tick events should not produce bubbles via handle")
    }
}

private let baseDate = Date(timeIntervalSince1970: 1_700_000_000)

@MainActor
private func makeEngine(
    profile: BubbleProfile = BubbleProfileDefaults.defaultProfile(),
    isEnabled: Bool = true,
    frequency: BubbleFrequency = .normal
) -> BubbleEngine {
    BubbleEngine(
        profile: profile,
        isEnabled: isEnabled,
        frequency: frequency,
        phraseProvider: DefaultBubblePhraseProvider(profile: profile, selector: { $0.first })
    )
}

private func customProfile(minimumInterval: Double = 60, displayDuration: Double = 3) -> BubbleProfile {
    let defaults = BubbleProfileDefaults.defaultProfile()
    return BubbleProfile(
        phrases: defaults.phrases,
        minimumIntervalSeconds: minimumInterval,
        displayDurationSeconds: displayDuration
    )
}
