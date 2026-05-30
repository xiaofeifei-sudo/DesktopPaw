import Foundation

public protocol PetdexAnimationMappingProviding {
    func convention(
        for manifest: PetdexManifest,
        imageSize: CGSizeCodable
    ) throws -> PetdexSpriteSheetConvention

    func actions(
        for convention: PetdexSpriteSheetConvention
    ) throws -> PetdexMappingResult
}

public struct PetdexMappingResult: Equatable, Sendable {
    public let actions: [Action]
    public let warnings: [ActionImportWarning]

    public init(actions: [Action], warnings: [ActionImportWarning]) {
        self.actions = actions
        self.warnings = warnings
    }
}

public final class DefaultPetdexAnimationMappingProvider: PetdexAnimationMappingProviding {
    public static let defaultColumns = 8
    public static let defaultRows = 9
    public static let loopingFrameDurationMs = 160
    public static let oneShotFrameDurationMs = 120

    private let columns: Int
    private let rows: Int
    private let extraRowInferrer: PetdexExtraRowInferring
    private let gracefulSynthesizer: PetdexGracefulSynthesizing

    public init(
        columns: Int = DefaultPetdexAnimationMappingProvider.defaultColumns,
        rows: Int = DefaultPetdexAnimationMappingProvider.defaultRows,
        extraRowInferrer: PetdexExtraRowInferring = DefaultPetdexExtraRowInferrer(),
        gracefulSynthesizer: PetdexGracefulSynthesizing = DefaultPetdexGracefulSynthesizer()
    ) {
        self.columns = columns
        self.rows = rows
        self.extraRowInferrer = extraRowInferrer
        self.gracefulSynthesizer = gracefulSynthesizer
    }

    public func convention(
        for manifest: PetdexManifest,
        imageSize: CGSizeCodable
    ) throws -> PetdexSpriteSheetConvention {
        _ = manifest

        guard columns > 0, rows > 0 else {
            throw PetdexImportError.invalidSpritesheetLayout("grid columns and rows must be greater than zero")
        }

        let width = imageSize.width
        let height = imageSize.height
        guard width > 0, height > 0 else {
            throw PetdexImportError.invalidSpritesheetLayout("image size must be greater than zero")
        }

        guard width.rounded(.towardZero) == width,
              height.rounded(.towardZero) == height else {
            throw PetdexImportError.invalidSpritesheetLayout("image size must use whole pixels")
        }

        let pixelWidth = Int(width)
        let pixelHeight = Int(height)
        guard pixelWidth % columns == 0,
              pixelHeight % rows == 0 else {
            throw PetdexImportError.invalidSpritesheetLayout(
                "image dimensions \(pixelWidth)x\(pixelHeight) are not divisible by \(columns)x\(rows)"
            )
        }

        return PetdexSpriteSheetConvention(
            columns: columns,
            rows: rows,
            frameSize: CGSizeCodable(
                width: Double(pixelWidth / columns),
                height: Double(pixelHeight / rows)
            ),
            stateRows: defaultStateRows,
            framesPerState: defaultFramesPerState,
            frameDurationsMs: defaultFrameDurationsMs,
            previewFrame: SpriteFrame(column: 0, row: defaultStateRows[.idle] ?? 0)
        )
    }

    public func actions(
        for convention: PetdexSpriteSheetConvention
    ) throws -> PetdexMappingResult {
        try validateGrid(convention)

        guard convention.rows > 0 else {
            return PetdexMappingResult(actions: [], warnings: [])
        }

        let actions = (0..<convention.rows).map { row in
            makeGenericRowAction(row: row, columns: convention.columns)
        }
        return PetdexMappingResult(actions: actions, warnings: [])
    }

    private static let contractRoleCount = 7

    private static let defaultRoleRows: [(role: ActionRole, row: Int)] = [
        (.idle, 0),
        (.walking, 1),
        (.sleeping, 2),
        (.happy, 3),
        (.eating, 4),
        (.jumping, 5),
        (.dragging, 6)
    ]

    private static let roleDisplayNames: [ActionRole: String] = [
        .idle: "Idle",
        .walking: "Walking",
        .sleeping: "Sleeping",
        .happy: "Happy",
        .eating: "Eating",
        .jumping: "Jumping",
        .dragging: "Dragging"
    ]

    private var defaultStateRows: [PetState: Int] {
        [
            .idle: 0,
            .walking: 1,
            .sleeping: 2,
            .happy: 3,
            .eating: 4,
            .jumping: 5,
            .dragging: 6
        ]
    }

    private var defaultFramesPerState: [PetState: Int] {
        Dictionary(uniqueKeysWithValues: PetState.allCases.map { state in
            (state, columns)
        })
    }

    private var defaultFrameDurationsMs: [PetState: Int] {
        Dictionary(uniqueKeysWithValues: PetState.allCases.map { state in
            let duration = loopingStates.contains(state)
                ? Self.loopingFrameDurationMs
                : Self.oneShotFrameDurationMs
            return (state, duration)
        })
    }

    private var loopingStates: Set<PetState> {
        [.idle, .walking, .sleeping, .dragging]
    }

