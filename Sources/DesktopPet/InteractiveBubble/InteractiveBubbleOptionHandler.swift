import Foundation

public struct InteractiveBubbleOptionHandler: InteractiveBubbleOptionHandling, Sendable {

    public init() {}

    public func handle(
        result: OptionInteractionResult,
        state: inout PetRuntimeState
    ) -> BubbleEffectOutcome {
        let effect = result.selectedOption.effect
        let changes = stateChanges(for: effect)

        state.hunger = MoodModel.clamp01(state.hunger + changes.hungerDelta)
        state.mood = MoodModel.clamp01(state.mood + changes.moodDelta)
        state.energy = MoodModel.clamp01(state.energy + changes.energyDelta)

        return BubbleEffectOutcome(
            stateChanges: changes,
            shouldShowFeedback: effect != .chat,
            feedbackText: feedbackText(for: effect),
            shouldOpenChat: effect == .chat,
            animationTrigger: animationTrigger(for: effect)
        )
    }

    private func stateChanges(for effect: BubbleEffect) -> StateChanges {
        switch effect {
        case .feed:             return StateChanges(hungerDelta: -0.20, moodDelta: 0.05, energyDelta: 0)
        case .play:             return StateChanges(hungerDelta: 0, moodDelta: 0.15, energyDelta: -0.10)
        case .pet:              return StateChanges(hungerDelta: 0, moodDelta: 0.10, energyDelta: 0)
        case .chat:             return .zero
        case .positiveResponse: return StateChanges(hungerDelta: 0, moodDelta: 0.05, energyDelta: 0)
        case .none:             return StateChanges(hungerDelta: 0, moodDelta: -0.03, energyDelta: 0)
        }
    }

    private func feedbackText(for effect: BubbleEffect) -> String? {
        guard let texts = Self.feedbackTexts[effect], !texts.isEmpty else { return nil }
        return texts.randomElement()
    }

    private func animationTrigger(for effect: BubbleEffect) -> PetState? {
        switch effect {
        case .feed:             return .eating
        case .play, .pet:       return .happy
        case .positiveResponse: return .happy
        case .chat, .none:      return nil
        }
    }

    public static let feedbackTexts: [BubbleEffect: [String]] = [
        .feed: ["好吃好吃！满足~", "谢谢投喂！", "饱了饱了~"],
        .play: ["太好玩啦！", "再来再来！", "嘿嘿好开心"],
        .pet: ["好舒服~", "还要还要！", "幸福..."],
        .positiveResponse: ["开心！", "嘿嘿~", "你真好"],
        .none: ["好吧...", "没关系~", "理解理解"]
    ]
}
