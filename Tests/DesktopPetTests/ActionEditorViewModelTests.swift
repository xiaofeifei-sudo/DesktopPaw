import Foundation
import DesktopPet

@MainActor
func runActionEditorViewModelTests() {
    let tests = ActionEditorViewModelTests()
    tests.displayNameEmptyAndOverLimitAreRejected()
    tests.moodBrightTagIsRejectedWithSpecifiedMessage()
    tests.nonReservedVibeTagIsAccepted()
    tests.tagContainingSpaceIsRejectedWithSpecifiedMessage()
    tests.seventeenthTagIsRejected()
    tests.packageThirtyThirdTagIsRejectedOnSave()
    tests.cancelDoesNotWriteOverrides()
    tests.saveWritesOverrideAndPreservesOtherOverrides()
    tests.saveWritesFrameDurationsForBaseAction()
    tests.saveRejectsOutOfRangeFrameDuration()
    tests.saveWritesActionPackFrameDurationsToActionPackOverrides()
    tests.savedOverrideIsAppliedByReloadedDefinition()
    tests.playPreviewRoutesToActionTriggerService()
}

@MainActor
private struct ActionEditorViewModelTests {
    func displayNameEmptyAndOverLimitAreRejected() {
        let bundle = makeEditor()

        bundle.model.displayName = ""
        expect(!bundle.model.save(), "empty displayName should be rejected")
        expect(
            bundle.model.displayNameError == ActionEditorViewModel.displayNameValidationMessage,
            "empty displayName should show the specified validation message"
        )

        bundle.model.displayName = String(repeating: "a", count: 65)
        expect(!bundle.model.save(), "65-character displayName should be rejected")
        expect(
            bundle.model.displayNameError == ActionEditorViewModel.displayNameValidationMessage,
            "over-limit displayName should show the specified validation message"
        )
        expect(bundle.overrideStore.saveCount == 0, "invalid displayName must not write overrides")
    }

    func moodBrightTagIsRejectedWithSpecifiedMessage() {
        let bundle = makeEditor()

        expect(!bundle.model.addTag("mood:bright"), "mood:bright should be rejected")
        expect(
            bundle.model.tagError == ActionEditorViewModel.moodValidationMessage,
            "mood:bright should show the specified mood validation message"
        )
    }

    func nonReservedVibeTagIsAccepted() {
        let bundle = makeEditor()

        expect(bundle.model.addTag("vibe:cozy"), "non-reserved vibe:cozy tag should be accepted")
        expect(bundle.model.tags.contains("vibe:cozy"), "accepted tag should be added to the editor")
        expect(bundle.model.tagError == nil, "accepted tag should clear tag error")
    }

    func tagContainingSpaceIsRejectedWithSpecifiedMessage() {
        let bundle = makeEditor()

        expect(!bundle.model.addTag("vibe cozy"), "tag containing a space should be rejected")
        expect(
            bundle.model.tagError == ActionEditorViewModel.tagCharacterValidationMessage,
            "space-containing tag should show the specified character validation message"
        )
    }

    func seventeenthTagIsRejected() {
        let bundle = makeEditor()

        for index in 0..<16 {
            expect(bundle.model.addTag("tag\(index)"), "tag \(index) should be accepted before the limit")
        }

        expect(!bundle.model.addTag("tag16"), "17th tag should be rejected")
        expect(bundle.model.tags.count == 16, "editor should keep exactly 16 tags")
        expect(
            bundle.model.tagError == ActionEditorViewModel.tagLimitValidationMessage,
            "17th tag should show the single-action tag limit message"
        )
    }

    func packageThirtyThirdTagIsRejectedOnSave() {
        let extras = (0..<32).map { index in
            makeAction(
                id: "extra_tagged_\(index)",
                role: nil,
                displayName: "Tagged \(index)",
                tags: [ActionTag(rawValue: "tag\(index)")!]
            )
        }
        let bundle = makeEditor(extras: extras)

        expect(bundle.model.addTag("vibe:cozy"), "new action tag should be individually valid")
        expect(!bundle.model.save(), "33rd package tag should be rejected")
        expect(
            bundle.model.tagError == ActionEditorViewModel.packageTagLimitValidationMessage,
            "package tag overflow should show the package tag limit message"
        )
        expect(bundle.overrideStore.saveCount == 0, "package tag overflow must not write overrides")
    }

