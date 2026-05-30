import DesktopPet
import AppKit
import Foundation

@MainActor
func runValidation() async {
    validateShowAndHidePetRouteThroughWindowController()
    validatePetClickRoutesThroughCoordinator()
    validatePetAndFeedRouteThroughPetCommandHandler()
    validateSleepOrWakeTogglesFromCurrentPetState()
    validateOpenSettingsAndResetPositionRouteToTheirOwners()
    validateLaunchAtLoginCommandUpdatesLaunchController()
    validateQuitSavesStateBeforeTerminating()
    validateScreenGeometryDefaultFrame()
    validateScreenGeometryOffScreenStartupReset()
    validateScreenGeometryClampsOverflowingFrame()
    validateScreenGeometryRecognizesMultiDisplayCoordinates()
    validatePetPanelConfiguration()
    validatePetHitTestHoverFeedback()
    validatePetWindowControllerResetAndVisibilityState()
    validatePetWindowContextMenuItems()
    validatePetWindowDragSession()
    validatePetEngineAppLaunch()
    validatePetEngineDirectInteractions()
    validatePetEngineDragPriority()
    validatePetEngineSleepAndWake()
    validatePetEngineAmbientWalking()
    validatePetEngineReactionNextState()
    validateMoodModelDecayAndClamp()
    validateMoodModelPetAndFeedChanges()
    validatePetPackageManifestDecode()
    validatePetPackageManifestMissingRequiredField()
    validatePetPackageManifestAnimationStateMapping()
    validatePetPackageLoaderLoadsLocalPackage()
    validateBuiltInPetDefinitionLoads()
    validatePetDefinitionValidationFailures()
    validatePetDefinitionFallbacks()
    validateBuiltInPetResources()
    validateAnimationPlayerLooping()
    validateAnimationPlayerNonLoopingNextState()
    validateAnimationPlayerPerFrameDuration()
    validateAnimationPlayerReducedMotion()
    validateSpriteSheetRendererCropsBuiltInFrames()
    validateSpriteSheetRendererFallbacks()
    validatePetViewRenderSizeUsesScale()
    validatePetWindowControllerUpdatesFrameSize()
    validatePetWindowControllerUpdateBubbleGrowsPanelAndPreservesPetAnchor()
    validatePetWindowControllerUpdateBubbleNilRestoresCompactSize()
    validatePetWindowControllerUpdateBubbleEmitsLayoutCallback()
    validatePetWindowControllerDragSavesPetSubFrameNotPanelFrame()
    validatePreferencesStoreDefaults()
    validatePreferencesStorePersistsValuesAcrossInstances()
    validatePreferencesStoreClampsInvalidScale()
    validatePreferencesStoreClampsRuntimeNumbers()
    validatePreferencesStoreUnknownPetFallback()
    validatePreferencesStoreOffscreenFrameFallback()
    validatePetWindowControllerCorrectsStoredOffscreenFrame()
    validatePreferencesStoreIgnoresUnknownFutureKeys()
    validatePetWindowVisibilityPersistsThroughPreferencesStore()
    validateSettingsViewModelActions()
    validateSettingsViewModelPersistsPreferenceChanges()
    validateSettingsViewModelStatusText()
    validateCustomPetPlaceholderContent()
    validateSettingsWindowControllerReusesWindow()
    validateSoundRoutesThroughCoordinator()
    validatePetSoundPlayerRespectsSoundPreference()
    validatePetSoundPlayerMissingResourcesAreSilent()
    validateLaunchAtLoginControllerStatusQuery()
    validateLaunchAtLoginControllerEnableAndDisable()
    validateLaunchAtLoginControllerFailureRollback()
    validateSettingsLaunchAtLoginRollbackUsesActualStatus()
    validateDesktopPetLogCategories()

    validateExecutablePathResolverFindsVersionedNodeToolDirectories()
    validateMiniMaxCLIDetectedPathIsClean()
    validateAIVisualActionParsing()
    validateAIVisualPolicyDeniesWhenDisabled()
    validateAIVisualSafetyRejectsUnsafeContent()
    validateAIVisualQuotaEnforcesDailyLimit()
    await validateAIVisualMockProviderEndToEnd()
    validateAIVisualAssetStoreCommitAndRestore()
    validateAIVisualStateControllerApplyAndRestore()
}

@MainActor
private func validateShowAndHidePetRouteThroughWindowController() {
    let harness = CoordinatorHarness()

    harness.coordinator.handle(.hidePet)
    expect(harness.petWindow.actions == [.hidePet], "hidePet should route to pet window")
    expect(harness.coordinator.menuState.isPetVisible == false, "menu state should reflect hidden pet")

    harness.coordinator.handle(.showPet)
    expect(harness.petWindow.actions == [.hidePet, .showPet], "showPet should route to pet window")
    expect(harness.coordinator.menuState.isPetVisible, "menu state should reflect visible pet")
}

@MainActor
private func validatePetClickRoutesThroughCoordinator() {
    let harness = CoordinatorHarness()

    harness.coordinator.handle(.clicked)

    expect(harness.petCommands.actions == [.clicked], "clicked should route to pet command handler")
}

@MainActor
private func validatePetAndFeedRouteThroughPetCommandHandler() {
    let harness = CoordinatorHarness()

    harness.coordinator.handle(.pet)
    harness.coordinator.handle(.feed)

    expect(harness.petCommands.actions == [.pet, .feed], "pet/feed should route to pet command handler")
}

@MainActor
private func validateSoundRoutesThroughCoordinator() {
    let harness = CoordinatorHarness()

    harness.coordinator.handle(.clicked)
    harness.coordinator.handle(.pet)
    harness.coordinator.handle(.feed)
    harness.coordinator.handle(.sleepOrWake)

    expect(harness.soundPlayer.events == [.click, .pet, .feed], "only click/pet/feed should trigger sound events")
}

@MainActor
private func validateSleepOrWakeTogglesFromCurrentPetState() {
    let harness = CoordinatorHarness()

    harness.coordinator.handle(.sleepOrWake)
    expect(harness.petCommands.actions == [.sleep], "first sleepOrWake should sleep")
    expect(harness.coordinator.menuState.isSleeping, "menu state should reflect sleeping pet")

    harness.coordinator.handle(.sleepOrWake)
    expect(harness.petCommands.actions == [.sleep, .wake], "second sleepOrWake should wake")
    expect(harness.coordinator.menuState.isSleeping == false, "menu state should reflect awake pet")
}

@MainActor
private func validateOpenSettingsAndResetPositionRouteToTheirOwners() {
    let harness = CoordinatorHarness()

    harness.coordinator.handle(.resetPosition)
    harness.coordinator.handle(.openSettings)

    expect(harness.petWindow.actions == [.resetPosition], "resetPosition should route to pet window")
    expect(harness.settingsWindow.showCount == 1, "openSettings should show settings once")
}

@MainActor
private func validateLaunchAtLoginCommandUpdatesLaunchController() {
    let harness = CoordinatorHarness()

    harness.coordinator.handle(.setLaunchAtLogin(true))
    expect(harness.launchAtLogin.values == [true], "launch at login should enable")
    expect(harness.coordinator.menuState.isLaunchAtLoginEnabled, "menu state should reflect enabled launch at login")

    harness.coordinator.handle(.setLaunchAtLogin(false))
    expect(harness.launchAtLogin.values == [true, false], "launch at login should disable")
    expect(harness.coordinator.menuState.isLaunchAtLoginEnabled == false, "menu state should reflect disabled launch at login")
}

@MainActor
private func validateLaunchAtLoginControllerStatusQuery() {
    let service = FakeLaunchAtLoginService(status: .enabled)
    let controller = LaunchAtLoginController(service: service)

    expect(controller.isLaunchAtLoginEnabled, "launch at login controller should report enabled status")

    service.status = .disabled
    expect(controller.isLaunchAtLoginEnabled == false, "launch at login controller should report disabled status")
}

@MainActor
private func validateLaunchAtLoginControllerEnableAndDisable() {
    let service = FakeLaunchAtLoginService(status: .disabled)
    let controller = LaunchAtLoginController(service: service)

    controller.setLaunchAtLoginEnabled(true)
    expect(service.registerCount == 1, "enabling launch at login should register main app")
    expect(controller.isLaunchAtLoginEnabled, "successful registration should report enabled status")

    controller.setLaunchAtLoginEnabled(false)
    expect(service.unregisterCount == 1, "disabling launch at login should unregister main app")
    expect(controller.isLaunchAtLoginEnabled == false, "successful unregistration should report disabled status")
}

@MainActor
private func validateLaunchAtLoginControllerFailureRollback() {
    let service = FakeLaunchAtLoginService(status: .disabled)
    service.registerError = FakeLaunchAtLoginError.failed
    let controller = LaunchAtLoginController(service: service)

    controller.setLaunchAtLoginEnabled(true)

    expect(service.registerCount == 1, "failed enable should still attempt registration once")
    expect(controller.isLaunchAtLoginEnabled == false, "failed enable should roll UI back to actual disabled status")

    service.registerError = nil
    controller.setLaunchAtLoginEnabled(true)
    service.unregisterError = FakeLaunchAtLoginError.failed
    controller.setLaunchAtLoginEnabled(false)

    expect(controller.isLaunchAtLoginEnabled, "failed disable should roll UI back to actual enabled status")
}

@MainActor
private func validateSettingsLaunchAtLoginRollbackUsesActualStatus() {
    let service = FakeLaunchAtLoginService(status: .disabled)
    service.registerError = FakeLaunchAtLoginError.failed
    let controller = LaunchAtLoginController(service: service)
    let model = SettingsViewModel(isLaunchAtLoginEnabled: controller.isLaunchAtLoginEnabled)

    model.onLaunchAtLoginChanged = { [controller, model] enabled in
        controller.setLaunchAtLoginEnabled(enabled)
        model.updateLaunchAtLogin(controller.isLaunchAtLoginEnabled)
    }

    model.setLaunchAtLoginEnabled(true)

    expect(model.isLaunchAtLoginEnabled == false, "settings launch at login toggle should roll back after failure")
}

