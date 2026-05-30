import Foundation
import DesktopPet

func runMoodModelTests() {
    let tests = MoodModelTests()
    tests.advanceClampsMoodHungerAndEnergy()
    tests.sleepingRecoversEnergyWithoutExceedingOne()
    tests.petAndFeedApplyExpectedChanges()
}

private struct MoodModelTests {
    func advanceClampsMoodHungerAndEnergy() {
        let initial = PetRuntimeState(
            currentState: .idle,
            mood: 0.01,
            hunger: 0.99,
            energy: 0.01,
            lastInteractionAt: referenceDate,
            isDragging: false,
            scale: 1
        )

        let state = MoodModel.advance(initial, elapsedSeconds: 20 * 60)

        expect(state.mood == 0, "mood should clamp at 0")
        expect(state.hunger == 1, "hunger should clamp at 1")
        expect(state.energy == 0, "active energy should clamp at 0")
    }

    func sleepingRecoversEnergyWithoutExceedingOne() {
        let initial = PetRuntimeState(
            currentState: .sleeping,
            mood: 0.8,
            hunger: 0.2,
            energy: 0.99,
            lastInteractionAt: referenceDate,
            isDragging: false,
            scale: 1
        )

        let state = MoodModel.advance(initial, elapsedSeconds: 10 * 60)

        expect(state.energy == 1, "sleeping energy should clamp at 1")
    }

    func petAndFeedApplyExpectedChanges() {
        let initial = PetRuntimeState(
            currentState: .idle,
            mood: 0.5,
            hunger: 0.5,
            energy: 0.8,
            lastInteractionAt: referenceDate,
            isDragging: false,
            scale: 1
        )

        let petted = MoodModel.applyingPet(to: initial)
        let fed = MoodModel.applyingFeed(to: initial)

        expect(abs(petted.mood - 0.65) < 0.0001, "pet should increase mood")
        expect(abs(fed.hunger - 0.25) < 0.0001, "feed should decrease hunger")
        expect(abs(fed.mood - 0.55) < 0.0001, "feed should increase mood")
    }

    private let referenceDate = Date(timeIntervalSince1970: 1_700_000_000)
}
