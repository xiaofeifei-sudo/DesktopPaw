import Foundation
import DesktopPet

func runInteractiveBubbleOptionHandlerTests() {
    let tests = InteractiveBubbleOptionHandlerTests()
    tests.feedEffectReducesHungerAndIncreasesMood()
    tests.playEffectIncreasesMoodAndReducesEnergy()
    tests.petEffectIncreasesMood()
    tests.chatEffectNoStateChanges()
    tests.positiveResponseEffectIncreasesMood()
    tests.noneEffectDecreasesMood()
    tests.chatEffectOpensChatWithoutFeedback()
    tests.noneEffectHasNoAnimation()
    tests.feedEffectTriggersEatingAnimation()
    tests.playAndPetTriggersHappyAnimation()
    tests.positiveResponseTriggersHappyAnimation()
    tests.feedbackTextFromPresetList()
    tests.stateClampedToUpperBound()
    tests.stateClampedToLowerBound()
    tests.outcomeStateChangesMatchAppliedDeltas()
}

private struct InteractiveBubbleOptionHandlerTests {

    private let handler = InteractiveBubbleOptionHandler()

    private func makeOption(effect: BubbleEffect, isPrimary: Bool = true) -> BubbleOption {
        BubbleOption(emoji: "X", label: "test", effect: effect, isPrimary: isPrimary)
    }

    private func makeResult(effect: BubbleEffect) -> OptionInteractionResult {
        let option = makeOption(effect: effect)
        let bubble = InteractiveBubble(
            text: "test",
            type: .needExpression,
            options: [option],
            expiresAt: Date() + 60
        )
        return OptionInteractionResult(bubble: bubble, selectedOption: option)
    }

    func feedEffectReducesHungerAndIncreasesMood() {
        var state = PetRuntimeState.defaultState()
        state.hunger = 0.5
        state.mood = 0.5

        _ = handler.handle(result: makeResult(effect: .feed), state: &state)

        expect(state.hunger == 0.3, "feed should reduce hunger by 0.20")
        expect(state.mood == 0.55, "feed should increase mood by 0.05")
        expect(state.energy == 0.8, "feed should not change energy")
    }

    func playEffectIncreasesMoodAndReducesEnergy() {
        var state = PetRuntimeState.defaultState()
        state.mood = 0.5
        state.energy = 0.5

        _ = handler.handle(result: makeResult(effect: .play), state: &state)

        expect(state.mood == 0.65, "play should increase mood by 0.15")
        expect(state.energy == 0.4, "play should reduce energy by 0.10")
        expect(state.hunger == 0.2, "play should not change hunger")
    }

    func petEffectIncreasesMood() {
        var state = PetRuntimeState.defaultState()
        state.mood = 0.5

        _ = handler.handle(result: makeResult(effect: .pet), state: &state)

        expect(state.mood == 0.6, "pet should increase mood by 0.10")
        expect(state.hunger == 0.2, "pet should not change hunger")
        expect(state.energy == 0.8, "pet should not change energy")
    }

    func chatEffectNoStateChanges() {
        var state = PetRuntimeState.defaultState()
        let original = state

        _ = handler.handle(result: makeResult(effect: .chat), state: &state)

        expect(state.hunger == original.hunger, "chat should not change hunger")
        expect(state.mood == original.mood, "chat should not change mood")
        expect(state.energy == original.energy, "chat should not change energy")
    }

    func positiveResponseEffectIncreasesMood() {
        var state = PetRuntimeState.defaultState()
        state.mood = 0.5

        _ = handler.handle(result: makeResult(effect: .positiveResponse), state: &state)

        expect(state.mood == 0.55, "positiveResponse should increase mood by 0.05")
        expect(state.hunger == 0.2, "positiveResponse should not change hunger")
        expect(state.energy == 0.8, "positiveResponse should not change energy")
    }

