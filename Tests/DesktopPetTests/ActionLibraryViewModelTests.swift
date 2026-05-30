@preconcurrency import AppKit
import CoreGraphics
import Foundation
import ImageIO
import DesktopPet

@MainActor
func runActionLibraryViewModelTests() {
    let tests = ActionLibraryViewModelTests()
    tests.rowsAreSortedByRoleThenExtraDisplayName()
    tests.refreshingDefinitionUpdatesRowsForSelectedPet()
    tests.playPreviewRoutesToActionTriggerService()
    tests.busyEligibilityDisablesRowsAndShowsNotice()
    tests.previewUsesFirstActionFrame()
    tests.actionPackWizardDoesNotReportSaveSucceededWithoutCommander()
    tests.onlyActionPackExtrasAreDeletable()
    tests.actionPackEditorWritesActionPackOverrides()
}

@MainActor
private struct ActionLibraryViewModelTests {
    func rowsAreSortedByRoleThenExtraDisplayName() {
        let definition = makeDefinition(
            petId: "pet-a",
            extras: [
                makeAction(id: "extra_z", role: nil, displayName: "Zulu"),
                makeAction(id: "extra_a", role: nil, displayName: "Alpha")
            ]
        )
        let model = makeModel(definition: definition)

        let ids = model.rows.map(\.actionId.rawValue)
        expect(
            ids == [
                "idle_default",
                "walk_default",
                "sleep_default",
                "happy_default",
                "eat_default",
                "jump_default",
                "drag_default",
                "extra_a",
                "extra_z"
            ],
            "actions should be sorted by role order, then extras by displayName"
        )
    }

    func refreshingDefinitionUpdatesRowsForSelectedPet() {
        let initial = makeDefinition(
            petId: "pet-a",
            extras: [makeAction(id: "extra_wave", role: nil, displayName: "Wave")]
        )
        let next = makeDefinition(
            petId: "pet-b",
            extras: [makeAction(id: "extra_blink", role: nil, displayName: "Blink")]
        )
        let model = makeModel(definition: initial)

        model.refresh(definition: next)

        let titles = model.rows.map(\.displayName)
        expect(model.currentPetId == "pet-b", "refresh should update current pet id")
        expect(titles.contains("Blink"), "refresh should show the new pet catalog")
        expect(!titles.contains("Wave"), "refresh should remove the previous pet catalog")
    }

    func playPreviewRoutesToActionTriggerService() {
        let triggerService = ActionLibraryTriggerService()
        let definition = makeDefinition(petId: "pet-a")
        let model = makeModel(definition: definition, triggerService: triggerService)
        let actionId = ActionId(rawValue: "happy_default")!

        let result = model.playPreview(actionId)

        expect(result == .allowed, "allowed preview should return allowed eligibility")
        expect(triggerService.triggeredActionIds == [actionId], "playPreview should trigger the requested action id")
    }

    func busyEligibilityDisablesRowsAndShowsNotice() {
        let triggerService = ActionLibraryTriggerService(result: .rejectedBusy(reason: ActionTriggerService.busyReason))
        let definition = makeDefinition(petId: "pet-a")
        let model = makeModel(definition: definition, triggerService: triggerService)

        expect(!model.rows.isEmpty, "precondition: rows should be present")
        expect(model.rows.allSatisfy { !$0.canPlay }, "busy eligibility should disable every preview button")
        expect(
            model.rows.allSatisfy { $0.notice == ActionTriggerService.busyReason },
            "busy eligibility should expose the busy notice on each row"
        )
    }

    func previewUsesFirstActionFrame() {
        let firstFrame = SpriteFrame(column: 2, row: 3)
        let secondFrame = SpriteFrame(column: 4, row: 5)
        let previewImage = NSImage(size: NSSize(width: 8, height: 8))
        var capturedFrame: SpriteFrame?
        let extra = makeAction(
            id: "extra_preview",
            role: nil,
            displayName: "Preview",
            frames: [firstFrame, secondFrame]
        )
        let definition = makeDefinition(petId: "pet-a", extras: [extra])
        let model = makeModel(definition: definition) { _, action, frame in
            if action.id == extra.id {
                capturedFrame = frame
            }
            return previewImage
        }

        guard let row = model.rows.first(where: { $0.actionId == extra.id }) else {
            fail("expected preview extra row")
        }
        expect(row.previewFrame == firstFrame, "row should expose the first action frame")
        expect(capturedFrame == firstFrame, "preview provider should receive the first action frame")
        expect(row.previewImage === previewImage, "row should keep the image returned by the preview provider")
    }

    func actionPackWizardDoesNotReportSaveSucceededWithoutCommander() {
        let definition = makeDefinition(petId: "pet-a")
        let model = makeModel(definition: definition)
        var savedPetId: String?
        let imageURL = writeTempPNG(width: 64, height: 64)
        defer { try? FileManager.default.removeItem(at: imageURL) }

        model.onActionMetadataSaved = { savedPetId = $0 }
        model.openActionPackImportWizard()

        guard let wizard = model.actionPackWizardModel else {
            fail("expected action pack wizard model")
        }

        wizard.selectImage(from: imageURL)
        wizard.displayName = "Wave"
        wizard.save()

        expect(savedPetId == nil, "wizard should not report a successful save without an action pack commander")
        expect(model.isActionPackWizardPresented, "wizard should stay open when the action pack cannot be saved")
    }

