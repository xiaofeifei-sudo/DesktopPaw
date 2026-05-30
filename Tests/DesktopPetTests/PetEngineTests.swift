import Foundation
import DesktopPet

func runPetEngineTests() {
    let tests = PetEngineTests()
    tests.appLaunchEntersIdle()
    tests.clickEntersJumping()
    tests.petIncreasesMoodAndEntersHappy()
    tests.feedLowersHungerAndEntersEating()
    tests.dragPriorityOverridesOtherInteractions()
    tests.sleepingCanBeInterruptedByUserInteraction()
    tests.reactionStateReturnsToIdleAfterDuration()
    tests.randomWalkingCanBeTriggeredDeterministically()
}

private struct PetEngineTests {
    func appLaunchEntersIdle() {
        let engine = makeEngine(isRandomWalkingEnabled: false)

        let state = engine.handle(.appLaunched)

        expect(state.currentState == .idle, "app launch should enter idle")
        expect(!state.isDragging, "app launch should not be dragging")
    }

    func clickEntersJumping() {
        let engine = makeEngine(isRandomWalkingEnabled: false)

        let state = engine.handle(.clicked)

        expect(state.currentState == .jumping, "click should enter jumping")
        expect(state.lastInteractionAt == referenceDate, "click should update interaction time")
    }

    func petIncreasesMoodAndEntersHappy() {
        let initial = PetRuntimeState(
            currentState: .idle,
            mood: 0.4,
            hunger: 0.2,
            energy: 0.8,
            lastInteractionAt: referenceDate,
            isDragging: false,
            scale: 1
        )
        let engine = makeEngine(initialState: initial, isRandomWalkingEnabled: false)

        let state = engine.handle(.pet)

        expect(state.currentState == .happy, "pet should enter happy")
        expect(abs(state.mood - 0.55) < 0.0001, "pet should increase mood")
    }

    func feedLowersHungerAndEntersEating() {
        let initial = PetRuntimeState(
            currentState: .idle,
            mood: 0.4,
            hunger: 0.6,
            energy: 0.8,
            lastInteractionAt: referenceDate,
            isDragging: false,
            scale: 1
        )
        let engine = makeEngine(initialState: initial, isRandomWalkingEnabled: false)

        let state = engine.handle(.feed)

        expect(state.currentState == .eating, "feed should enter eating")
        expect(abs(state.hunger - 0.35) < 0.0001, "feed should lower hunger")
        expect(abs(state.mood - 0.45) < 0.0001, "feed should increase mood slightly")
    }

    func dragPriorityOverridesOtherInteractions() {
        let engine = makeEngine(isRandomWalkingEnabled: false)

        _ = engine.handle(.dragStarted)
        let afterPet = engine.handle(.pet)
        let afterClick = engine.handle(.clicked)

        expect(afterPet.currentState == .dragging, "dragging should override pet")
        expect(afterClick.currentState == .dragging, "dragging should override click")
        expect(afterClick.isDragging, "dragging flag should stay true")

        let released = engine.handle(.dragEnded)
        expect(released.currentState == .idle, "drag end should return to idle")
        expect(!released.isDragging, "drag end should clear dragging flag")
    }

    func sleepingCanBeInterruptedByUserInteraction() {
        let engine = makeEngine(isRandomWalkingEnabled: false)

        _ = engine.handle(.sleepRequested)
        let state = engine.handle(.clicked)

        expect(state.currentState == .jumping, "click should interrupt sleeping")
    }

    func reactionStateReturnsToIdleAfterDuration() {
        let engine = makeEngine(isRandomWalkingEnabled: false)

        _ = engine.handle(.clicked)
        let state = engine.handle(.tick(referenceDate.addingTimeInterval(1.3)))

        expect(state.currentState == .idle, "reaction should return to idle")
    }

    func randomWalkingCanBeTriggeredDeterministically() {
        let random = SequenceRandomNumberGenerator(values: [20, 0])
        let engine = makeEngine(
            isRandomWalkingEnabled: true,
            randomNumberGenerator: random
        )

        let state = engine.handle(.tick(referenceDate.addingTimeInterval(20)))

        expect(state.currentState == .walking, "fixed random delay should trigger walking")
    }

    private let referenceDate = Date(timeIntervalSince1970: 1_700_000_000)

    private func makeEngine(
        initialState: PetRuntimeState? = nil,
        isRandomWalkingEnabled: Bool,
        randomNumberGenerator: RandomNumberGenerating? = nil
    ) -> PetEngine {
        let rng: RandomNumberGenerating = randomNumberGenerator ?? FixedRandomNumberGenerator(value: 20)
        let catalog = makeStandardCatalog()
        return PetEngine(
            catalog: catalog,
            scheduler: UniformIdleBehaviorScheduler(randomNumberGenerator: rng),
            initialState: initialState,
            initialDate: referenceDate,
            isRandomWalkingEnabled: isRandomWalkingEnabled,
            randomNumberGenerator: rng,
            now: { referenceDate }
        )
    }
}
