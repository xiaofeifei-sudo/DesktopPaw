import AppKit
import DesktopPet
import Foundation
import ImageIO

@MainActor
func runActionValidation() {
    validateSchemaV1Fixture()
    validateSchemaV2Fixture()
    validateEightByNinePetdexGenericActions()
    validateSixByNinePetdexGenericActions()
    validateSixRowPetdexGenericActions()
    validateZeroRowPetdexFails()
    validateIdlePoolUniformSampling()
    validateMissingWalkingDoesNotStallIdle()
    validateClickedSamplesAvailableInteractionAction()
    validateReduceMotionWithExtras()
    validateMenuBarActionsMatchCatalog()
    validateContextMenuMatchesActionsMenu()
    validateActionLibraryShowsCompleteCatalog()
    validateActiveTriggersRejectBusyStates()
    validateActionTriggerThrottling()
    validateEditorPersistenceAfterRestart()
    validateV1FirstEditUpgradesManifest()
    validateV1LoadDoesNotRewriteManifest()
    validateImportWizardOverridesAutoInference()
    validateReleaseV1V2AndPetdexCompatibility()
    validateReleaseActionSurfacesShareCatalogSnapshot()
    validateEditorWritesOverrideWithoutManifestMutation()
    validateEditorWritesActionPackFrameDurationOverride()
    validateP3MoodTagWeights()
    validateP3AfterPetOneShotIdleScheduling()
    validateP3TimeMorningWeight()
    validateP3MultiTagMultiplier()
    validateP3SameRoleWeightedSampling()
    validateP3SameRoleAllZeroFallsBack()
    validateP3OpenTagNeutralAndEditorVisible()
    validateP3MoodSnapshotDebounce()
    validateReleaseReduceMotionKeepsWeightedSampling()
    validateActionCatalogErrorMessagesReadable()
    print("DesktopPetActionValidation passed")
}

private func validateSchemaV1Fixture() {
    let manifest = decodeManifest(v1FixtureJSON, "schema v1 fixture should decode")
    expect(manifest.schemaVersion == 1, "schema v1 fixture should preserve schemaVersion=1")
    expect(manifest.legacyAnimations != nil, "schema v1 fixture should load legacy animations")
    expect(manifest.actions.isEmpty, "schema v1 fixture should not decode actions directly")

    let definition = tryOrFail(try manifest.petDefinition(), "schema v1 fixture should produce a pet definition")
    expect(definition.catalog.actions.count == PetState.allCases.count, "schema v1 fixture should build one action per legacy state")
    expect(definition.catalog.extras.isEmpty, "schema v1 fixture should not create extras")

    for state in PetState.allCases {
        guard let clip = definition.animation(for: state) else {
            fail("schema v1 fixture should provide \(state.rawValue) animation")
        }
        expect(clip.frames.first?.row == expectedLegacyRows[state], "schema v1 \(state.rawValue) should keep its legacy row")
    }

    let encoded = tryOrFail(try JSONEncoder().encode(manifest), "schema v1 fixture should re-encode")
    let encodedJSON = jsonObject(from: encoded)
    expect(encodedJSON["schemaVersion"] as? Int == 2, "schema v1 fixture should encode as schema v2")
    expect(encodedJSON["animations"] == nil, "schema v1 fixture should encode without legacy animations")
}

private func validateSchemaV2Fixture() {
    let manifest = decodeManifest(v2FixtureJSON, "schema v2 fixture should decode")
    expect(manifest.schemaVersion == 2, "schema v2 fixture should preserve schemaVersion=2")
    expect(manifest.legacyAnimations == nil, "schema v2 fixture should not load legacy animations")
    expect(manifest.actions.count >= 8, "schema v2 fixture should load at least eight actions")

    let definition = tryOrFail(try manifest.petDefinition(), "schema v2 fixture should produce a pet definition")
    expect(definition.catalog.actions.count == manifest.actions.count, "schema v2 definition should keep all actions")
    expect(definition.catalog.extras.count >= 1, "schema v2 fixture should expose extras")
    expect(definition.animation(for: .dragging) != nil, "schema v2 fixture should include required dragging role")
}

private func validateEightByNinePetdexGenericActions() {
    let scratch = ActionValidationScratch(name: "DesktopPetActionValidation-8x9")
    defer { scratch.cleanUp() }

    let archiveURL = scratch.writeZip(name: "my-cat-v3-large.zip", entries: validPetdexEntries(id: "my-cat-v3-large", columns: 8, rows: 9))
    let petsRoot = scratch.root.appendingPathComponent("Pets", isDirectory: true)
    _ = tryOrFail(
        try makeImporter(columns: 8, rows: 9).importPackage(at: archiveURL, to: petsRoot, builtInPetId: "starter-pet"),
        "8x9 Petdex fixture should import"
    )

    let manifest = readImportedManifest(id: "my-cat-v3-large", petsRoot: petsRoot)
    expect(manifest.schemaVersion == 2, "8x9 Petdex import should write schema v2")
    expect(manifest.actions.count == 9, "8x9 Petdex import should write one generic action per row")
    expect(manifest.actions.allSatisfy { $0.role == nil }, "8x9 Petdex import should not force rows into legacy roles")
    expect(manifest.actions.map(\.id.rawValue) == (1...9).map { "action_\($0)" }, "8x9 Petdex actions should preserve row order")
}

private func validateSixByNinePetdexGenericActions() {
    let scratch = ActionValidationScratch(name: "DesktopPetActionValidation-6x9")
    defer { scratch.cleanUp() }

    let archiveURL = scratch.writeZip(name: "six-by-nine.zip", entries: validPetdexEntries(id: "six-by-nine", columns: 6, rows: 9))
    let petsRoot = scratch.root.appendingPathComponent("Pets", isDirectory: true)
    _ = tryOrFail(
        try makeImporter(columns: 6, rows: 9).importPackage(at: archiveURL, to: petsRoot, builtInPetId: "starter-pet"),
        "6x9 Petdex fixture should import"
    )

    let manifest = readImportedManifest(id: "six-by-nine", petsRoot: petsRoot)
    expect(manifest.actions.count == 9, "6x9 Petdex import should keep all rows as generic actions")
    expect(manifest.actions.allSatisfy { $0.role == nil }, "6x9 Petdex import should not assign fixed roles")
    expect(!warningsFileExists(id: "six-by-nine", petsRoot: petsRoot), "6x9 generic Petdex import should not write mapping warnings")
}

private func validateSixRowPetdexGenericActions() {
    let scratch = ActionValidationScratch(name: "DesktopPetActionValidation-6rows")
    defer { scratch.cleanUp() }

    let archiveURL = scratch.writeZip(name: "six-rows.zip", entries: validPetdexEntries(id: "six-rows", columns: 8, rows: 6))
    let petsRoot = scratch.root.appendingPathComponent("Pets", isDirectory: true)
    _ = tryOrFail(
        try makeImporter(columns: 8, rows: 6).importPackage(at: archiveURL, to: petsRoot, builtInPetId: "starter-pet"),
        "6-row Petdex fixture should import"
    )

    let manifest = readImportedManifest(id: "six-rows", petsRoot: petsRoot)
    expect(manifest.actions.count == 6, "6-row Petdex import should keep exactly six generic actions")
    expect(manifest.actions.allSatisfy { $0.role == nil }, "6-row Petdex import should not synthesize legacy roles")
    expect(manifest.actions.map(\.id.rawValue) == (1...6).map { "action_\($0)" }, "6-row Petdex actions should preserve row order")
    expect(!warningsFileExists(id: "six-rows", petsRoot: petsRoot), "6-row generic Petdex import should not write role synthesis warnings")
}

private func validateZeroRowPetdexFails() {
    let scratch = ActionValidationScratch(name: "DesktopPetActionValidation-0rows")
    defer { scratch.cleanUp() }

    let archiveURL = scratch.writeZip(name: "zero-rows.zip", entries: validPetdexEntries(id: "zero-rows", columns: 8, rows: 1))
    let petsRoot = scratch.root.appendingPathComponent("Pets", isDirectory: true)

    do {
        _ = try makeImporter(columns: 8, rows: 0).importPackage(at: archiveURL, to: petsRoot, builtInPetId: "starter-pet")
        fail("0-row Petdex fixture should fail import")
    } catch PetdexImportError.invalidSpritesheetLayout {
    } catch {
        fail("0-row Petdex fixture should fail with invalidSpritesheetLayout, got \(error)")
    }
}

private func validateIdlePoolUniformSampling() {
    let walking = makeAction(id: "walking_default", role: .walking)
    let extraA = makeAction(id: "extra_a", role: nil)
    let extraB = makeAction(id: "extra_b", role: nil)
    let pool = IdleBehaviorPool(candidates: [walking, extraA, extraB])
    let scheduler = UniformIdleBehaviorScheduler(randomNumberGenerator: EvenDistributionRandomNumberGenerator(iterations: 1000))

    var counts: [ActionId: Int] = [:]
    let context = IdleScheduleContext(now: Date(timeIntervalSince1970: 1_800_000_000), mood: 0.5, pendingAfterTag: nil)
    for _ in 0..<1000 {
        guard let action = scheduler.nextAction(in: pool, context: context) else {
            fail("uniform scheduler should return an action for a non-empty pool")
        }
        counts[action.id, default: 0] += 1
    }

    for action in pool.candidates {
        let count = counts[action.id, default: 0]
        expect((233...433).contains(count), "\(action.id.rawValue) sampled \(count) times; expected approximately one third")
    }
}

