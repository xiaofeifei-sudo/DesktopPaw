import Foundation
import DesktopPet

func runActionPackCatalogComposerTests() {
    let tests = ActionPackCatalogComposerTests()
    tests.composeWithNoPacksReturnsEquivalentDefinition()
    tests.composeWithPackAddsExtraActions()
    tests.composeSkipsConflictingActionWithWarning()
    tests.composeAppliesDisabledPackOverride()
    tests.composeAppliesDisabledActionOverride()
    tests.composeAppliesDisplayNameOverride()
    tests.composeAppliesFrameDurationOverride()
    tests.composeAppliesSortOrderOverride()
    tests.composeRewritesAssetIds()
    tests.composeGeneratesRenderAssetLibrary()
    tests.composeRegistersBaseDefaultResource()
    tests.composeRegistersPackResources()
}

private let testFrameSize = CGSizeCodable(width: 256, height: 256)

private struct ActionPackCatalogComposerTests {

    func composeWithNoPacksReturnsEquivalentDefinition() {
        let baseDef = makeBaseDefinition()
        let composer = DefaultActionPackCatalogComposer()

        do {
            let result = try composer.compose(
                baseDefinition: baseDef,
                packs: [],
                overrides: nil
            )
            expect(result.catalog.actions.count == baseDef.catalog.actions.count,
                   "no packs: action count should match base")
            expect(result.renderAssetLibrary != nil, "renderAssetLibrary should be set")
        } catch {
            fail("compose with no packs should succeed; got \(error)")
        }
    }

    func composeWithPackAddsExtraActions() {
        let baseDef = makeBaseDefinition()
        let pack = makeValidatedPack(
            id: "wave_pack",
            actionId: "wave_pack_wave",
            displayName: "Wave"
        )
        let composer = DefaultActionPackCatalogComposer()

        do {
            let result = try composer.compose(
                baseDefinition: baseDef,
                packs: [pack],
                overrides: nil
            )
            let baseCount = baseDef.catalog.actions.count
            expect(result.catalog.actions.count == baseCount + 1,
                   "should have 1 extra action, got \(result.catalog.actions.count - baseCount)")
            expect(result.catalog.resolve(actionId: ActionId(rawValue: "wave_pack_wave")!) != nil,
                   "pack action should be in catalog")
        } catch {
            fail("compose with pack should succeed; got \(error)")
        }
    }

    func composeSkipsConflictingActionWithWarning() {
        let baseDef = makeBaseDefinition()
        // Use an action id that conflicts with base
        let pack = makeValidatedPack(
            id: "conflict_pack",
            actionId: "idle_default", // conflicts with base
            displayName: "Conflict"
        )
        let composer = DefaultActionPackCatalogComposer()

        do {
            let result = try composer.compose(
                baseDefinition: baseDef,
                packs: [pack],
                overrides: nil
            )
            expect(result.catalog.actions.count == baseDef.catalog.actions.count,
                   "conflicting action should be skipped")
        } catch {
            fail("conflict should not throw; got \(error)")
        }
    }

    func composeAppliesDisabledPackOverride() {
        let baseDef = makeBaseDefinition()
        let pack = makeValidatedPack(
            id: "disabled_pack",
            actionId: "disabled_pack_wave",
            displayName: "Wave"
        )
        let overrides = ActionPackOverrideSet(petId: "test-pet")
            .disablingPack("disabled_pack")
        let composer = DefaultActionPackCatalogComposer()

        do {
            let result = try composer.compose(
                baseDefinition: baseDef,
                packs: [pack],
                overrides: overrides
            )
            expect(result.catalog.actions.count == baseDef.catalog.actions.count,
                   "disabled pack actions should not be in catalog")
        } catch {
            fail("disabled pack should not throw; got \(error)")
        }
    }

    func composeAppliesDisabledActionOverride() {
        let baseDef = makeBaseDefinition()
        let pack = makeValidatedPack(
            id: "test_pack",
            actionId: "test_pack_wave",
            displayName: "Wave"
        )
        let overrides = ActionPackOverrideSet(petId: "test-pet")
            .disablingAction(ActionId(rawValue: "test_pack_wave")!)
        let composer = DefaultActionPackCatalogComposer()

        do {
            let result = try composer.compose(
                baseDefinition: baseDef,
                packs: [pack],
                overrides: overrides
            )
            expect(result.catalog.resolve(actionId: ActionId(rawValue: "test_pack_wave")!) == nil,
                   "disabled action should not be in catalog")
        } catch {
            fail("disabled action should not throw; got \(error)")
        }
    }

