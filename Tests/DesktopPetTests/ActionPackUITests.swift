import Foundation
import DesktopPet

@MainActor
func runActionPackImportWizardViewModelTests() {
    let tests = ActionPackImportWizardViewModelTests()
    tests.initialPhaseIsSelectImage()
    tests.frameSelectionToggle()
    tests.selectAllAndDeselectAll()
    tests.proceedToConfigureRequiresSelectedFrames()
    tests.proceedToPreviewRequiresName()
    tests.saveRequiresName()
    tests.cancelCallsCallback()
    tests.goBackTransitions()
}

@MainActor
func runActionLibraryViewModelActionPackTests() {
    let tests = ActionLibraryViewModelActionPackTests()
    tests.sortedActionsIncludesExtras()
    tests.extrasAppearAfterRoleActions()
}

@MainActor
func runActionsMenuBuilderActionPackTests() {
    let tests = ActionsMenuBuilderActionPackTests()
    tests.menuIncludesExtraActions()
    tests.menuSortsExtrasAlphabetically()
}

// MARK: - Wizard ViewModel Tests

@MainActor
private struct ActionPackImportWizardViewModelTests {

    private func makeDefinition() -> PetDefinition {
        let catalog = PetActionCatalog(
            petId: "test-pet",
            actions: [
                Action(
                    id: ActionId(rawValue: "idle_default")!,
                    displayName: "Idle",
                    role: .idle,
                    frames: [SpriteFrame(column: 0, row: 0)],
                    frameDurationMs: 160,
                    loop: true
                )
            ],
            warnings: []
        )
        return PetDefinition(
            id: "test-pet",
            displayName: "Test",
            description: "test",
            assetName: "spritesheet.png",
            previewAssetName: nil,
            frameSize: CGSizeCodable(width: 256, height: 256),
            spritesheet: SpriteSheetLayout(columns: 4, rows: 1),
            defaultScale: 1.0,
            catalog: catalog,
            assetKind: .spriteSheet
        )
    }

    func initialPhaseIsSelectImage() {
        let vm = ActionPackImportWizardViewModel(
            definition: makeDefinition(),
            onSave: { _ in },
            onCancel: {}
        )
        expect(vm.phase == .selectImage, "initial phase should be selectImage")
    }

    func frameSelectionToggle() {
        let vm = ActionPackImportWizardViewModel(
            definition: makeDefinition(),
            onSave: { _ in },
            onCancel: {}
        )
        // Simulate having frames
        vm.frames = [
            ActionPackFrameItem(column: 0, row: 0, isSelected: true),
            ActionPackFrameItem(column: 1, row: 0, isSelected: true)
        ]
        vm.toggleFrame("0_0")
        expect(vm.frames[0].isSelected == false, "toggled frame should be deselected")
        expect(vm.frames[1].isSelected == true, "other frame should remain selected")
    }

    func selectAllAndDeselectAll() {
        let vm = ActionPackImportWizardViewModel(
            definition: makeDefinition(),
            onSave: { _ in },
            onCancel: {}
        )
        vm.frames = [
            ActionPackFrameItem(column: 0, row: 0, isSelected: false),
            ActionPackFrameItem(column: 1, row: 0, isSelected: false)
        ]
        vm.selectAllFrames()
        expect(vm.frames.allSatisfy { $0.isSelected }, "all should be selected")

        vm.deselectAllFrames()
        expect(vm.frames.allSatisfy { !$0.isSelected }, "all should be deselected")
    }

    func proceedToConfigureRequiresSelectedFrames() {
        let vm = ActionPackImportWizardViewModel(
            definition: makeDefinition(),
            onSave: { _ in },
            onCancel: {}
        )
        vm.frames = [
            ActionPackFrameItem(column: 0, row: 0, isSelected: false)
        ]
        vm.phase = .selectFrames
        vm.proceedToConfigure()
        expect(vm.phase == .selectFrames, "should stay in selectFrames when no frames selected")
        expect(vm.errorMessage != nil, "should show error")
    }

    func proceedToPreviewRequiresName() {
        let vm = ActionPackImportWizardViewModel(
            definition: makeDefinition(),
            onSave: { _ in },
            onCancel: {}
        )
        vm.phase = .configure
        vm.displayName = ""
        vm.proceedToPreview()
        expect(vm.phase == .configure, "should stay in configure when name is empty")
        expect(vm.errorMessage != nil, "should show error")
    }