private func validateMissingWalkingDoesNotStallIdle() {
    let extra = makeAction(
        id: "extra_idle",
        role: nil,
        frames: [SpriteFrame(column: 0, row: 7), SpriteFrame(column: 1, row: 7)],
        frameDurationMs: 120,
        loop: false,
        nextActionId: .idle
    )
    let catalog = makeCatalog(missingRoles: [.walking, .happy, .eating, .jumping], extras: [extra])
    let rng = SequenceRandomNumberGenerator(values: [20, 0.0, 20])
    let engine = PetEngine(
        catalog: catalog,
        scheduler: UniformIdleBehaviorScheduler(randomNumberGenerator: rng),
        initialDate: referenceDate,
        isRandomWalkingEnabled: true,
        randomNumberGenerator: rng,
        now: { referenceDate }
    )

    _ = engine.handle(.tick(referenceDate.addingTimeInterval(20)))
    expect(engine.state.currentState == .idle, "missing walking should keep idle state when an extra is selected")
    expect(engine.currentActionId == extra.id, "missing walking should still allow idle extras to play")

    _ = engine.handle(.tick(referenceDate.addingTimeInterval(40)))
    expect(engine.state.currentState == .idle, "missing walking should remain stable across later idle ticks")
}

private func validateClickedSamplesAvailableInteractionAction() {
    let catalog = makeCatalog(missingRoles: [.jumping])
    let rng = FixedRandomNumberGenerator(value: 0)
    let engine = PetEngine(
        catalog: catalog,
        scheduler: UniformIdleBehaviorScheduler(randomNumberGenerator: rng),
        initialDate: referenceDate,
        isRandomWalkingEnabled: false,
        randomNumberGenerator: rng,
        now: { referenceDate }
    )

    _ = engine.handle(.clicked)
    expect(engine.state.currentState == .walking, "clicked should sample from available interaction actions")
    expect(engine.currentActionId == ActionId(rawValue: "walking_default"), "clicked sampling should expose the selected action id")
}

private func validateReduceMotionWithExtras() {
    let extra = makeAction(
        id: "extra_reduce_motion",
        role: nil,
        frames: [SpriteFrame(column: 0, row: 7), SpriteFrame(column: 1, row: 7)],
        frameDurationMs: 120,
        loop: false,
        nextActionId: .idle
    )
    let catalog = makeCatalog(extras: [extra])
    let definition = PetDefinition(
        id: "reduce-motion-pet",
        displayName: "Reduce Motion Pet",
        description: "Validation fixture.",
        assetName: "spritesheet.png",
        previewAssetName: nil,
        frameSize: CGSizeCodable(width: 128, height: 128),
        spritesheet: SpriteSheetLayout(columns: 2, rows: 8),
        defaultScale: 1.0,
        catalog: catalog
    )
    _ = tryOrFail(try definition.validated(), "reduce motion fixture should validate with extras")
    guard let clip = definition.clip(for: extra.id) else {
        fail("reduce motion fixture should expose extra clip")
    }

    var player = AnimationPlayer(clip: clip, reducedMotion: true)
    expect(player.currentFrame == SpriteFrame(column: 0, row: 7), "reduced motion should start on the first extra frame")
    let advance = player.advance(by: 240)
    expect(player.isComplete, "reduced motion should complete the extra after total duration")
    expect(advance.completedNextState == .idle, "reduced motion extra should still report idle completion")
}

@MainActor
private func validateMenuBarActionsMatchCatalog() {
    let catalog = makeP2Catalog(
        petId: "menu-bar-validation-pet",
        extraNames: ["Wave", "Blink", "Spin", "Nod", "Stretch", "Look"]
    )
    let commands = ActionValidationCommandSpy(catalog: catalog)
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    defer { NSStatusBar.system.removeStatusItem(statusItem) }

    let coordinator = AppCoordinator(
        petWindow: ActionValidationWindowSpy(),
        petCommands: commands,
        settingsWindow: ActionValidationSettingsSpy(),
        launchAtLogin: ActionValidationLaunchSpy(),
        application: ActionValidationApplicationSpy()
    )
    let controller = MenuBarController(coordinator: coordinator, statusItem: statusItem)
    controller.configure()

    guard let actionsMenu = statusItem.menu?.item(withTitle: "Actions")?.submenu else {
        fail("menu bar should expose an Actions submenu")
    }

    let items = actionMenuItems(in: actionsMenu)
    expect(items.map(\.title) == expectedActionTitles(in: catalog), "menu bar Actions submenu titles should match the catalog")
    expect(actionIds(in: items) == expectedActionIds(in: catalog), "menu bar Actions submenu action ids should match the catalog")
    expect(actionsMenu.item(withTitle: "More") != nil, "menu bar Actions submenu should keep overflow actions in More")
}

@MainActor
private func validateContextMenuMatchesActionsMenu() {
    let disabledId = ActionId(rawValue: "extra_context_5")!
    let catalog = makeP2Catalog(
        petId: "context-validation-pet",
        extraNames: ["Alpha", "Bravo", "Charlie", "Delta", "Echo", "Foxtrot"],
        extraIdPrefix: "extra_context"
    )
    let eligibility: (ActionId) -> ActionTriggerEligibility = { actionId in
        actionId == disabledId ? .rejectedBusy(reason: ActionTriggerService.busyReason) : .allowed
    }

    let actionsMenu = ActionsMenuBuilder().buildMenu(
        catalog: catalog,
        eligibility: eligibility,
        trigger: { _ in }
    )
    let contextMenu = PetContextMenuBuilder().buildMenu(
        catalog: catalog,
        eligibility: eligibility,
        trigger: { _ in }
    )

    expect(
        menuSnapshots(in: contextMenu) == menuSnapshots(in: actionsMenu),
        "right-click menu should match menu bar Actions submenu titles, overflow, and enabled state"
    )
}

@MainActor
private func validateActionLibraryShowsCompleteCatalog() {
    let catalog = makeP2Catalog(petId: "library-validation-pet", extraNames: ["Wave", "Blink"])
    let definition = makeValidationDefinition(petId: "library-validation-pet", catalog: catalog)
    let triggerService = ActionValidationTriggerService()
    var previewedActionIds: [ActionId] = []
    let model = ActionLibraryViewModel(
        definition: definition,
        triggerService: triggerService,
        previewProvider: { _, action, _ in
            previewedActionIds.append(action.id)
            return nil
        }
    )

    expect(model.rows.map(\.actionId) == expectedActionIds(in: catalog), "action library rows should list every catalog action in UI order")
    expect(model.rows.allSatisfy(\.canPlay), "action library rows should be playable when trigger eligibility is allowed")
    expect(previewedActionIds == expectedActionIds(in: catalog), "action library should request previews for every catalog action")
}

@MainActor
private func validateActiveTriggersRejectBusyStates() {
    let actionId = ActionId(rawValue: "idle_default")!
    let rejectedStates: [(PetState, Bool, String)] = [
        (.sleeping, false, "sleeping"),
        (.dragging, true, "dragging")
    ]

    for (state, isDragging, label) in rejectedStates {
        let commands = ActionValidationCommandSpy(
            catalog: makeP2Catalog(petId: "busy-\(label)", extraNames: []),
            state: state,
            isDragging: isDragging
        )
        let service = ActionTriggerService(commandHandler: commands, now: { referenceDate })
        let result = service.trigger(actionId: actionId)

        expect(result == .rejectedBusy(reason: ActionTriggerService.busyReason), "active trigger should reject \(label)")
        expect(commands.playedActionIds.isEmpty, "active trigger should not play action while \(label)")
    }

    for state in [PetState.happy, .eating, .jumping] {
        let commands = ActionValidationCommandSpy(
            catalog: makeP2Catalog(petId: "reaction-\(state.rawValue)", extraNames: []),
            state: state,
            isDragging: false
        )
        let service = ActionTriggerService(commandHandler: commands, now: { referenceDate })
        let result = service.trigger(actionId: actionId)

        expect(result == .allowed, "active trigger should allow menu actions during \(state.rawValue)")
        expect(commands.playedActionIds == [actionId], "active trigger should play action during \(state.rawValue)")
    }
}

@MainActor
private func validateActionTriggerThrottling() {
    let idleId = ActionId(rawValue: "idle_default")!
    let walkingId = ActionId(rawValue: "walking_default")!
    var now = referenceDate
    let commands = ActionValidationCommandSpy(catalog: makeP2Catalog(petId: "throttle-pet", extraNames: []))
    let service = ActionTriggerService(commandHandler: commands, now: { now })

    expect(service.trigger(actionId: idleId) == .allowed, "first action trigger should be allowed")
    now = now.addingTimeInterval(0.5)
    expect(service.trigger(actionId: walkingId) == .rejectedThrottled, "second action trigger inside 1s should be throttled")
    expect(commands.playedActionIds == [idleId], "throttling should allow only one action inside one second")

    now = now.addingTimeInterval(0.6)
    expect(service.trigger(actionId: walkingId) == .allowed, "action trigger after 1s should be allowed again")
    expect(commands.playedActionIds == [idleId, walkingId], "trigger after throttle window should play once")
}

