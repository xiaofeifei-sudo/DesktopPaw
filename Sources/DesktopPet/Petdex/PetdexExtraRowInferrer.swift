import Foundation

public protocol PetdexExtraRowInferring: Sendable {
    func inferExtras(rows: Int, columns: Int, skipRows: Set<Int>) -> [Action]
}

public struct DefaultPetdexExtraRowInferrer: PetdexExtraRowInferring, Sendable {
    public static let defaultColumns = 8
    public static let defaultRows = 9
    public static let extraFrameDurationMs = 120

    // Phase 1 fallback: when no localization helper is wired up yet, fall back
    // to hard-coded zh-CN labels so existing 8x9 packs immediately gain extras.
    private static let extraDisplayNames: [String] = [
        "自定义动作 1",
        "自定义动作 2"
    ]

    private static let requiredSkipRows: Set<Int> = [0, 1, 2, 3, 4, 5, 6]

    public init() {}

    public func inferExtras(
        rows: Int,
        columns: Int,
        skipRows: Set<Int>
    ) -> [Action] {
        guard columns > 0 else {
            return []
        }
        guard rows == Self.defaultRows, columns == Self.defaultColumns else {
            return []
        }
        guard skipRows.isSuperset(of: Self.requiredSkipRows) else {
            return []
        }

        let extraRows = [7, 8]
        var extras: [Action] = []
        extras.reserveCapacity(extraRows.count)

        for (index, rowIndex) in extraRows.enumerated() {
            let displayName = Self.extraDisplayNames[index]
            let rawId = "extra_\(index + 1)"
            guard let actionId = ActionId(rawValue: rawId) else {
                continue
            }

            let frames = (0..<columns).map { column in
                SpriteFrame(column: column, row: rowIndex)
            }

            extras.append(
                Action(
                    id: actionId,
                    displayName: displayName,
                    role: nil,
                    tags: [],
                    frames: frames,
                    frameDurationMs: Self.extraFrameDurationMs,
                    loop: false,
                    nextActionId: ActionId.idle
                )
            )
        }

        return extras
    }
}
