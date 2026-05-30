import Foundation

public struct PetRuntimeState: Equatable, Sendable {
    public var currentState: PetState
    public var mood: Double
    public var hunger: Double
    public var energy: Double
    public var lastInteractionAt: Date
    public var isDragging: Bool
    public var scale: Double
    public var currentActionId: ActionId?

    public init(
        currentState: PetState,
        mood: Double,
        hunger: Double,
        energy: Double,
        lastInteractionAt: Date,
        isDragging: Bool,
        scale: Double,
        currentActionId: ActionId? = nil
    ) {
        self.currentState = currentState
        self.mood = MoodModel.clamp01(mood)
        self.hunger = MoodModel.clamp01(hunger)
        self.energy = MoodModel.clamp01(energy)
        self.lastInteractionAt = lastInteractionAt
        self.isDragging = isDragging
        self.scale = scale
        self.currentActionId = currentActionId
    }

    public static func defaultState(at date: Date = Date()) -> PetRuntimeState {
        PetRuntimeState(
            currentState: .idle,
            mood: 0.8,
            hunger: 0.2,
            energy: 0.8,
            lastInteractionAt: date,
            isDragging: false,
            scale: 1.0
        )
    }
}
