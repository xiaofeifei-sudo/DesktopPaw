import AppKit
import Foundation
import DesktopPet

@MainActor
func runAppCoordinatorMicroDialogTests() {
    let tests = AppCoordinatorMicroDialogTests()
    tests.selectFeedOptionTriggersFeedCommand()
    tests.selectPetOptionTriggersPetCommand()
    tests.selectSleepOptionTriggersSleep()
    tests.selectDismissOptionDoesNotProduceNegativeFeedback()
    tests.selectDismissWithReplyShowsReplyBubble()
    tests.selectExpiredOptionDoesNothing()
    tests.selectOptionEmitsMicroDialogCompletedEvent()
}

@MainActor
private struct AppCoordinatorMicroDialogTests {
    func selectFeedOptionTriggersFeedCommand() {
        let harness = makeHarness()
        let optionId = MicroDialogOptionId(rawValue: "opt-feed")
        let dialog = makeDialog(options: [
            MicroDialogOption(id: optionId, title: "Feed", command: .feed)
        ])
        harness.microDialogService.setActiveDialog(dialog)

        harness.coordinator.handle(.selectMicroDialogOption(optionId))

        expect(
            harness.commandsSpy.actions.contains(.feed),
            "selectMicroDialogOption with feed command should trigger feed"
        )
    }

    func selectPetOptionTriggersPetCommand() {
        let harness = makeHarness()
        let optionId = MicroDialogOptionId(rawValue: "opt-pet")
        let dialog = makeDialog(options: [
            MicroDialogOption(id: optionId, title: "Pet", command: .pet)
        ])
        harness.microDialogService.setActiveDialog(dialog)

        harness.coordinator.handle(.selectMicroDialogOption(optionId))

        expect(
            harness.commandsSpy.actions.contains(.pet),
            "selectMicroDialogOption with pet command should trigger pet"
        )
    }

    func selectSleepOptionTriggersSleep() {
        let harness = makeHarness()
        let optionId = MicroDialogOptionId(rawValue: "opt-sleep")
        let dialog = makeDialog(options: [
            MicroDialogOption(id: optionId, title: "Sleep", command: .sleep)
        ])
        harness.microDialogService.setActiveDialog(dialog)

        harness.coordinator.handle(.selectMicroDialogOption(optionId))

        expect(
            harness.commandsSpy.actions.contains(.sleep),
            "selectMicroDialogOption with sleep command should trigger sleep"
        )
    }

    func selectDismissOptionDoesNotProduceNegativeFeedback() {
        let harness = makeHarness()
        let optionId = MicroDialogOptionId(rawValue: "opt-dismiss")
        let dialog = makeDialog(options: [
            MicroDialogOption(id: optionId, title: "Later", command: .dismiss(replyTrigger: nil))
        ])
        harness.microDialogService.setActiveDialog(dialog)

        harness.coordinator.handle(.selectMicroDialogOption(optionId))

        expect(
            harness.commandsSpy.actions.isEmpty,
            "dismiss option should not trigger any pet commands"
        )
        expect(
            harness.bubbleSpy.companionInteractions.isEmpty,
            "dismiss option without reply should not trigger any bubble"
        )
    }

    func selectDismissWithReplyShowsReplyBubble() {
        let harness = makeHarness()
        let optionId = MicroDialogOptionId(rawValue: "opt-reply")
        let dialog = makeDialog(options: [
            MicroDialogOption(id: optionId, title: "Done", command: .dismiss(replyTrigger: .idle))
        ])
        harness.microDialogService.setActiveDialog(dialog)

        harness.coordinator.handle(.selectMicroDialogOption(optionId))

        expect(
            harness.bubbleSpy.companionInteractions.contains(.idle),
            "dismiss with replyTrigger should show reply bubble"
        )
    }

    func selectExpiredOptionDoesNothing() {
        let harness = makeHarness()
        let optionId = MicroDialogOptionId(rawValue: "opt-expired")
        let past = Date().addingTimeInterval(-60)
        let dialog = MicroDialog(
            id: "dlg-1",
            promptPhraseId: "phrase-1",
            options: [MicroDialogOption(id: optionId, title: "Feed", command: .feed)],
            expiresAt: past
        )
        harness.microDialogService.setActiveDialog(dialog)

        harness.coordinator.handle(.selectMicroDialogOption(optionId))

        expect(
            harness.commandsSpy.actions.isEmpty,
            "expired dialog option should not trigger any command"
        )
    }

    func selectOptionEmitsMicroDialogCompletedEvent() {
        let harness = makeHarness()
        let optionId = MicroDialogOptionId(rawValue: "opt-feed")
        let dialog = makeDialog(options: [
            MicroDialogOption(id: optionId, title: "Feed", command: .feed)
        ])
        harness.microDialogService.setActiveDialog(dialog)

        harness.coordinator.handle(.selectMicroDialogOption(optionId))

        expect(
            harness.routerSpy.lastEvent != nil,
            "selectMicroDialogOption should emit microDialogCompleted event"
        )
        if case .microDialogCompleted(let id, _) = harness.routerSpy.lastEvent {
            expect(id == optionId, "microDialogCompleted should carry the option id")
        } else if harness.routerSpy.lastEvent != nil {
            fail("expected microDialogCompleted event")
        }
    }

