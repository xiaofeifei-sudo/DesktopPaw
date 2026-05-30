import AppKit
import Foundation
import DesktopPet

@MainActor
func runImportWizardViewModelTests() {
    let tests = ImportWizardViewModelTests()
    tests.rowSevenAndEightExtrasAreListedWithFirstFramePreview()
    tests.assigningRowSevenToHappyPersistsAndReloadsAsHappy()
    tests.namingRowSevenExtraPersistsAndAppearsInMenu()
    tests.duplicateRoleAssignmentShowsInlineNoticeAndSaves()
    tests.cancelDoesNotWriteOverrides()
    tests.commitPreservesOtherOverridesAndManifestBytes()
}

@MainActor
private struct ImportWizardViewModelTests {
    func rowSevenAndEightExtrasAreListedWithFirstFramePreview() {
        let firstFrame = SpriteFrame(column: 2, row: 7)
        let secondFrame = SpriteFrame(column: 3, row: 7)
        let rowEightFrame = SpriteFrame(column: 1, row: 8)
        let previewImage = NSImage(size: NSSize(width: 8, height: 8))
        var captured: [(ActionId, SpriteFrame)] = []
        let extraSeven = makeAction(
            id: "extra_1",
            role: nil,
            displayName: "自定义动作 1",
            frames: [firstFrame, secondFrame]
        )
        let extraEight = makeAction(
            id: "extra_2",
            role: nil,
            displayName: "自定义动作 2",
            frames: [rowEightFrame]
        )
        let ignoredExtra = makeAction(
            id: "extra_low",
            role: nil,
            displayName: "Not Petdex Extra",
            frames: [SpriteFrame(column: 0, row: 6)]
        )
        let definition = makeDefinition(extras: [ignoredExtra, extraEight, extraSeven])

        let model = makeModel(definition: definition) { _, action, frame in
            captured.append((action.id, frame))
            return action.id == extraSeven.id ? previewImage : nil
        }

        expect(model.rows.map(\.rowIndex) == [7, 8], "import wizard should list Petdex extra rows 7 and 8 only")
        guard let rowSeven = model.rows.first(where: { $0.rowIndex == 7 }) else {
            fail("expected row 7 in import wizard")
        }
        expect(rowSeven.actionId == extraSeven.id, "row 7 should expose its action id")
        expect(rowSeven.displayName == "自定义动作 1", "row 7 should expose its display name")
        expect(rowSeven.previewFrame == firstFrame, "row 7 should use the first action frame as preview")
        expect(rowSeven.previewImage === previewImage, "row 7 should keep the preview image from the provider")
        expect(
            captured.contains { $0.0 == extraSeven.id && $0.1 == firstFrame },
            "preview provider should receive row 7 first frame"
        )
        expect(
            rowSeven.selection == .namedExtra("自定义动作 1"),
            "default selection should keep the row as a named extra"
        )
    }

    func assigningRowSevenToHappyPersistsAndReloadsAsHappy() {
        let fixture = ImportWizardPersistentFixture()
        defer { fixture.cleanUp() }
        let petId = "wizard-happy-pet"
        try! fixture.writeManifest(petId: petId)
        let definition = try! fixture.store.loadDefinition(id: petId)
        let model = makeModel(definition: definition, overrideStore: fixture.overrideStore)

        model.assign(rowIndex: 7, role: .happy, customName: nil)
        expect(model.commit(), "assigning row 7 to happy should save")

        let saved = try! fixture.overrideStore.load(petId: petId)
        expect(
            saved?.override(for: ActionId(rawValue: "extra_1")!)?.role == .happy,
            "row 7 override should persist role=happy"
        )

        let reloaded = try! fixture.store.loadDefinition(id: petId)
        let happyActions = reloaded.catalog.actionsByRole[.happy] ?? []
        expect(
            happyActions.contains { $0.id.rawValue == "extra_1" && $0.frames.first?.row == 7 },
            "reloaded catalog happy role should retain the row 7 action when duplicate role came from override"
        )
        expect(
            reloaded.catalog.warnings.isEmpty,
            "duplicate role assignments should remain valid sampling alternatives without catalog warnings"
        )
    }