@MainActor
private func validateEditorPersistenceAfterRestart() {
    let fixture = ActionValidationLibraryFixture(name: "DesktopPetActionValidation-editor-restart")
    defer { fixture.cleanUp() }

    let petId = "editor-restart-pet"
    let extra = makeAction(
        id: "extra_restart",
        displayName: "Wave",
        role: nil,
        tags: [],
        frames: [SpriteFrame(column: 0, row: 7)],
        nextActionId: .idle
    )
    tryOrFail(try fixture.writeV2Manifest(petId: petId, extras: [extra]), "editor persistence fixture should write v2 manifest")

    let definition = tryOrFail(try fixture.store.loadDefinition(id: petId), "editor persistence fixture should load before editing")
    guard let action = definition.catalog.resolve(actionId: extra.id) else {
        fail("editor persistence fixture should contain editable extra")
    }

    let model = ActionEditorViewModel(
        definition: definition,
        action: action,
        overrideStore: fixture.overrideStore,
        triggerService: ActionValidationTriggerService()
    )
    model.displayName = "Persistent Wave"
    model.setFrameDuration(index: 0, durationMs: 90)
    expect(model.addTag("vibe:cozy"), "editor should accept a non-reserved tag")
    expect(model.save(), "editor should save action metadata")

    let restartedStore = PetLibraryStore(rootDirectory: fixture.rootDirectory)
    let reloaded = tryOrFail(try restartedStore.loadDefinition(id: petId), "pet definition should reload after simulated restart")
    let reloadedAction = reloaded.catalog.resolve(actionId: extra.id)
    expect(reloadedAction?.displayName == "Persistent Wave", "edited displayName should persist after restart")
    expect(reloadedAction?.tags == [ActionTag(rawValue: "vibe:cozy")!], "edited tags should persist after restart")
    expect(reloadedAction?.frames.first?.durationMs == 90, "edited frame duration should persist after restart")
}

@MainActor
private func validateV1FirstEditUpgradesManifest() {
    let fixture = ActionValidationLibraryFixture(name: "DesktopPetActionValidation-v1-edit")
    defer { fixture.cleanUp() }

    let petId = "v1-first-edit-pet"
    let originalData = validationV1ManifestJSON(id: petId)
    tryOrFail(try fixture.writeManifest(petId: petId, data: originalData), "v1 first edit fixture should write manifest")

    let definition = tryOrFail(try fixture.store.loadDefinition(id: petId), "v1 package should load before first edit")
    guard let action = definition.catalog.resolve(actionId: ActionId(rawValue: "idle_default")!) else {
        fail("v1 package should expose idle action in memory")
    }

    let model = ActionEditorViewModel(
        definition: definition,
        action: action,
        overrideStore: fixture.overrideStore,
        triggerService: ActionValidationTriggerService()
    )
    model.displayName = "Edited Idle"
    expect(model.save(), "first user edit on v1 package should save")

    let upgradedData = tryOrFail(try Data(contentsOf: fixture.manifestURL(for: petId)), "upgraded v1 manifest should be readable")
    expect(upgradedData != originalData, "first edit should rewrite v1 manifest bytes")
    let upgradedManifest = tryOrFail(try JSONDecoder().decode(PetPackageManifest.self, from: upgradedData), "upgraded v1 manifest should decode")
    expect(upgradedManifest.schemaVersion == 2, "first edit should upgrade manifest to schemaVersion=2")
    expect(upgradedManifest.legacyAnimations == nil, "upgraded manifest should not retain legacy animations")
    expect(jsonObject(from: upgradedData)["animations"] == nil, "upgraded manifest JSON should not write animations")
    expect(FileManager.default.fileExists(atPath: fixture.overrideStore.overrideFileURL(for: petId).path), "first edit should write action-overrides.json")
}

private func validateV1LoadDoesNotRewriteManifest() {
    let fixture = ActionValidationLibraryFixture(name: "DesktopPetActionValidation-v1-load")
    defer { fixture.cleanUp() }

    let petId = "v1-load-pet"
    let originalData = validationV1ManifestJSON(id: petId)
    tryOrFail(try fixture.writeManifest(petId: petId, data: originalData), "v1 load fixture should write manifest")

    _ = tryOrFail(try fixture.store.loadDefinition(id: petId), "v1 package should load without editing")
    let loadedData = tryOrFail(try Data(contentsOf: fixture.manifestURL(for: petId)), "v1 manifest should remain readable after load")
    expect(loadedData == originalData, "loading a v1 package should not rewrite manifest bytes")
}

@MainActor
private func validateImportWizardOverridesAutoInference() {
    let fixture = ActionValidationLibraryFixture(name: "DesktopPetActionValidation-import-wizard")
    defer { fixture.cleanUp() }

    let petId = "wizard-override-pet"
    tryOrFail(try fixture.writePetdexLikeV2Manifest(petId: petId), "import wizard fixture should write v2 manifest")
    let definition = tryOrFail(try fixture.store.loadDefinition(id: petId), "import wizard fixture should load")
    let extraId = ActionId(rawValue: "extra_1")!
    expect(definition.catalog.resolve(actionId: extraId)?.role == nil, "Petdex row 7 should initially be inferred as an extra")

    let model = ImportWizardViewModel(
        definition: definition,
        overrideStore: fixture.overrideStore,
        previewProvider: { _, _, _ in nil }
    )
    expect(
        model.rows.contains { $0.rowIndex == 7 && $0.actionId == extraId && $0.selection == .namedExtra("Extra Row 7") },
        "import wizard should expose auto-inferred row 7 as a named extra"
    )

    model.assign(rowIndex: 7, role: .happy, customName: nil)
    expect(model.commit(), "import wizard should commit explicit row 7 role override")

    let reloaded = tryOrFail(try fixture.store.loadDefinition(id: petId), "import wizard fixture should reload after override")
    let overriddenAction = reloaded.catalog.resolve(actionId: extraId)
    expect(overriddenAction?.role == .happy, "import wizard override should replace auto-inferred extra role")
    expect(overriddenAction?.frames.first?.row == 7, "import wizard override should keep the original extra row frames")
    expect(reloaded.catalog.actions(for: .happy).contains { $0.id == extraId }, "row 7 action should participate in the overridden role")
}

private func validateReleaseV1V2AndPetdexCompatibility() {
    let fixture = ActionValidationLibraryFixture(name: "DesktopPetActionValidation-release-compat")
    let scratch = ActionValidationScratch(name: "DesktopPetActionValidation-release-compat-archives")
    defer {
        fixture.cleanUp()
        scratch.cleanUp()
    }

    tryOrFail(
        try fixture.writeManifest(petId: "release-v1-pet", data: validationV1ManifestJSON(id: "release-v1-pet")),
        "release compatibility should write v1 manifest"
    )
    tryOrFail(
        try fixture.writeV2Manifest(
            petId: "release-v2-pet",
            extras: [makeAction(id: "release_extra", role: nil, frames: [SpriteFrame(column: 0, row: 7)], nextActionId: .idle)]
        ),
        "release compatibility should write v2 manifest"
    )

    let eightByNineArchive = scratch.writeZip(
        name: "release-petdex-8x9.zip",
        entries: validPetdexEntries(id: "release-petdex-8x9", columns: 8, rows: 9)
    )
    _ = tryOrFail(
        try makeImporter(columns: 8, rows: 9).importPackage(
            at: eightByNineArchive,
            to: fixture.store.importedPetsDirectoryURL,
            builtInPetId: fixture.store.builtInPetId
        ),
        "release compatibility should import 8x9 Petdex package"
    )

    let oneRowArchive = scratch.writeZip(
        name: "release-petdex-1row.zip",
        entries: validPetdexEntries(id: "release-petdex-1row", columns: 8, rows: 1)
    )
    _ = tryOrFail(
        try makeImporter(columns: 8, rows: 1).importPackage(
            at: oneRowArchive,
            to: fixture.store.importedPetsDirectoryURL,
            builtInPetId: fixture.store.builtInPetId
        ),
        "release compatibility should import one-row Petdex package with synthesis"
    )

    let v1Definition = tryOrFail(try fixture.store.loadDefinition(id: "release-v1-pet"), "release v1 package should load")
    let v2Definition = tryOrFail(try fixture.store.loadDefinition(id: "release-v2-pet"), "release v2 package should load")
    let eightByNineDefinition = tryOrFail(try fixture.store.loadDefinition(id: "release-petdex-8x9"), "release Petdex 8x9 package should load")
    let oneRowDefinition = tryOrFail(try fixture.store.loadDefinition(id: "release-petdex-1row"), "release Petdex one-row package should load")

    expect(v1Definition.id == "release-v1-pet", "release v1 package should coexist without falling back")
    expect(v1Definition.catalog.actions.count == PetState.allCases.count, "release v1 package should expose legacy roles as actions")
    expect(v2Definition.catalog.extras.map(\.id.rawValue) == ["release_extra"], "release v2 package should keep declared extras")
    expect(eightByNineDefinition.catalog.actions.count == 9, "release Petdex 8x9 package should expose one generic action per row")
    expect(eightByNineDefinition.catalog.actions.allSatisfy { $0.role == nil }, "release Petdex 8x9 package should keep row actions role-less")

    guard let action = oneRowDefinition.catalog.actions.first,
          let idleClip = oneRowDefinition.animation(for: .idle),
          let walkingFallbackClip = oneRowDefinition.animation(for: .walking) else {
        fail("release Petdex one-row package should expose a generic fallback action")
    }
    expect(oneRowDefinition.catalog.actions.count == 1, "release Petdex one-row package should keep one generic action")
    expect(action.id.rawValue == "action_1", "release Petdex one-row action should use the generic row id")
    expect(action.frames == rowFrames(row: 0, columns: 8), "release Petdex one-row action should use row 0 frames")
    expect(oneRowDefinition.catalog.actions(for: .dragging).isEmpty, "release Petdex one-row package should not synthesize dragging")
    expect(walkingFallbackClip.frames == idleClip.frames, "release Petdex missing walking should use the default action fallback")
    expect(!warningsFileExists(id: "release-petdex-1row", petsRoot: fixture.store.importedPetsDirectoryURL), "release Petdex one-row generic import should not write role fallback warnings")
}

