import Foundation
import DesktopPet

@MainActor
func runBubbleEngineCompanionshipTests() {
    let tests = BubbleEngineCompanionshipTests()
    tests.contextHandleProducesInteractionBubble()
    tests.contextHandleProducesRelationshipBubble()
    tests.contextTickEmitsHungryWhenHungerHigh()
    tests.contextTickEmitsTiredWhenEnergyLow()
    tests.contextTickEmitsHappyForHappyState()
    tests.contextTickEmitsAmbientForLongIdle()
    tests.contextTickSuppressesWhileDragging()
    tests.quietModeSuppressesAmbientTriggers()
    tests.quietModeSuppressesStateTriggers()
    tests.quietModeAllowsInteractionTriggers()
    tests.disabledEngineProducesNothing()
    tests.relationPriorityHandledCorrectly()
    tests.newPriorityOrdering()
    tests.interactionOverridesAmbientInContext()
}

@MainActor
private struct BubbleEngineCompanionshipTests {
    func contextHandleProducesInteractionBubble() {
        let engine = makeContextualEngine()
        let context = makeContext()
        let now = baseDate

        let bubble = engine.handle(trigger: .clicked, context: context, at: now)
        expect(bubble?.priority == .interaction, "contextual clicked should produce interaction bubble")
    }

    func contextHandleProducesRelationshipBubble() {
        let engine = makeContextualEngine()
        let context = makeContext()
        let now = baseDate

        let bubble = engine.handle(trigger: .dailyGreeting, context: context, at: now)
        expect(bubble?.priority == .relationship, "dailyGreeting should produce relationship bubble")
    }

    func contextTickEmitsHungryWhenHungerHigh() {
        let engine = makeContextualEngine()
        var state = PetRuntimeState.defaultState(at: baseDate)
        state.hunger = 0.8
        state.currentState = .idle
        let context = makeContext(state: state)

        let bubble = engine.tick(context: context, at: baseDate.addingTimeInterval(10))
        expect(bubble?.priority == .state, "high hunger should emit state bubble")
    }

    func contextTickEmitsTiredWhenEnergyLow() {
        let engine = makeContextualEngine()
        var state = PetRuntimeState.defaultState(at: baseDate)
        state.energy = 0.2
        state.hunger = 0.1
        state.currentState = .idle
        let context = makeContext(state: state)

        let bubble = engine.tick(context: context, at: baseDate.addingTimeInterval(10))
        expect(bubble?.priority == .state, "low energy should emit state bubble")
    }

    func contextTickEmitsHappyForHappyState() {
        let engine = makeContextualEngine()
        var state = PetRuntimeState.defaultState(at: baseDate)
        state.currentState = .happy
        state.hunger = 0.1
        state.energy = 0.9
        let context = makeContext(state: state)

        let bubble = engine.tick(context: context, at: baseDate.addingTimeInterval(10))
        expect(bubble?.priority == .state, "happy state should emit state bubble")
    }

    func contextTickEmitsAmbientForLongIdle() {
        let engine = makeContextualEngine()
        var state = PetRuntimeState.defaultState(at: baseDate)
        state.currentState = .idle
        state.hunger = 0.1
        state.energy = 0.9
        let context = makeContext(state: state)

        let bubble = engine.tick(context: context, at: baseDate.addingTimeInterval(BubbleEngine.idleAmbientSeconds + 5))
        expect(bubble?.priority == .ambient, "long idle should emit ambient bubble")
    }

    func contextTickSuppressesWhileDragging() {
        let engine = makeContextualEngine()
        var state = PetRuntimeState.defaultState(at: baseDate)
        state.isDragging = true
        state.hunger = 0.9
        let context = makeContext(state: state)

        let bubble = engine.tick(context: context, at: baseDate.addingTimeInterval(10))
        expect(bubble == nil, "dragging should suppress all context tick bubbles")
    }

    func quietModeSuppressesAmbientTriggers() {
        let engine = makeContextualEngine()
        var state = PetRuntimeState.defaultState(at: baseDate)
        state.currentState = .idle
        state.hunger = 0.1
        state.energy = 0.9
        var prefs = CompanionPreferences()
        prefs.quietUntil = baseDate.addingTimeInterval(3600)
        let context = makeContext(state: state, preferences: prefs)

        let bubble = engine.tick(context: context, at: baseDate.addingTimeInterval(BubbleEngine.idleAmbientSeconds + 5))
        expect(bubble == nil, "quiet mode should suppress idle ambient trigger")
    }

