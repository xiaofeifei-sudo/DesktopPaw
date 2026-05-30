import Foundation

public protocol PetdexGracefulSynthesizing: Sendable {
    func synthesizeRequiredRolesIfMissing(
        actions: [Action],
        rowZeroFrames: [SpriteFrame],
        frameDurationMs: Int
    ) -> (synthesized: [Action], warnings: [ActionImportWarning])
}

public struct DefaultPetdexGracefulSynthesizer: PetdexGracefulSynthesizing, Sendable {
    // Phase 1 fallback: hard-coded zh-CN labels until a localization helper is wired up.
    private static let idleDisplayName = "待机"
    private static let draggingDisplayName = "拖拽"

    public init() {}

    public func synthesizeRequiredRolesIfMissing(
        actions: [Action],
        rowZeroFrames: [SpriteFrame],
        frameDurationMs: Int
    ) -> (synthesized: [Action], warnings: [ActionImportWarning]) {
        guard !rowZeroFrames.isEmpty else {
            return (synthesized: actions, warnings: [])
        }

        let presentRoles = Set(actions.compactMap { $0.role })
        var synthesized = actions
        var warnings: [ActionImportWarning] = []

        if !presentRoles.contains(.idle) {
            let idleId = ActionId(rawValue: "idle_default")!
            let idleAction = Action(
                id: idleId,
                displayName: Self.idleDisplayName,
                role: .idle,
                tags: [],
                frames: rowZeroFrames,
                frameDurationMs: frameDurationMs,
                loop: true,
                nextActionId: nil
            )
            synthesized.append(idleAction)
            warnings.append(
                ActionImportWarning(
                    kind: .requiredRoleSynthesized,
                    detail: "角色 idle 已用 row 0 帧自动填充",
                    role: .idle,
                    actionId: idleId
                )
            )
        }

        if !presentRoles.contains(.dragging) {
            let draggingId = ActionId(rawValue: "dragging_default")!
            let draggingAction = Action(
                id: draggingId,
                displayName: Self.draggingDisplayName,
                role: .dragging,
                tags: [],
                frames: rowZeroFrames,
                frameDurationMs: frameDurationMs,
                loop: true,
                nextActionId: nil
            )
            synthesized.append(draggingAction)
            warnings.append(
                ActionImportWarning(
                    kind: .requiredRoleSynthesized,
                    detail: "角色 dragging 已用 row 0 帧自动填充",
                    role: .dragging,
                    actionId: draggingId
                )
            )
        }

        return (synthesized: synthesized, warnings: warnings)
    }
}