@MainActor
private func validateReleaseActionSurfacesShareCatalogSnapshot() {
    let catalog = makeP2Catalog(
        petId: "release-shared-catalog-pet",
        extraNames: ["Wave", "Blink", "Spin", "Nod", "Stretch", "Look"]
    )
    let definition = makeValidationDefinition(petId: "release-shared-catalog-pet", catalog: catalog)
    let commands = ActionValidationCommandSpy(catalog: catalog)
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    defer { NSStatusBar.system.removeStatusItem(statusItem) }

    let coordinator = AppCoordinator(
        petWindow: ActionValidationWindowSpy(),
        petCommands: commands,
        settingsWindow: ActionValidationSettingsSpy(),
        launchAtLogin: ActionValidationLaunchSpy(),
        application: ActionValidationApplicationSpy()
    )
    let controller = MenuBarController(coordinator: coordinator, statusItem: statusItem)
    controller.configure()

    guard let menuBarActions = statusItem.menu?.item(withTitle: "Actions")?.submenu else {
        fail("release shared catalog should expose menu bar Actions submenu")
    }

    let contextMenu = PetContextMenuBuilder().buildMenu(
        catalog: catalog,
        eligibility: { _ in .allowed },
        trigger: { _ in }
    )
    let libraryModel = ActionLibraryViewModel(
        definition: definition,
        triggerService: ActionValidationTriggerService(),
        previewProvider: { _, _, _ in nil }
    )

    let expectedIds = expectedActionIds(in: catalog)
    let expectedTitles = expectedActionTitles(in: catalog)
    let menuBarItems = actionMenuItems(in: menuBarActions)
    let contextItems = actionMenuItems(in: contextMenu)

    expect(actionIds(in: menuBarItems) == expectedIds, "release menu bar should use the shared catalog action ids")
    expect(actionIds(in: contextItems) == expectedIds, "release right-click menu should use the shared catalog action ids")
    expect(libraryModel.rows.map(\.actionId) == expectedIds, "release settings action library should use the shared catalog action ids")
    expect(menuBarItems.map(\.title) == expectedTitles, "release menu bar should use shared catalog action titles")
    expect(contextItems.map(\.title) == expectedTitles, "release right-click menu should use shared catalog action titles")
    expect(libraryModel.rows.map(\.displayName) == expectedTitles, "release settings action library should use shared catalog action titles")
}

@MainActor
private func validateEditorWritesOverrideWithoutManifestMutation() {
    let fixture = ActionValidationLibraryFixture(name: "DesktopPetActionValidation-editor-no-manifest-mutation")
    defer { fixture.cleanUp() }

    let petId = "editor-no-manifest-mutation-pet"
    let extra = makeAction(
        id: "extra_original_package",
        displayName: "Original Wave",
        role: nil,
        tags: [],
        frames: [SpriteFrame(column: 0, row: 7), SpriteFrame(column: 1, row: 7)],
        nextActionId: .idle
    )
    tryOrFail(try fixture.writeV2Manifest(petId: petId, extras: [extra]), "editor no-mutation fixture should write v2 manifest")

    let manifestBefore = tryOrFail(try Data(contentsOf: fixture.manifestURL(for: petId)), "editor no-mutation fixture should read manifest before edit")
    let definition = tryOrFail(try fixture.store.loadDefinition(id: petId), "editor no-mutation fixture should load before edit")
    guard let action = definition.catalog.resolve(actionId: extra.id) else {
        fail("editor no-mutation fixture should contain editable extra")
    }

    let model = ActionEditorViewModel(
        definition: definition,
        action: action,
        overrideStore: fixture.overrideStore,
        triggerService: ActionValidationTriggerService()
    )
    model.displayName = "Override Wave"
    model.setFrameDuration(index: 0, durationMs: 90)
    model.setFrameDuration(index: 1, durationMs: 240)
    expect(model.addTag("vibe:quiet"), "editor no-mutation fixture should accept metadata tag")
    expect(model.save(), "editor no-mutation fixture should save override metadata")

    let manifestAfter = tryOrFail(try Data(contentsOf: fixture.manifestURL(for: petId)), "editor no-mutation fixture should read manifest after edit")
    expect(manifestAfter == manifestBefore, "editor should write override metadata without mutating the original v2 manifest")

    let overrides = tryOrFail(try fixture.overrideStore.load(petId: petId), "editor should write override file")
    let override = overrides?.override(for: extra.id)
    expect(override?.displayName == "Override Wave", "editor override should contain edited display name")
    expect(override?.tags == [ActionTag(rawValue: "vibe:quiet")!], "editor override should contain edited tags")
    expect(override?.frameDurationsMs == [90, 240], "editor override should contain edited frame durations")

    let rawManifest = tryOrFail(try JSONDecoder().decode(PetPackageManifest.self, from: manifestAfter), "editor no-mutation manifest should decode")
    let rawExtra = rawManifest.actions.first { $0.id == extra.id }
    expect(rawExtra?.displayName == "Original Wave", "original manifest action display name should remain unchanged")
    expect(rawExtra?.tags.isEmpty == true, "original manifest action tags should remain unchanged")
    expect(rawExtra?.frames == extra.frames, "original manifest action frames should remain unchanged")
    expect(rawExtra?.frameDurationMs == extra.frameDurationMs, "original manifest action timing should remain unchanged")
}

@MainActor
private func validateEditorWritesActionPackFrameDurationOverride() {
    let fixture = ActionValidationLibraryFixture(name: "DesktopPetActionValidation-editor-action-pack-duration")
    defer { fixture.cleanUp() }

    let petId = "editor-action-pack-duration-pet"
    let packed = makeAction(
        id: "wave_pack_123",
        displayName: "Wave",
        role: nil,
        assetId: "wave_pack/wave_sheet",
        frames: [
            SpriteFrame(column: 0, row: 0),
            SpriteFrame(column: 9, row: 0)
        ],
        frameDurationMs: 120,
        nextActionId: .idle
    )
    let catalog = PetActionCatalog(petId: petId, actions: p2RoleActions() + [packed], warnings: [])
    let definition = makeValidationDefinition(petId: petId, catalog: catalog)
    let actionPackOverrideStore = FileActionPackOverrideStore(petsDirectoryURL: fixture.store.importedPetsDirectoryURL)

    let model = ActionEditorViewModel(
        definition: definition,
        action: packed,
        overrideStore: fixture.overrideStore,
        actionPackOverrideStore: actionPackOverrideStore,
        triggerService: ActionValidationTriggerService()
    )
    model.displayName = "Slow Wave"
    model.setFrameDuration(index: 0, durationMs: 80)
    model.setFrameDuration(index: 1, durationMs: 260)
    expect(model.save(), "action pack editor should save frame duration overrides")

    let overrides = actionPackOverrideStore.load(petId: petId)
    let override = overrides?.override(for: packed.id)
    expect(override?.displayName == "Slow Wave", "action pack override should contain display name edit")
    expect(override?.frameDurationsMs == [80, 260], "action pack override should contain frame duration edits")
}

private func validateP3MoodTagWeights() {
    let evaluator = DefaultTagConditionEvaluator()
    let highContext = TagConditionContext(
        moodLevel: MoodLevelClassifier.level(for: MoodLevelClassifier.highThreshold),
        timeSlots: [.afternoon, .workday]
    )
    let high = makeAction(id: "p3_mood_high_extra", role: nil, tags: [tag("mood:high")])
    let low = makeAction(id: "p3_mood_low_extra", role: nil, tags: [tag("mood:low")])

    expect(evaluator.weight(for: high, context: highContext) == 3, "P3 mood:high should be weighted x3 at mood >= 0.66")
    expect(evaluator.weight(for: low, context: highContext) == 0, "P3 mood:low should be weighted 0 at mood >= 0.66")
}

