import Foundation
import DesktopPet

@MainActor
func runAppCoordinatorCompanionshipTests() {
    let tests = AppCoordinatorCompanionshipTests()
    tests.quietForOneHourSetsQuietModeActive()
    tests.clearQuietModeResetsQuietModeActive()
    tests.setSpeechBubbleEnabledUpdatesMenuState()
    tests.quietModeStateChangedCallbackFires()
}

@MainActor
private struct AppCoordinatorCompanionshipTests {
    func quietForOneHourSetsQuietModeActive() {
        let harness = makeHarness()

        harness.coordinator.handle(.quietForOneHour)

        expect(harness.coordinator.menuState.isQuietModeActive, "quietForOneHour should set isQuietModeActive")
    }

    func clearQuietModeResetsQuietModeActive() {
        let harness = makeHarness()
        harness.coordinator.handle(.quietForOneHour)

        harness.coordinator.handle(.clearQuietMode)

        expect(!harness.coordinator.menuState.isQuietModeActive, "clearQuietMode should reset isQuietModeActive")
    }

    func setSpeechBubbleEnabledUpdatesMenuState() {
        let harness = makeHarness()
        expect(harness.coordinator.menuState.isSpeechBubbleEnabled, "speech bubbles should start enabled")

        harness.coordinator.handle(.setSpeechBubbleEnabled(false))

        expect(!harness.coordinator.menuState.isSpeechBubbleEnabled, "setSpeechBubbleEnabled(false) should disable speech bubbles in menuState")
        expect(!harness.bubbleCommander.isEnabled, "setSpeechBubbleEnabled(false) should disable the bubble engine")

        harness.coordinator.handle(.setSpeechBubbleEnabled(true))

        expect(harness.coordinator.menuState.isSpeechBubbleEnabled, "setSpeechBubbleEnabled(true) should re-enable speech bubbles")
        expect(harness.bubbleCommander.isEnabled, "setSpeechBubbleEnabled(true) should re-enable the bubble engine")
    }

    func quietModeStateChangedCallbackFires() {
        let harness = makeHarness()
        var callbackValues: [Bool] = []

        harness.coordinator.onQuietModeStateChanged = { isActive in
            callbackValues.append(isActive)
        }

        harness.coordinator.handle(.quietForOneHour)
        harness.coordinator.handle(.clearQuietMode)

        expect(callbackValues == [true, false], "onQuietModeStateChanged should fire with true then false")
    }

    private func makeHarness() -> CoordinatorCompanionshipHarness {
        let windowSpy = CoordinatorCompanionshipWindowSpy()
        let commandsSpy = CoordinatorCompanionshipCommandSpy()
        let bubbleCommander = CoordinatorCompanionshipBubbleSpy()
        let coordinator = AppCoordinator(
            petWindow: windowSpy,
            petCommands: commandsSpy,
            settingsWindow: CoordinatorCompanionshipSettingsSpy(),
            launchAtLogin: CoordinatorCompanionshipLaunchSpy(),
            application: CoordinatorCompanionshipApplicationSpy(),
            bubble: bubbleCommander,
            speechBubbleEnabled: true
        )
        return CoordinatorCompanionshipHarness(
            coordinator: coordinator,
            bubbleCommander: bubbleCommander
        )
    }
}

@MainActor
private struct CoordinatorCompanionshipHarness {
    let coordinator: AppCoordinator
    let bubbleCommander: CoordinatorCompanionshipBubbleSpy
}

@MainActor
private final class CoordinatorCompanionshipBubbleSpy: BubbleCommanding {
    var isEnabled = true
    var lastFrequency: BubbleFrequency?
    var currentBubble: PetBubble? { nil }

    func setSpeechBubbleEnabled(_ enabled: Bool) { isEnabled = enabled }
    func setBubbleFrequency(_ frequency: BubbleFrequency) { lastFrequency = frequency }
    func handleInteraction(_ event: PetEvent, state: PetRuntimeState, at date: Date) {}
    func handleTick(state: PetRuntimeState, at date: Date) {}
    func handleCompanionInteraction(_ trigger: BubbleTrigger, context: CompanionContext, at date: Date) {}
    func handleCompanionTick(context: CompanionContext, at date: Date) {}
}

@MainActor
private final class CoordinatorCompanionshipCommandSpy: PetCommandHandling {
    var runtimeState = PetRuntimeState.defaultState(at: Date())
    var catalog = PetActionCatalog(petId: "test", actions: [], warnings: [])
    var isSleeping: Bool { false }

    func clicked() {}
    func pet() {}
    func feed() {}
    func sleep() {}
    func wake() {}
    func dragStarted() {}
    func dragEnded() {}
    func playAction(_ id: ActionId) {}
    func setScale(_ scale: Double) {}
    func setRandomWalkingEnabled(_ enabled: Bool) {}
    func tick(at date: Date) {}
}

@MainActor
private final class CoordinatorCompanionshipWindowSpy: PetWindowControlling {
    var isPetVisible = true
    func showPet() { isPetVisible = true }
    func hidePet() { isPetVisible = false }
    func resetPosition() {}
    func saveStateBeforeQuit() {}
}

@MainActor
private final class CoordinatorCompanionshipSettingsSpy: SettingsWindowControlling {
    func showSettings() {}
}

@MainActor
private final class CoordinatorCompanionshipLaunchSpy: LaunchAtLoginControlling {
    var isLaunchAtLoginEnabled = false
    func setLaunchAtLoginEnabled(_ enabled: Bool) { isLaunchAtLoginEnabled = enabled }
}

@MainActor
private final class CoordinatorCompanionshipApplicationSpy: ApplicationTerminating {
    func terminate() {}
}
