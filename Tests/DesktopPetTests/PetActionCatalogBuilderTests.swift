import Foundation
import DesktopPet

func runPetActionCatalogBuilderTests() {
    let tests = PetActionCatalogBuilderTests()
    tests.v1InputProducesSevenRoleActions()
    tests.v2InputProducesEquivalentCatalog()
    tests.v2MissingIdleStillBuildsCatalog()
    tests.v2MissingDraggingStillBuildsCatalog()
    tests.duplicateActionIdThrows()
    tests.schemaVersionThreeThrowsUnsupported()
    tests.tooManyTagsOnSingleActionThrows()
    tests.tooManyTagsInPackageThrows()
    tests.duplicateRoleKeepsAllActions()
    tests.nextActionIdMissingIsClearedAndWarns()
    tests.frameOutOfBoundsThrowsWhenSpritesheetGiven()
    tests.overrideReplacesDisplayName()
    tests.overrideReplacesTags()
    tests.overrideReplacesRole()
    tests.overrideReplacesFrameDurations()
    tests.overrideNilFieldsKeepOriginal()
    tests.catalogReflectsPetIdAndIndexes()
}

private struct PetActionCatalogBuilderTests {
    func v1InputProducesSevenRoleActions() {
        let clip = ManifestAnimationClip(frames: [SpriteFrame(column: 0, row: 0)], frameDurationMs: 160, loop: true)
        var animations: [PetState: ManifestAnimationClip] = [:]
        for state in PetState.allCases {
            animations[state] = clip
        }
        let input = makeV1Input(animations: animations)
        let builder = DefaultPetActionCatalogBuilder()
        let catalog: PetActionCatalog
        do {
            catalog = try builder.build(input: input, overrides: nil)
        } catch {
            fail("v1 build should succeed but threw: \(error)")
        }
        expect(catalog.actions.count == 7, "v1 build should produce 7 actions, got \(catalog.actions.count)")
        expect(catalog.extras.isEmpty, "v1 build extras should be empty")
        expect(catalog.warnings.isEmpty, "v1 build warnings should be empty")
        expect(catalog.actionsByRole[.idle]?.count == 1, "v1 build should index idle role")
        expect(catalog.actionsByRole[.dragging]?.count == 1, "v1 build should index dragging role")
    }

    func v2InputProducesEquivalentCatalog() {
        let actions = sevenRoleActions()
        let extra = makeAction(id: "extra_1", role: nil)
        let input = makeV2Input(actions: actions + [extra])
        let builder = DefaultPetActionCatalogBuilder()
        let catalog: PetActionCatalog
        do {
            catalog = try builder.build(input: input, overrides: nil)
        } catch {
            fail("v2 build should succeed but threw: \(error)")
        }
        expect(catalog.actions.count == 8, "v2 build should produce 8 actions (7 roles + 1 extra)")
        expect(catalog.extras == [extra], "extras should contain the role-less action")
        expect(catalog.warnings.isEmpty, "v2 build with valid input should not emit warnings")
    }

    func v2MissingIdleStillBuildsCatalog() {
        let actions = sevenRoleActions().filter { $0.role != .idle }
        let input = makeV2Input(actions: actions)
        let builder = DefaultPetActionCatalogBuilder()
        let catalog = try! builder.build(input: input, overrides: nil)
        expect(catalog.actions.count == actions.count, "schema v2 should allow catalogs without an idle role")
        expect(catalog.defaultAction != nil, "role-free fallback should still find a default action")
    }

    func v2MissingDraggingStillBuildsCatalog() {
        let actions = sevenRoleActions().filter { $0.role != .dragging }
        let input = makeV2Input(actions: actions)
        let builder = DefaultPetActionCatalogBuilder()
        let catalog = try! builder.build(input: input, overrides: nil)
        expect(catalog.actions.count == actions.count, "schema v2 should allow catalogs without a dragging role")
    }