    func composeAppliesDisplayNameOverride() {
        let baseDef = makeBaseDefinition()
        let pack = makeValidatedPack(
            id: "name_pack",
            actionId: "name_pack_wave",
            displayName: "Wave"
        )
        let overrides = ActionPackOverrideSet(petId: "test-pet")
            .settingDisplayName("Custom Wave", for: ActionId(rawValue: "name_pack_wave")!)
        let composer = DefaultActionPackCatalogComposer()

        do {
            let result = try composer.compose(
                baseDefinition: baseDef,
                packs: [pack],
                overrides: overrides
            )
            let action = result.catalog.resolve(actionId: ActionId(rawValue: "name_pack_wave")!)
            expect(action?.displayName == "Custom Wave", "displayName override should be applied")
            expect(action?.assetId == "name_pack/wave_sheet", "assetId should be preserved with displayName override")
        } catch {
            fail("displayName override should work; got \(error)")
        }
    }

    func composeAppliesFrameDurationOverride() {
        let baseDef = makeBaseDefinition()
        let actionId = ActionId(rawValue: "duration_pack_wave")!
        let pack = makeValidatedPack(
            id: "duration_pack",
            actionId: actionId.rawValue,
            displayName: "Wave"
        )
        let overrides = ActionPackOverrideSet(petId: "test-pet")
            .settingFrameDurations([80, 120, 240, 320], for: actionId)
        let composer = DefaultActionPackCatalogComposer()

        do {
            let result = try composer.compose(
                baseDefinition: baseDef,
                packs: [pack],
                overrides: overrides
            )
            let action = result.catalog.resolve(actionId: actionId)
            expect(
                action?.frames.map(\.durationMs) == [80, 120, 240, 320],
                "frame duration overrides should be applied to action pack frames"
            )
        } catch {
            fail("frame duration override should work; got \(error)")
        }
    }

    func composeAppliesSortOrderOverride() {
        let baseDef = makeBaseDefinition()
        let pack1 = makeValidatedPack(id: "pack_a", actionId: "pack_a_wave", displayName: "A Wave")
        let pack2 = makeValidatedPack(id: "pack_b", actionId: "pack_b_wave", displayName: "B Wave")
        let overrides = ActionPackOverrideSet(petId: "test-pet")
            .settingSortOrder(1, for: ActionId(rawValue: "pack_b_wave")!)
            .settingSortOrder(2, for: ActionId(rawValue: "pack_a_wave")!)
        let composer = DefaultActionPackCatalogComposer()

        do {
            let result = try composer.compose(
                baseDefinition: baseDef,
                packs: [pack1, pack2],
                overrides: overrides
            )
            let extras = result.catalog.extras
            let bIndex = extras.firstIndex(where: { $0.id.rawValue == "pack_b_wave" })
            let aIndex = extras.firstIndex(where: { $0.id.rawValue == "pack_a_wave" })
            if let bIdx = bIndex, let aIdx = aIndex {
                expect(bIdx < aIdx, "pack_b should come before pack_a due to sortOrder")
            }
        } catch {
            fail("sort order should work; got \(error)")
        }
    }

    func composeRewritesAssetIds() {
        let baseDef = makeBaseDefinition()
        let pack = makeValidatedPack(
            id: "rewrite_pack",
            actionId: "rewrite_pack_wave",
            displayName: "Wave"
        )
        let composer = DefaultActionPackCatalogComposer()

        do {
            let result = try composer.compose(
                baseDefinition: baseDef,
                packs: [pack],
                overrides: nil
            )
            let action = result.catalog.resolve(actionId: ActionId(rawValue: "rewrite_pack_wave")!)
            expect(action?.assetId == "rewrite_pack/wave_sheet",
                   "action assetId should be rewritten to global id")
        } catch {
            fail("assetId rewrite should work; got \(error)")
        }
    }

    func composeGeneratesRenderAssetLibrary() {
        let baseDef = makeBaseDefinition()
        let pack = makeValidatedPack(
            id: "lib_pack",
            actionId: "lib_pack_wave",
            displayName: "Wave"
        )
        let composer = DefaultActionPackCatalogComposer()

        do {
            let result = try composer.compose(
                baseDefinition: baseDef,
                packs: [pack],
                overrides: nil
            )
            let library = result.renderAssetLibrary
            expect(library != nil, "renderAssetLibrary should be set")
            expect(library?.defaultAssetId == "base/default", "default asset should be base/default")
            expect(library?.assetsById["lib_pack/wave_sheet"] != nil, "pack resource should be in library")
        } catch {
            fail("render asset library should be generated; got \(error)")
        }
    }