private func validateP3AfterPetOneShotIdleScheduling() {
    let initialDate = validationDate(hour: 9)
    let afterPet = makeAction(id: "p3_after_pet_extra", role: nil, tags: [tag("after.pet")], nextActionId: .idle)
    let neutral = makeAction(id: "p3_after_neutral_extra", role: nil, nextActionId: .idle)
    let afterTagState = DefaultAfterTagState()
    let rng = SequenceRandomNumberGenerator(values: [20, 0, 20, 3.5, 20, 1.5, 20])
    let engine = PetEngine(
        catalog: makeCatalog(missingRoles: [.walking], extras: [afterPet, neutral]),
        moodSnapshotProvider: SystemMoodSnapshot(nowProvider: { initialDate }),
        afterTagState: afterTagState,
        initialState: initialRuntimeState(at: initialDate, mood: 0.6),
        initialDate: initialDate,
        isRandomWalkingEnabled: true,
        randomNumberGenerator: rng,
        now: { initialDate }
    )

    _ = engine.handle(.pet)
    _ = engine.handle(.tick(initialDate.addingTimeInterval(1.3)))
    expect(afterTagState.pending == tag("after.pet"), "P3 happy completion should mark pending after.pet")

    _ = engine.handle(.tick(initialDate.addingTimeInterval(21.3)))
    expect(engine.currentActionId == afterPet.id, "P3 after.pet should be prioritized on the next idle schedule after happy")
    expect(afterTagState.pending == nil, "P3 after.pet hit should consume the pending after tag")

    _ = engine.handle(.tick(initialDate.addingTimeInterval(41.3)))
    expect(engine.currentActionId != afterPet.id, "P3 after.pet should not stay weighted after the one-shot hit")
}

private func validateP3TimeMorningWeight() {
    let evaluator = DefaultTagConditionEvaluator()
    let morning = makeAction(id: "p3_time_morning_extra", role: nil, tags: [tag("time.morning")])

    for (hour, minute) in [(5, 0), (11, 59)] {
        let slots = TimeOfDayClassifier.slots(for: validationDate(hour: hour, minute: minute))
        let context = TagConditionContext(moodLevel: .medium, timeSlots: slots)
        expect(evaluator.weight(for: morning, context: context) == 3, "P3 time.morning should be weighted x3 from 05:00 through 11:59")
    }
}

private func validateP3MultiTagMultiplier() {
    let evaluator = DefaultTagConditionEvaluator()
    let multi = makeAction(
        id: "p3_multi_tag_extra",
        role: nil,
        tags: [tag("mood:high"), tag("time.morning")]
    )
    let context = TagConditionContext(moodLevel: .high, timeSlots: [.morning, .workday])

    expect(evaluator.weight(for: multi, context: context) == 9, "P3 multiple matching tags should multiply independently to x9")
}

private func validateP3SameRoleWeightedSampling() {
    let initialDate = validationDate(hour: 9)
    let lowHappy = makeAction(id: "p3_happy_low", role: .happy, tags: [tag("mood:low")], nextActionId: .idle)
    let highHappy = makeAction(id: "p3_happy_high", role: .happy, tags: [tag("mood:high")], nextActionId: .idle)
    let catalog = PetActionCatalog(
        petId: "p3-same-role-weighted",
        actions: [makeRoleAction(for: .idle), makeRoleAction(for: .dragging), lowHappy, highHappy],
        warnings: []
    )
    let engine = PetEngine(
        catalog: catalog,
        initialState: initialRuntimeState(at: initialDate, mood: 0.6),
        initialDate: initialDate,
        isRandomWalkingEnabled: false,
        randomNumberGenerator: FixedRandomNumberGenerator(value: 0),
        now: { initialDate }
    )

    _ = engine.handle(.pet)

    expect(engine.state.currentState == .happy, "P3 same-role weighted sampling should keep the requested happy role")
    expect(engine.currentActionId == highHappy.id, "P3 same-role happy actions should be sampled by current tag weight")
}

private func validateP3SameRoleAllZeroFallsBack() {
    let initialDate = validationDate(hour: 9)
    let lowHappy = makeAction(id: "p3_happy_low_only", role: .happy, tags: [tag("mood:low")], nextActionId: .idle)
    let catalog = PetActionCatalog(
        petId: "p3-same-role-fallback",
        actions: [makeRoleAction(for: .idle), makeRoleAction(for: .dragging), lowHappy],
        warnings: []
    )
    let engine = PetEngine(
        catalog: catalog,
        initialState: initialRuntimeState(at: initialDate, mood: 0.7),
        initialDate: initialDate,
        isRandomWalkingEnabled: false,
        randomNumberGenerator: FixedRandomNumberGenerator(value: 0),
        now: { initialDate }
    )

    _ = engine.handle(.pet)

    expect(engine.state.currentState == .idle, "P3 all-zero same-role candidates should fall back through happy -> idle")
    expect(engine.currentActionId == ActionId(rawValue: "idle_default"), "P3 all-zero same-role fallback should select idle_default")
}

@MainActor
private func validateP3OpenTagNeutralAndEditorVisible() {
    let openTag = tag("vibe:cozy")
    let open = makeAction(id: "p3_open_tag_extra", role: nil, tags: [openTag], nextActionId: .idle)
    let neutral = makeAction(id: "p3_open_neutral_extra", role: nil, nextActionId: .idle)
    let context = TagConditionContext(moodLevel: .medium, timeSlots: [.afternoon, .workday])
    let evaluator = DefaultTagConditionEvaluator()
    let sampled = DefaultWeightedActionSampler().sample(
        [open, neutral],
        context: context,
        rng: FixedRandomNumberGenerator(value: 0.5)
    )

    expect(evaluator.weight(for: open, context: context) == 1, "P3 open tags should be neutral in weight calculation")
    expect(sampled == open, "P3 open tags should not exclude or boost scheduler candidates")

    let catalog = PetActionCatalog(petId: "p3-open-tag-display", actions: p2RoleActions() + [open], warnings: [])
    let definition = makeValidationDefinition(petId: "p3-open-tag-display", catalog: catalog)
    let libraryModel = ActionLibraryViewModel(
        definition: definition,
        triggerService: ActionValidationTriggerService(),
        previewProvider: { _, _, _ in nil }
    )
    guard let row = libraryModel.rows.first(where: { $0.actionId == open.id }) else {
        fail("P3 action library should include the open-tag action row")
    }
    expect(row.tags == [openTag], "P3 action library row should display open tag strings")

    let editorModel = ActionEditorViewModel(
        definition: definition,
        action: open,
        overrideStore: PetActionOverrideStore(),
        triggerService: ActionValidationTriggerService()
    )
    expect(editorModel.tags == [openTag.rawValue], "P3 editor should expose open tag strings for editing")
}

private func validateP3MoodSnapshotDebounce() {
    let initialDate = validationDate(hour: 9)
    let high = makeAction(id: "p3_snapshot_high_extra", role: nil, tags: [tag("mood:high")], nextActionId: .idle)
    let low = makeAction(id: "p3_snapshot_low_extra", role: nil, tags: [tag("mood:low")], nextActionId: .idle)
    let snapshotProvider = BoundaryFluctuationMoodSnapshotProvider(capturedAt: initialDate)
    let engine = PetEngine(
        catalog: makeCatalog(missingRoles: [.walking, .happy, .eating, .jumping], extras: [high, low]),
        moodSnapshotProvider: snapshotProvider,
        initialState: initialRuntimeState(at: initialDate, mood: MoodLevelClassifier.highThreshold),
        initialDate: initialDate,
        isRandomWalkingEnabled: true,
        randomNumberGenerator: SequenceRandomNumberGenerator(values: [20, 2.5]),
        now: { initialDate }
    )

    _ = engine.handle(.tick(initialDate.addingTimeInterval(20)))

    expect(snapshotProvider.callCount == 1, "P3 idle scheduling should take exactly one mood snapshot per sampling pass")
    expect(engine.currentActionId == high.id, "P3 scheduling should use the captured mood level for the whole sampling pass")
}

private func validateReleaseReduceMotionKeepsWeightedSampling() {
    let high = makeAction(
        id: "release_reduce_high",
        role: nil,
        tags: [tag("mood:high")],
        frames: [SpriteFrame(column: 0, row: 7), SpriteFrame(column: 1, row: 7)],
        nextActionId: .idle
    )
    let low = makeAction(
        id: "release_reduce_low",
        role: nil,
        tags: [tag("mood:low")],
        frames: [SpriteFrame(column: 0, row: 8), SpriteFrame(column: 1, row: 8)],
        nextActionId: .idle
    )
    let scheduler = WeightedIdleBehaviorScheduler(randomNumberGenerator: FixedRandomNumberGenerator(value: 0))
    let sampled = scheduler.nextAction(
        in: IdleBehaviorPool(candidates: [low, high]),
        context: IdleScheduleContext(
            now: validationDate(hour: 9),
            mood: 0.8,
            pendingAfterTag: nil,
            moodLevel: .high,
            timeSlots: [.morning, .workday]
        )
    )
    expect(sampled?.id == high.id, "release reduce motion should not disable tag-weighted sampling")

    let definition = makeValidationDefinition(
        petId: "release-reduce-motion-weighted-pet",
        catalog: makeCatalog(missingRoles: [.walking], extras: [low, high])
    )
    guard let clip = definition.clip(for: high.id) else {
        fail("release reduce motion weighted action should expose a clip")
    }
    var player = AnimationPlayer(clip: clip, reducedMotion: true)
    expect(player.currentFrame == high.frames.first, "release reduce motion should start sampled action on its first frame")
    let advance = player.advance(by: high.frameDurationMs * high.frames.count)
    expect(player.isComplete, "release reduce motion should degrade playback without changing sampling")
    expect(advance.completedNextState == .idle, "release reduce motion sampled action should still complete to idle")
}