    func namingRowSevenExtraPersistsAndAppearsInMenu() {
        let fixture = ImportWizardPersistentFixture()
        defer { fixture.cleanUp() }
        let petId = "wizard-name-pet"
        try! fixture.writeManifest(petId: petId)
        let definition = try! fixture.store.loadDefinition(id: petId)
        let model = makeModel(definition: definition, overrideStore: fixture.overrideStore)

        model.assign(rowIndex: 7, role: nil, customName: "extra_lickpaw")
        expect(model.commit(), "naming row 7 as a custom extra should save")

        let reloaded = try! fixture.store.loadDefinition(id: petId)
        let extraId = ActionId(rawValue: "extra_1")!
        expect(
            reloaded.catalog.resolve(actionId: extraId)?.displayName == "extra_lickpaw",
            "reloaded catalog should apply the custom extra displayName"
        )

        let menu = ActionsMenuBuilder().buildMenu(
            catalog: reloaded.catalog,
            eligibility: { _ in .allowed },
            trigger: { _ in }
        )
        expect(menu.item(withTitle: "extra_lickpaw") != nil, "actions menu should show the custom extra displayName")
    }

    func duplicateRoleAssignmentShowsInlineNoticeAndSaves() {
        let extra = makeAction(
            id: "extra_1",
            role: nil,
            displayName: "自定义动作 1",
            frames: [SpriteFrame(column: 0, row: 7)]
        )
        let overrideStore = ImportWizardOverrideStore()
        let model = makeModel(
            definition: makeDefinition(extras: [extra]),
            overrideStore: overrideStore
        )

        model.assign(rowIndex: 7, role: .happy, customName: nil)

        expect(
            model.rows.first(where: { $0.rowIndex == 7 })?.notice == ImportWizardViewModel.phase3Notice,
            "assigning an extra to an existing role should expose the Phase 3 inline notice"
        )
        expect(model.commit(), "same-role assignment should be accepted in Phase 2")
        expect(
            overrideStore.saved?.override(for: extra.id)?.role == .happy,
            "same-role assignment should still be written to overrides"
        )
    }

    func cancelDoesNotWriteOverrides() {
        let overrideStore = ImportWizardOverrideStore()
        var didCancel = false
        let model = makeModel(
            definition: makeDefinition(extras: [
                makeAction(
                    id: "extra_1",
                    role: nil,
                    displayName: "自定义动作 1",
                    frames: [SpriteFrame(column: 0, row: 7)]
                )
            ]),
            overrideStore: overrideStore,
            onCancel: { didCancel = true }
        )

        model.assign(rowIndex: 7, role: .happy, customName: nil)
        model.cancel()

        expect(didCancel, "cancel should invoke the close callback")
        expect(overrideStore.saveCount == 0, "cancel must not write overrides")
    }

    func commitPreservesOtherOverridesAndManifestBytes() {
        let fixture = ImportWizardPersistentFixture()
        defer { fixture.cleanUp() }
        let petId = "wizard-preserve-pet"
        try! fixture.writeManifest(petId: petId)

        let otherOverride = PetActionOverride(
            actionId: ActionId(rawValue: "extra_2")!,
            displayName: "Keep Existing",
            tags: [ActionTag(rawValue: "vibe:cozy")!],
            role: nil
        )
        try! fixture.overrideStore.save(
            PetActionOverrideSet(petId: petId, overrides: [otherOverride]),
            for: petId
        )
        let manifestBefore = try! fixture.manifestBytes(petId: petId)
        let definition = try! fixture.store.loadDefinition(id: petId)
        let model = makeModel(definition: definition, overrideStore: fixture.overrideStore)

        model.assign(rowIndex: 7, role: .happy, customName: nil)
        expect(model.commit(), "commit should save valid wizard choices")

        let saved = try! fixture.overrideStore.load(petId: petId)
        expect(
            saved?.override(for: ActionId(rawValue: "extra_2")!) == otherOverride,
            "commit should preserve unrelated action overrides"
        )
        let manifestAfter = try! fixture.manifestBytes(petId: petId)
        expect(manifestAfter == manifestBefore, "commit must not rewrite original manifest bytes")
    }