    func onlyActionPackExtrasAreDeletable() {
        let packedExtra = makeAction(
            id: "wave_pack_123",
            role: nil,
            displayName: "Wave",
            assetId: "wave_pack/wave_sheet"
        )
        let legacyExtra = makeAction(
            id: "legacy_extra",
            role: nil,
            displayName: "Legacy",
            assetId: "base/default"
        )
        let definition = makeDefinition(petId: "pet-a", extras: [packedExtra, legacyExtra])
        let model = makeModel(definition: definition)

        let idle = model.rows.first { $0.actionId.rawValue == "idle_default" }
        let packed = model.rows.first { $0.actionId == packedExtra.id }
        let legacy = model.rows.first { $0.actionId == legacyExtra.id }

        expect(idle?.deletablePackId == nil, "built-in role actions should not be deletable")
        expect(packed?.deletablePackId == "wave_pack", "action pack extras should expose their pack id for deletion")
        expect(legacy?.deletablePackId == nil, "non-pack extras should not expose a destructive delete")
    }

    func actionPackEditorWritesActionPackOverrides() {
        let packedExtra = makeAction(
            id: "wave_pack_123",
            role: nil,
            displayName: "Wave",
            assetId: "wave_pack/wave_sheet",
            frames: [
                SpriteFrame(column: 0, row: 0),
                SpriteFrame(column: 9, row: 0)
            ],
            frameDurationMs: 120
        )
        let definition = makeDefinition(petId: "pet-a", extras: [packedExtra])
        let packOverrideStore = ActionLibraryActionPackOverrideStore()
        let model = makeModel(
            definition: definition,
            actionPackOverrideStore: packOverrideStore
        )

        model.openEditor(for: packedExtra.id)
        guard let editor = model.editorModel else {
            fail("opening an action pack action should create an editor")
        }

        editor.displayName = "Slow Wave"
        editor.setFrameDuration(index: 0, durationMs: 90)
        editor.setFrameDuration(index: 1, durationMs: 240)
        expect(editor.save(), "action pack editor save should succeed")

        let override = packOverrideStore.saved?.override(for: packedExtra.id)
        expect(override?.displayName == "Slow Wave", "library editor should save action pack display name override")
        expect(override?.frameDurationsMs == [90, 240], "library editor should save action pack frame duration override")
    }

    private func makeModel(
        definition: PetDefinition,
        triggerService: ActionLibraryTriggerService = ActionLibraryTriggerService(),
        previewProvider: @escaping ActionLibraryViewModel.PreviewProvider = { _, _, _ in nil },
        actionPackOverrideStore: ActionLibraryActionPackOverrideStore? = nil
    ) -> ActionLibraryViewModel {
        ActionLibraryViewModel(
            definition: definition,
            triggerService: triggerService,
            previewProvider: previewProvider,
            actionPackOverrideStore: actionPackOverrideStore
        )
    }

    private func makeDefinition(
        petId: String,
        extras: [Action] = []
    ) -> PetDefinition {
        PetDefinition(
            id: petId,
            displayName: petId,
            description: "Action library test pet",
            assetName: "spritesheet.png",
            previewAssetName: "preview.png",
            frameSize: CGSizeCodable(width: 64, height: 64),
            spritesheet: SpriteSheetLayout(columns: 6, rows: 6),
            defaultScale: 1.0,
            catalog: makeStandardCatalog(petId: petId, extras: extras)
        )
    }

    private func writeTempPNG(width: Int, height: Int) -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("DesktopPetActionLibrary-\(UUID().uuidString).png")
        try! makePNGData(width: width, height: height).write(to: url)
        return url
    }

    private func makePNGData(width: Int, height: Int) -> Data {
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        }

        context.setFillColor(CGColor(red: 0, green: 0, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))

        guard let image = context.makeImage() else {
            return Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        }

        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, "public.png" as CFString, 1, nil) else {
            return Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        }
        CGImageDestinationAddImage(destination, image, nil)
        CGImageDestinationFinalize(destination)
        return data as Data
    }
}

private final class ActionLibraryActionPackOverrideStore: ActionPackOverrideStoring, @unchecked Sendable {
    var loaded: ActionPackOverrideSet?
    var saved: ActionPackOverrideSet?

    func load(petId: String) -> ActionPackOverrideSet? {
        loaded
    }

    func save(_ overrides: ActionPackOverrideSet, petId: String) throws {
        saved = overrides
        loaded = overrides
    }

    func delete(petId: String) {
        loaded = nil
        saved = nil
    }
}

@MainActor
private final class ActionLibraryTriggerService: ActionTriggerServicing {
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