private func validateActionCatalogErrorMessagesReadable() {
    let cases: [(error: ActionCatalogError, tokens: [String])] = [
        (.duplicateActionId(ActionId(rawValue: "idle_default")!), ["duplicate", "idle_default"]),
        (.missingRequiredRole(.dragging), ["missing", "dragging"]),
        (.unsupportedSchemaVersion(3), ["unsupported", "3"])
    ]

    for entry in cases {
        let description = entry.error.errorDescription ?? ""
        expect(!description.isEmpty, "\(entry.error) should expose a user-facing error description")
        expect(description.count <= 180, "\(entry.error) error description should stay concise")
        expect(!description.localizedCaseInsensitiveContains("Optional("), "\(entry.error) error description should not leak debug formatting")
        expect(!description.localizedCaseInsensitiveContains("ActionCatalogError"), "\(entry.error) error description should not expose enum type names")
        for token in entry.tokens {
            expect(
                description.localizedCaseInsensitiveContains(token),
                "\(entry.error) error description should mention \(token)"
            )
        }
    }
}

private let referenceDate = Date(timeIntervalSince1970: 1_800_000_000)

private let expectedLegacyRows: [PetState: Int] = [
    .idle: 0,
    .walking: 1,
    .sleeping: 2,
    .happy: 3,
    .eating: 4,
    .jumping: 5,
    .dragging: 6
]

private func decodeManifest(_ data: Data, _ message: String) -> PetPackageManifest {
    tryOrFail(try JSONDecoder().decode(PetPackageManifest.self, from: data), message)
}

private func jsonObject(from data: Data) -> [String: Any] {
    do {
        guard let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            fail("encoded payload should be a JSON object")
        }
        return dict
    } catch {
        fail("JSON deserialization failed: \(error)")
    }
}

private func makeImporter(columns: Int, rows: Int) -> PetdexPackageImporter {
    PetdexPackageImporter(
        mappingProvider: DefaultPetdexAnimationMappingProvider(columns: columns, rows: rows),
        imageConvention: PetdexSpriteSheetConvention(columns: columns, rows: rows)
    )
}

private func validPetdexEntries(id: String, columns: Int, rows: Int) -> [ActionValidationZipEntry] {
    [
        .stored(name: "pet.json", data: validPetdexManifestData(id: id)),
        .stored(name: "spritesheet.png", data: makePNGData(width: max(columns, 1) * 2, height: max(rows, 1) * 2))
    ]
}

private func validPetdexManifestData(id: String) -> Data {
    Data(
        """
        {
          "id": "\(id)",
          "displayName": "Beibei",
          "description": "A Petdex validation package.",
          "spritesheetPath": "spritesheet.png"
        }
        """.utf8
    )
}

private func readImportedManifest(id: String, petsRoot: URL) -> PetPackageManifest {
    let url = petsRoot
        .appendingPathComponent(id, isDirectory: true)
        .appendingPathComponent(ConvertedPetPackage.manifestFileName)
    return tryOrFail(try JSONDecoder().decode(PetPackageManifest.self, from: Data(contentsOf: url)), "imported manifest should decode")
}

private func readWarnings(id: String, petsRoot: URL) -> [ValidationWarningSidecarEntry] {
    let url = petsRoot
        .appendingPathComponent(id, isDirectory: true)
        .appendingPathComponent(ConvertedPetPackage.importWarningsFileName)
    return tryOrFail(try JSONDecoder().decode([ValidationWarningSidecarEntry].self, from: Data(contentsOf: url)), "import warnings should decode")
}

private func warningsFileExists(id: String, petsRoot: URL) -> Bool {
    let url = petsRoot
        .appendingPathComponent(id, isDirectory: true)
        .appendingPathComponent(ConvertedPetPackage.importWarningsFileName)
    return FileManager.default.fileExists(atPath: url.path)
}

private func rowFrames(row: Int, columns: Int) -> [SpriteFrame] {
    (0..<columns).map { SpriteFrame(column: $0, row: row) }
}

private func makeCatalog(missingRoles: Set<ActionRole> = [], extras: [Action] = []) -> PetActionCatalog {
    let allRoles: [ActionRole] = [.idle, .walking, .sleeping, .happy, .eating, .jumping, .dragging]
    var actions = allRoles
        .filter { !missingRoles.contains($0) }
        .map(makeRoleAction)
    actions.append(contentsOf: extras)
    return PetActionCatalog(petId: "action-validation-pet", actions: actions, warnings: [])
}

private func makeRoleAction(for role: ActionRole) -> Action {
    switch role {
    case .idle:
        makeAction(id: "idle_default", role: role, loop: true, nextActionId: nil)
    case .walking:
        makeAction(id: "walking_default", role: role, loop: true, nextActionId: nil)
    case .sleeping:
        makeAction(id: "sleeping_default", role: role, loop: true, nextActionId: nil)
    case .happy:
        makeAction(id: "happy_default", role: role, loop: false, nextActionId: .idle)
    case .eating:
        makeAction(id: "eating_default", role: role, loop: false, nextActionId: .idle)
    case .jumping:
        makeAction(id: "jumping_default", role: role, loop: false, nextActionId: .idle)
    case .dragging:
        makeAction(id: "dragging_default", role: role, loop: true, nextActionId: nil)
    }
}

private func makeAction(
    id rawId: String,
    displayName: String? = nil,
    role: ActionRole?,
    tags: [ActionTag] = [],
    assetId: String? = nil,
    frames: [SpriteFrame] = [SpriteFrame(column: 0, row: 0)],
    frameDurationMs: Int = 120,
    loop: Bool = false,
    nextActionId: ActionId? = nil
) -> Action {
    Action(
        id: ActionId(rawValue: rawId)!,
        displayName: displayName ?? rawId,
        role: role,
        tags: tags,
        assetId: assetId,
        frames: frames,
        frameDurationMs: frameDurationMs,
        loop: loop,
        nextActionId: nextActionId
    )
}

private func tag(_ rawValue: String) -> ActionTag {
    guard let tag = ActionTag(rawValue: rawValue) else {
        fail("validation tag should be valid: \(rawValue)")
    }
    return tag
}

private func validationDate(hour: Int, minute: Int = 0) -> Date {
    var components = DateComponents()
    components.calendar = Calendar.current
    components.timeZone = Calendar.current.timeZone
    components.year = 2026
    components.month = 5
    components.day = 14
    components.hour = hour
    components.minute = minute
    guard let date = components.date else {
        fail("validation date should be constructible")
    }
    return date
}

private func initialRuntimeState(at date: Date, mood: Double) -> PetRuntimeState {
    PetRuntimeState(
        currentState: .idle,
        mood: mood,
        hunger: 0.4,
        energy: 0.8,
        lastInteractionAt: date,
        isDragging: false,
        scale: 1.0
    )
}

private func makeP2Catalog(
    petId: String,
    extraNames: [String],
    extraIdPrefix: String = "extra_p2"
) -> PetActionCatalog {
    let extras = extraNames.enumerated().map { index, name in
        makeAction(
            id: "\(extraIdPrefix)_\(index)",
            displayName: name,
            role: nil,
            frames: [SpriteFrame(column: 0, row: 7 + index)],
            nextActionId: .idle
        )
    }
    return PetActionCatalog(petId: petId, actions: p2RoleActions() + extras, warnings: [])
}

private func p2RoleActions() -> [Action] {
    [
        makeAction(id: "idle_default", displayName: "Idle", role: .idle, frames: [SpriteFrame(column: 0, row: 0)], loop: true),
        makeAction(id: "walking_default", displayName: "Walking", role: .walking, frames: [SpriteFrame(column: 0, row: 1)], loop: true),
        makeAction(id: "sleeping_default", displayName: "Sleeping", role: .sleeping, frames: [SpriteFrame(column: 0, row: 2)], loop: true),
        makeAction(id: "happy_default", displayName: "Happy", role: .happy, frames: [SpriteFrame(column: 0, row: 3)], nextActionId: .idle),
        makeAction(id: "eating_default", displayName: "Eating", role: .eating, frames: [SpriteFrame(column: 0, row: 4)], nextActionId: .idle),
        makeAction(id: "jumping_default", displayName: "Jumping", role: .jumping, frames: [SpriteFrame(column: 0, row: 5)], nextActionId: .idle),
        makeAction(id: "dragging_default", displayName: "Dragging", role: .dragging, frames: [SpriteFrame(column: 0, row: 6)], loop: true)
    ]
}

private func expectedActionIds(in catalog: PetActionCatalog) -> [ActionId] {
    expectedActions(in: catalog).map(\.id)
}

private func expectedActionTitles(in catalog: PetActionCatalog) -> [String] {
    expectedActions(in: catalog).map(\.displayName)
}

private func expectedActions(in catalog: PetActionCatalog) -> [Action] {
    let roleOrder: [ActionRole] = [.idle, .walking, .sleeping, .happy, .eating, .jumping, .dragging]
    let roleActions = roleOrder.flatMap { catalog.actions(for: $0) }
    let extraActions = catalog.extras.sorted { lhs, rhs in
        if lhs.displayName == rhs.displayName {
            return lhs.id.rawValue < rhs.id.rawValue
        }
        return lhs.displayName < rhs.displayName
    }
    return roleActions + extraActions
}

