import AppKit
import Foundation
import DesktopPet

@MainActor
func runMenuBarControllerCompanionshipTests() {
    let tests = MenuBarControllerCompanionshipTests()
    tests.quietForOneHourMenuItemAppearsWhenNotQuiet()
    tests.resumeBubblesMenuItemAppearsWhenQuiet()
    tests.hideBubblesMenuItemAppearsWhenBubblesEnabled()
    tests.showBubblesMenuItemAppearsWhenBubblesDisabled()
    tests.quietForOneHourUpdatesMenuState()
    tests.clearQuietModeUpdatesMenuState()
    tests.toggleSpeechBubblesUpdatesMenuState()
}

@MainActor
private struct MenuBarControllerCompanionshipTests {
    func quietForOneHourMenuItemAppearsWhenNotQuiet() {
        let harness = makeHarness()

        let menu = harness.statusItem.menu
        let quietItem = menu?.item(withTitle: "Quiet for 1 Hour")

        expect(quietItem != nil, "menu should contain 'Quiet for 1 Hour' when not in quiet mode")
        expect(menu?.item(withTitle: "Resume Bubbles") == nil, "menu should not contain 'Resume Bubbles' when not quiet")
    }

    func resumeBubblesMenuItemAppearsWhenQuiet() {
        let harness = makeHarness()
        harness.coordinator.handle(.quietForOneHour)
        harness.controller.refresh()

        let menu = harness.statusItem.menu
        let resumeItem = menu?.item(withTitle: "Resume Bubbles")

        expect(resumeItem != nil, "menu should contain 'Resume Bubbles' when in quiet mode")
        expect(menu?.item(withTitle: "Quiet for 1 Hour") == nil, "menu should not contain 'Quiet for 1 Hour' when quiet")
    }

    func hideBubblesMenuItemAppearsWhenBubblesEnabled() {
        let harness = makeHarness()

        let menu = harness.statusItem.menu
        let hideItem = menu?.item(withTitle: "Hide Bubbles")

        expect(hideItem != nil, "menu should contain 'Hide Bubbles' when speech bubbles are enabled")
    }

    func showBubblesMenuItemAppearsWhenBubblesDisabled() {
        let harness = makeHarness()
        harness.coordinator.handle(.setSpeechBubbleEnabled(false))
        harness.controller.refresh()

        let menu = harness.statusItem.menu
        let showItem = menu?.item(withTitle: "Show Bubbles")

        expect(showItem != nil, "menu should contain 'Show Bubbles' when speech bubbles are disabled")
        expect(menu?.item(withTitle: "Hide Bubbles") == nil, "menu should not contain 'Hide Bubbles' when disabled")
    }

    func quietForOneHourUpdatesMenuState() {
        let harness = makeHarness()

        harness.coordinator.handle(.quietForOneHour)

        expect(harness.coordinator.menuState.isQuietModeActive, "menuState should reflect quiet mode after quietForOneHour")
    }

    func clearQuietModeUpdatesMenuState() {
        let harness = makeHarness()
        harness.coordinator.handle(.quietForOneHour)

        harness.coordinator.handle(.clearQuietMode)

        expect(!harness.coordinator.menuState.isQuietModeActive, "menuState should not be quiet after clearQuietMode")
    }

    func toggleSpeechBubblesUpdatesMenuState() {
        let harness = makeHarness()
        expect(harness.coordinator.menuState.isSpeechBubbleEnabled, "speech bubbles should start enabled")

        harness.coordinator.handle(.setSpeechBubbleEnabled(false))

        expect(!harness.coordinator.menuState.isSpeechBubbleEnabled, "speech bubbles should be disabled after toggle")
    }

    private func makeHarness() -> MenuBarCompanionshipHarness {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let commands = MenuBarCompanionshipCommandSpy()
        let coordinator = AppCoordinator(
            petWindow: MenuBarCompanionshipWindowSpy(),
            petCommands: commands,
            settingsWindow: MenuBarCompanionshipSettingsSpy(),
            launchAtLogin: MenuBarCompanionshipLaunchSpy(),
            application: MenuBarCompanionshipApplicationSpy(),
            speechBubbleEnabled: true
        )
        let controller = MenuBarController(coordinator: coordinator, statusItem: statusItem)
        controller.configure()
        return MenuBarCompanionshipHarness(
            statusItem: statusItem,
            coordinator: coordinator,
            controller: controller
        )
    }
}

@MainActor
private struct MenuBarCompanionshipHarness {
    let statusItem: NSStatusItem
    let coordinator: AppCoordinator
    let controller: MenuBarController
}

@MainActor
private final class MenuBarCompanionshipCommandSpy: PetCommandHandling {
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
private final class MenuBarCompanionshipWindowSpy: PetWindowControlling {
    var isPetVisible = true
    func showPet() { isPetVisible = true }
    func hidePet() { isPetVisible = false }
    func resetPosition() {}
    func saveStateBeforeQuit() {}
}

@MainActor
private final class MenuBarCompanionshipSettingsSpy: SettingsWindowControlling {
    func showSettings() {}
}

@MainActor
private final class MenuBarCompanionshipLaunchSpy: LaunchAtLoginControlling {
    var isLaunchAtLoginEnabled = false
    func setLaunchAtLoginEnabled(_ enabled: Bool) { isLaunchAtLoginEnabled = enabled }
}

@MainActor
private final class MenuBarCompanionshipApplicationSpy: ApplicationTerminating {
    func terminate() {}
}