    func cancelDoesNotWriteOverrides() {
        var didCancel = false
        let bundle = makeEditor(onCancel: {
            didCancel = true
        })

        bundle.model.displayName = "Should Not Persist"
        bundle.model.addTag("vibe:cozy")
        bundle.model.cancel()

        expect(didCancel, "cancel should invoke its close callback")
        expect(bundle.overrideStore.saveCount == 0, "cancel must not write overrides")
    }

    func saveWritesOverrideAndPreservesOtherOverrides() {
        let extra1 = makeAction(id: "extra_1", role: nil, displayName: "Wave")
        let extra2 = makeAction(id: "extra_2", role: nil, displayName: "Blink")
        let otherOverride = PetActionOverride(
            actionId: extra2.id,
            displayName: "Other Renamed",
            tags: [ActionTag(rawValue: "after.pet")!],
            role: nil
        )
        let overrideStore = EditorOverrideStore(
            loaded: PetActionOverrideSet(
                petId: "editor-pet",
                overrides: [otherOverride]
            )
        )
        var savedPetId: String?
        let bundle = makeEditor(
            extras: [extra1, extra2],
            actionId: extra1.id,
            overrideStore: overrideStore,
            onSaveSucceeded: { savedPetId = $0 }
        )

        bundle.model.displayName = "Wave Renamed"
        expect(bundle.model.addTag("vibe:cozy"), "test tag should be accepted")
        expect(bundle.model.save(), "valid editor save should succeed")

        let saved = overrideStore.saved
        expect(savedPetId == "editor-pet", "save should notify with the edited pet id")
        expect(overrideStore.saveCount == 1, "valid save should write once")
        expect(
            saved?.override(for: extra1.id)?.displayName == "Wave Renamed",
            "saved overrides should include the edited displayName"
        )
        expect(
            saved?.override(for: extra1.id)?.tags == [ActionTag(rawValue: "vibe:cozy")!],
            "saved overrides should include the edited tags"
        )
        expect(
            saved?.override(for: extra2.id) == otherOverride,
            "saving one action should preserve other action overrides"
        )
    }

    func saveWritesFrameDurationsForBaseAction() {
        let frames = [
            SpriteFrame(column: 0, row: 3),
            SpriteFrame(column: 1, row: 3)
        ]
        let happy = makeAction(
            id: "happy_default",
            role: .happy,
            displayName: "Happy",
            frames: frames,
            frameDurationMs: 120,
            loop: false,
            nextActionId: ActionId(rawValue: "idle_default")
        )
        let definition = makeDefinition(petId: "editor-pet", actions: [happy])
        let overrideStore = EditorOverrideStore()
        let model = makeModel(
            definition: definition,
            action: happy,
            overrideStore: overrideStore
        )

        model.setFrameDuration(index: 0, durationMs: 90)
        model.setFrameDuration(index: 1, durationMs: 240)

        expect(model.save(), "valid frame durations should save")
        expect(
            overrideStore.saved?.override(for: happy.id)?.frameDurationsMs == [90, 240],
            "base action overrides should persist per-frame durations"
        )
    }

    func saveRejectsOutOfRangeFrameDuration() {
        let bundle = makeEditor()

        bundle.model.setFrameDuration(index: 0, durationMs: 49)

        expect(!bundle.model.save(), "frame duration below range should be rejected")
        expect(
            bundle.model.frameDurationError == ActionEditorViewModel.frameDurationValidationMessage,
            "invalid frame duration should show the specified validation message"
        )
        expect(bundle.overrideStore.saveCount == 0, "invalid frame duration must not write overrides")
    }