private func makeValidationDefinition(petId: String, catalog: PetActionCatalog) -> PetDefinition {
    PetDefinition(
        id: petId,
        displayName: petId,
        description: "Action validation pet.",
        assetName: "spritesheet.png",
        previewAssetName: "preview.png",
        frameSize: CGSizeCodable(width: 64, height: 64),
        spritesheet: SpriteSheetLayout(columns: 8, rows: 16),
        defaultScale: 1.0,
        catalog: catalog
    )
}

@MainActor
private func actionMenuItems(in menu: NSMenu) -> [NSMenuItem] {
    var result: [NSMenuItem] = []
    for item in menu.items {
        if let submenu = item.submenu {
            result.append(contentsOf: actionMenuItems(in: submenu))
        } else if item.representedObject is ActionsMenuItemTrigger {
            result.append(item)
        }
    }
    return result
}

@MainActor
private func actionIds(in items: [NSMenuItem]) -> [ActionId] {
    items.compactMap { ($0.representedObject as? ActionsMenuItemTrigger)?.actionId }
}

@MainActor
private func menuSnapshots(in menu: NSMenu) -> [ActionValidationMenuSnapshot] {
    menu.items
        .filter { !$0.isSeparatorItem }
        .map { item in
            ActionValidationMenuSnapshot(
                title: item.title,
                isEnabled: item.isEnabled,
                children: item.submenu.map { menuSnapshots(in: $0) } ?? []
            )
        }
}

private struct ActionValidationMenuSnapshot: Equatable {
    let title: String
    let isEnabled: Bool
    let children: [ActionValidationMenuSnapshot]
}

@MainActor
private final class ActionValidationTriggerService: ActionTriggerServicing {
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

@MainActor
private final class ActionValidationCommandSpy: PetCommandHandling {
    var runtimeState: PetRuntimeState
    var catalog: PetActionCatalog
    var playedActionIds: [ActionId] = []

    init(
        catalog: PetActionCatalog,
        state: PetState = .idle,
        isDragging: Bool = false
    ) {
        self.catalog = catalog
        self.runtimeState = PetRuntimeState(
            currentState: state,
            mood: 0.8,
            hunger: 0.2,
            energy: 0.8,
            lastInteractionAt: referenceDate,
            isDragging: isDragging,
            scale: 1.0
        )
    }

    var isSleeping: Bool {
        runtimeState.currentState == .sleeping
    }

    func clicked() {}
    func pet() {}
    func feed() {}

    func sleep() {
        runtimeState.currentState = .sleeping
    }

    func wake() {
        runtimeState.currentState = .idle
    }

    func dragStarted() {
        runtimeState.isDragging = true
        runtimeState.currentState = .dragging
    }

    func dragEnded() {
        runtimeState.isDragging = false
        runtimeState.currentState = .idle
    }

    func playAction(_ id: ActionId) {
        playedActionIds.append(id)
    }

    func setScale(_ scale: Double) {
        runtimeState.scale = scale
    }

    func setRandomWalkingEnabled(_ enabled: Bool) {}
    func tick(at date: Date) {}
}

@MainActor
private final class ActionValidationWindowSpy: PetWindowControlling {
    var isPetVisible = true

    func showPet() {
        isPetVisible = true
    }

    func hidePet() {
        isPetVisible = false
    }

    func resetPosition() {}
    func saveStateBeforeQuit() {}
}

@MainActor
private final class ActionValidationSettingsSpy: SettingsWindowControlling {
    func showSettings() {}
}

@MainActor
private final class ActionValidationLaunchSpy: LaunchAtLoginControlling {
    var isLaunchAtLoginEnabled = false

    func setLaunchAtLoginEnabled(_ enabled: Bool) {
        isLaunchAtLoginEnabled = enabled
    }
}

@MainActor
private final class ActionValidationApplicationSpy: ApplicationTerminating {
    func terminate() {}
}

private struct ActionValidationLibraryFixture {
    let rootDirectory: URL
    let store: PetLibraryStore
    let overrideStore: PetActionOverrideStore

    init(name: String) {
        rootDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(name)-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: rootDirectory, withIntermediateDirectories: true)
        store = PetLibraryStore(rootDirectory: rootDirectory)
        overrideStore = PetActionOverrideStore(petsDirectoryURL: store.importedPetsDirectoryURL)
    }

    func cleanUp() {
        try? FileManager.default.removeItem(at: rootDirectory)
    }

    func writeManifest(petId: String, data: Data) throws {
        let directory = petDirectoryURL(for: petId)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try data.write(to: manifestURL(for: petId))
    }

    func writeV2Manifest(petId: String, extras: [Action]) throws {
        try writeV2Manifest(
            petId: petId,
            actions: p2RoleActions() + extras,
            spritesheet: SpriteSheetLayout(columns: 8, rows: 16)
        )
    }

    func writePetdexLikeV2Manifest(petId: String) throws {
        let extras = [
            makeAction(
                id: "extra_1",
                displayName: "Extra Row 7",
                role: nil,
                frames: rowFrames(row: 7, columns: 8),
                nextActionId: .idle
            ),
            makeAction(
                id: "extra_2",
                displayName: "Extra Row 8",
                role: nil,
                frames: rowFrames(row: 8, columns: 8),
                nextActionId: .idle
            )
        ]
        try writeV2Manifest(
            petId: petId,
            actions: p2RoleActions() + extras,
            spritesheet: SpriteSheetLayout(columns: 8, rows: 9)
        )
    }

    func manifestURL(for petId: String) -> URL {
        petDirectoryURL(for: petId).appendingPathComponent(PetLibraryStore.manifestFileName, isDirectory: false)
    }

    private func writeV2Manifest(
        petId: String,
        actions: [Action],
        spritesheet: SpriteSheetLayout
    ) throws {
        let manifest = PetPackageManifest(
            schemaVersion: 2,
            id: petId,
            displayName: petId,
            description: "Action validation fixture.",
            asset: "spritesheet.png",
            preview: "preview.png",
            frameSize: CGSizeCodable(width: 64, height: 64),
            spritesheet: spritesheet,
            defaultScale: 1.0,
            actions: actions
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try writeManifest(petId: petId, data: encoder.encode(manifest))
    }

    private func petDirectoryURL(for petId: String) -> URL {
        store.importedPetsDirectoryURL.appendingPathComponent(petId, isDirectory: true)
    }
}

private func makePNGData(width: Int, height: Int) -> Data {
    guard let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        fail("could not create PNG context")
    }

    context.setFillColor(red: 0, green: 0, blue: 0, alpha: 0)
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    context.setFillColor(red: 0.3, green: 0.6, blue: 0.9, alpha: 0.7)
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))

    guard let image = context.makeImage() else {
        fail("could not create PNG image")
    }

    let output = NSMutableData()
    guard let destination = CGImageDestinationCreateWithData(output, "public.png" as CFString, 1, nil) else {
        fail("could not create PNG destination")
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        fail("could not encode PNG")
    }
    return output as Data
}

private struct ValidationWarningSidecarEntry: Decodable, Equatable {
    let kind: String
    let detail: String
    let role: ActionRole?
    let actionId: ActionId?
}

private struct ActionValidationZipEntry {
    let name: String
    let data: Data

    static func stored(name: String, data: Data) -> ActionValidationZipEntry {
        ActionValidationZipEntry(name: name, data: data)
    }
}

private final class ActionValidationScratch {
    let root: URL

    init(name: String) {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(name)-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    func cleanUp() {
        try? FileManager.default.removeItem(at: root)
    }

    func writeZip(name: String, entries: [ActionValidationZipEntry]) -> URL {
        let url = root.appendingPathComponent(name)
        do {
            try makeZipData(entries: entries).write(to: url)
        } catch {
            fail("could not write Petdex zip fixture: \(error)")
        }
        return url
    }

    private func makeZipData(entries: [ActionValidationZipEntry]) -> Data {
        var localData = Data()
        var centralDirectory = Data()

        for entry in entries {
            let localHeaderOffset = localData.count
            let nameData = Data(entry.name.utf8)

            localData.appendValidationZipUInt32(0x0403_4B50)
            localData.appendValidationZipUInt16(20)
            localData.appendValidationZipUInt16(0)
            localData.appendValidationZipUInt16(0)
            localData.appendValidationZipUInt16(0)
            localData.appendValidationZipUInt16(0)
            localData.appendValidationZipUInt32(0)
            localData.appendValidationZipUInt32(UInt32(entry.data.count))
            localData.appendValidationZipUInt32(UInt32(entry.data.count))
            localData.appendValidationZipUInt16(UInt16(nameData.count))
            localData.appendValidationZipUInt16(0)
            localData.append(nameData)
            localData.append(entry.data)

            centralDirectory.appendValidationZipUInt32(0x0201_4B50)
            centralDirectory.appendValidationZipUInt16(20)
            centralDirectory.appendValidationZipUInt16(20)
            centralDirectory.appendValidationZipUInt16(0)
            centralDirectory.appendValidationZipUInt16(0)
            centralDirectory.appendValidationZipUInt16(0)
            centralDirectory.appendValidationZipUInt16(0)
            centralDirectory.appendValidationZipUInt32(0)
            centralDirectory.appendValidationZipUInt32(UInt32(entry.data.count))
            centralDirectory.appendValidationZipUInt32(UInt32(entry.data.count))
            centralDirectory.appendValidationZipUInt16(UInt16(nameData.count))
            centralDirectory.appendValidationZipUInt16(0)
            centralDirectory.appendValidationZipUInt16(0)
            centralDirectory.appendValidationZipUInt16(0)
            centralDirectory.appendValidationZipUInt16(0)
            centralDirectory.appendValidationZipUInt32(0)
            centralDirectory.appendValidationZipUInt32(UInt32(localHeaderOffset))
            centralDirectory.append(nameData)
        }

        let centralDirectoryOffset = localData.count
        localData.append(centralDirectory)
        localData.appendValidationZipUInt32(0x0605_4B50)
        localData.appendValidationZipUInt16(0)
        localData.appendValidationZipUInt16(0)
        localData.appendValidationZipUInt16(UInt16(entries.count))
        localData.appendValidationZipUInt16(UInt16(entries.count))
        localData.appendValidationZipUInt32(UInt32(centralDirectory.count))
        localData.appendValidationZipUInt32(UInt32(centralDirectoryOffset))
        localData.appendValidationZipUInt16(0)

        return localData
    }
}

private final class FixedRandomNumberGenerator: RandomNumberGenerating {
    private let value: Double

