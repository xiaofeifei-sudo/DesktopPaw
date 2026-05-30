import Foundation

public enum MoodModel {
    public static let moodDecayPerMinute = 0.005
    public static let hungerIncreasePerMinute = 0.005
    public static let activeEnergyDecayPerMinute = 0.004
    public static let sleepingEnergyRecoveryPerMinute = 0.02
    public static let petMoodIncrease = 0.15
    public static let feedHungerDecrease = 0.25
    public static let feedMoodIncrease = 0.05

    public static func advance(_ state: PetRuntimeState, elapsedSeconds: TimeInterval) -> PetRuntimeState {
        let minutes = max(0, elapsedSeconds / 60)
        let energyDelta = state.currentState == .sleeping
            ? sleepingEnergyRecoveryPerMinute * minutes
            : -activeEnergyDecayPerMinute * minutes

        var next = state
        next.mood = clamp01(state.mood - moodDecayPerMinute * minutes)
        next.hunger = clamp01(state.hunger + hungerIncreasePerMinute * minutes)
        next.energy = clamp01(state.energy + energyDelta)
        return next
    }

    public static func applyingPet(to state: PetRuntimeState) -> PetRuntimeState {
        var next = state
        next.mood = clamp01(state.mood + petMoodIncrease)
        return next
    }

    public static func applyingFeed(to state: PetRuntimeState) -> PetRuntimeState {
        var next = state
        next.hunger = clamp01(state.hunger - feedHungerDecrease)
        next.mood = clamp01(state.mood + feedMoodIncrease)
        return next
    }

    public static func clamp01(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }
}