@MainActor
private func validateQuitSavesStateBeforeTerminating() {
    let harness = CoordinatorHarness()

    harness.coordinator.handle(.quit)

    expect(harness.petWindow.actions == [.saveStateBeforeQuit], "quit should save pet window state")
    expect(harness.application.terminateCount == 1, "quit should terminate application")
}

private func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        fputs("Validation failed: \(message)\n", stderr)
        Foundation.exit(1)
    }
}

private func fail(_ message: String) -> Never {
    fputs("Validation failed: \(message)\n", stderr)
    Foundation.exit(1)
}

private func validateScreenGeometryDefaultFrame() {
    let geometry = ScreenGeometry(visibleFrames: [
        CGRect(x: 0, y: 0, width: 1440, height: 900)
    ])

    let frame = geometry.defaultPetFrame(frameSize: CGSize(width: 128, height: 128))

    expect(frame == CGRect(x: 1288, y: 24, width: 128, height: 128), "default frame should be main screen bottom-right with 24px inset")
}

private func validateScreenGeometryOffScreenStartupReset() {
    let geometry = ScreenGeometry(visibleFrames: [
        CGRect(x: 0, y: 0, width: 1440, height: 900)
    ])
    let savedFrame = CGRect(x: 2500, y: 1600, width: 128, height: 128)

    let frame = geometry.startupFrame(savedFrame: savedFrame, frameSize: CGSize(width: 128, height: 128))

    expect(frame == CGRect(x: 1288, y: 24, width: 128, height: 128), "off-screen saved frame should reset to default frame")
}

private func validateScreenGeometryClampsOverflowingFrame() {
    let geometry = ScreenGeometry(visibleFrames: [
        CGRect(x: 0, y: 0, width: 1440, height: 900)
    ])
    let overflowingFrame = CGRect(x: 1400, y: -50, width: 128, height: 128)

    let frame = geometry.clamp(frame: overflowingFrame)

    expect(frame == CGRect(x: 1312, y: 0, width: 128, height: 128), "overflowing frame should clamp into visible bounds")
}

private func validateScreenGeometryRecognizesMultiDisplayCoordinates() {
    let geometry = ScreenGeometry(visibleFrames: [
        CGRect(x: 0, y: 0, width: 1440, height: 900),
        CGRect(x: 1440, y: 100, width: 1280, height: 800)
    ])

    let point = CGPoint(x: 1800, y: 300)
    let frame = CGRect(x: 2600, y: 850, width: 160, height: 160)

    expect(
        geometry.visibleFrame(containing: point) == CGRect(x: 1440, y: 100, width: 1280, height: 800),
        "point should map to the second display"
    )
    expect(geometry.isFrameVisible(frame), "partially visible frame on second display should be considered recoverable")
    expect(
        geometry.clamp(frame: frame) == CGRect(x: 2560, y: 740, width: 160, height: 160),
        "multi-display frame should clamp within nearest visible display"
    )
}

@MainActor
private func validatePetPanelConfiguration() {
    let panel = PetPanel(contentRect: CGRect(x: 0, y: 0, width: 128, height: 128))

    expect(panel.styleMask.contains(.borderless), "pet panel should be borderless")
    expect(panel.styleMask.contains(.nonactivatingPanel), "pet panel should be non-activating")
    expect(panel.isOpaque == false, "pet panel should be transparent")
    expect(panel.backgroundColor == .clear, "pet panel should use clear background")
    expect(panel.level == .floating, "pet panel should use floating level")
    expect(panel.collectionBehavior.contains(.canJoinAllSpaces), "pet panel should join all spaces")
    expect(panel.collectionBehavior.contains(.fullScreenAuxiliary), "pet panel should support full-screen auxiliary behavior")
    expect(panel.collectionBehavior.contains(.stationary), "pet panel should be stationary across spaces")
    panel.close()
}

@MainActor
private func validatePetHitTestHoverFeedback() {
    let view = PetHitTestView(frame: CGRect(x: 0, y: 0, width: 128, height: 128))

    view.applyHoverFeedback(true)
    expect(view.isHovering, "hover feedback should track hovering state")
    expect(view.alphaValue == 0.92, "hover feedback should use subtle opacity change")

    view.applyHoverFeedback(false)
    expect(view.isHovering == false, "hover feedback should clear hovering state")
    expect(view.alphaValue == 1.0, "hover feedback should restore normal opacity")
}

@MainActor
private func validatePetWindowControllerResetAndVisibilityState() {
    let store = InMemoryPetWindowFrameStore()
    let geometry = ScreenGeometry(visibleFrames: [
        CGRect(x: 0, y: 0, width: 1440, height: 900)
    ])
    let controller = PetWindowController(
        frameSize: CGSize(width: 128, height: 128),
        frameStore: store,
        screenGeometryProvider: { geometry }
    )

    controller.resetPosition()
    expect(store.frame == CGRect(x: 1288, y: 24, width: 128, height: 128), "reset should persist default visible frame")

    controller.hidePet()
    expect(controller.isPetVisible == false, "hide should update visibility state")

    controller.showPet()
    expect(controller.isPetVisible, "show should update visibility state")

    controller.saveStateBeforeQuit()
    expect(store.frame != nil, "saveStateBeforeQuit should persist current panel frame")
    controller.hidePet()
}

@MainActor
private func validatePetWindowContextMenuItems() {
    let controller = PetWindowController(
        frameSize: CGSize(width: 128, height: 128),
        frameStore: InMemoryPetWindowFrameStore(),
        screenGeometryProvider: {
            ScreenGeometry(visibleFrames: [
                CGRect(x: 0, y: 0, width: 1440, height: 900)
            ])
        }
    )

    controller.menuStateProvider = {
        AppMenuState(isPetVisible: true, isSleeping: false, isLaunchAtLoginEnabled: false)
    }
    expect(
        controller.contextMenuTitlesForCurrentState() == ["Pet", "Feed", "Sleep", "-", "Hide Pet", "Reset Position", "Settings", "-", "Quit"],
        "context menu should expose MVP pet commands"
    )

    controller.menuStateProvider = {
        AppMenuState(isPetVisible: true, isSleeping: true, isLaunchAtLoginEnabled: false)
    }
    expect(
        controller.contextMenuTitlesForCurrentState().contains("Wake"),
        "context menu should switch Sleep to Wake when pet is sleeping"
    )
}

private func validatePetWindowDragSession() {
    let session = PetWindowDragSession(
        startFrame: CGRect(x: 100, y: 200, width: 128, height: 128),
        startMouseLocation: CGPoint(x: 20, y: 30)
    )

    expect(
        session.hasExceededThreshold(currentMouseLocation: CGPoint(x: 22, y: 32)) == false,
        "small pointer movement should not start dragging"
    )
    expect(
        session.hasExceededThreshold(currentMouseLocation: CGPoint(x: 25, y: 30)),
        "movement at threshold should start dragging"
    )
    expect(
        session.frame(currentMouseLocation: CGPoint(x: 50, y: 10)) == CGRect(x: 130, y: 180, width: 128, height: 128),
        "drag session should translate window frame by pointer delta"
    )
}

private func validatePetEngineAppLaunch() {
    let date = Date(timeIntervalSince1970: 0)
    let engine = makeValidationEngine(initialDate: date, fixedRandomValue: 20)

    let state = engine.handle(.appLaunched)

    expect(state.currentState == .idle, "app launch should enter idle")
}

private func validatePetEngineDirectInteractions() {
    let date = Date(timeIntervalSince1970: 0)
    let engine = makeValidationEngine(initialDate: date, fixedRandomValue: 20)

    engine.handle(.clicked)
    expect(engine.state.currentState == .jumping, "click should enter jumping")
    engine.handle(.tick(date.addingTimeInterval(2)))
    expect(engine.state.currentState == .idle, "jumping should return to idle after reaction duration")

    let moodBeforePet = engine.state.mood
    engine.handle(.pet)
    expect(engine.state.currentState == .happy, "pet action should enter happy")
    expect(engine.state.mood > moodBeforePet, "pet action should increase mood")
    engine.handle(.tick(date.addingTimeInterval(4)))

    let hungerBeforeFeed = engine.state.hunger
    engine.handle(.feed)
    expect(engine.state.currentState == .eating, "feed action should enter eating")
    expect(engine.state.hunger < hungerBeforeFeed, "feed action should lower hunger")
}

private func validatePetEngineDragPriority() {
    let date = Date(timeIntervalSince1970: 0)
    let engine = makeValidationEngine(initialDate: date, fixedRandomValue: 20)

    engine.handle(.dragStarted)
    expect(engine.state.currentState == .dragging, "dragStarted should enter dragging")
    expect(engine.state.isDragging, "dragStarted should mark runtime as dragging")

    engine.handle(.pet)
    engine.handle(.feed)
    engine.handle(.sleepRequested)
    expect(engine.state.currentState == .dragging, "dragging should override other events")

    engine.handle(.dragEnded)
    expect(engine.state.currentState == .idle, "dragEnded should return to idle")
    expect(engine.state.isDragging == false, "dragEnded should clear dragging flag")
}

private func validatePetEngineSleepAndWake() {
    let date = Date(timeIntervalSince1970: 0)
    let sleepyState = PetRuntimeState(
        currentState: .idle,
        mood: 0.5,
        hunger: 0.5,
        energy: 0.2,
        lastInteractionAt: date,
        isDragging: false,
        scale: 1.0
    )
    let engine = makeValidationEngine(
        initialState: sleepyState,
        initialDate: date,
        fixedRandomValue: 60
    )

    engine.handle(.tick(date.addingTimeInterval(10 * 60)))
    expect(engine.state.currentState == .sleeping, "low-energy long inactivity should enter sleeping")

    let energyBeforeSleepTick = engine.state.energy
    engine.handle(.tick(date.addingTimeInterval(11 * 60)))
    expect(engine.state.energy > energyBeforeSleepTick, "sleeping should recover energy")

    engine.handle(.pet)
    expect(engine.state.currentState == .happy, "petting should interrupt sleeping")

    engine.handle(.sleepRequested)
    expect(engine.state.currentState == .sleeping, "sleepRequested should enter sleeping")
    engine.handle(.wakeRequested)
    expect(engine.state.currentState == .idle, "wakeRequested should enter idle")
}