    func duplicateActionIdThrows() {
        var actions = sevenRoleActions()
        let dup = makeAction(id: "idle_default", role: nil)
        actions.append(dup)
        let input = makeV2Input(actions: actions)
        let builder = DefaultPetActionCatalogBuilder()
        do {
            _ = try builder.build(input: input, overrides: nil)
            fail("duplicate action id should throw duplicateActionId")
        } catch let ActionCatalogError.duplicateActionId(id) {
            expect(id.rawValue == "idle_default", "duplicate id should be `idle_default`")
        } catch {
            fail("expected duplicateActionId, got: \(error)")
        }
    }

    func schemaVersionThreeThrowsUnsupported() {
        let input = PetActionCatalogBuildInput(
            petId: "pet",
            schemaVersion: 3,
            legacyAnimations: nil,
            actions: [],
            spritesheet: nil
        )
        let builder = DefaultPetActionCatalogBuilder()
        do {
            _ = try builder.build(input: input, overrides: nil)
            fail("schemaVersion = 3 should throw unsupportedSchemaVersion")
        } catch let ActionCatalogError.unsupportedSchemaVersion(version) {
            expect(version == 3, "unsupported version should be 3")
        } catch {
            fail("expected unsupportedSchemaVersion, got: \(error)")
        }
    }

    func tooManyTagsOnSingleActionThrows() {
        let manyTags = (0..<17).map { ActionTag(rawValue: "tag\($0)")! }
        var actions = sevenRoleActions()
        let bigTagAction = makeAction(id: "extra_big", role: nil, tags: manyTags)
        actions.append(bigTagAction)
        let input = makeV2Input(actions: actions)
        let builder = DefaultPetActionCatalogBuilder()
        do {
            _ = try builder.build(input: input, overrides: nil)
            fail("17 tags on single action should throw tooManyTagsOnAction")
        } catch let ActionCatalogError.tooManyTagsOnAction(actionId, count, limit) {
            expect(actionId.rawValue == "extra_big", "actionId should be the offender")
            expect(count == 17, "count should be 17")
            expect(limit == 16, "limit should be 16")
        } catch {
            fail("expected tooManyTagsOnAction, got: \(error)")
        }
    }

    func tooManyTagsInPackageThrows() {
        var actions = sevenRoleActions()
        for index in 0..<11 {
            let tags = (0..<3).map { ActionTag(rawValue: "x\(index)_\($0)")! }
            actions.append(makeAction(id: "extra_\(index)", role: nil, tags: tags))
        }
        let input = makeV2Input(actions: actions)
        let builder = DefaultPetActionCatalogBuilder()
        do {
            _ = try builder.build(input: input, overrides: nil)
            fail("33 tags total in package should throw tooManyTagsInPackage")
        } catch let ActionCatalogError.tooManyTagsInPackage(count, limit) {
            expect(count == 33, "package tag count should be 33, got \(count)")
            expect(limit == 32, "package tag limit should be 32")
        } catch {
            fail("expected tooManyTagsInPackage, got: \(error)")
        }
    }

    func duplicateRoleKeepsAllActions() {
        var actions = sevenRoleActions()
        let secondHappy = makeAction(id: "happy_alt", role: .happy)
        actions.append(secondHappy)
        let input = makeV2Input(actions: actions)
        let builder = DefaultPetActionCatalogBuilder()
        let catalog: PetActionCatalog
        do {
            catalog = try builder.build(input: input, overrides: nil)
        } catch {
            fail("duplicate roles should not throw; got: \(error)")
        }
        expect(catalog.actionsByRole[.happy]?.count == 2, "duplicate role actions should remain available for sampling")
        expect(catalog.actionsByRole[.happy]?.first?.id.rawValue == "happy_default", "first happy should be kept")
        expect(catalog.actionsById[secondHappy.id] == secondHappy, "second happy action should remain addressable by id")
    }