    func noneEffectDecreasesMood() {
        var state = PetRuntimeState.defaultState()
        state.mood = 0.5

        _ = handler.handle(result: makeResult(effect: .none), state: &state)

        expect(state.mood == 0.47, "none should decrease mood by 0.03")
        expect(state.hunger == 0.2, "none should not change hunger")
        expect(state.energy == 0.8, "none should not change energy")
    }

    func chatEffectOpensChatWithoutFeedback() {
        var state = PetRuntimeState.defaultState()
        let outcome = handler.handle(result: makeResult(effect: .chat), state: &state)

        expect(outcome.shouldOpenChat, "chat should set shouldOpenChat true")
        expect(!outcome.shouldShowFeedback, "chat should not show feedback")
        expect(outcome.feedbackText == nil, "chat should have no feedback text")
    }

    func noneEffectHasNoAnimation() {
        var state = PetRuntimeState.defaultState()
        let outcome = handler.handle(result: makeResult(effect: .none), state: &state)

        expect(outcome.animationTrigger == nil, "none should have no animation")
    }

    func feedEffectTriggersEatingAnimation() {
        var state = PetRuntimeState.defaultState()
        let outcome = handler.handle(result: makeResult(effect: .feed), state: &state)

        expect(outcome.animationTrigger == .eating, "feed should trigger eating animation")
    }

    func playAndPetTriggersHappyAnimation() {
        var state = PetRuntimeState.defaultState()

        let playOutcome = handler.handle(result: makeResult(effect: .play), state: &state)
        expect(playOutcome.animationTrigger == .happy, "play should trigger happy animation")

        let petOutcome = handler.handle(result: makeResult(effect: .pet), state: &state)
        expect(petOutcome.animationTrigger == .happy, "pet should trigger happy animation")
    }

    func positiveResponseTriggersHappyAnimation() {
        var state = PetRuntimeState.defaultState()
        let outcome = handler.handle(result: makeResult(effect: .positiveResponse), state: &state)

        expect(outcome.animationTrigger == .happy, "positiveResponse should trigger happy animation")
    }

    func feedbackTextFromPresetList() {
        let presets = InteractiveBubbleOptionHandler.feedbackTexts

        for effect in BubbleEffect.allCases {
            var state = PetRuntimeState.defaultState()
            let outcome = handler.handle(result: makeResult(effect: effect), state: &state)

            if effect == .chat {
                expect(outcome.feedbackText == nil, "chat should have no feedback text")
                continue
            }

            guard let text = outcome.feedbackText,
                  let allowed = presets[effect] else {
                expect(false, "effect \(effect) should have feedback text from presets")
                continue
            }
            expect(allowed.contains(text), "feedback text '\(text)' should be in presets for \(effect)")
        }
    }

    func stateClampedToUpperBound() {
        var state = PetRuntimeState.defaultState()
        state.mood = 0.99

        _ = handler.handle(result: makeResult(effect: .pet), state: &state)

        expect(state.mood <= 1.0, "mood should be clamped to 1.0")
    }

    func stateClampedToLowerBound() {
        var state = PetRuntimeState.defaultState()
        state.mood = 0.01

        _ = handler.handle(result: makeResult(effect: .none), state: &state)

        expect(state.mood >= 0.0, "mood should be clamped to 0.0")
    }

    func outcomeStateChangesMatchAppliedDeltas() {
        var state = PetRuntimeState.defaultState()
        state.hunger = 0.5
        state.mood = 0.5
        state.energy = 0.5

        let outcome = handler.handle(result: makeResult(effect: .feed), state: &state)

        expect(outcome.stateChanges.hungerDelta == -0.20, "stateChanges hungerDelta should be -0.20")
        expect(outcome.stateChanges.moodDelta == 0.05, "stateChanges moodDelta should be 0.05")
        expect(outcome.stateChanges.energyDelta == 0, "stateChanges energyDelta should be 0")
        expect(state.hunger == 0.3, "state hunger should reflect applied delta")
        expect(state.mood == 0.55, "state mood should reflect applied delta")
    }
}