    func quietModeSuppressesStateTriggers() {
        let engine = makeContextualEngine()
        var state = PetRuntimeState.defaultState(at: baseDate)
        state.hunger = 0.8
        state.currentState = .idle
        var prefs = CompanionPreferences()
        prefs.quietUntil = baseDate.addingTimeInterval(3600)
        let context = makeContext(state: state, preferences: prefs)

        let bubble = engine.tick(context: context, at: baseDate.addingTimeInterval(10))
        expect(bubble == nil, "quiet mode should suppress hungry state trigger")
    }

    func quietModeAllowsInteractionTriggers() {
        let engine = makeContextualEngine()
        var prefs = CompanionPreferences()
        prefs.quietUntil = baseDate.addingTimeInterval(3600)
        let context = makeContext(preferences: prefs)

        let bubble = engine.handle(trigger: .clicked, context: context, at: baseDate)
        expect(bubble != nil, "quiet mode should not suppress interaction triggers")
        expect(bubble?.priority == .interaction, "interaction should still work in quiet mode")
    }

    func disabledEngineProducesNothing() {
        let engine = makeContextualEngine(isEnabled: false)
        let context = makeContext()

        expect(engine.handle(trigger: .clicked, context: context, at: baseDate) == nil,
               "disabled engine should not produce bubbles from handle")
        expect(engine.tick(context: context, at: baseDate.addingTimeInterval(200)) == nil,
               "disabled engine should not produce bubbles from tick")
    }

    func relationPriorityHandledCorrectly() {
        let scheduler = BubbleScheduler()
        let now = baseDate
        scheduler.register(makeBubble(priority: .relationship, createdAt: now, duration: 60))
        expect(scheduler.currentBubble?.priority == .relationship, "relationship bubble should be registered")
        expect(scheduler.lastRelationshipAt == now, "lastRelationshipAt should be set")
    }

    func newPriorityOrdering() {
        expect(BubblePriority.decorative < .ambient, "decorative < ambient")
        expect(BubblePriority.ambient < .relationship, "ambient < relationship")
        expect(BubblePriority.relationship < .state, "relationship < state")
        expect(BubblePriority.state < .interaction, "state < interaction")
    }

    func interactionOverridesAmbientInContext() {
        let engine = makeContextualEngine()
        var state = PetRuntimeState.defaultState(at: baseDate)
        state.currentState = .walking
        state.hunger = 0.1
        state.energy = 0.9
        let context = makeContext(state: state)

        let ambient = engine.tick(context: context, at: baseDate.addingTimeInterval(10))
        expect(ambient?.priority == .ambient, "ambient should fire first")

        let interaction = engine.handle(trigger: .pet, context: context, at: baseDate.addingTimeInterval(11))
        expect(interaction?.priority == .interaction, "interaction should override ambient")
        expect(engine.currentBubble?.priority == .interaction, "current bubble should be interaction")
    }
}

private let baseDate = Date(timeIntervalSince1970: 1_700_000_000)

@MainActor
private func makeContextualEngine(
    isEnabled: Bool = true,
    frequency: BubbleFrequency = .normal
) -> BubbleEngine {
    let profile = BubbleProfileDefaults.defaultProfile()
    let catalog = BubblePhraseCatalogBuilder.defaultCatalog()
    let provider = StubContextualPhraseProvider(catalog: catalog)
    return BubbleEngine(
        profile: profile,
        isEnabled: isEnabled,
        frequency: frequency,
        phraseProvider: DefaultBubblePhraseProvider(profile: profile, selector: { $0.first }),
        contextualPhraseProvider: provider
    )
}

@MainActor
private func makeContext(
    state: PetRuntimeState = PetRuntimeState.defaultState(at: baseDate),
    relationship: RelationshipSnapshot = RelationshipState().snapshot,
    preferences: CompanionPreferences = CompanionPreferences()
) -> CompanionContext {
    CompanionContext(
        petId: "test_pet",
        petDisplayName: "TestPet",
        runtimeState: state,
        relationship: relationship,
        preferences: preferences,
        timeSlots: CompanionTimeSlot.slots(for: baseDate),
        recentBubbleTexts: []
    )
}

private func makeBubble(priority: BubblePriority, createdAt: Date, duration: TimeInterval) -> PetBubble {
    PetBubble(
        id: UUID(),
        text: "phrase",
        priority: priority,
        createdAt: createdAt,
        expiresAt: createdAt.addingTimeInterval(duration)
    )
}

private struct StubContextualPhraseProvider: ContextualBubblePhraseProviding {
    let catalog: BubblePhraseCatalog

    func phrase(for trigger: BubbleTrigger, context: CompanionContext, now: Date) -> BubblePhraseSelection? {
        let candidates = catalog.phrases(for: trigger, relationshipLevel: context.relationship.currentLevel)
        guard let first = candidates.first else {
            return nil
        }
        return BubblePhraseSelection(phrase: first, renderedText: first.text)
    }
}
