import Foundation
import DesktopPet

@MainActor
func runAppCoordinatorActionsTests() {
    let tests = AppCoordinatorActionsTests()
    tests.playActionForwardsToActionTriggerService()
    tests.rejectedPlayActionUpdatesMenuStateNotice()
}

@MainActor
private struct AppCoordinatorActionsTests {
    func playActionForwardsToActionTriggerService() {
        let actionId = ActionId(rawValue: "extra_wave")!
        let triggerService = AppCoordinatorActionsTriggerService()
        let coordinator = makeCoordinator(triggerService: triggerService)

        coordinator.handle(.playAction(actionId))

        expect(triggerService.triggeredActionIds == [actionId], "playAction should forward actionId to ActionTriggerService.trigger")
        expect(coordinator.menuState.actionNotice == nil, "allowed playAction should clear action notice")
    }

    func rejectedPlayActionUpdatesMenuStateNotice() {
        let actionId = ActionId(rawValue: "extra_wave")!
        let triggerService = AppCoordinatorActionsTriggerService(result: .rejectedBusy(reason: ActionTriggerService.busyReason))
        let coordinator = makeCoordinator(triggerService: triggerService)

        coordinator.handle(.playAction(actionId))

        expect(
            coordinator.menuState.actionNotice == ActionTriggerService.busyReason,
            "rejected playAction should expose an inline menuState notice"
        )
    }

    private func makeCoordinator(triggerService: ActionTriggerServicing) -> AppCoordinator {
        AppCoordinator(
            petWindow: AppCoordinatorActionsWindowSpy(),
            petCommands: AppCoordinatorActionsCommandSpy(),
            settingsWindow: AppCoordinatorActionsSettingsSpy(),
            launchAtLogin: AppCoordinatorActionsLaunchSpy(),
            application: AppCoordinatorActionsApplicationSpy(),
            actionTriggerService: triggerService
        )
    }
}

@MainActor
private final class AppCoordinatorActionsTriggerService: ActionTriggerServicing {
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
private final class AppCoordinatorActionsWindowSpy: PetWindowControlling {
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
private final class AppCoordinatorActionsCommandSpy: PetCommandHandling {
    var runtimeState = PetRuntimeState.defaultState()
    var catalog = makeStandardCatalog(
        petId: "app-coordinator-actions",
        extras: [makeAction(id: "extra_wave", role: nil)]
    )

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
    func dragStarted() {}
    func dragEnded() {}
    func playAction(_ id: ActionId) {}
    func setScale(_ scale: Double) {}
    func setRandomWalkingEnabled(_ enabled: Bool) {}
    func tick(at date: Date) {}
}

@MainActor
private final class AppCoordinatorActionsSettingsSpy: SettingsWindowControlling {
    func showSettings() {}
}

@MainActor
private final class AppCoordinatorActionsLaunchSpy: LaunchAtLoginControlling {
    var isLaunchAtLoginEnabled = false

    func setLaunchAtLoginEnabled(_ enabled: Bool) {
        isLaunchAtLoginEnabled = enabled
    }
}

@MainActor
private final class AppCoordinatorActionsApplicationSpy: ApplicationTerminating {
    func terminate() {}
}
