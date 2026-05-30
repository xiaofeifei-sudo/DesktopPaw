import Foundation
import DesktopPet

func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        fail(message)
    }
}

func fail(_ message: String) -> Never {
    fputs("DesktopPetUnitTests failed: \(message)\n", stderr)
    Foundation.exit(1)
}

final class ExpectationHelper: @unchecked Sendable {
    private(set) var wasFulfilled = false

    func fulfill() {
        wasFulfilled = true
    }

    func reset() {
        wasFulfilled = false
    }
}

/// 共享给 PetEngine 相关测试使用的 RNG：固定返回某个值，clamp 到范围内。
final class FixedRandomNumberGenerator: RandomNumberGenerating {
    let value: Double

    init(value: Double) {
        self.value = value
    }

    func nextDouble(in range: ClosedRange<Double>) -> Double {
        min(max(value, range.lowerBound), range.upperBound)
    }
}

/// 按固定序列回放的 RNG（每次调用前进一个值；越界后停留在最后一个）。
final class SequenceRandomNumberGenerator: RandomNumberGenerating {
    private let values: [Double]
    private var index = 0

    init(values: [Double]) {
        precondition(!values.isEmpty, "Sequence RNG requires at least one value")
        self.values = values
    }

    func nextDouble(in range: ClosedRange<Double>) -> Double {
        let raw = values[min(index, values.count - 1)]
        index = min(index + 1, values.count - 1)
        return min(max(raw, range.lowerBound), range.upperBound)
    }
}

func makeAction(
    id rawId: String,
    role: ActionRole?,
    displayName: String? = nil,
    tags: [ActionTag] = [],
    assetId: String? = nil,
    frames: [SpriteFrame] = [SpriteFrame(column: 0, row: 0)],
    frameDurationMs: Int = 160,
    loop: Bool? = nil,
    nextActionId: ActionId? = nil
) -> Action {
    let resolvedLoop = loop ?? defaultLoop(for: role)
    return Action(
        id: ActionId(rawValue: rawId)!,
        displayName: displayName ?? rawId,
        role: role,
        tags: tags,
        assetId: assetId,
        frames: frames,
        frameDurationMs: frameDurationMs,
        loop: resolvedLoop,
        nextActionId: nextActionId
    )
}

private func defaultLoop(for role: ActionRole?) -> Bool {
    guard let role else {
        return false
    }
    switch role {
    case .idle, .walking, .sleeping, .dragging:
        return true
    case .happy, .eating, .jumping:
        return false
    }
}

/// 构造一个含 7 角色 default action 的标准 catalog，便于 PetEngine 单元测试使用。
func makeStandardCatalog(petId: String = "test-pet", extras: [Action] = []) -> PetActionCatalog {
    let actions: [Action] = [
        makeAction(id: "idle_default", role: .idle),
        makeAction(id: "walk_default", role: .walking),
        makeAction(id: "sleep_default", role: .sleeping),
        makeAction(
            id: "happy_default",
            role: .happy,
            frameDurationMs: 120,
            loop: false,
            nextActionId: ActionId(rawValue: "idle_default")
        ),
        makeAction(
            id: "eat_default",
            role: .eating,
            frameDurationMs: 120,
            loop: false,
            nextActionId: ActionId(rawValue: "idle_default")
        ),
        makeAction(
            id: "jump_default",
            role: .jumping,
            frameDurationMs: 110,
            loop: false,
            nextActionId: ActionId(rawValue: "idle_default")
        ),
        makeAction(id: "drag_default", role: .dragging)
    ] + extras
    return PetActionCatalog(petId: petId, actions: actions, warnings: [])
}