    init(value: Double) {
        self.value = value
    }

    func nextDouble(in range: ClosedRange<Double>) -> Double {
        min(max(value, range.lowerBound), range.upperBound)
    }
}

private final class SequenceRandomNumberGenerator: RandomNumberGenerating {
    private let values: [Double]
    private var cursor = 0

    init(values: [Double]) {
        self.values = values
    }

    func nextDouble(in range: ClosedRange<Double>) -> Double {
        guard !values.isEmpty else {
            fail("SequenceRandomNumberGenerator requires at least one value")
        }
        let raw = values[cursor % values.count]
        cursor += 1
        return min(max(raw, range.lowerBound), range.upperBound)
    }
}

private final class EvenDistributionRandomNumberGenerator: RandomNumberGenerating {
    private let iterations: Int
    private var cursor = 0

    init(iterations: Int) {
        self.iterations = iterations
    }

    func nextDouble(in range: ClosedRange<Double>) -> Double {
        let raw = (Double(cursor % iterations) + 0.5) / Double(iterations)
        cursor += 1
        return range.lowerBound + raw * (range.upperBound - range.lowerBound)
    }
}

private final class BoundaryFluctuationMoodSnapshotProvider: MoodSnapshotProviding {
    private let capturedAt: Date
    private(set) var callCount = 0

    init(capturedAt: Date) {
        self.capturedAt = capturedAt
    }

    func snapshot(currentMood: Double) -> MoodSnapshot {
        callCount += 1
        return MoodSnapshot(
            mood: MoodLevelClassifier.highThreshold - 0.01,
            level: callCount == 1 ? .high : .low,
            capturedAt: capturedAt
        )
    }
}

private extension Data {
    mutating func appendValidationZipUInt16(_ value: UInt16) {
        append(UInt8(value & 0x00FF))
        append(UInt8((value >> 8) & 0x00FF))
    }

    mutating func appendValidationZipUInt32(_ value: UInt32) {
        append(UInt8(value & 0x0000_00FF))
        append(UInt8((value >> 8) & 0x0000_00FF))
        append(UInt8((value >> 16) & 0x0000_00FF))
        append(UInt8((value >> 24) & 0x0000_00FF))
    }
}

private func tryOrFail<T>(_ expression: @autoclosure () throws -> T, _ message: String) -> T {
    do {
        return try expression()
    } catch {
        fail("\(message): \(error)")
    }
}

private func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        fail(message)
    }
}

private func fail(_ message: String) -> Never {
    fputs("DesktopPetActionValidation failed: \(message)\n", stderr)
    Foundation.exit(1)
}

private func validationV1ManifestJSON(id: String) -> Data {
    Data(
        """
        {
          "schemaVersion": 1,
          "id": "\(id)",
          "displayName": "Validation V1 Pet",
          "description": "A schema v1 validation pet.",
          "asset": "spritesheet.png",
          "preview": "preview.png",
          "frameSize": { "width": 128, "height": 128 },
          "spritesheet": { "columns": 2, "rows": 7 },
          "defaultScale": 1.0,
          "animations": {
            "idle": { "frames": [{ "column": 0, "row": 0 }, { "column": 1, "row": 0 }], "frameDurationMs": 160, "loop": true },
            "walking": { "frames": [{ "column": 0, "row": 1 }], "frameDurationMs": 160, "loop": true },
            "sleeping": { "frames": [{ "column": 0, "row": 2 }], "frameDurationMs": 160, "loop": true },
            "happy": { "frames": [{ "column": 0, "row": 3 }], "frameDurationMs": 120, "loop": false, "nextState": "idle" },
            "eating": { "frames": [{ "column": 0, "row": 4 }], "frameDurationMs": 120, "loop": false, "nextState": "idle" },
            "jumping": { "frames": [{ "column": 0, "row": 5 }], "frameDurationMs": 120, "loop": false, "nextState": "idle" },
            "dragging": { "frames": [{ "column": 0, "row": 6 }], "frameDurationMs": 120, "loop": true }
          }
        }
        """.utf8
    )
}

private let v1FixtureJSON = Data(
        """
        {
          "schemaVersion": 1,
          "id": "test-pet",
          "displayName": "Test Pet",
          "description": "A test pet.",
          "asset": "spritesheet.png",
          "preview": "preview.png",
          "frameSize": { "width": 128, "height": 128 },
          "spritesheet": { "columns": 2, "rows": 7 },
          "defaultScale": 1.0,
          "animations": {
            "idle": { "frames": [{ "column": 0, "row": 0 }, { "column": 1, "row": 0 }], "frameDurationMs": 160, "loop": true },
            "walking": { "frames": [{ "column": 0, "row": 1 }], "frameDurationMs": 160, "loop": true },
            "sleeping": { "frames": [{ "column": 0, "row": 2 }], "frameDurationMs": 160, "loop": true },
            "happy": { "frames": [{ "column": 0, "row": 3 }], "frameDurationMs": 120, "loop": false, "nextState": "idle" },
            "eating": { "frames": [{ "column": 0, "row": 4 }], "frameDurationMs": 120, "loop": false, "nextState": "idle" },
            "jumping": { "frames": [{ "column": 0, "row": 5 }], "frameDurationMs": 120, "loop": false, "nextState": "idle" },
            "dragging": { "frames": [{ "column": 0, "row": 6 }], "frameDurationMs": 120, "loop": true }
          }
        }
        """.utf8
)

private let v2FixtureJSON = Data(
        """
        {
          "schemaVersion": 2,
          "id": "test-pet",
          "displayName": "Test Pet",
          "description": "A test pet.",
          "asset": "spritesheet.png",
          "preview": "preview.png",
          "frameSize": { "width": 128, "height": 128 },
          "spritesheet": { "columns": 2, "rows": 9 },
          "defaultScale": 1.0,
          "actions": [
            { "id": "idle_default", "displayName": "Idle", "role": "idle", "tags": [], "frames": [{ "column": 0, "row": 0 }, { "column": 1, "row": 0 }], "frameDurationMs": 160, "loop": true },
            { "id": "walking_default", "displayName": "Walking", "role": "walking", "tags": [], "frames": [{ "column": 0, "row": 1 }], "frameDurationMs": 160, "loop": true },
            { "id": "sleeping_default", "displayName": "Sleeping", "role": "sleeping", "tags": [], "frames": [{ "column": 0, "row": 2 }], "frameDurationMs": 160, "loop": true },
            { "id": "happy_default", "displayName": "Happy", "role": "happy", "tags": [], "frames": [{ "column": 0, "row": 3 }], "frameDurationMs": 120, "loop": false, "nextActionId": "idle_default" },
            { "id": "eating_default", "displayName": "Eating", "role": "eating", "tags": [], "frames": [{ "column": 0, "row": 4 }], "frameDurationMs": 120, "loop": false, "nextActionId": "idle_default" },
            { "id": "jumping_default", "displayName": "Jumping", "role": "jumping", "tags": [], "frames": [{ "column": 0, "row": 5 }], "frameDurationMs": 120, "loop": false, "nextActionId": "idle_default" },
            { "id": "dragging_default", "displayName": "Dragging", "role": "dragging", "tags": [], "frames": [{ "column": 0, "row": 6 }], "frameDurationMs": 120, "loop": true },
            { "id": "extra_1", "displayName": "Extra 1", "role": null, "tags": [], "frames": [{ "column": 0, "row": 7 }, { "column": 1, "row": 7 }], "frameDurationMs": 120, "loop": false, "nextActionId": "idle_default" },
            { "id": "extra_2", "displayName": "Extra 2", "role": null, "tags": [], "frames": [{ "column": 0, "row": 8 }, { "column": 1, "row": 8 }], "frameDurationMs": 120, "loop": false, "nextActionId": "idle_default" }
          ]
        }
        """.utf8
)

runActionValidation()