    func saveWritesActionPackFrameDurationsToActionPackOverrides() {
        let actionPackStore = EditorActionPackOverrideStore()
        let packedAction = makeAction(
            id: "wave_pack_123",
            role: nil,
            displayName: "Wave",
            tags: [ActionTag(rawValue: "vibe:cozy")!],
            assetId: "wave_pack/wave_sheet",
            frames: [
                SpriteFrame(column: 0, row: 0),
                SpriteFrame(column: 9, row: 0)
            ],
            frameDurationMs: 120
        )
        let definition = makeDefinition(petId: "editor-pet", actions: [packedAction])
        let model = makeModel(
            definition: definition,
            action: packedAction,
            overrideStore: EditorOverrideStore(),
            actionPackOverrideStore: actionPackStore
        )

        model.displayName = "Custom Wave"
        model.setFrameDuration(index: 0, durationMs: 80)
        model.setFrameDuration(index: 1, durationMs: 260)

        expect(model.save(), "valid action pack frame durations should save")
        let override = actionPackStore.saved?.override(for: packedAction.id)
        expect(override?.displayName == "Custom Wave", "action pack save should preserve displayName edits")
        expect(override?.tags == [ActionTag(rawValue: "vibe:cozy")!], "action pack save should preserve tags")
        expect(
            override?.frameDurationsMs == [80, 260],
            "action pack overrides should persist per-frame durations"
        )
    }

    func savedOverrideIsAppliedByReloadedDefinition() {
        let fixture = PersistentFixture()
        defer { fixture.cleanUp() }

        let petId = "persistent-editor-pet"
        let extra = makeAction(id: "extra_1", role: nil, displayName: "Wave")
        do {
            try fixture.writeManifest(petId: petId, extras: [extra])
        } catch {
            fail("failed to seed persistent editor fixture: \(error)")
        }

        let definition: PetDefinition
        do {
            definition = try fixture.store.loadDefinition(id: petId)
        } catch {
            fail("seeded definition should load before editing: \(error)")
        }

        guard let action = definition.catalog.resolve(actionId: extra.id) else {
            fail("seeded extra action should be in the catalog")
        }

        let model = ActionEditorViewModel(
            definition: definition,
            action: action,
            overrideStore: fixture.overrideStore,
            triggerService: EditorTriggerService()
        )
        model.displayName = "Persistent Wave"
        expect(model.save(), "saving persistent override should succeed")

        do {
            let reloaded = try fixture.store.loadDefinition(id: petId)
            expect(
                reloaded.catalog.resolve(actionId: extra.id)?.displayName == "Persistent Wave",
                "reload after save should apply action-overrides.json to the catalog"
            )
        } catch {
            fail("definition should reload with saved action override: \(error)")
        }
    }

    func playPreviewRoutesToActionTriggerService() {
        let triggerService = EditorTriggerService()
        let bundle = makeEditor(triggerService: triggerService)

        let result = bundle.model.playPreview()

        expect(result == .allowed, "allowed preview should return allowed")
        expect(
            triggerService.triggeredActionIds == [bundle.model.actionId],
            "playPreview should trigger the editor action through ActionTriggerService"
        )
    }

    private func makeEditor(
        extras: [Action] = [],
        actionId: ActionId? = nil,
        overrideStore: EditorOverrideStore = EditorOverrideStore(),
        actionPackOverrideStore: EditorActionPackOverrideStore? = nil,
        triggerService: EditorTriggerService = EditorTriggerService(),
        onSaveSucceeded: ((String) -> Void)? = nil,
        onCancel: (() -> Void)? = nil
    ) -> EditorBundle {
        let definition = makeDefinition(petId: "editor-pet", extras: extras)
        let resolvedActionId = actionId ?? ActionId(rawValue: "happy_default")!
        guard let action = definition.catalog.resolve(actionId: resolvedActionId) else {
            fail("test action \(resolvedActionId.rawValue) should exist")
        }
        let model = ActionEditorViewModel(
            definition: definition,
            action: action,
            overrideStore: overrideStore,
            actionPackOverrideStore: actionPackOverrideStore,
            triggerService: triggerService,
            onSaveSucceeded: onSaveSucceeded,
            onCancel: onCancel
        )
        return EditorBundle(model: model, overrideStore: overrideStore, triggerService: triggerService)
    }

    private func makeModel(
        definition: PetDefinition,
        action: Action,
        overrideStore: EditorOverrideStore,
        actionPackOverrideStore: EditorActionPackOverrideStore? = nil
    ) -> ActionEditorViewModel {
        ActionEditorViewModel(
            definition: definition,
            action: action,
            overrideStore: overrideStore,
            actionPackOverrideStore: actionPackOverrideStore,
            triggerService: EditorTriggerService()
        )
    }