private func validatePetEngineAmbientWalking() {
    let date = Date(timeIntervalSince1970: 0)
    let randomWalkingEngine = makeValidationEngine(
        initialDate: date,
        isRandomWalkingEnabled: true,
        fixedRandomValue: 0
    )

    randomWalkingEngine.handle(.tick(date.addingTimeInterval(19)))
    expect(randomWalkingEngine.state.currentState == .idle, "random walking should not start before scheduled delay")

    randomWalkingEngine.handle(.tick(date.addingTimeInterval(20)))
    expect(randomWalkingEngine.state.currentState == .walking, "random walking should start at scheduled delay")

    randomWalkingEngine.handle(.pet)
    expect(randomWalkingEngine.state.currentState == .happy, "user interaction should override ambient walking")

    let disabledWalkingEngine = makeValidationEngine(
        initialDate: date,
        isRandomWalkingEnabled: false,
        fixedRandomValue: 20
    )
    disabledWalkingEngine.handle(.tick(date.addingTimeInterval(120)))
    expect(disabledWalkingEngine.state.currentState == .idle, "disabled random walking should remain idle")
}

private func validatePetEngineReactionNextState() {
    let date = Date(timeIntervalSince1970: 0)
    let engine = makeValidationEngine(initialDate: date, fixedRandomValue: 20)

    engine.handle(.clicked)
    engine.handle(.tick(date.addingTimeInterval(2)))

    expect(engine.state.currentState == .idle, "reaction should return to idle after default reaction duration")
}

private func makeValidationEngine(
    initialState: PetRuntimeState? = nil,
    initialDate: Date,
    isRandomWalkingEnabled: Bool = true,
    fixedRandomValue: Double
) -> PetEngine {
    let rng = FixedRandomNumberGenerator(value: fixedRandomValue)
    let catalog = makeValidationCatalog()
    return PetEngine(
        catalog: catalog,
        scheduler: UniformIdleBehaviorScheduler(randomNumberGenerator: rng),
        initialState: initialState,
        initialDate: initialDate,
        isRandomWalkingEnabled: isRandomWalkingEnabled,
        randomNumberGenerator: rng,
        now: { initialDate }
    )
}

private func makeValidationCatalog() -> PetActionCatalog {
    func id(_ raw: String) -> ActionId { ActionId(rawValue: raw)! }
    let actions: [Action] = [
        Action(id: id("idle_default"), displayName: "Idle", role: .idle, frames: [SpriteFrame(column: 0, row: 0)], frameDurationMs: 160, loop: true),
        Action(id: id("walk_default"), displayName: "Walk", role: .walking, frames: [SpriteFrame(column: 0, row: 0)], frameDurationMs: 160, loop: true),
        Action(id: id("sleep_default"), displayName: "Sleep", role: .sleeping, frames: [SpriteFrame(column: 0, row: 0)], frameDurationMs: 300, loop: true),
        Action(id: id("happy_default"), displayName: "Happy", role: .happy, frames: [SpriteFrame(column: 0, row: 0)], frameDurationMs: 120, loop: false, nextActionId: id("idle_default")),
        Action(id: id("eat_default"), displayName: "Eat", role: .eating, frames: [SpriteFrame(column: 0, row: 0)], frameDurationMs: 120, loop: false, nextActionId: id("idle_default")),
        Action(id: id("jump_default"), displayName: "Jump", role: .jumping, frames: [SpriteFrame(column: 0, row: 0)], frameDurationMs: 110, loop: false, nextActionId: id("idle_default")),
        Action(id: id("drag_default"), displayName: "Drag", role: .dragging, frames: [SpriteFrame(column: 0, row: 0)], frameDurationMs: 160, loop: true)
    ]
    return PetActionCatalog(petId: "validation-pet", actions: actions, warnings: [])
}

private func validateMoodModelDecayAndClamp() {
    let date = Date(timeIntervalSince1970: 0)
    let state = PetRuntimeState(
        currentState: .idle,
        mood: 0.001,
        hunger: 0.999,
        energy: 0.001,
        lastInteractionAt: date,
        isDragging: false,
        scale: 1.0
    )

    let advanced = MoodModel.advance(state, elapsedSeconds: 60 * 10)

    expect(advanced.mood == 0, "mood decay should clamp at zero")
    expect(advanced.hunger == 1, "hunger growth should clamp at one")
    expect(advanced.energy == 0, "active energy decay should clamp at zero")
}

private func validateMoodModelPetAndFeedChanges() {
    let date = Date(timeIntervalSince1970: 0)
    let state = PetRuntimeState(
        currentState: .idle,
        mood: 0.5,
        hunger: 0.5,
        energy: 0.5,
        lastInteractionAt: date,
        isDragging: false,
        scale: 1.0
    )

    let petted = MoodModel.applyingPet(to: state)
    expect(petted.mood == 0.65, "petting should increase mood by expected amount")

    let fed = MoodModel.applyingFeed(to: state)
    expect(fed.hunger == 0.25, "feeding should decrease hunger by expected amount")
    expect(fed.mood == 0.55, "feeding should increase mood by expected amount")
}

private func validatePetPackageManifestDecode() {
    let data = validManifestJSON().data(using: .utf8)!
    let loader = PetPackageLoader()

    do {
        let definition = try loader.decodeManifest(data: data)
        expect(definition.id == "my-pet", "manifest should decode pet id")
        expect(definition.animations[.jumping]?.nextState == .idle, "manifest should decode animation nextState")
        expect(definition.animations.count == PetState.allCases.count, "manifest should decode all MVP states")
    } catch {
        fail("manifest should decode successfully: \(error)")
    }
}

private func validatePetPackageManifestMissingRequiredField() {
    let invalidJSON = #"{"schemaVersion":1,"id":"broken"}"#.data(using: .utf8)!
    let loader = PetPackageLoader()

    do {
        _ = try loader.decodeManifest(data: invalidJSON)
        fail("manifest missing required fields should throw")
    } catch {
        return
    }
}

private func validatePetPackageManifestAnimationStateMapping() {
    let invalidJSON = validManifestJSON().replacingOccurrences(of: #""walking""#, with: #""unknown""#)
    let loader = PetPackageLoader()

    do {
        _ = try loader.decodeManifest(data: invalidJSON.data(using: .utf8)!)
        fail("unknown animation state should throw")
    } catch {
        return
    }
}

private func validatePetPackageLoaderLoadsLocalPackage() {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("DesktopPetValidation-\(UUID().uuidString)", isDirectory: true)
    let package = root.appendingPathComponent("MyPet.pet", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: root) }

    do {
        try FileManager.default.createDirectory(at: package, withIntermediateDirectories: true)
        try Data(validManifestJSON().utf8).write(to: package.appendingPathComponent("manifest.json"))
        try validationPNGData(width: 896, height: 128).write(to: package.appendingPathComponent("spritesheet.png"))
        try validationPNGData(width: 128, height: 128).write(to: package.appendingPathComponent("preview.png"))
    } catch {
        fail("failed to seed validation pet package: \(error)")
    }

    let loader = PetPackageLoader()

    do {
        let definition = try loader.loadPackage(at: package)
        expect(definition.id == "my-pet", "external package loading should return manifest definition")
        expect(definition.assetKind == .spriteSheet, "external package should load as spriteSheet")
    } catch {
        fail("external package loading should validate local .pet folders: \(error)")
    }
}

private func validateBuiltInPetDefinitionLoads() {
    let provider = BuiltInPetDefinitionProvider()

    do {
        let definition = try provider.loadBuiltInPet()
        expect(definition.id == "starter-pet", "built-in pet should have stable id")
        expect(definition.animations.count == PetState.allCases.count, "built-in pet should include all MVP states")

        for state in PetState.allCases {
            expect(definition.animation(for: state) != nil, "built-in pet should provide animation for \(state)")
        }
    } catch {
        fail("built-in pet definition should load: \(error)")
    }
}

private func validatePetDefinitionValidationFailures() {
    let invalidLayout = PetDefinition(
        id: "invalid",
        displayName: "Invalid",
        description: "Invalid",
        assetName: "invalid",
        previewAssetName: nil,
        frameSize: CGSizeCodable(width: 128, height: 128),
        spritesheet: SpriteSheetLayout(columns: 0, rows: 1),
        defaultScale: 1.0,
        animations: [:]
    )

    do {
        _ = try invalidLayout.validated()
        fail("invalid spritesheet layout should throw")
    } catch PetAssetError.invalidSpriteSheetLayout {
        // Expected.
    } catch {
        fail("invalid spritesheet layout threw unexpected error: \(error)")
    }

    var animations = validSingleFrameAnimations()
    animations[.jumping] = AnimationClip(
        state: .jumping,
        frames: [SpriteFrame(column: 10, row: 0)],
        frameDurationMs: 100,
        loop: false
    )
    let outOfBounds = PetDefinition(
        id: "invalid-frame",
        displayName: "Invalid Frame",
        description: "Invalid",
        assetName: "invalid",
        previewAssetName: nil,
        frameSize: CGSizeCodable(width: 128, height: 128),
        spritesheet: SpriteSheetLayout(columns: 7, rows: 1),
        defaultScale: 1.0,
        animations: animations
    )

    do {
        _ = try outOfBounds.validated()
        fail("out-of-bounds frame should throw")
    } catch PetAssetError.frameOutOfBounds {
        // Expected.
    } catch {
        fail("out-of-bounds frame threw unexpected error: \(error)")
    }
}

private func validatePetDefinitionFallbacks() {
    let definition = PetDefinition(
        id: "fallback",
        displayName: "Fallback",
        description: "Fallback",
        assetName: "missing-main",
        previewAssetName: "preview",
        frameSize: CGSizeCodable(width: 128, height: 128),
        spritesheet: SpriteSheetLayout(columns: 1, rows: 1),
        defaultScale: 1.0,
        animations: [
            .idle: AnimationClip(
                state: .idle,
                frames: [SpriteFrame(column: 0, row: 0)],
                frameDurationMs: 100,
                loop: true
            )
        ]
    )

    expect(definition.animation(for: .walking)?.state == .idle, "missing animation should fall back to idle clip")
    expect(
        definition.renderAssetName { $0 == "preview" } == "preview",
        "missing main asset should fall back to preview"
    )
    expect(
        definition.renderAssetName { _ in false } == PetDefinition.placeholderAssetName,
        "missing main and preview assets should fall back to placeholder"
    )
}

