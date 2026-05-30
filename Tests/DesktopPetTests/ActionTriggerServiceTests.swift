import Foundation
import DesktopPet

@MainActor
func runActionTriggerServiceTests() {
    let tests = ActionTriggerServiceTests()
    tests.throttlesRepeatedTriggersForSameActionId()
    tests.throttlesRepeatedTriggersAcrossDifferentActionIds()
    tests.rejectsSleepingAndAllowsAfterWake()
    tests.rejectsDragging()
    tests.allowsReactionStates()
    tests.allowsIdleWalkingAndExtras()
    tests.rejectsUnknownActionId()
    tests.callsOnTriggerRejected()
    tests.eligibilityQueryDoesNotUpdateThrottleTime()
}

@MainActor
private struct ActionTriggerServiceTests {
    private let baseDate = Date(timeIntervalSince1970: 1_800_100_000)
    private let idleId = ActionId(rawValue: "idle_default")!
    private let walkId = ActionId(rawValue: "walk_default")!
    private let extraId = ActionId(rawValue: "extra_1")!
    private let unknownId = ActionId(rawValue: "unknown_action")!

    func throttlesRepeatedTriggersForSameActionId() {
        var currentDate = baseDate
        let spy = makeSpy()
        let service = ActionTriggerService(commandHandler: spy, now: { currentDate })

        expect(service.trigger(actionId: idleId) == .allowed, "first trigger should be allowed")
        currentDate = currentDate.addingTimeInterval(0.25)
        expect(service.trigger(actionId: idleId) == .rejectedThrottled, "same action within 1s should be throttled")

        expect(spy.playedActionIds == [idleId], "same action within 1s should call playAction once")
    }

    func throttlesRepeatedTriggersAcrossDifferentActionIds() {
        var currentDate = baseDate
        let spy = makeSpy()
        let service = ActionTriggerService(commandHandler: spy, now: { currentDate })

        expect(service.trigger(actionId: idleId) == .allowed, "first trigger should be allowed")
        currentDate = currentDate.addingTimeInterval(0.5)
        expect(service.trigger(actionId: walkId) == .rejectedThrottled, "different action within 1s should be globally throttled")

        expect(spy.playedActionIds == [idleId], "different action within 1s should still call playAction once")
    }

    func rejectsSleepingAndAllowsAfterWake() {
        let spy = makeSpy(state: .sleeping)
        let service = ActionTriggerService(commandHandler: spy, now: { baseDate })

        expect(
            service.trigger(actionId: idleId) == .rejectedBusy(reason: ActionTriggerService.busyReason),
            "sleeping trigger should be rejectedBusy"
        )
        expect(spy.playedActionIds.isEmpty, "sleeping trigger should not call playAction")

        spy.runtimeState.currentState = .idle
        expect(service.trigger(actionId: idleId) == .allowed, "wake to idle should allow trigger")
        expect(spy.playedActionIds == [idleId], "wake to idle should call playAction")
    }

    func rejectsDragging() {
        let spy = makeSpy(state: .idle, isDragging: true)
        let service = ActionTriggerService(commandHandler: spy, now: { baseDate })

        expect(
            service.trigger(actionId: idleId) == .rejectedBusy(reason: ActionTriggerService.busyReason),
            "dragging trigger should be rejectedBusy"
        )
        expect(spy.playedActionIds.isEmpty, "dragging trigger should not call playAction")
    }

    func allowsReactionStates() {
        for state in [PetState.happy, .eating, .jumping] {
            let spy = makeSpy(state: state)
            let service = ActionTriggerService(commandHandler: spy, now: { baseDate })

            expect(
                service.trigger(actionId: idleId) == .allowed,
                "\(state.rawValue) trigger should be allowed so menu actions can interrupt active playback"
            )
            expect(spy.playedActionIds == [idleId], "\(state.rawValue) trigger should call playAction")
        }
    }