    private func makeDefinition(petId: String, extras: [Action]) -> PetDefinition {
        makeDefinition(
            petId: petId,
            actions: makeStandardCatalog(petId: petId, extras: extras).actions
        )
    }

    private func makeDefinition(petId: String, actions: [Action]) -> PetDefinition {
        PetDefinition(
            id: petId,
            displayName: "Editor Pet",
            description: "Action editor test pet",
            assetName: "spritesheet.png",
            previewAssetName: "preview.png",
            frameSize: CGSizeCodable(width: 64, height: 64),
            spritesheet: SpriteSheetLayout(columns: 8, rows: 8),
            defaultScale: 1.0,
            catalog: PetActionCatalog(petId: petId, actions: actions, warnings: [])
        )
    }
}

@MainActor
private struct EditorBundle {
    let model: ActionEditorViewModel
    let overrideStore: EditorOverrideStore
    let triggerService: EditorTriggerService
}

private final class EditorOverrideStore: PetActionOverrideStoring {
    var loaded: PetActionOverrideSet?
    var saved: PetActionOverrideSet?
    var savedPetId: String?
    var saveCount = 0

    init(loaded: PetActionOverrideSet? = nil) {
        self.loaded = loaded
    }

    func load(petId: String) throws -> PetActionOverrideSet? {
        loaded
    }

    func save(_ overrides: PetActionOverrideSet, for petId: String) throws {
        saveCount += 1
        saved = overrides
        savedPetId = petId
        loaded = overrides
    }

    func delete(petId: String) throws {
        loaded = nil
        saved = nil
    }
}

private final class EditorActionPackOverrideStore: ActionPackOverrideStoring, @unchecked Sendable {
    var loaded: ActionPackOverrideSet?
    var saved: ActionPackOverrideSet?
    var savedPetId: String?
    var saveCount = 0

    init(loaded: ActionPackOverrideSet? = nil) {
        self.loaded = loaded
    }

    func load(petId: String) -> ActionPackOverrideSet? {
        loaded
    }

    func save(_ overrides: ActionPackOverrideSet, petId: String) throws {
        saveCount += 1
        saved = overrides
        savedPetId = petId
        loaded = overrides
    }

    func delete(petId: String) {
        loaded = nil
        saved = nil
    }
}

@MainActor
private final class EditorTriggerService: ActionTriggerServicing {
    var onTriggerRejected: ((ActionId, ActionTriggerEligibility) -> Void)?
    var result: ActionTriggerEligibility
    var triggeredActionIds: [ActionId] = []

    init(result: ActionTriggerEligibility = .allowed) {
        self.result = result
    }

    func eligibility(for actionId: ActionId) -> ActionTriggerEligibility {
        result
    }

    func trigger(actionId: ActionId) -> ActionTriggerEligibility {
        triggeredActionIds.append(actionId)
        if result != .allowed {
            onTriggerRejected?(actionId, result)
        }
        return result
    }
}

private struct PersistentFixture {
    let rootDirectory: URL
    let store: PetLibraryStore
    let overrideStore: PetActionOverrideStore

    init() {
        rootDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ActionEditorPersistenceTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: rootDirectory, withIntermediateDirectories: true)
        store = PetLibraryStore(rootDirectory: rootDirectory)
        overrideStore = PetActionOverrideStore(petsDirectoryURL: store.importedPetsDirectoryURL)
    }

    func cleanUp() {
        try? FileManager.default.removeItem(at: rootDirectory)
    }

    func writeManifest(petId: String, extras: [Action]) throws {
        let folderURL = store.importedPetsDirectoryURL.appendingPathComponent(petId, isDirectory: true)
        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        let manifest = PetPackageManifest(
            schemaVersion: 2,
            id: petId,
            displayName: "Persistent Editor Pet",
            description: "Action editor persistence fixture",
            asset: "spritesheet.png",
            preview: "preview.png",
            frameSize: CGSizeCodable(width: 64, height: 64),
            spritesheet: SpriteSheetLayout(columns: 8, rows: 8),
            defaultScale: 1.0,
            actions: makeStandardCatalog(petId: petId, extras: extras).actions
        )
        let data = try JSONEncoder().encode(manifest)
        try data.write(to: folderURL.appendingPathComponent(PetLibraryStore.manifestFileName))
    }
}