    func nextActionIdMissingIsClearedAndWarns() {
        let phantom = ActionId(rawValue: "ghost")!
        var actions = sevenRoleActions()
        let happy = actions.first(where: { $0.role == .happy })!
        let happyWithBadNext = Action(
            id: happy.id,
            displayName: happy.displayName,
            role: happy.role,
            tags: happy.tags,
            frames: happy.frames,
            frameDurationMs: happy.frameDurationMs,
            loop: happy.loop,
            nextActionId: phantom
        )
        actions.removeAll(where: { $0.id == happy.id })
        actions.append(happyWithBadNext)
        let input = makeV2Input(actions: actions)
        let builder = DefaultPetActionCatalogBuilder()
        let catalog: PetActionCatalog
        do {
            catalog = try builder.build(input: input, overrides: nil)
        } catch {
            fail("missing nextActionId should warn, not throw; got: \(error)")
        }
        let resolvedHappy = catalog.actionsById[happy.id]
        expect(resolvedHappy?.nextActionId == nil, "missing nextActionId should be cleared instead of forcing idle_default")
        expect(catalog.warnings.contains { $0.actionId == happy.id }, "warning should mention the affected action")
    }

    func frameOutOfBoundsThrowsWhenSpritesheetGiven() {
        var actions = sevenRoleActions()
        let outOfBounds = makeAction(
            id: "extra_oob",
            role: nil,
            frames: [SpriteFrame(column: 99, row: 99)]
        )
        actions.append(outOfBounds)
        let input = PetActionCatalogBuildInput(
            petId: "pet",
            schemaVersion: 2,
            legacyAnimations: nil,
            actions: actions,
            spritesheet: SpriteSheetLayout(columns: 8, rows: 9)
        )
        let builder = DefaultPetActionCatalogBuilder()
        do {
            _ = try builder.build(input: input, overrides: nil)
            fail("frame outside spritesheet bounds should throw frameOutOfBounds")
        } catch let ActionCatalogError.frameOutOfBounds(actionId, frame) {
            expect(actionId.rawValue == "extra_oob", "frameOutOfBounds should reference the offender")
            expect(frame.column == 99 && frame.row == 99, "frameOutOfBounds should carry the offending frame")
        } catch {
            fail("expected frameOutOfBounds, got: \(error)")
        }
    }

    func overrideReplacesDisplayName() {
        let happyId = ActionId(rawValue: "happy_default")!
        var actions = sevenRoleActions().filter { $0.id != happyId }
        actions.append(makeAction(id: happyId.rawValue, role: .happy, assetId: "base/happy_sheet"))
        let input = makeV2Input(actions: actions)
        let overrides = PetActionOverrideSet(
            petId: "pet",
            overrides: [PetActionOverride(actionId: happyId, displayName: "心情真好")]
        )
        let builder = DefaultPetActionCatalogBuilder()
        let catalog = try! builder.build(input: input, overrides: overrides)
        expect(catalog.actionsById[happyId]?.displayName == "心情真好", "displayName should be overridden")
        expect(catalog.actionsById[happyId]?.assetId == "base/happy_sheet", "assetId should be preserved")
    }

    func overrideReplacesTags() {
        let actions = sevenRoleActions()
        let input = makeV2Input(actions: actions)
        let extraId = ActionId(rawValue: "happy_default")!
        let mood = ActionTag(rawValue: "mood:high")!
        let overrides = PetActionOverrideSet(
            petId: "pet",
            overrides: [PetActionOverride(actionId: extraId, tags: [mood])]
        )
        let builder = DefaultPetActionCatalogBuilder()
        let catalog = try! builder.build(input: input, overrides: overrides)
        expect(catalog.actionsById[extraId]?.tags == [mood], "tags should be overridden")
    }

    func overrideReplacesRole() {
        var actions = sevenRoleActions().filter { $0.role != .happy }
        actions.append(makeAction(id: "extra_1", role: nil))
        let input = makeV2Input(actions: actions)
        let extraId = ActionId(rawValue: "extra_1")!
        let overrides = PetActionOverrideSet(
            petId: "pet",
            overrides: [PetActionOverride(actionId: extraId, role: .happy)]
        )
        let builder = DefaultPetActionCatalogBuilder()
        let catalog = try! builder.build(input: input, overrides: overrides)
        expect(catalog.actionsById[extraId]?.role == .happy, "role should be overridden")
    }