    private func makeModel(
        definition: PetDefinition,
        overrideStore: PetActionOverrideStoring = ImportWizardOverrideStore(),
        previewProvider: @escaping ActionLibraryViewModel.PreviewProvider = { _, _, _ in nil },
        onCommitSucceeded: ((String) -> Void)? = nil,
        onCancel: (() -> Void)? = nil
    ) -> ImportWizardViewModel {
        ImportWizardViewModel(
            definition: definition,
            overrideStore: overrideStore,
            previewProvider: previewProvider,
            onCommitSucceeded: onCommitSucceeded,
            onCancel: onCancel
        )
    }

    private func makeDefinition(extras: [Action]) -> PetDefinition {
        PetDefinition(
            id: "wizard-pet",
            displayName: "Wizard Pet",
            description: "Import wizard test pet",
            assetName: "spritesheet.png",
            previewAssetName: "preview.png",
            frameSize: CGSizeCodable(width: 64, height: 64),
            spritesheet: SpriteSheetLayout(columns: 8, rows: 9),
            defaultScale: 1.0,
            catalog: makeStandardCatalog(petId: "wizard-pet", extras: extras)
        )
    }
}

private final class ImportWizardOverrideStore: PetActionOverrideStoring {
    var loaded: PetActionOverrideSet?
    var saved: PetActionOverrideSet?
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
        loaded = overrides
    }

    func delete(petId: String) throws {
        loaded = nil
        saved = nil
    }
}

private struct ImportWizardPersistentFixture {
    let rootDirectory: URL
    let store: PetLibraryStore
    let overrideStore: PetActionOverrideStore

    init() {
        rootDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ImportWizardPersistenceTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: rootDirectory, withIntermediateDirectories: true)
        store = PetLibraryStore(rootDirectory: rootDirectory)
        overrideStore = PetActionOverrideStore(petsDirectoryURL: store.importedPetsDirectoryURL)
    }

    func cleanUp() {
        try? FileManager.default.removeItem(at: rootDirectory)
    }

    func writeManifest(petId: String) throws {
        let folderURL = store.importedPetsDirectoryURL.appendingPathComponent(petId, isDirectory: true)
        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        let manifest = PetPackageManifest(
            schemaVersion: 2,
            id: petId,
            displayName: "Persistent Wizard Pet",
            description: "Import wizard persistence fixture",
            asset: "spritesheet.png",
            preview: "preview.png",
            frameSize: CGSizeCodable(width: 64, height: 64),
            spritesheet: SpriteSheetLayout(columns: 8, rows: 9),
            defaultScale: 1.0,
            actions: petdexLikeActions()
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(manifest)
        try data.write(to: manifestURL(petId: petId))
    }

    func manifestBytes(petId: String) throws -> Data {
        try Data(contentsOf: manifestURL(petId: petId))
    }

    private func manifestURL(petId: String) -> URL {
        store.importedPetsDirectoryURL
            .appendingPathComponent(petId, isDirectory: true)
            .appendingPathComponent(PetLibraryStore.manifestFileName)
    }

    private func petdexLikeActions() -> [Action] {
        let roleRows: [(ActionRole, Int)] = [
            (.idle, 0),
            (.walking, 1),
            (.sleeping, 2),
            (.happy, 3),
            (.eating, 4),
            (.jumping, 5),
            (.dragging, 6)
        ]
        let roleActions = roleRows.map { role, row in
            Action(
                id: ActionId(rawValue: "\(role.rawValue)_default")!,
                displayName: role.rawValue,
                role: role,
                tags: [],
                frames: [SpriteFrame(column: 0, row: row)],
                frameDurationMs: 120,
                loop: role == .idle || role == .walking || role == .sleeping || role == .dragging,
                nextActionId: role == .idle || role == .walking || role == .sleeping || role == .dragging ? nil : ActionId.idle
            )
        }
        let extraActions = [
            makeAction(
                id: "extra_1",
                role: nil,
                displayName: "自定义动作 1",
                frames: [SpriteFrame(column: 0, row: 7), SpriteFrame(column: 1, row: 7)]
            ),
            makeAction(
                id: "extra_2",
                role: nil,
                displayName: "自定义动作 2",
                frames: [SpriteFrame(column: 0, row: 8), SpriteFrame(column: 1, row: 8)]
            )
        ]
        return roleActions + extraActions
    }
}
