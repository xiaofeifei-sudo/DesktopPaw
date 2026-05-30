public protocol LegacyAnimationsAdapting: Sendable {
    func actions(from animations: [PetState: ManifestAnimationClip]) -> [Action]
}

public struct LegacyAnimationsAdapter: LegacyAnimationsAdapting {
    public init() {}

    public func actions(from animations: [PetState: ManifestAnimationClip]) -> [Action] {
        animations.map { state, clip in
            let role = ActionRole(legacyState: state)
            let id = ActionId(rawValue: "\(state.rawValue)_default")!
            let nextActionId = clip.nextState.map { ActionId(rawValue: "\($0.rawValue)_default")! }
            return Action(
                id: id,
                displayName: state.rawValue.prefix(1).uppercased() + state.rawValue.dropFirst(),
                role: role,
                tags: [],
                frames: clip.frames,
                frameDurationMs: clip.frameDurationMs,
                loop: clip.loop,
                nextActionId: nextActionId
            )
        }
    }
}