    private func makeDialog(options: [MicroDialogOption]) -> MicroDialog {
        MicroDialog(
            id: "dlg-1",
            promptPhraseId: "phrase-1",
            options: options,
            expiresAt: Date().addingTimeInterval(60)
        )
    }

    private func makeHarness() -> MicroDialogCoordinatorHarness {
        let commandsSpy = MicroDialogCommandSpy()
        let bubbleSpy = MicroDialogBubbleSpy()
        let routerSpy = MicroDialogEventRouterSpy()
        let microDialogService = MicroDialogService()
        let coordinator = AppCoordinator(
            petWindow: MicroDialogWindowSpy(),
            petCommands: commandsSpy,
            settingsWindow: MicroDialogSettingsSpy(),
            launchAtLogin: MicroDialogLaunchSpy(),
            application: MicroDialogApplicationSpy(),
            bubble: bubbleSpy,
            companionRouter: routerSpy,
            microDialogService: microDialogService,
            speechBubbleEnabled: true
        )
        return MicroDialogCoordinatorHarness(
            coordinator: coordinator,
            commandsSpy: commandsSpy,
            bubbleSpy: bubbleSpy,
            routerSpy: routerSpy,
            microDialogService: microDialogService
        )
    }
}

@MainActor
private struct MicroDialogCoordinatorHarness {
    let coordinator: AppCoordinator
    let commandsSpy: MicroDialogCommandSpy
    let bubbleSpy: MicroDialogBubbleSpy
    let routerSpy: MicroDialogEventRouterSpy
    let microDialogService: MicroDialogService
}

private enum MicroDialogCommandAction: Equatable {
    case clicked, pet, feed, sleep, wake
}

@MainActor
private final class MicroDialogCommandSpy: PetCommandHandling {
    var runtimeState = PetRuntimeState.defaultState(at: Date())
    var catalog = PetActionCatalog(petId: "test", actions: [], warnings: [])
    var isSleeping = false
    var actions: [MicroDialogCommandAction] = []

    func clicked() { actions.append(.clicked) }
    func pet() { actions.append(.pet) }
    func feed() { actions.append(.feed) }
    func sleep() { actions.append(.sleep); isSleeping = true }
    func wake() { actions.append(.wake); isSleeping = false }
    func dragStarted() {}
    func dragEnded() {}
    func playAction(_ id: ActionId) {}
    func setScale(_ scale: Double) {}
    func setRandomWalkingEnabled(_ enabled: Bool) {}
    func tick(at date: Date) {}
}

@MainActor
private final class MicroDialogBubbleSpy: BubbleCommanding {
    var isEnabled = true
    var currentBubble: PetBubble? { nil }
    var companionInteractions: [BubbleTrigger] = []

    func setSpeechBubbleEnabled(_ enabled: Bool) { isEnabled = enabled }
    func setBubbleFrequency(_ frequency: BubbleFrequency) {}
    func handleInteraction(_ event: PetEvent, state: PetRuntimeState, at date: Date) {}
    func handleTick(state: PetRuntimeState, at date: Date) {}
    func handleCompanionInteraction(_ trigger: BubbleTrigger, context: CompanionContext, at date: Date) {
        companionInteractions.append(trigger)
    }
    func handleCompanionTick(context: CompanionContext, at date: Date) {}
}

@MainActor
private final class MicroDialogEventRouterSpy: CompanionEventRouting {
    var lastEvent: CompanionEvent?

    func handle(_ event: CompanionEvent, runtimeState: PetRuntimeState) -> CompanionEventResult {
        lastEvent = event
        return CompanionEventResult()
    }

    func context(runtimeState: PetRuntimeState) -> CompanionContext {
        CompanionContext(
            petId: "test",
            petDisplayName: "Test",
            petNickname: nil,
            userNickname: nil,
            runtimeState: runtimeState,
            relationship: RelationshipSnapshot(intimacyPoints: 0, currentLevel: .acquaintance),
            preferences: CompanionPreferences(),
            timeSlots: [.morning],
            recentBubbleTexts: [],
            lastCompanionEvent: nil
        )
    }

    func switchPet(id: String, displayName: String) {}

    func resetRelationship(runtimeState: PetRuntimeState) -> CompanionEventResult {
        CompanionEventResult()
    }
}

@MainActor
private final class MicroDialogWindowSpy: PetWindowControlling {
    var isPetVisible = true
    func showPet() {}
    func hidePet() {}
    func resetPosition() {}
    func saveStateBeforeQuit() {}
}

@MainActor
private final class MicroDialogSettingsSpy: SettingsWindowControlling {
    func showSettings() {}
}

@MainActor
private final class MicroDialogLaunchSpy: LaunchAtLoginControlling {
    var isLaunchAtLoginEnabled = false
    func setLaunchAtLoginEnabled(_ enabled: Bool) { isLaunchAtLoginEnabled = enabled }
}

@MainActor
private final class MicroDialogApplicationSpy: ApplicationTerminating {
    func terminate() {}
}