    func saveRequiresName() {
        let vm = ActionPackImportWizardViewModel(
            definition: makeDefinition(),
            onSave: { _ in },
            onCancel: {}
        )
        vm.displayName = ""
        vm.frames = [ActionPackFrameItem(column: 0, row: 0)]
        vm.save()
        expect(vm.errorMessage != nil, "should show error when name is empty")
    }

    func cancelCallsCallback() {
        var cancelled = false
        let vm = ActionPackImportWizardViewModel(
            definition: makeDefinition(),
            onSave: { _ in },
            onCancel: { cancelled = true }
        )
        vm.cancel()
        expect(cancelled, "cancel callback should be called")
    }

    func goBackTransitions() {
        let vm = ActionPackImportWizardViewModel(
            definition: makeDefinition(),
            onSave: { _ in },
            onCancel: {}
        )
        vm.phase = .selectFrames
        vm.goBack()
        expect(vm.phase == .selectImage, "goBack from selectFrames should go to selectImage")

        vm.phase = .configure
        vm.goBack()
        expect(vm.phase == .selectFrames, "goBack from configure should go to selectFrames")

        vm.phase = .preview
        vm.goBack()
        expect(vm.phase == .configure, "goBack from preview should go to configure")
    }
}

// MARK: - ActionLibraryViewModel Tests

@MainActor
private struct ActionLibraryViewModelActionPackTests {

    func sortedActionsIncludesExtras() {
        let catalog = PetActionCatalog(
            petId: "test",
            actions: [
                makeAction(id: "idle_default", role: .idle),
                makeAction(id: "walk_default", role: .walking),
                makeAction(id: "wave_pack_wave", role: nil, displayName: "Wave")
            ],
            warnings: []
        )
        let sorted = ActionLibraryViewModel.sortedActions(in: catalog)
        expect(sorted.count == 3, "should include all actions")
        expect(sorted.contains { $0.id.rawValue == "wave_pack_wave" }, "should include extra action")
    }

    func extrasAppearAfterRoleActions() {
        let catalog = PetActionCatalog(
            petId: "test",
            actions: [
                makeAction(id: "idle_default", role: .idle),
                makeAction(id: "wave_pack_wave", role: nil, displayName: "Wave"),
                makeAction(id: "walk_default", role: .walking)
            ],
            warnings: []
        )
        let sorted = ActionLibraryViewModel.sortedActions(in: catalog)
        let idleIndex = sorted.firstIndex { $0.id.rawValue == "idle_default" }!
        let walkIndex = sorted.firstIndex { $0.id.rawValue == "walk_default" }!
        let waveIndex = sorted.firstIndex { $0.id.rawValue == "wave_pack_wave" }!
        expect(idleIndex < waveIndex, "role action should come before extra")
        expect(walkIndex < waveIndex, "role action should come before extra")
    }
}

// MARK: - ActionsMenuBuilder Tests

@MainActor
private struct ActionsMenuBuilderActionPackTests {

    func menuIncludesExtraActions() {
        let catalog = PetActionCatalog(
            petId: "test",
            actions: [
                makeAction(id: "idle_default", role: .idle),
                makeAction(id: "wave_pack_wave", role: nil, displayName: "Wave")
            ],
            warnings: []
        )
        let builder = ActionsMenuBuilder()
        let menu = builder.buildMenu(
            catalog: catalog,
            eligibility: { _ in .allowed },
            trigger: { _ in () }
        )
        let allTitles = menu.items.compactMap { $0.title }
        expect(allTitles.contains("Wave"), "menu should include pack action 'Wave'")
    }

    func menuSortsExtrasAlphabetically() {
        let catalog = PetActionCatalog(
            petId: "test",
            actions: [
                makeAction(id: "idle_default", role: .idle),
                makeAction(id: "zzz_extra", role: nil, displayName: "Zebra"),
                makeAction(id: "aaa_extra", role: nil, displayName: "Apple")
            ],
            warnings: []
        )
        let builder = ActionsMenuBuilder()
        let menu = builder.buildMenu(
            catalog: catalog,
            eligibility: { _ in .allowed },
            trigger: { _ in () }
        )
        let allTitles = menu.items.compactMap { $0.title }
        if let appleIndex = allTitles.firstIndex(of: "Apple"),
           let zebraIndex = allTitles.firstIndex(of: "Zebra") {
            expect(appleIndex < zebraIndex, "Apple should come before Zebra")
        }
    }
}