private func validateBuiltInPetResources() {
    let provider = BuiltInPetDefinitionProvider()

    expect(provider.bundledResourceExists(named: "starter-pet-spritesheet"), "built-in spritesheet resource should exist")
    expect(provider.bundledResourceExists(named: "starter-pet-preview"), "built-in preview resource should exist")
    expect(provider.bundledResourceExists(named: PetDefinition.placeholderAssetName), "placeholder pet resource should exist")

    validatePNGResource(
        provider.bundledResourceURL(named: "starter-pet-spritesheet"),
        expectedWidth: 896,
        expectedHeight: 128,
        description: "starter spritesheet"
    )
    validatePNGResource(
        provider.bundledResourceURL(named: "starter-pet-preview"),
        expectedWidth: 128,
        expectedHeight: 128,
        description: "starter preview"
    )
}

private func validatePNGResource(_ url: URL?, expectedWidth: Int, expectedHeight: Int, description: String) {
    guard let url else {
        fail("\(description) resource URL should exist")
    }

    do {
        let data = try Data(contentsOf: url)
        guard let image = NSBitmapImageRep(data: data) else {
            fail("\(description) should decode as PNG")
        }

        expect(image.pixelsWide == expectedWidth, "\(description) should have expected width")
        expect(image.pixelsHigh == expectedHeight, "\(description) should have expected height")
        expect(image.hasAlpha, "\(description) should preserve transparent background")
    } catch {
        fail("\(description) should be readable: \(error)")
    }
}

private func validateAnimationPlayerLooping() {
    let clip = AnimationClip(
        state: .idle,
        frames: [
            SpriteFrame(column: 0, row: 0),
            SpriteFrame(column: 1, row: 0)
        ],
        frameDurationMs: 100,
        loop: true
    )
    var player = AnimationPlayer(clip: clip)

    player.advance(by: 100)
    expect(player.currentFrame == SpriteFrame(column: 1, row: 0), "looping clip should advance to second frame")

    player.advance(by: 100)
    expect(player.currentFrame == SpriteFrame(column: 0, row: 0), "looping clip should wrap to first frame")
}

private func validateAnimationPlayerNonLoopingNextState() {
    let clip = AnimationClip(
        state: .jumping,
        frames: [
            SpriteFrame(column: 0, row: 0),
            SpriteFrame(column: 1, row: 0)
        ],
        frameDurationMs: 100,
        loop: false,
        nextState: .idle
    )
    var player = AnimationPlayer(clip: clip)

    let firstAdvance = player.advance(by: 100)
    expect(firstAdvance.completedNextState == nil, "non-looping clip should not complete before final frame duration")
    expect(player.currentFrame == SpriteFrame(column: 1, row: 0), "non-looping clip should show final frame")

    let completion = player.advance(by: 100)
    expect(completion.completedNextState == .idle, "non-looping clip should emit nextState at the end")
    expect(player.isComplete, "non-looping clip should mark completion")
}

private func validateAnimationPlayerPerFrameDuration() {
    let clip = AnimationClip(
        state: .walking,
        frames: [
            SpriteFrame(column: 0, row: 0, durationMs: 250),
            SpriteFrame(column: 1, row: 0)
        ],
        frameDurationMs: 100,
        loop: true
    )
    var player = AnimationPlayer(clip: clip)

    player.advance(by: 249)
    expect(player.currentFrame == SpriteFrame(column: 0, row: 0, durationMs: 250), "per-frame duration should hold frame until override duration")

    player.advance(by: 1)
    expect(player.currentFrame == SpriteFrame(column: 1, row: 0), "per-frame duration should advance after override duration")
}

private func validateAnimationPlayerReducedMotion() {
    let loopingClip = AnimationClip(
        state: .idle,
        frames: [
            SpriteFrame(column: 0, row: 0),
            SpriteFrame(column: 1, row: 0)
        ],
        frameDurationMs: 100,
        loop: true
    )
    var loopingPlayer = AnimationPlayer(clip: loopingClip, reducedMotion: true)
    loopingPlayer.advance(by: 1_000)
    expect(loopingPlayer.currentFrame == SpriteFrame(column: 0, row: 0), "reduced motion looping clip should stay on first frame")

    let nonLoopingClip = AnimationClip(
        state: .jumping,
        frames: [
            SpriteFrame(column: 0, row: 0),
            SpriteFrame(column: 1, row: 0)
        ],
        frameDurationMs: 100,
        loop: false,
        nextState: .idle
    )
    var nonLoopingPlayer = AnimationPlayer(clip: nonLoopingClip, reducedMotion: true)
    let completion = nonLoopingPlayer.advance(by: 200)
    expect(nonLoopingPlayer.currentFrame == SpriteFrame(column: 0, row: 0), "reduced motion non-looping clip should display first frame")
    expect(completion.completedNextState == .idle, "reduced motion non-looping clip should still complete after total duration")
}

@MainActor
private func validateSpriteSheetRendererCropsBuiltInFrames() {
    do {
        let definition = try BuiltInPetDefinitionProvider().loadBuiltInPet()
        let renderer = SpriteSheetRenderer(definition: definition)

        expect(
            renderer.cropRect(for: SpriteFrame(column: 5, row: 0)) == CGRect(x: 640, y: 0, width: 128, height: 128),
            "renderer should calculate expected crop rect from frame coordinates"
        )

        for state in PetState.allCases {
            guard let image = renderer.image(for: state) else {
                fail("renderer should return image for \(state)")
            }

            expect(image.size == CGSize(width: 128, height: 128), "rendered \(state) frame should match pet frame size")
        }
    } catch {
        fail("built-in renderer validation should load definition: \(error)")
    }
}

@MainActor
private func validateSpriteSheetRendererFallbacks() {
    let fallbackImage = NSImage(size: CGSize(width: 128, height: 128))
    let definition = PetDefinition(
        id: "fallback-renderer",
        displayName: "Fallback Renderer",
        description: "Fallback Renderer",
        assetName: "missing",
        previewAssetName: "preview",
        frameSize: CGSizeCodable(width: 128, height: 128),
        spritesheet: SpriteSheetLayout(columns: 1, rows: 1),
        defaultScale: 1.0,
        animations: [
            .idle: AnimationClip(
                state: .idle,
                frames: [SpriteFrame(column: 0, row: 0)],
                frameDurationMs: 100,
                loop: true
            )
        ]
    )
    let renderer = SpriteSheetRenderer(definition: definition) { name in
        name == "preview" ? fallbackImage : nil
    }

    expect(renderer.image(for: .walking) === fallbackImage, "missing state or spritesheet should render preview fallback")
}

private func validatePetViewRenderSizeUsesScale() {
    let definition = PetDefinition(
        id: "scale",
        displayName: "Scale",
        description: "Scale",
        assetName: "scale",
        previewAssetName: nil,
        frameSize: CGSizeCodable(width: 128, height: 128),
        spritesheet: SpriteSheetLayout(columns: 1, rows: 1),
        defaultScale: 1.0,
        animations: [:]
    )
    let state = PetRuntimeState(
        currentState: .idle,
        mood: 0.5,
        hunger: 0.5,
        energy: 0.5,
        lastInteractionAt: Date(timeIntervalSince1970: 0),
        isDragging: false,
        scale: 1.5
    )

    expect(PetView.renderSize(for: definition, state: state) == CGSize(width: 192, height: 192), "PetView render size should follow runtime scale")
}

@MainActor
private func validatePetWindowControllerUpdatesFrameSize() {
    let store = InMemoryPetWindowFrameStore()
    let geometry = ScreenGeometry(visibleFrames: [
        CGRect(x: 0, y: 0, width: 1440, height: 900)
    ])
    let controller = PetWindowController(
        frameSize: CGSize(width: 128, height: 128),
        frameStore: store,
        screenGeometryProvider: { geometry }
    )

    controller.showPet()
    controller.updateFrameSize(CGSize(width: 192, height: 192))

    expect(store.frame?.size == CGSize(width: 192, height: 192), "window controller should persist scaled pet frame size")
    controller.hidePet()
}

@MainActor
private func validatePetWindowControllerUpdateBubbleGrowsPanelAndPreservesPetAnchor() {
    let store = InMemoryPetWindowFrameStore()
    let geometry = ScreenGeometry(visibleFrames: [
        CGRect(x: 0, y: 0, width: 1440, height: 900)
    ])
    let layoutProvider = FixedBubbleLayoutProvider(bubbleSize: CGSize(width: 160, height: 36))
    let controller = PetWindowController(
        frameSize: CGSize(width: 128, height: 128),
        frameStore: store,
        screenGeometryProvider: { geometry },
        layoutProvider: layoutProvider
    )

    controller.showPet()
    let initialPetFrame = store.frame ?? .zero
    expect(initialPetFrame.size == CGSize(width: 128, height: 128), "no-bubble pet frame should equal pet size")

    let bubble = PetBubble(
        id: UUID(),
        text: "Hello",
        priority: .interaction,
        createdAt: Date(timeIntervalSince1970: 0),
        expiresAt: Date(timeIntervalSince1970: 3)
    )
    controller.updateBubble(bubble)

    expect(store.frame?.size == CGSize(width: 128, height: 128), "saved frame should remain pet sub-frame even after bubble resize")
    expect(store.frame?.origin == initialPetFrame.origin, "pet anchor should be preserved when bubble appears")

    controller.hidePet()
}