    private func makeAction(for role: ActionRole, row: Int, columns: Int) -> Action {
        let loop = Self.loopingRoles.contains(role)
        return Action(
            id: ActionId(rawValue: "\(role.rawValue)_default")!,
            displayName: Self.roleDisplayNames[role] ?? role.rawValue,
            role: role,
            tags: [],
            frames: makeFrames(row: row, columns: columns),
            frameDurationMs: loop ? Self.loopingFrameDurationMs : Self.oneShotFrameDurationMs,
            loop: loop,
            nextActionId: loop ? nil : ActionId.idle
        )
    }

    private func makeGenericRowAction(row: Int, columns: Int) -> Action {
        let isDefault = row == 0
        return Action(
            id: ActionId(rawValue: "action_\(row + 1)")!,
            displayName: "Action \(row + 1)",
            role: nil,
            tags: [],
            frames: makeFrames(row: row, columns: columns),
            frameDurationMs: isDefault ? Self.loopingFrameDurationMs : Self.oneShotFrameDurationMs,
            loop: isDefault,
            nextActionId: nil
        )
    }

    private func makeFrames(row: Int, columns: Int) -> [SpriteFrame] {
        (0..<columns).map { column in
            SpriteFrame(column: column, row: row)
        }
    }

    private func roleFallbackWarnings(forMissingFrom actions: [Action]) -> [ActionImportWarning] {
        let presentRoles = Set(actions.compactMap(\.role))
        return ActionRole.recommended
            .filter { !presentRoles.contains($0) }
            .sorted { Self.row(for: $0) < Self.row(for: $1) }
            .map { role in
                let fallback = ActionFallbackChain.chain[role]?.first?.rawValue ?? "idle"
                return ActionImportWarning(
                    kind: .roleFallbackUsed,
                    detail: "Petdex role \(role.rawValue) is missing; runtime fallback will use \(fallback)",
                    role: role,
                    actionId: ActionId(rawValue: "\(role.rawValue)_default")
                )
            }
    }

    private static var loopingRoles: Set<ActionRole> {
        [.idle, .walking, .sleeping, .dragging]
    }

    private static func row(for role: ActionRole) -> Int {
        defaultRoleRows.first { $0.role == role }?.row ?? 0
    }

    private func validateGrid(_ convention: PetdexSpriteSheetConvention) throws {
        guard convention.columns > 0, convention.rows >= 0 else {
            throw PetdexImportError.invalidSpritesheetLayout("grid columns must be greater than zero and rows must not be negative")
        }

        guard convention.frameSize.width > 0,
              convention.frameSize.height > 0 else {
            throw PetdexImportError.invalidSpritesheetLayout("frame size must be greater than zero")
        }
    }

    private func validate(_ convention: PetdexSpriteSheetConvention) throws {
        try validateGrid(convention)
        for mapping in Self.defaultRoleRows where mapping.row < min(convention.rows, Self.contractRoleCount) {
            let state = mapping.role.legacyState
            guard let row = convention.stateRows[state], row == mapping.row else {
                throw PetdexImportError.invalidSpritesheetLayout("missing animation mapping for \(state.rawValue)")
            }
            guard let frameCount = convention.framesPerState[state], frameCount == convention.columns else {
                throw PetdexImportError.invalidSpritesheetLayout("frame count for \(state.rawValue) must match grid columns")
            }
            guard let frameDurationMs = convention.frameDurationsMs[state], frameDurationMs > 0 else {
                throw PetdexImportError.invalidSpritesheetLayout("frame duration for \(state.rawValue) must be greater than zero")
            }
        }
    }
}

public extension PetdexAnimationMappingProviding {
    func animationClips(
        for convention: PetdexSpriteSheetConvention
    ) throws -> [PetState: ManifestAnimationClip] {
        guard convention.columns > 0, convention.rows >= 0 else {
            throw PetdexImportError.invalidSpritesheetLayout("grid columns must be greater than zero and rows must not be negative")
        }
        guard convention.frameSize.width > 0,
              convention.frameSize.height > 0 else {
            throw PetdexImportError.invalidSpritesheetLayout("frame size must be greater than zero")
        }
        var clips: [PetState: ManifestAnimationClip] = [:]

        for state in PetState.allCases {
            guard let row = convention.stateRows[state],
                  let frameCount = convention.framesPerState[state],
                  let frameDurationMs = convention.frameDurationsMs[state],
                  row >= 0,
                  row < convention.rows,
                  frameCount > 0,
                  frameCount <= convention.columns,
                  frameDurationMs > 0 else {
                throw PetdexImportError.invalidSpritesheetLayout("missing or invalid animation mapping for \(state.rawValue)")
            }

            let loop = state == .idle || state == .walking || state == .sleeping || state == .dragging
            clips[state] = ManifestAnimationClip(
                frames: (0..<frameCount).map { SpriteFrame(column: $0, row: row) },
                frameDurationMs: frameDurationMs,
                loop: loop,
                nextState: loop ? nil : .idle
            )
        }

        return clips
    }
}
