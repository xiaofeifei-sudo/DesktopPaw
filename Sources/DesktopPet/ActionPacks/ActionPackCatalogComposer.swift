import Foundation

public protocol ActionPackCatalogComposing: Sendable {
    func compose(
        baseDefinition: PetDefinition,
        packs: [ValidatedActionPack],
        overrides: ActionPackOverrideSet?
    ) throws -> PetDefinition
}

public struct DefaultActionPackCatalogComposer: ActionPackCatalogComposing {
    private let catalogBuilder: PetActionCatalogBuilding

    public init(catalogBuilder: PetActionCatalogBuilding = DefaultPetActionCatalogBuilder()) {
        self.catalogBuilder = catalogBuilder
    }

    public func compose(
        baseDefinition: PetDefinition,
        packs: [ValidatedActionPack],
        overrides: ActionPackOverrideSet?
    ) throws -> PetDefinition {
        let baseAssetId = "base/default"
        var assetsById: [String: PetRenderAsset] = [:]

        assetsById[baseAssetId] = buildBaseAsset(baseDefinition: baseDefinition)

        var mergedActions = baseDefinition.catalog.actions
        var allWarnings: [ActionPackWarning] = []
        var existingActionIds = Set(mergedActions.map { $0.id })
        var seenResourceGlobalIds = Set<String>()

        for pack in packs {
            if overrides?.isPackDisabled(pack.manifest.id) == true {
                continue
            }

            for resource in pack.manifest.resources {
                let globalId = "\(pack.manifest.id)/\(resource.id)"
                guard seenResourceGlobalIds.insert(globalId).inserted else {
                    throw ActionPackError.duplicateResourceId(
                        packId: pack.manifest.id, resourceId: resource.id
                    )
                }
                assetsById[globalId] = buildPackAsset(
                    resource: resource,
                    packId: pack.manifest.id,
                    packURL: pack.packURL
                )
            }

            for var action in pack.manifest.actions {
                let actionOverride = overrides?.override(for: action.id)
                if actionOverride?.disabled == true {
                    continue
                }

                if existingActionIds.contains(action.id) {
                    allWarnings.append(ActionPackWarning(
                        kind: .actionIdConflict,
                        packId: pack.manifest.id,
                        actionId: action.id.rawValue,
                        detail: "Action id conflicts with existing action"
                    ))
                    continue
                }

                action = rewriteAssetIds(
                    action: action,
                    packId: pack.manifest.id
                )

                action = applyActionOverride(actionOverride, to: action)

                mergedActions.append(action)
                existingActionIds.insert(action.id)
            }

            allWarnings.append(contentsOf: pack.warnings)
        }

        mergedActions = applySortOrder(mergedActions, overrides: overrides)

        let input = PetActionCatalogBuildInput(
            petId: baseDefinition.id,
            schemaVersion: 2,
            legacyAnimations: nil,
            actions: mergedActions,
            spritesheet: nil
        )

        let petOverrides = buildPetOverrides(overrides: overrides, mergedActions: mergedActions)
        let catalog = try catalogBuilder.build(input: input, overrides: petOverrides)

        let renderLibrary = PetRenderAssetLibrary(
            defaultAssetId: baseAssetId,
            assetsById: assetsById
        )

        return PetDefinition(
            id: baseDefinition.id,
            displayName: baseDefinition.displayName,
            description: baseDefinition.description,
            assetName: baseDefinition.assetName,
            previewAssetName: baseDefinition.previewAssetName,
            frameSize: baseDefinition.frameSize,
            spritesheet: baseDefinition.spritesheet,
            defaultScale: baseDefinition.defaultScale,
            catalog: catalog,
            assetKind: baseDefinition.assetKind,
            motionProfile: baseDefinition.motionProfile,
            bubbleProfile: baseDefinition.bubbleProfile,
            renderAssetLibrary: renderLibrary
        )
    }

    // MARK: - Helpers

    private func buildBaseAsset(baseDefinition: PetDefinition) -> PetRenderAsset {
        switch baseDefinition.assetKind {
        case .spriteSheet:
            return PetRenderAsset(
                id: "base/default",
                kind: .gridImage,
                relativePath: baseDefinition.assetName,
                frameSize: baseDefinition.frameSize,
                grid: baseDefinition.spritesheet,
                previewRelativePath: baseDefinition.previewAssetName
            )
        case .singleImage:
            return PetRenderAsset(
                id: "base/default",
                kind: .wholeImage,
                relativePath: baseDefinition.assetName,
                frameSize: baseDefinition.frameSize,
                previewRelativePath: baseDefinition.previewAssetName
            )
        }
    }

    private func buildPackAsset(
        resource: ActionPackResource,
        packId: String,
        packURL: URL
    ) -> PetRenderAsset {
        PetRenderAsset(
            id: "\(packId)/\(resource.id)",
            kind: .gridImage,
            relativePath: "action-packs/\(packId)/\(resource.path)",
            frameSize: resource.frameSize,
            grid: resource.grid,
            previewRelativePath: nil
        )
    }

    private func rewriteAssetIds(action: Action, packId: String) -> Action {
        let rewrittenFrames = action.frames.map { frame -> SpriteFrame in
            let newAssetId: String?
            if let frameAssetId = frame.assetId {
                newAssetId = "\(packId)/\(frameAssetId)"
            } else {
                newAssetId = frame.assetId
            }
            return SpriteFrame(
                assetId: newAssetId,
                column: frame.column,
                row: frame.row,
                durationMs: frame.durationMs
            )
        }

        let actionAssetId = action.assetId.map { "\(packId)/\($0)" }

        return Action(
            id: action.id,
            displayName: action.displayName,
            role: action.role,
            tags: action.tags,
            assetId: actionAssetId,
            frames: rewrittenFrames,
            frameDurationMs: action.frameDurationMs,
            loop: action.loop,
            nextActionId: action.nextActionId
        )
    }

    private func applyActionOverride(
        _ override: ActionPackActionOverride?,
        to action: Action
    ) -> Action {
        guard let override else {
            return action
        }

        return Action(
            id: action.id,
            displayName: override.displayName ?? action.displayName,
            role: action.role,
            tags: override.tags ?? action.tags,
            assetId: action.assetId,
            frames: frames(action.frames, applyingDurations: override.frameDurationsMs),
            frameDurationMs: action.frameDurationMs,
            loop: action.loop,
            nextActionId: action.nextActionId
        )
    }

    private func frames(
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

    private func applySortOrder(_ actions: [Action], overrides: ActionPackOverrideSet?) -> [Action] {
        guard let overrides else { return actions }

        return actions.sorted { a, b in
            let aSort = overrides.sortOrderOverride(for: a.id)
            let bSort = overrides.sortOrderOverride(for: b.id)

            switch (aSort, bSort) {
            case let (lhs?, rhs?):
                return lhs < rhs
            case (_?, nil):
                return true
            case (nil, _?):
                return false
            case (nil, nil):
                return true
            }
        }
    }

    private func buildPetOverrides(
        overrides: ActionPackOverrideSet?,
        mergedActions: [Action]
    ) -> PetActionOverrideSet? {
        guard let overrides else { return nil }

        var petOverrides: [PetActionOverride] = []
        for actionOverride in overrides.actionOverrides {
            if actionOverride.displayName != nil {
                petOverrides.append(PetActionOverride(
                    actionId: actionOverride.actionId,
                    displayName: actionOverride.displayName
                ))
            }
        }

        guard !petOverrides.isEmpty else { return nil }
        return PetActionOverrideSet(
            petId: overrides.petId,
            overrides: petOverrides
        )
    }
}