@MainActor
private func validatePetWindowControllerUpdateBubbleNilRestoresCompactSize() {
    let store = InMemoryPetWindowFrameStore()
    let geometry = ScreenGeometry(visibleFrames: [
        CGRect(x: 0, y: 0, width: 1440, height: 900)
    ])
    let layoutProvider = FixedBubbleLayoutProvider(bubbleSize: CGSize(width: 140, height: 30))
    let controller = PetWindowController(
        frameSize: CGSize(width: 128, height: 128),
        frameStore: store,
        screenGeometryProvider: { geometry },
        layoutProvider: layoutProvider
    )

    controller.showPet()
    let bubble = PetBubble(
        id: UUID(),
        text: "Hi",
        priority: .interaction,
        createdAt: Date(timeIntervalSince1970: 0),
        expiresAt: Date(timeIntervalSince1970: 3)
    )
    controller.updateBubble(bubble)
    let petAnchor = store.frame?.origin
    controller.updateBubble(nil)

    expect(store.frame?.size == CGSize(width: 128, height: 128), "panel should shrink back to pet size when bubble cleared")
    expect(store.frame?.origin == petAnchor, "pet anchor should remain stable across bubble dismiss")

    controller.hidePet()
}

@MainActor
private func validatePetWindowControllerUpdateBubbleEmitsLayoutCallback() {
    let store = InMemoryPetWindowFrameStore()
    let geometry = ScreenGeometry(visibleFrames: [
        CGRect(x: 0, y: 0, width: 1440, height: 900)
    ])
    let layoutProvider = FixedBubbleLayoutProvider(bubbleSize: CGSize(width: 144, height: 32))
    let controller = PetWindowController(
        frameSize: CGSize(width: 128, height: 128),
        frameStore: store,
        screenGeometryProvider: { geometry },
        layoutProvider: layoutProvider
    )

    var observed: [(PetBubble?, CGSize)] = []
    controller.onBubbleLayoutChanged = { bubble, layout in
        observed.append((bubble, layout.contentSize))
    }

    controller.showPet()
    let bubble = PetBubble(
        id: UUID(),
        text: "Hello",
        priority: .interaction,
        createdAt: Date(timeIntervalSince1970: 0),
        expiresAt: Date(timeIntervalSince1970: 3)
    )
    controller.updateBubble(bubble)
    controller.updateBubble(nil)

    expect(observed.count >= 3, "layout callback should fire on showPet, updateBubble, and dismiss")
    expect(observed.first?.0 == nil, "initial layout should report no bubble")
    expect(observed.first?.1 == CGSize(width: 128, height: 128), "initial layout content size should match pet size")
    let bubbleEntry = observed.first { $0.0 != nil }
    expect(bubbleEntry?.1.height ?? 0 > 128, "bubble layout should grow content height beyond pet height")
    expect(observed.last?.0 == nil, "final layout should report no bubble after dismiss")
    expect(observed.last?.1 == CGSize(width: 128, height: 128), "final layout content size should return to pet size")

    controller.hidePet()
}

@MainActor
private func validatePetWindowControllerDragSavesPetSubFrameNotPanelFrame() {
    let store = InMemoryPetWindowFrameStore()
    let geometry = ScreenGeometry(visibleFrames: [
        CGRect(x: 0, y: 0, width: 1440, height: 900)
    ])
    let layoutProvider = FixedBubbleLayoutProvider(bubbleSize: CGSize(width: 160, height: 36))
    let controller = PetWindowController(
        frameSize: CGSize(width: 128, height: 128),
        frameStore: store,
        screenGeometryProvider: { geometry },
        layoutProvider: layoutProvider
    )

    controller.showPet()
    let bubble = PetBubble(
        id: UUID(),
        text: "Hello",
        priority: .interaction,
        createdAt: Date(timeIntervalSince1970: 0),
        expiresAt: Date(timeIntervalSince1970: 3)
    )
    controller.updateBubble(bubble)
    controller.resetPosition()

    expect(store.frame?.size == CGSize(width: 128, height: 128), "resetPosition with bubble should still save pet sub-frame size")

    controller.hidePet()
}

@MainActor
private func validatePreferencesStoreDefaults() {
    let fixedNow = Date(timeIntervalSince1970: 123)
    let store = PreferencesStore(userDefaults: makeIsolatedUserDefaults(), now: { fixedNow })

    expect(store.isPetVisible, "default pet visibility should be true")
    expect(store.petScale == 1.0, "default pet scale should be 1.0")
    expect(store.isRandomWalkingEnabled, "default random walking should be enabled")
    expect(store.isSoundEnabled, "default sound should be enabled")
    expect(store.selectedPetId == "starter-pet", "default selected pet should be starter-pet")
    expect(store.mood == 0.8, "default mood should be 0.8")
    expect(store.hunger == 0.2, "default hunger should be 0.2")
    expect(store.energy == 0.8, "default energy should be 0.8")
    expect(store.lastInteractionAt == fixedNow, "default last interaction should use injected current date")

    let runtimeState = store.loadRuntimeState()
    expect(runtimeState.currentState == .idle, "persisted runtime should restart in idle")
    expect(runtimeState.scale == 1.0, "persisted runtime should include stored scale")
}

@MainActor
private func validatePreferencesStorePersistsValuesAcrossInstances() {
    let defaults = makeIsolatedUserDefaults()
    let date = Date(timeIntervalSince1970: 456)
    let geometry = ScreenGeometry(visibleFrames: [
        CGRect(x: 0, y: 0, width: 1440, height: 900)
    ])
    let firstStore = PreferencesStore(
        userDefaults: defaults,
        knownPetIds: ["starter-pet", "cat"],
        screenGeometryProvider: { geometry }
    )

    firstStore.isPetVisible = false
    firstStore.petScale = 1.5
    firstStore.isRandomWalkingEnabled = false
    firstStore.isSoundEnabled = false
    firstStore.selectedPetId = "cat"
    firstStore.saveRuntimeState(
        PetRuntimeState(
            currentState: .happy,
            mood: 0.6,
            hunger: 0.4,
            energy: 0.7,
            lastInteractionAt: date,
            isDragging: false,
            scale: 1.5
        )
    )
    firstStore.savePetWindowFrame(CGRect(x: 100, y: 120, width: 128, height: 128))

    let secondStore = PreferencesStore(
        userDefaults: defaults,
        knownPetIds: ["starter-pet", "cat"],
        screenGeometryProvider: { geometry }
    )
    let runtimeState = secondStore.loadRuntimeState()

    expect(secondStore.isPetVisible == false, "pet visibility should persist across store instances")
    expect(secondStore.petScale == 1.5, "pet scale should persist across store instances")
    expect(secondStore.isRandomWalkingEnabled == false, "random walking setting should persist")
    expect(secondStore.isSoundEnabled == false, "sound setting should persist")
    expect(secondStore.selectedPetId == "cat", "selected pet should persist")
    expect(runtimeState.mood == 0.6, "mood should persist")
    expect(runtimeState.hunger == 0.4, "hunger should persist")
    expect(runtimeState.energy == 0.7, "energy should persist")
    expect(runtimeState.lastInteractionAt == date, "last interaction date should persist")
    expect(secondStore.loadPetWindowFrame() == CGRect(x: 100, y: 120, width: 128, height: 128), "pet window frame should persist")
}

@MainActor
private func validatePreferencesStoreClampsInvalidScale() {
    let defaults = makeIsolatedUserDefaults()
    defaults.set(9.0, forKey: PreferenceKeys.petScale)
    let store = PreferencesStore(userDefaults: defaults)

    expect(store.petScale == 2.0, "invalid high scale should clamp to upper bound")
    expect(defaults.double(forKey: PreferenceKeys.petScale) == 2.0, "clamped scale should be written back")

    defaults.set(0.1, forKey: PreferenceKeys.petScale)
    expect(store.petScale == 0.5, "invalid low scale should clamp to lower bound")
    expect(defaults.double(forKey: PreferenceKeys.petScale) == 0.5, "low clamped scale should be written back")
}

@MainActor
private func validatePreferencesStoreClampsRuntimeNumbers() {
    let defaults = makeIsolatedUserDefaults()
    defaults.set(2.0, forKey: PreferenceKeys.mood)
    defaults.set(-1.0, forKey: PreferenceKeys.hunger)
    defaults.set(3.0, forKey: PreferenceKeys.energy)
    let store = PreferencesStore(userDefaults: defaults)

    expect(store.mood == 1.0, "mood should clamp to 0...1")
    expect(store.hunger == 0.0, "hunger should clamp to 0...1")
    expect(store.energy == 1.0, "energy should clamp to 0...1")
    expect(defaults.double(forKey: PreferenceKeys.mood) == 1.0, "clamped mood should be written back")
    expect(defaults.double(forKey: PreferenceKeys.hunger) == 0.0, "clamped hunger should be written back")
    expect(defaults.double(forKey: PreferenceKeys.energy) == 1.0, "clamped energy should be written back")
}

@MainActor
private func validatePreferencesStoreUnknownPetFallback() {
    let defaults = makeIsolatedUserDefaults()
    defaults.set("ghost", forKey: PreferenceKeys.selectedPetId)
    let store = PreferencesStore(userDefaults: defaults, knownPetIds: ["starter-pet", "cat"])

    expect(store.selectedPetId == "starter-pet", "unknown selected pet should fall back to built-in pet")
    expect(defaults.string(forKey: PreferenceKeys.selectedPetId) == "starter-pet", "selected pet fallback should be written back")

    store.selectedPetId = "cat"
    expect(store.selectedPetId == "cat", "known selected pet should be accepted")

    store.selectedPetId = "missing"
    expect(store.selectedPetId == "starter-pet", "unknown assigned pet should fall back")
}

@MainActor
private func validatePreferencesStoreOffscreenFrameFallback() {
    let defaults = makeIsolatedUserDefaults()
    let geometry = ScreenGeometry(visibleFrames: [
        CGRect(x: 0, y: 0, width: 1440, height: 900)
    ])
    defaults.set(
        NSStringFromRect(CGRect(x: 3000, y: 2000, width: 128, height: 128)),
        forKey: PreferenceKeys.petWindowFrame
    )
    let store = PreferencesStore(
        userDefaults: defaults,
        screenGeometryProvider: { geometry },
        frameSizeProvider: { CGSize(width: 128, height: 128) }
    )

    let expectedFrame = CGRect(x: 1288, y: 24, width: 128, height: 128)
    expect(store.resolvedPetWindowFrame() == expectedFrame, "off-screen pet frame should fall back to default visible frame")
    expect(
        NSRectFromString(defaults.string(forKey: PreferenceKeys.petWindowFrame) ?? "") == expectedFrame,
        "corrected pet frame should be written back"
    )
}

