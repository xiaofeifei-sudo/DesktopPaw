import AppKit
import Foundation
import DesktopPet

@MainActor
func runMenuBarControllerActionsTests() {
    let tests = MenuBarControllerActionsTests()
    tests.actionsSubmenuContainsSevenRolesAndTwoExtras()
    tests.actionsSubmenuReflectsChangedCatalog()
    tests.sleepingDisablesActionsAndShowsBusyPrompt()
    tests.clickingActionRoutesToPlayActionTrigger()
}

@MainActor
private struct MenuBarControllerActionsTests {
    func actionsSubmenuContainsSevenRolesAndTwoExtras() {
        let commands = MenuBarControllerActionsCommandSpy(
            catalog: makeCatalog(petId: "pet-a", extraNames: ["Wave", "Spin"])
        )
        let harness = makeHarness(commands: commands)

        let actionsMenu = actionsSubmenu(in: harness.statusItem.menu)

        expect(actionItems(in: actionsMenu).count == 9, "7 role actions plus 2 extras should produce 9 Actions submenu items")
    }

    func actionsSubmenuReflectsChangedCatalog() {
        let commands = MenuBarControllerActionsCommandSpy(
            catalog: makeCatalog(petId: "pet-a", extraNames: ["Wave", "Spin"])
        )
        let harness = makeHarness(commands: commands)

        commands.catalog = makeCatalog(petId: "pet-b", extraNames: ["Blink"])
        harness.controller.refresh()

        let titles = actionItems(in: actionsSubmenu(in: harness.statusItem.menu)).map(\.title)
        expect(titles.contains("Blink"), "Actions submenu should include the new catalog extra after refresh")
        expect(!titles.contains("Wave"), "Actions submenu should drop the previous catalog after refresh")
    }

    func sleepingDisablesActionsAndShowsBusyPrompt() {
        let commands = MenuBarControllerActionsCommandSpy(
            catalog: makeCatalog(petId: "pet-a", extraNames: ["Wave", "Spin"]),
            state: .sleeping
        )
        let triggerService = ActionTriggerService(commandHandler: commands)
        let harness = makeHarness(commands: commands, triggerService: triggerService)

        let actionsMenu = actionsSubmenu(in: harness.statusItem.menu)

        expect(actionItems(in: actionsMenu).allSatisfy { !$0.isEnabled }, "sleeping should disable every action item")
        expect(actionsMenu.item(withTitle: ActionTriggerService.busyReason) != nil, "sleeping submenu should show the busy prompt")

        let actionId = ActionId(rawValue: "idle_default")!
        harness.coordinator.handle(.playAction(actionId))
        expect(
            harness.coordinator.menuState.actionNotice == ActionTriggerService.busyReason,
            "sleeping rejection should be observable through menuState"
        )
    }

    func clickingActionRoutesToPlayActionTrigger() {
        let commands = MenuBarControllerActionsCommandSpy(
            catalog: makeCatalog(petId: "pet-a", extraNames: ["Wave", "Spin"])
        )
        let triggerService = MenuBarControllerActionsTriggerService()
        let harness = makeHarness(commands: commands, triggerService: triggerService)
        let actionsMenu = actionsSubmenu(in: harness.statusItem.menu)
        let handler = firstActionHandler(in: actionsMenu)

        handler.trigger()

        expect(triggerService.triggeredActionIds == [handler.actionId], "clicking an action should route through coordinator playAction")
    }

    private func makeHarness(
        commands: MenuBarControllerActionsCommandSpy,
        triggerService: ActionTriggerServicing? = nil
    ) -> MenuBarControllerActionsHarness {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let coordinator = AppCoordinator(
            petWindow: MenuBarControllerActionsWindowSpy(),
            petCommands: commands,
            settingsWindow: MenuBarControllerActionsSettingsSpy(),
            launchAtLogin: MenuBarControllerActionsLaunchSpy(),
            application: MenuBarControllerActionsApplicationSpy(),
            actionTriggerService: triggerService
        )
        let controller = MenuBarController(coordinator: coordinator, statusItem: statusItem)
        controller.configure()
        return MenuBarControllerActionsHarness(
            statusItem: statusItem,
            coordinator: coordinator,
            controller: controller
        )
    }

    private func actionsSubmenu(in menu: NSMenu?) -> NSMenu {
        guard let submenu = menu?.item(withTitle: "Actions")?.submenu else {
            fail("status menu should include an Actions submenu")
        }
        return submenu
    }

    private func actionItems(in menu: NSMenu) -> [NSMenuItem] {
        menu.items.filter { item in
            !item.isSeparatorItem && item.submenu == nil && item.representedObject is ActionsMenuItemTrigger
        }
    }

    private func firstActionHandler(in menu: NSMenu) -> ActionsMenuItemTrigger {
        guard let handler = actionItems(in: menu).first?.representedObject as? ActionsMenuItemTrigger else {
            fail("Actions submenu should retain an ActionsMenuItemTrigger")
        }
        return handler
    }

    private func makeCatalog(petId: String, extraNames: [String]) -> PetActionCatalog {
        let extras = extraNames.enumerated().map { index, name in
            makeAction(id: "extra_\(petId)_\(index)", role: nil, displayName: name)
        }
        return makeStandardCatalog(petId: petId, extras: extras)
    }
}

@MainActor
private struct MenuBarControllerActionsHarness {
    let statusItem: NSStatusItem
    let coordinator: AppCoordinator
    let controller: MenuBarController
}

@MainActor
private final class MenuBarControllerActionsTriggerService: ActionTriggerServicing {
    var onTriggerRejected: ((ActionId, ActionTriggerEligibility) -> Void)?
    var triggeredActionIds: [ActionId] = []

    func eligibility(for actionId: ActionId) -> ActionTriggerEligibility {
        .allowed
    }

    func trigger(actionId: ActionId) -> ActionTriggerEligibility {
        triggeredActionIds.append(actionId)
        return .allowed
    }
}

@MainActor
private final class MenuBarControllerActionsCommandSpy: PetCommandHandling {
    var runtimeState: PetRuntimeState
    var catalog: PetActionCatalog

    init(catalog: PetActionCatalog, state: PetState = .idle) {
        self.catalog = catalog
        self.runtimeState = PetRuntimeState(
            currentState: state,
            mood: 0.8,
            hunger: 0.2,
            energy: 0.8,
            lastInteractionAt: Date(timeIntervalSince1970: 1_800_100_000),
            isDragging: false,
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
    func playAction(_ id: ActionId) {}
    func setScale(_ scale: Double) {
        runtimeState.scale = scale
    }
    func setRandomWalkingEnabled(_ enabled: Bool) {}
    func tick(at date: Date) {}
}

@MainActor
private final class MenuBarControllerActionsWindowSpy: PetWindowControlling {
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
private final class MenuBarControllerActionsSettingsSpy: SettingsWindowControlling {
    func showSettings() {}
}

@MainActor
private final class MenuBarControllerActionsLaunchSpy: LaunchAtLoginControlling {
    var isLaunchAtLoginEnabled = false

    func setLaunchAtLoginEnabled(_ enabled: Bool) {
        isLaunchAtLoginEnabled = enabled
    }
}

@MainActor
private final class MenuBarControllerActionsApplicationSpy: ApplicationTerminating {
    func terminate() {}
}