    func overrideReplacesFrameDurations() {
        let actionId = ActionId(rawValue: "happy_default")!
        var actions = sevenRoleActions().filter { $0.id != actionId }
        actions.append(makeAction(
            id: actionId.rawValue,
            role: .happy,
            frames: [
                SpriteFrame(column: 0, row: 3),
                SpriteFrame(column: 1, row: 3)
            ],
            frameDurationMs: 120
        ))
        let input = makeV2Input(actions: actions)
        let overrides = PetActionOverrideSet(
            petId: "pet",
            overrides: [PetActionOverride(actionId: actionId, frameDurationsMs: [90, 240])]
        )
        let builder = DefaultPetActionCatalogBuilder()
        let catalog = try! builder.build(input: input, overrides: overrides)
        expect(
            catalog.actionsById[actionId]?.frames.map { $0.durationMs } == [90, 240],
            "frame durations should be overridden"
        )
    }

    func overrideNilFieldsKeepOriginal() {
        let actions = sevenRoleActions()
        let input = makeV2Input(actions: actions)
        let happyId = ActionId(rawValue: "happy_default")!
        let original = actions.first(where: { $0.id == happyId })!
        let overrides = PetActionOverrideSet(
            petId: "pet",
            overrides: [PetActionOverride(actionId: happyId)]
        )
        let builder = DefaultPetActionCatalogBuilder()
        let catalog = try! builder.build(input: input, overrides: overrides)
        let resolved = catalog.actionsById[happyId]
        expect(resolved?.displayName == original.displayName, "displayName should remain original")
        expect(resolved?.tags == original.tags, "tags should remain original")
        expect(resolved?.role == original.role, "role should remain original")
    }

    func catalogReflectsPetIdAndIndexes() {
        let actions = sevenRoleActions()
        let extra = makeAction(id: "extra_1", role: nil)
        let input = makeV2Input(actions: actions + [extra], petId: "my_pet")
        let builder = DefaultPetActionCatalogBuilder()
        let catalog = try! builder.build(input: input, overrides: nil)
        expect(catalog.petId == "my_pet", "catalog.petId should follow input")
        expect(catalog.actionsById.count == 8, "actionsById should have 8 entries")
        expect(catalog.extras == [extra], "extras index should reflect role-less actions")
    }

    private func makeAction(
        id rawId: String,
        role: ActionRole?,
        tags: [ActionTag] = [],
        assetId: String? = nil,
        frames: [SpriteFrame] = [SpriteFrame(column: 0, row: 0)],
        frameDurationMs: Int = 160,
        loop: Bool = true,
        nextActionId: ActionId? = nil
    ) -> Action {
        Action(
            id: ActionId(rawValue: rawId)!,
            displayName: rawId,
            role: role,
            tags: tags,
            assetId: assetId,
            frames: frames,
            frameDurationMs: frameDurationMs,
            loop: loop,
            nextActionId: nextActionId
        )
    }

    private func sevenRoleActions() -> [Action] {
        let mapping: [(String, ActionRole)] = [
            ("idle_default", .idle),
            ("walking_default", .walking),
            ("sleeping_default", .sleeping),
            ("happy_default", .happy),
            ("eating_default", .eating),
            ("jumping_default", .jumping),
            ("dragging_default", .dragging)
        ]
        return mapping.map { rawId, role in
            makeAction(id: rawId, role: role)
        }
    }

    private func makeV1Input(animations: [PetState: ManifestAnimationClip], petId: String = "pet") -> PetActionCatalogBuildInput {
        PetActionCatalogBuildInput(
            petId: petId,
            schemaVersion: 1,
            legacyAnimations: animations,
            actions: [],
            spritesheet: nil
        )
    }

    private func makeV2Input(actions: [Action], petId: String = "pet") -> PetActionCatalogBuildInput {
        PetActionCatalogBuildInput(
            petId: petId,
            schemaVersion: 2,
            legacyAnimations: nil,
            actions: actions,
            spritesheet: nil
        )
    }
}