    func composeRegistersBaseDefaultResource() {
        let baseDef = makeBaseDefinition()
        let composer = DefaultActionPackCatalogComposer()

        do {
            let result = try composer.compose(
                baseDefinition: baseDef,
                packs: [],
                overrides: nil
            )
            let library = result.renderAssetLibrary
            let baseAsset = library?.assetsById["base/default"]
            expect(baseAsset != nil, "base/default should exist")
            expect(baseAsset?.kind == .gridImage, "spriteSheet base should be gridImage")
            expect(baseAsset?.grid?.columns == 4, "grid columns should match")
        } catch {
            fail("base resource registration should work; got \(error)")
        }
    }

    func composeRegistersPackResources() {
        let baseDef = makeBaseDefinition()
        let pack = makeValidatedPack(
            id: "reg_pack",
            actionId: "reg_pack_wave",
            displayName: "Wave"
        )
        let composer = DefaultActionPackCatalogComposer()

        do {
            let result = try composer.compose(
                baseDefinition: baseDef,
                packs: [pack],
                overrides: nil
            )
            let library = result.renderAssetLibrary
            let packAsset = library?.assetsById["reg_pack/wave_sheet"]
            expect(packAsset != nil, "pack resource should be registered")
            expect(packAsset?.kind == .gridImage, "pack resource should be gridImage")
            expect(packAsset?.relativePath.contains("action-packs/reg_pack/spritesheet.png") == true,
                   "relative path should include action-packs prefix")
        } catch {
            fail("pack resource registration should work; got \(error)")
        }
    }
}

// MARK: - Test Helpers

private func makeBaseDefinition() -> PetDefinition {
    let actions = [
        makeAction(id: "idle_default", role: .idle),
        makeAction(id: "walk_default", role: .walking),
        makeAction(id: "sleep_default", role: .sleeping),
        makeAction(
            id: "happy_default", role: .happy,
            frameDurationMs: 120, loop: false,
            nextActionId: ActionId(rawValue: "idle_default")
        ),
        makeAction(
            id: "eat_default", role: .eating,
            frameDurationMs: 120, loop: false,
            nextActionId: ActionId(rawValue: "idle_default")
        ),
        makeAction(
            id: "jump_default", role: .jumping,
            frameDurationMs: 110, loop: false,
            nextActionId: ActionId(rawValue: "idle_default")
        ),
        makeAction(id: "drag_default", role: .dragging)
    ]
    let catalog = PetActionCatalog(petId: "test-pet", actions: actions, warnings: [])
    return PetDefinition(
        id: "test-pet",
        displayName: "Test Pet",
        description: "A test pet",
        assetName: "spritesheet.png",
        previewAssetName: "preview.png",
        frameSize: testFrameSize,
        spritesheet: SpriteSheetLayout(columns: 4, rows: 7),
        defaultScale: 1.0,
        catalog: catalog,
        assetKind: .spriteSheet
    )
}

private func makeValidatedPack(
    id: String,
    actionId: String,
    displayName: String
) -> ValidatedActionPack {
    let manifest = ActionPackManifest(
        schemaVersion: 1,
        id: id,
        displayName: displayName,
        createdAt: Date(timeIntervalSince1970: 1_717_000_000),
        resources: [
            ActionPackResource(
                id: "wave_sheet",
                kind: .gridImage,
                path: "spritesheet.png",
                frameSize: testFrameSize,
                grid: SpriteSheetLayout(columns: 4, rows: 1)
            )
        ],
        actions: [
            Action(
                id: ActionId(rawValue: actionId)!,
                displayName: displayName,
                role: nil,
                assetId: "wave_sheet",
                frames: [
                    SpriteFrame(column: 0, row: 0),
                    SpriteFrame(column: 1, row: 0),
                    SpriteFrame(column: 2, row: 0),
                    SpriteFrame(column: 3, row: 0)
                ],
                frameDurationMs: 120,
                loop: false,
                nextActionId: ActionId(rawValue: "idle_default")
            )
        ]
    )
    let tmpURL = URL(fileURLWithPath: "/tmp/\(id)")
    return ValidatedActionPack(manifest: manifest, packURL: tmpURL)
}