@MainActor
private func validatePetWindowControllerCorrectsStoredOffscreenFrame() {
    let defaults = makeIsolatedUserDefaults()
    defaults.set(
        NSStringFromRect(CGRect(x: 3000, y: 2000, width: 128, height: 128)),
        forKey: PreferenceKeys.petWindowFrame
    )
    let geometry = ScreenGeometry(visibleFrames: [
        CGRect(x: 0, y: 0, width: 1440, height: 900)
    ])
    let store = PreferencesStore(userDefaults: defaults, screenGeometryProvider: { geometry })
    let controller = PetWindowController(
        frameSize: CGSize(width: 192, height: 192),
        frameStore: store,
        screenGeometryProvider: { geometry }
    )

    controller.showPet()

    expect(
        NSRectFromString(defaults.string(forKey: PreferenceKeys.petWindowFrame) ?? "") == CGRect(x: 1224, y: 24, width: 192, height: 192),
        "window controller should correct off-screen stored frame using current render size"
    )
    controller.hidePet()
}

@MainActor
private func validatePreferencesStoreIgnoresUnknownFutureKeys() {
    let defaults = makeIsolatedUserDefaults()
    defaults.set("future-value", forKey: "future.unknown.preference")
    let store = PreferencesStore(userDefaults: defaults)

    expect(store.isPetVisible, "unknown future keys should not affect known defaults")
    expect(store.selectedPetId == "starter-pet", "unknown future keys should not affect selected pet fallback")
}

@MainActor
private func validatePetWindowVisibilityPersistsThroughPreferencesStore() {
    let defaults = makeIsolatedUserDefaults()
    let store = PreferencesStore(userDefaults: defaults)
    let controller = PetWindowController(
        frameSize: CGSize(width: 128, height: 128),
        initiallyVisible: store.isPetVisible,
        frameStore: store,
        screenGeometryProvider: {
            ScreenGeometry(visibleFrames: [
                CGRect(x: 0, y: 0, width: 1440, height: 900)
            ])
        }
    )
    controller.onVisibilityChanged = { [store] isVisible in
        store.isPetVisible = isVisible
    }

    controller.hidePet()
    expect(store.isPetVisible == false, "hiding pet should persist visibility immediately")

    controller.showPet()
    expect(store.isPetVisible, "showing pet should persist visibility immediately")
    controller.hidePet()
}

private func makeIsolatedUserDefaults() -> UserDefaults {
    let suiteName = "DesktopPetValidation.\(UUID().uuidString)"
    guard let userDefaults = UserDefaults(suiteName: suiteName) else {
        fail("test user defaults suite should be creatable")
    }

    userDefaults.removePersistentDomain(forName: suiteName)
    return userDefaults
}

@MainActor
private func validateSettingsViewModelActions() {
    let model = SettingsViewModel()
    var visibilityValues: [Bool] = []
    var scaleValues: [Double] = []
    var randomWalkingValues: [Bool] = []
    var soundValues: [Bool] = []
    var launchAtLoginValues: [Bool] = []
    var resetCount = 0

    model.onPetVisibilityChanged = { visibilityValues.append($0) }
    model.onScaleChanged = { scaleValues.append($0) }
    model.onRandomWalkingChanged = { randomWalkingValues.append($0) }
    model.onSoundChanged = { soundValues.append($0) }
    model.onLaunchAtLoginChanged = { launchAtLoginValues.append($0) }
    model.onResetPosition = { resetCount += 1 }

    model.setPetVisible(false)
    model.setPetScale(1.4)
    model.setPetScale(9.0)
    model.setRandomWalkingEnabled(false)
    model.setSoundEnabled(false)
    model.setLaunchAtLoginEnabled(true)
    model.resetPosition()

    expect(visibilityValues == [false], "settings visibility toggle should emit changed value")
    expect(scaleValues == [1.4, 2.0], "settings scale should emit clamped values")
    expect(randomWalkingValues == [false], "settings random walking toggle should emit changed value")
    expect(soundValues == [false], "settings sound toggle should emit changed value")
    expect(launchAtLoginValues == [true], "settings launch at login toggle should emit changed value")
    expect(resetCount == 1, "settings reset position should emit command")
}

@MainActor
private func validateSettingsViewModelPersistsPreferenceChanges() {
    let defaults = makeIsolatedUserDefaults()
    let store = PreferencesStore(userDefaults: defaults)
    let model = SettingsViewModel(
        isPetVisible: store.isPetVisible,
        petScale: store.petScale,
        isRandomWalkingEnabled: store.isRandomWalkingEnabled,
        isSoundEnabled: store.isSoundEnabled
    )

    model.onScaleChanged = { [store] scale in
        store.petScale = scale
    }
    model.onRandomWalkingChanged = { [store] enabled in
        store.isRandomWalkingEnabled = enabled
    }
    model.onSoundChanged = { [store] enabled in
        store.isSoundEnabled = enabled
    }

    model.setPetScale(1.35)
    model.setRandomWalkingEnabled(false)
    model.setSoundEnabled(false)

    let restoredStore = PreferencesStore(userDefaults: defaults)
    expect(restoredStore.petScale == 1.35, "settings scale change should persist")
    expect(restoredStore.isRandomWalkingEnabled == false, "settings random walking change should persist")
    expect(restoredStore.isSoundEnabled == false, "settings sound change should persist")
}

@MainActor
private func validateSettingsViewModelStatusText() {
    let date = Date(timeIntervalSince1970: 0)
    let model = SettingsViewModel(runtimeState: PetRuntimeState(
        currentState: .idle,
        mood: 0.8,
        hunger: 0.2,
        energy: 0.8,
        lastInteractionAt: date,
        isDragging: false,
        scale: 1.0
    ))
    expect(model.petStatusText == "Happy", "high mood should display happy status")

    model.updateRuntimeState(PetRuntimeState(
        currentState: .idle,
        mood: 0.8,
        hunger: 0.2,
        energy: 0.1,
        lastInteractionAt: date,
        isDragging: false,
        scale: 1.0
    ))
    expect(model.petStatusText == "Tired", "low energy should display tired status")

    model.updateRuntimeState(PetRuntimeState(
        currentState: .idle,
        mood: 0.8,
        hunger: 0.9,
        energy: 0.8,
        lastInteractionAt: date,
        isDragging: false,
        scale: 1.0
    ))
    expect(model.petStatusText == "Hungry", "high hunger should display hungry status")
}

@MainActor
private func validateCustomPetPlaceholderContent() {
    expect(
        SettingsViewModel.customPetPackageFolder == "~/Library/Application Support/DesktopPet/Pets",
        "settings should expose reserved custom pet package folder"
    )
    expect(
        SettingsViewModel.customPetPackageFormat == "manifest.json + spritesheet.png + preview.png",
        "settings should expose future custom pet package format"
    )
}

private func validateDesktopPetLogCategories() {
    expect(DesktopPetLog.subsystem == "DesktopPet", "logs should use stable DesktopPet subsystem")
    expect(
        DesktopPetLog.categoryNames == ["window", "engine", "assets", "preferences", "launchAtLogin", "petLibrary", "petdex", "bubble", "aiCompanion"],
        "logs should expose MVP and custom pet categories"
    )
}

private func validateMiniMaxCLIDetectedPathIsClean() {
    guard let detectedPath = MiniMaxCLIClient.detectedMMXPath() else {
        return
    }

    expect(!detectedPath.contains("\n"), "detected mmx path should not include shell startup output")
    expect(detectedPath.hasSuffix("/mmx"), "detected mmx path should point to the mmx executable")
}

private func validateExecutablePathResolverFindsVersionedNodeToolDirectories() {
    let home = FileManager.default.temporaryDirectory
        .appendingPathComponent("desktop-pet-path-resolver-\(UUID().uuidString)")
    let bin = home
        .appendingPathComponent(".nvm", isDirectory: true)
        .appendingPathComponent("versions", isDirectory: true)
        .appendingPathComponent("node", isDirectory: true)
        .appendingPathComponent("v24.14.0", isDirectory: true)
        .appendingPathComponent("bin", isDirectory: true)
    let mmx = bin.appendingPathComponent("mmx")

    try! FileManager.default.createDirectory(at: bin, withIntermediateDirectories: true)
    try! Data("#!/bin/sh\n".utf8).write(to: mmx)
    try! FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: mmx.path)

    let resolver = ExecutablePathResolver(environmentPATH: "/usr/bin:/bin", homeDirectory: home)

    expect(resolver.resolve("mmx") == mmx.path, "resolver should find mmx inside nvm versioned bin directories")

    try? FileManager.default.removeItem(at: home)
}

@MainActor
private func validateSettingsWindowControllerReusesWindow() {
    let controller = SettingsWindowController(viewModel: SettingsViewModel())

    controller.showSettings()
    controller.showSettings()

    expect(controller.createdWindowCount == 1, "settings window controller should reuse existing window")
}

@MainActor
private func validatePetSoundPlayerRespectsSoundPreference() {
    var isEnabled = false
    var requestedNames: [String] = []
    let player = PetSoundPlayer(
        isSoundEnabled: { isEnabled },
        soundLoader: { name in
            requestedNames.append(name)
            return nil
        }
    )

    player.play(.click)
    expect(requestedNames.isEmpty, "disabled sound preference should skip loading sound resources")

    isEnabled = true
    player.play(.pet)
    expect(requestedNames == ["pet-happy"], "enabled sound preference should request matching sound resource")
}

@MainActor
private func validatePetSoundPlayerMissingResourcesAreSilent() {
    let player = PetSoundPlayer(
        isSoundEnabled: { true },
        soundLoader: { _ in nil }
    )

    for event in PetSoundEvent.allCases {
        player.play(event)
    }

    expect(true, "missing sound resources should not throw or crash")
}

