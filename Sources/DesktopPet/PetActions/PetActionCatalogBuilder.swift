public protocol PetActionCatalogBuilding: Sendable {
    func build(input: PetActionCatalogBuildInput, overrides: PetActionOverrideSet?) throws -> PetActionCatalog
}

public struct DefaultPetActionCatalogBuilder: PetActionCatalogBuilding {
    private let legacyAdapter: LegacyAnimationsAdapting

    public init(legacyAdapter: LegacyAnimationsAdapting = LegacyAnimationsAdapter()) {
        self.legacyAdapter = legacyAdapter
    }

    public func build(
        input: PetActionCatalogBuildInput,
        overrides: PetActionOverrideSet?
    ) throws -> PetActionCatalog {
        switch input.schemaVersion {
        case 1, 2:
            break
        default:
            throw ActionCatalogError.unsupportedSchemaVersion(input.schemaVersion)
        }

        var actions: [Action]
        if input.schemaVersion == 1 {
            actions = legacyAdapter.actions(from: input.legacyAnimations ?? [:])
        } else {
            actions = input.actions
        }

        var seenIds: Set<ActionId> = []
        for action in actions {
            if seenIds.contains(action.id) {
                throw ActionCatalogError.duplicateActionId(action.id)
            }
            seenIds.insert(action.id)
        }

        if let overrides {
            actions = actions.map { action in
                guard let override = overrides.override(for: action.id) else {
                    return action
                }
                let frames = Self.frames(
                    action.frames,
                    applyingDurations: override.frameDurationsMs
                )
                return Action(
                    id: action.id,
                    displayName: override.displayName ?? action.displayName,
                    role: override.role ?? action.role,
                    tags: override.tags ?? action.tags,
                    assetId: action.assetId,
                    frames: frames,
                    frameDurationMs: action.frameDurationMs,
                    loop: action.loop,
                    nextActionId: action.nextActionId
                )
            }
        }

        for action in actions {
            if action.tags.count > maxTagsPerAction {
                throw ActionCatalogError.tooManyTagsOnAction(
                    actionId: action.id,
                    count: action.tags.count,
                    limit: maxTagsPerAction
                )
            }
        }

        let totalTags = actions.reduce(0) { $0 + $1.tags.count }
        if totalTags > maxTagsPerPackage {
            throw ActionCatalogError.tooManyTagsInPackage(count: totalTags, limit: maxTagsPerPackage)
        }

        if let spritesheet = input.spritesheet {
            for action in actions {
                for frame in action.frames {
                    if frame.column < 0 || frame.column >= spritesheet.columns ||
                        frame.row < 0 || frame.row >= spritesheet.rows {
                        throw ActionCatalogError.frameOutOfBounds(actionId: action.id, frame: frame)
                    }
                }
            }
        }

        var warnings: [ActionImportWarning] = []
        let knownIds = Set(actions.map { $0.id })
        actions = actions.map { action in
            guard let next = action.nextActionId else { return action }
            if knownIds.contains(next) { return action }
            warnings.append(ActionImportWarning(
                kind: .roleFallbackUsed,
                detail: "nextActionId \(next.rawValue) not found; removed from action \(action.id.rawValue)",
                role: action.role,
                actionId: action.id
            ))
            return Action(
                id: action.id,
                displayName: action.displayName,
                role: action.role,
                tags: action.tags,
                frames: action.frames,
                frameDurationMs: action.frameDurationMs,
                loop: action.loop,
                nextActionId: nil
            )
        }

        return PetActionCatalog(petId: input.petId, actions: actions, warnings: warnings)
    }

    private static func frames(
        _ frames: [SpriteFrame],
        applyingDurations durations: [Int]?
    ) -> [SpriteFrame] {
        guard let durations, durations.count == frames.count else {
            return frames
        }

        return frames.enumerated().map { index, frame in
            SpriteFrame(
                assetId: frame.assetId,
                column: frame.column,
                row: frame.row,
                durationMs: durations[index]
            )
        }
    }
}

private let maxTagsPerAction = 16
private let maxTagsPerPackage = 32