    func allowsIdleWalkingAndExtras() {
        var currentDate = baseDate
        let spy = makeSpy(state: .idle)
        let service = ActionTriggerService(commandHandler: spy, now: { currentDate })

        expect(service.trigger(actionId: idleId) == .allowed, "idle state should allow role action")
        currentDate = currentDate.addingTimeInterval(1.1)
        spy.runtimeState.currentState = .walking
        expect(service.trigger(actionId: walkId) == .allowed, "walking state should allow role action")
        currentDate = currentDate.addingTimeInterval(1.1)
        spy.runtimeState.currentState = .idle
        expect(service.trigger(actionId: extraId) == .allowed, "idle state should allow extra action")

        expect(spy.playedActionIds == [idleId, walkId, extraId], "idle/walking/extras should call playAction")
    }

    func rejectsUnknownActionId() {
        let spy = makeSpy()
        let service = ActionTriggerService(commandHandler: spy, now: { baseDate })

        expect(service.trigger(actionId: unknownId) == .rejectedUnknownActionId, "unknown actionId should be rejected")
        expect(spy.playedActionIds.isEmpty, "unknown actionId should not call playAction")
    }

    func callsOnTriggerRejected() {
        let spy = makeSpy(state: .sleeping)
        let service = ActionTriggerService(commandHandler: spy, now: { baseDate })
        var rejections: [(ActionId, ActionTriggerEligibility)] = []
        service.onTriggerRejected = { actionId, eligibility in
            rejections.append((actionId, eligibility))
        }

        let result = service.trigger(actionId: idleId)

        expect(result == .rejectedBusy(reason: ActionTriggerService.busyReason), "sleeping trigger should be rejected")
        expect(rejections.count == 1, "rejected trigger should call onTriggerRejected once")
        expect(rejections.first?.0 == idleId, "rejection callback should include actionId")
        expect(rejections.first?.1 == result, "rejection callback should include eligibility")
    }

    func eligibilityQueryDoesNotUpdateThrottleTime() {
        var currentDate = baseDate
        let spy = makeSpy()
        let service = ActionTriggerService(commandHandler: spy, now: { currentDate })

        expect(service.eligibility(for: idleId) == .allowed, "initial eligibility query should be allowed")
        currentDate = currentDate.addingTimeInterval(0.5)
        expect(service.trigger(actionId: idleId) == .allowed, "query should not consume the throttle window")
        currentDate = currentDate.addingTimeInterval(0.5)
        expect(service.trigger(actionId: walkId) == .rejectedThrottled, "successful trigger should still start throttle")

        expect(spy.playedActionIds == [idleId], "eligibility query should not call playAction")
    }

    private func makeSpy(state: PetState = .idle, isDragging: Bool = false) -> SpyActionTriggerPetCommands {
        let extra = makeAction(id: "extra_1", role: nil, nextActionId: idleId)
        let runtimeState = PetRuntimeState(
            currentState: state,
            mood: 0.8,
            hunger: 0.2,
            energy: 0.8,
            lastInteractionAt: baseDate,
            isDragging: isDragging,
            scale: 1.0
        )
        return SpyActionTriggerPetCommands(
            runtimeState: runtimeState,
            catalog: makeStandardCatalog(petId: "action-trigger-test-pet", extras: [extra])
        )
    }
}

@MainActor
private final class SpyActionTriggerPetCommands: PetCommandHandling {
    var runtimeState: PetRuntimeState
    var catalog: PetActionCatalog
    var playedActionIds: [ActionId] = []

    init(runtimeState: PetRuntimeState, catalog: PetActionCatalog) {
        self.runtimeState = runtimeState
        self.catalog = catalog
    }

    var isSleeping: Bool {
        runtimeState.currentState == .sleeping
    }

    func clicked() {}
    func pet() {}
    func feed() {}
    func sleep() { runtimeState.currentState = .sleeping }
    func wake() { runtimeState.currentState = .idle }
    func dragStarted() {
        runtimeState.currentState = .dragging
        runtimeState.isDragging = true
    }
    func dragEnded() {
        runtimeState.currentState = .idle
        runtimeState.isDragging = false
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