private func validSingleFrameAnimations() -> [PetState: AnimationClip] {
    Dictionary(uniqueKeysWithValues: PetState.allCases.enumerated().map { index, state in
        (
            state,
            AnimationClip(
                state: state,
                frames: [SpriteFrame(column: index, row: 0)],
                frameDurationMs: 100,
                loop: state == .idle || state == .walking || state == .sleeping || state == .dragging,
                nextState: state == .idle || state == .walking || state == .sleeping || state == .dragging ? nil : .idle
            )
        )
    })
}

private func validManifestJSON() -> String {
    """
    {
      "schemaVersion": 1,
      "id": "my-pet",
      "displayName": "My Pet",
      "description": "A small desktop companion.",
      "asset": "spritesheet.png",
      "preview": "preview.png",
      "frameSize": { "width": 128, "height": 128 },
      "spritesheet": { "columns": 7, "rows": 1 },
      "defaultScale": 1.0,
      "animations": {
        "idle": {
          "frames": [{ "column": 0, "row": 0 }],
          "frameDurationMs": 160,
          "loop": true
        },
        "walking": {
          "frames": [{ "column": 1, "row": 0 }],
          "frameDurationMs": 140,
          "loop": true
        },
        "sleeping": {
          "frames": [{ "column": 2, "row": 0 }],
          "frameDurationMs": 300,
          "loop": true
        },
        "happy": {
          "frames": [{ "column": 3, "row": 0 }],
          "frameDurationMs": 120,
          "loop": false,
          "nextState": "idle"
        },
        "eating": {
          "frames": [{ "column": 4, "row": 0 }],
          "frameDurationMs": 120,
          "loop": false,
          "nextState": "idle"
        },
        "jumping": {
          "frames": [{ "column": 5, "row": 0 }],
          "frameDurationMs": 110,
          "loop": false,
          "nextState": "idle"
        },
        "dragging": {
          "frames": [{ "column": 6, "row": 0 }],
          "frameDurationMs": 160,
          "loop": true
        }
      }
    }
    """
}

private func validationPNGData(width: Int, height: Int) -> Data {
    let image = NSImage(size: CGSize(width: width, height: height))
    image.lockFocus()
    NSColor.systemTeal.setFill()
    NSRect(x: 0, y: 0, width: width, height: height).fill()
    image.unlockFocus()

    guard let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let data = bitmap.representation(using: .png, properties: [:]) else {
        fail("failed to create validation PNG data")
    }
    return data
}

@MainActor
private final class CoordinatorHarness {
    let petWindow = SpyPetWindowController()
    let petCommands = SpyPetCommandHandler()
    let settingsWindow = SpySettingsWindowController()
    let launchAtLogin = SpyLaunchAtLoginController()
    let soundPlayer = SpySoundPlayer()
    let application = SpyApplicationTerminator()
    let coordinator: AppCoordinator

    init() {
        coordinator = AppCoordinator(
            petWindow: petWindow,
            petCommands: petCommands,
            settingsWindow: settingsWindow,
            launchAtLogin: launchAtLogin,
            soundPlayer: soundPlayer,
            application: application
        )
    }
}

@MainActor
private final class SpyPetWindowController: PetWindowControlling {
    enum Action: Equatable {
        case showPet
        case hidePet
        case resetPosition
        case saveStateBeforeQuit
    }

    private(set) var isPetVisible = true
    private(set) var actions: [Action] = []

    func showPet() {
        actions.append(.showPet)
        isPetVisible = true
    }

    func hidePet() {
        actions.append(.hidePet)
        isPetVisible = false
    }

    func resetPosition() {
        actions.append(.resetPosition)
    }

    func saveStateBeforeQuit() {
        actions.append(.saveStateBeforeQuit)
    }
}

@MainActor
private final class SpyPetCommandHandler: PetCommandHandling {
    enum Action: Equatable {
        case clicked
        case pet
        case feed
        case sleep
        case wake
    }

    private(set) var isSleeping = false
    private(set) var actions: [Action] = []
    private(set) var tickDates: [Date] = []
    var runtimeState = PetRuntimeState.defaultState()
    var catalog = PetActionCatalog(petId: "spy-pet", actions: [], warnings: [])

    func clicked() {
        actions.append(.clicked)
    }

    func pet() {
        actions.append(.pet)
    }

    func feed() {
        actions.append(.feed)
    }

    func sleep() {
        actions.append(.sleep)
        isSleeping = true
    }

    func wake() {
        actions.append(.wake)
        isSleeping = false
    }

    func dragStarted() {}

    func dragEnded() {}

    func playAction(_ id: ActionId) {}

    func setScale(_ scale: Double) {}

    func setRandomWalkingEnabled(_ enabled: Bool) {}

    func tick(at date: Date) {
        tickDates.append(date)
    }
}

@MainActor
private final class SpySettingsWindowController: SettingsWindowControlling {
    private(set) var showCount = 0

    func showSettings() {
        showCount += 1
    }
}

@MainActor
private final class SpyLaunchAtLoginController: LaunchAtLoginControlling {
    private(set) var isLaunchAtLoginEnabled = false
    private(set) var values: [Bool] = []

    func setLaunchAtLoginEnabled(_ enabled: Bool) {
        values.append(enabled)
        isLaunchAtLoginEnabled = enabled
    }
}

@MainActor
private final class SpySoundPlayer: PetSoundPlaying {
    private(set) var events: [PetSoundEvent] = []

    func play(_ event: PetSoundEvent) {
        events.append(event)
    }
}

@MainActor
private final class SpyApplicationTerminator: ApplicationTerminating {
    private(set) var terminateCount = 0

    func terminate() {
        terminateCount += 1
    }
}

@MainActor
private final class InMemoryPetWindowFrameStore: PetWindowFrameStoring {
    private(set) var frame: CGRect?

    func loadPetWindowFrame() -> CGRect? {
        frame
    }

    func savePetWindowFrame(_ frame: CGRect) {
        self.frame = frame
    }
}

private final class FixedBubbleLayoutProvider: PetWindowLayoutProviding {
    private let bubbleSize: CGSize
    private let metrics: PetWindowLayoutMetrics

    init(bubbleSize: CGSize, metrics: PetWindowLayoutMetrics = .default) {
        self.bubbleSize = bubbleSize
        self.metrics = metrics
    }

