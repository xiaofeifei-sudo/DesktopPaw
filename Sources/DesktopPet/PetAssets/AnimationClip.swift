public struct AnimationClip: Codable, Equatable {
    public let state: PetState
    public let frames: [SpriteFrame]
    public let frameDurationMs: Int
    public let loop: Bool
    public let nextState: PetState?

    public init(
        state: PetState,
        frames: [SpriteFrame],
        frameDurationMs: Int,
        loop: Bool,
        nextState: PetState? = nil
    ) {
        self.state = state
        self.frames = frames
        self.frameDurationMs = frameDurationMs
        self.loop = loop
        self.nextState = nextState
    }
}