    func layout(petSize: CGSize, bubble: PetBubble?) -> PetWindowLayout {
        guard bubble != nil else {
            return PetWindowLayout(
                petSize: petSize,
                bubbleSize: nil,
                contentSize: petSize,
                petOrigin: .zero,
                bubbleOrigin: nil
            )
        }
        let contentWidth = max(petSize.width, bubbleSize.width)
        let contentHeight = petSize.height + metrics.bubbleSpacing + bubbleSize.height
        return PetWindowLayout(
            petSize: petSize,
            bubbleSize: bubbleSize,
            contentSize: CGSize(width: contentWidth, height: contentHeight),
            petOrigin: CGPoint(x: (contentWidth - petSize.width) / 2, y: 0),
            bubbleOrigin: CGPoint(
                x: (contentWidth - bubbleSize.width) / 2,
                y: petSize.height + metrics.bubbleSpacing
            )
        )
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

private enum FakeLaunchAtLoginError: Error {
    case failed
}

private final class FakeLaunchAtLoginService: LaunchAtLoginServicing {
    var status: LaunchAtLoginStatus
    var registerError: Error?
    var unregisterError: Error?
    private(set) var registerCount = 0
    private(set) var unregisterCount = 0

    init(status: LaunchAtLoginStatus) {
        self.status = status
    }

    func register() throws {
        registerCount += 1
        if let registerError {
            throw registerError
        }
        status = .enabled
    }

    func unregister() throws {
        unregisterCount += 1
        if let unregisterError {
            throw unregisterError
        }
        status = .disabled
    }
}

// MARK: - AI Visual Action Validation (M14)

@MainActor
private func validateAIVisualActionParsing() {
    let parser = AIVisualActionParser()
    let json = """
    {"kind":"expression","description":"开心地跳舞","renderMode":"replaceWholeImage","durationSeconds":60,"impact":"low"}
    """
    let response = "小猫想表达心情 [VISUAL_ACTION]\(json)[/VISUAL_ACTION] 继续聊天"

    let result = parser.parse(from: response, petId: "pet1", source: .chat)

    expect(result.candidates.count == 1, "should parse one candidate")
    expect(result.candidates.first?.kind == .expression, "kind should be expression")
    expect(result.candidates.first?.description == "开心地跳舞", "description should match")
    expect(result.cleanedResponse.contains("小猫想表达心情"), "cleaned response should retain text before tag")
    expect(result.cleanedResponse.contains("继续聊天"), "cleaned response should retain text after tag")
    expect(!result.cleanedResponse.contains("VISUAL_ACTION"), "cleaned response should not contain tags")
    expect(result.parseWarnings.isEmpty, "valid JSON should produce no warnings")

    let invalidResult = parser.parse(from: "[VISUAL_ACTION]bad json[/VISUAL_ACTION]", petId: "pet1", source: .chat)
    expect(invalidResult.candidates.isEmpty, "invalid JSON should produce no candidates")
    expect(!invalidResult.parseWarnings.isEmpty, "invalid JSON should produce warnings")

    let noTagResult = parser.parse(from: "普通回复没有标签", petId: "pet1", source: .chat)
    expect(noTagResult.candidates.isEmpty, "no tags should produce no candidates")
    expect(noTagResult.cleanedResponse == "普通回复没有标签", "no tags should return original text")
}

@MainActor
private func validateAIVisualPolicyDeniesWhenDisabled() {
    let policy = AIVisualActionPolicy()
    let candidate = AIVisualActionCandidate(
        id: "a1", petId: "pet1", source: .chat, kind: .expression,
        description: "开心", renderMode: .replaceWholeImage,
        requestedDurationSeconds: 60, impact: .low
    )

    let disabledAI = AIVisualActionContext(
        isAIEnabled: false, isVisualExpressionEnabled: true,
        isQuietMode: false, isBubbleEnabled: true,
        petId: "pet1", petName: "小猫"
    )
    let aiResult = policy.evaluate(candidate, context: disabledAI)
    if case .deny(let reason, _) = aiResult {
        expect(reason == .aiDisabled, "should deny with aiDisabled when AI disabled")
    } else {
        fail("should deny when AI disabled, got \(aiResult)")
    }

    let disabledVisual = AIVisualActionContext(
        isAIEnabled: true, isVisualExpressionEnabled: false,
        isQuietMode: false, isBubbleEnabled: true,
        petId: "pet1", petName: "小猫"
    )
    let visualResult = policy.evaluate(candidate, context: disabledVisual)
    if case .deny(let reason, _) = visualResult {
        expect(reason == .visualExpressionDisabled, "should deny with visualExpressionDisabled")
    } else {
        fail("should deny when visual expression disabled, got \(visualResult)")
    }

    let quietContext = AIVisualActionContext(
        isAIEnabled: true, isVisualExpressionEnabled: true,
        isQuietMode: true, isBubbleEnabled: true,
        petId: "pet1", petName: "小猫"
    )
    let quietResult = policy.evaluate(candidate, context: quietContext)
    if case .deny(let reason, _) = quietResult {
        expect(reason == .quietMode, "should deny with quietMode")
    } else {
        fail("should deny in quiet mode, got \(quietResult)")
    }

    let allowedContext = AIVisualActionContext(
        isAIEnabled: true, isVisualExpressionEnabled: true,
        isQuietMode: false, isBubbleEnabled: true,
        petId: "pet1", petName: "小猫",
        hasPreviousVisualAction: true
    )
    let allowedResult = policy.evaluate(candidate, context: allowedContext)
    if case .allow(let returned) = allowedResult {
        expect(returned.id == candidate.id, "allowed candidate should match")
    } else {
        fail("should allow when all enabled and has previous action, got \(allowedResult)")
    }

    let firstTriggerContext = AIVisualActionContext(
        isAIEnabled: true, isVisualExpressionEnabled: true,
        isQuietMode: false, isBubbleEnabled: true,
        petId: "pet1", petName: "小猫",
        hasPreviousVisualAction: false
    )
    let firstResult = policy.evaluate(candidate, context: firstTriggerContext)
    if case .needsConfirmation(_, reason: .firstTrigger) = firstResult {
        // expected
    } else {
        fail("first trigger should need confirmation, got \(firstResult)")
    }
}

@MainActor
private func validateAIVisualSafetyRejectsUnsafeContent() {
    let service = AIVisualSafetyService()

    let safeCandidate = AIVisualActionCandidate(
        id: "s1", petId: "pet1", source: .chat, kind: .expression,
        description: "戴着帽子开心地笑", renderMode: .replaceWholeImage,
        requestedDurationSeconds: 60, impact: .low
    )
    let safeResult = service.validate(candidate: safeCandidate)
    expect(safeResult.isAllowed, "safe description should be allowed")

    let nsfwCandidate = AIVisualActionCandidate(
        id: "s2", petId: "pet1", source: .chat, kind: .expression,
        description: "脱衣服跳舞", renderMode: .replaceWholeImage,
        requestedDurationSeconds: 60, impact: .low
    )
    let nsfwResult = service.validate(candidate: nsfwCandidate)
    expect(!nsfwResult.isAllowed, "NSFW content should be rejected")
    expect(nsfwResult.rejectionReason == .nsfwContent, "should reject with nsfwContent")

    let violenceCandidate = AIVisualActionCandidate(
        id: "s3", petId: "pet1", source: .chat, kind: .expression,
        description: "血腥的战斗场面", renderMode: .replaceWholeImage,
        requestedDurationSeconds: 60, impact: .low
    )
    let violenceResult = service.validate(candidate: violenceCandidate)
    expect(!violenceResult.isAllowed, "violence content should be rejected")
    expect(violenceResult.rejectionReason == .violenceOrGore, "should reject with violenceOrGore")

    let sanitized = service.sanitizePrompt("变成猫", petDescriptor: "一只可爱的小猫")
    expect(!sanitized.isEmpty, "sanitized prompt should not be empty")
}

@MainActor
private func validateAIVisualQuotaEnforcesDailyLimit() {
    let suiteName = "com.desktoppet.test.quota.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    let config = AIVisualQuotaConfig(dailyAutonomousLimit: 2, dailyUserRequestLimit: 3, dailyTotalLimit: 5, monthlyTotalLimit: 80)
    let now = Date()
    let store = AIVisualQuotaStore(config: config, userDefaults: defaults, now: { now })

    expect(store.canReserve(petId: "pet1", source: .chat, at: now) == .allowed,
           "first reserve should be allowed")

    try! store.reserve(petId: "pet1", actionId: "a1", source: .chat, at: now)
    try! store.reserve(petId: "pet1", actionId: "a2", source: .chat, at: now)

    expect(store.canReserve(petId: "pet1", source: .chat, at: now) == .dailyAutonomousExceeded,
           "third autonomous should exceed daily autonomous limit")

    expect(store.canReserve(petId: "pet1", source: .userRequest, at: now) == .allowed,
           "user request should still be allowed when autonomous is full")

    for i in 3...5 {
        try! store.reserve(petId: "pet1", actionId: "u\(i)", source: .userRequest, at: now)
    }

    expect(store.canReserve(petId: "pet1", source: .userRequest, at: now) == .dailyTotalExceeded,
           "should exceed daily total limit")

    let usage = store.loadUsage(petId: "pet1", date: now)
    expect(usage.dailyAutonomousCount == 2, "should have 2 autonomous")
    expect(usage.dailyUserRequestCount == 3, "should have 3 user requests")
    expect(usage.dailyTotalCount == 5, "total should be 5")

    defaults.removePersistentDomain(forName: suiteName)
}

@MainActor
private func validateAIVisualMockProviderEndToEnd() async {
    let provider = MockImageGenerator(isConfigured: true)
    expect(provider.isConfigured, "mock provider should be configured")
    expect(provider.providerId == "mock", "provider id should be mock")

    let tempDir = FileManager.default.temporaryDirectory
        .appendingPathComponent("mock-test-\(UUID().uuidString)")
    try! FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

    let stubImageURL = tempDir.appendingPathComponent("stub.png")
    let stubData = Data(repeating: 0x89, count: 8)
    try! stubData.write(to: stubImageURL)

    let expected = VisualGenerationResult(
        actionId: "test-action",
        imageURL: stubImageURL,
        providerId: "mock"
    )
    provider.stubResult(.success(expected))

    let request = VisualGenerationRequest(
        actionId: "test-action",
        petId: "pet1",
        prompt: "开心的小猫",
        outputDirectory: tempDir,
        outputPrefix: "test"
    )

    let result = try! await provider.generate(request)
    expect(result.actionId == "test-action", "result actionId should match")
    expect(result.providerId == "mock", "result providerId should be mock")
    expect(provider.generateCallCount == 1, "should have called generate once")
    expect(provider.lastRequest != nil, "lastRequest should be set")

    try? FileManager.default.removeItem(at: tempDir)
}

@MainActor
private func validateAIVisualAssetStoreCommitAndRestore() {
    let tempDir = FileManager.default.temporaryDirectory
        .appendingPathComponent("asset-test-\(UUID().uuidString)")
    let store = PetVisualAssetStore(baseDirectory: tempDir)

    let imageDir = tempDir.appendingPathComponent("pending")
    try! FileManager.default.createDirectory(at: imageDir, withIntermediateDirectories: true)
    let imageFile = imageDir.appendingPathComponent("image.png")
    try! Data(repeating: 0x89, count: 16).write(to: imageFile)

    let expiresAt = Date().addingTimeInterval(3600)
    let asset = try! store.commitAsset(
        from: imageFile,
        petId: "pet1",
        actionId: "action1",
        providerId: "mock",
        kind: .expression,
        renderMode: .replaceWholeImage,
        promptDigest: "test-digest",
        expiresAt: expiresAt
    )

    expect(asset.id.isEmpty == false, "committed asset should have an id")
    expect(asset.kind == .expression, "asset kind should match")
    expect(asset.renderMode == .replaceWholeImage, "render mode should match")

    let loaded = store.loadAsset(id: asset.id, petId: "pet1")
    expect(loaded != nil, "should load committed asset by id")
    expect(loaded?.id == asset.id, "loaded asset id should match")

    let active = store.loadActiveAssets(petId: "pet1", now: Date())
    expect(!active.isEmpty, "should find active assets")

    try? FileManager.default.removeItem(at: tempDir)
}

@MainActor
private func validateAIVisualStateControllerApplyAndRestore() {
    let controller = PetVisualStateController()
    let viewModel = PetViewModel()

    expect(viewModel.visualOverlay == nil, "initial overlay should be nil")

    let tempDir = FileManager.default.temporaryDirectory
        .appendingPathComponent("state-test-\(UUID().uuidString)")
    try! FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    let imageURL = tempDir.appendingPathComponent("visual.png")
    try! Data(repeating: 0x89, count: 8).write(to: imageURL)

    let overlay = PetVisualOverlayState(
        id: "overlay1",
        assetId: "asset1",
        imageURL: imageURL,
        renderMode: .replaceWholeImage,
        expiresAt: Date().addingTimeInterval(300)
    )

    controller.apply(overlay, to: viewModel)
    expect(viewModel.visualOverlay != nil, "apply should set visual overlay")
    expect(viewModel.visualOverlay?.id == "overlay1", "overlay id should match")

    controller.restore(viewModel: viewModel)
    expect(viewModel.visualOverlay == nil, "restore should clear overlay back to original state")

    controller.apply(overlay, to: viewModel)
    expect(viewModel.visualOverlay != nil, "apply again should set overlay")

    controller.clearAll(viewModel: viewModel)
    expect(viewModel.visualOverlay == nil, "clearAll should remove overlay")

    try? FileManager.default.removeItem(at: tempDir)
}

Task { @MainActor in
    await runValidation()
    print("DesktopPetValidation passed")
    Foundation.exit(0)
}

RunLoop.main.run()
