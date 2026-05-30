import Foundation
import DesktopPet

@MainActor
func runAIVisualActionCoordinatorTests() {
    let tests = AIVisualActionCoordinatorTests()
    tests.processCandidateReturnsAllowDecision()
    tests.processCandidateReturnsDenyDecision()
    tests.processCandidateReturnsConfirmationDecision()
    tests.confirmActionReturnsCandidate()
    tests.confirmActionFailsForUnknownId()
    tests.rejectActionRemovesPending()
    tests.confirmActionMarksFirstTrigger()
    tests.buildContextIncludesPreviousVisualAction()
    tests.eventsAreEmittedForAllow()
    tests.eventsAreEmittedForDeny()
    tests.eventsAreEmittedForConfirmation()
    tests.eventsAreEmittedForConfirmAction()
    tests.eventsAreEmittedForRejectAction()
}

private final class EventCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var _events: [AIVisualCoordinatorEvent] = []
    private var _capturedRequestId: String?

    var events: [AIVisualCoordinatorEvent] {
        lock.lock()
        defer { lock.unlock() }
        return _events
    }

    var capturedRequestId: String? {
        lock.lock()
        defer { lock.unlock() }
        return _capturedRequestId
    }

    func handler() -> (@Sendable (AIVisualCoordinatorEvent) -> Void) {
        { [weak self] event in
            self?.lock.lock()
            self?._events.append(event)
            if case .confirmationRequested(_, let req) = event {
                self?._capturedRequestId = req.id
            }
            self?.lock.unlock()
        }
    }

    func requestIdHandler() -> (@Sendable (AIVisualCoordinatorEvent) -> Void) {
        { [weak self] event in
            if case .confirmationRequested(_, let req) = event {
                self?.lock.lock()
                self?._capturedRequestId = req.id
                self?.lock.unlock()
            }
        }
    }

    func clear() {
        lock.lock()
        _events.removeAll()
        _capturedRequestId = nil
        lock.unlock()
    }
}

@MainActor
private struct AIVisualActionCoordinatorTests {
    private func makeCoordinator(
        hasPreviousConfirmation: Bool = false
    ) -> AIVisualActionCoordinator {
        let policy = AIVisualActionPolicy()
        let confirmationController = AIVisualConfirmationController(
            hasPreviousConfirmation: hasPreviousConfirmation
        )
        return AIVisualActionCoordinator(
            policy: policy,
            confirmationController: confirmationController
        )
    }

    private func makeCandidate(
        id: String = "action-1",
        source: AIVisualActionSource = .chat,
        kind: AIVisualActionKind = .expression,
        impact: AIVisualActionImpact = .low
    ) -> AIVisualActionCandidate {
        AIVisualActionCandidate(
            id: id,
            petId: "pet-1",
            source: source,
            kind: kind,
            description: "happy face",
            renderMode: .replaceWholeImage,
            requestedDurationSeconds: 60,
            impact: impact
        )
    }

    private func makeContext(
        hasPreviousVisualAction: Bool = true
    ) -> AIVisualActionContext {
        AIVisualActionContext(
            isAIEnabled: true,
            isVisualExpressionEnabled: true,
            isQuietMode: false,
            isBubbleEnabled: true,
            petId: "pet-1",
            petName: "Mimi",
            hasActiveOverlay: false,
            hasPreviousVisualAction: hasPreviousVisualAction
        )
    }

    func processCandidateReturnsAllowDecision() {
        let coordinator = makeCoordinator(hasPreviousConfirmation: true)
        let candidate = makeCandidate()
        let ctx = makeContext(hasPreviousVisualAction: true)
        let decision = coordinator.processCandidate(candidate, context: ctx)

        if case .allow(let c) = decision {
            expect(c.id == "action-1", "should return the candidate")
        } else {
            expect(false, "should return allow decision")
        }
    }

    func processCandidateReturnsDenyDecision() {
        let coordinator = makeCoordinator()
        let candidate = makeCandidate()
        let ctx = makeContext(hasPreviousVisualAction: true)
        var ctxDisabled = ctx
        ctxDisabled.isAIEnabled = false
        let decision = coordinator.processCandidate(candidate, context: ctxDisabled)

        if case .deny(let reason, _) = decision {
            expect(reason == .aiDisabled, "should deny with aiDisabled reason")
        } else {
            expect(false, "should return deny decision")
        }
    }

    func processCandidateReturnsConfirmationDecision() {
        let coordinator = makeCoordinator(hasPreviousConfirmation: false)
        let candidate = makeCandidate()
        let ctx = makeContext(hasPreviousVisualAction: false)
        let decision = coordinator.processCandidate(candidate, context: ctx)

        if case .needsConfirmation(_, reason: .firstTrigger) = decision {
            // expected
        } else {
            expect(false, "should return needsConfirmation for first trigger")
        }
    }

    func confirmActionReturnsCandidate() {
        let coordinator = makeCoordinator(hasPreviousConfirmation: false)
        let collector = EventCollector()
        coordinator.onEvent = collector.handler()

        let ctx = makeContext(hasPreviousVisualAction: false)
        _ = coordinator.processCandidate(makeCandidate(id: "action-2"), context: ctx)

        guard let requestId = collector.capturedRequestId else {
            expect(false, "should have captured confirmation request")
            return
        }

        let result = coordinator.confirmAction(requestId)
        if case .success(let confirmed) = result {
            expect(confirmed.id == "action-2", "should return the confirmed candidate")
        } else {
            expect(false, "confirm should return success with candidate")
        }
    }

    func confirmActionFailsForUnknownId() {
        let coordinator = makeCoordinator()
        let result = coordinator.confirmAction("unknown-id")

        if case .failure = result {
            // expected
        } else {
            expect(false, "confirm with unknown id should fail")
        }
    }

    func rejectActionRemovesPending() {
        let coordinator = makeCoordinator(hasPreviousConfirmation: false)
        let collector = EventCollector()
        coordinator.onEvent = collector.requestIdHandler()

        let candidate = makeCandidate()
        let ctx = makeContext(hasPreviousVisualAction: false)
        _ = coordinator.processCandidate(candidate, context: ctx)

        guard let requestId = collector.capturedRequestId else {
            expect(false, "should have captured confirmation request")
            return
        }

        coordinator.rejectAction(requestId)

        let result = coordinator.confirmAction(requestId)
        if case .failure = result {
            // expected - rejected request can't be confirmed
        } else {
            expect(false, "rejected request should not be confirmable")
        }
    }

    func confirmActionMarksFirstTrigger() {
        let coordinator = makeCoordinator(hasPreviousConfirmation: false)
        let collector = EventCollector()
        coordinator.onEvent = collector.requestIdHandler()

        let candidate = makeCandidate()
        let ctx = makeContext(hasPreviousVisualAction: false)
        _ = coordinator.processCandidate(candidate, context: ctx)

        guard let requestId = collector.capturedRequestId else { return }
        _ = coordinator.confirmAction(requestId)

        let ctxAfter = coordinator.buildContext(
            isAIEnabled: true,
            isVisualExpressionEnabled: true,
            isQuietMode: false,
            isBubbleEnabled: true,
            petId: "pet-1",
            petName: "Mimi"
        )
        expect(ctxAfter.hasPreviousVisualAction, "after first confirmation, context should reflect previous visual action")
    }

    func buildContextIncludesPreviousVisualAction() {
        let coordinator = makeCoordinator(hasPreviousConfirmation: true)
        let ctx = coordinator.buildContext(
            isAIEnabled: true,
            isVisualExpressionEnabled: true,
            isQuietMode: false,
            isBubbleEnabled: true,
            petId: "pet-1",
            petName: "Mimi"
        )
        expect(ctx.hasPreviousVisualAction, "buildContext should include hasPreviousVisualAction from confirmation controller")
    }

    func eventsAreEmittedForAllow() {
        let coordinator = makeCoordinator(hasPreviousConfirmation: true)
        let collector = EventCollector()
        coordinator.onEvent = collector.handler()

        let candidate = makeCandidate()
        let ctx = makeContext(hasPreviousVisualAction: true)
        _ = coordinator.processCandidate(candidate, context: ctx)

        expect(collector.events.count == 1, "should emit one event for allow")
        if let event = collector.events.first, case .readyForGeneration(let actionId, _) = event {
            expect(actionId == "action-1", "event should have correct actionId")
        } else {
            expect(false, "should emit readyForGeneration event")
        }
    }

    func eventsAreEmittedForDeny() {
        let coordinator = makeCoordinator()
        let collector = EventCollector()
        coordinator.onEvent = collector.handler()

        let candidate = makeCandidate()
        var ctx = makeContext()
        ctx.isAIEnabled = false
        _ = coordinator.processCandidate(candidate, context: ctx)

        expect(collector.events.count == 1, "should emit one event for deny")
        if let event = collector.events.first, case .policyDenied(let actionId, let reason) = event {
            expect(actionId == "action-1", "event should have correct actionId")
            expect(reason == .aiDisabled, "event should have correct reason")
        } else {
            expect(false, "should emit policyDenied event")
        }
    }

    func eventsAreEmittedForConfirmation() {
        let coordinator = makeCoordinator(hasPreviousConfirmation: false)
        let collector = EventCollector()
        coordinator.onEvent = collector.handler()

        let candidate = makeCandidate()
        let ctx = makeContext(hasPreviousVisualAction: false)
        _ = coordinator.processCandidate(candidate, context: ctx)

        expect(collector.events.count == 1, "should emit one event for confirmation")
        if let event = collector.events.first, case .confirmationRequested(let actionId, _) = event {
            expect(actionId == "action-1", "event should have correct actionId")
        } else {
            expect(false, "should emit confirmationRequested event")
        }
    }

    func eventsAreEmittedForConfirmAction() {
        let coordinator = makeCoordinator(hasPreviousConfirmation: false)
        let collector = EventCollector()

        // First pass: process candidate to get a confirmation request
        coordinator.onEvent = collector.handler()
        let ctx = makeContext(hasPreviousVisualAction: false)
        _ = coordinator.processCandidate(makeCandidate(id: "action-3"), context: ctx)

        guard let requestId = collector.capturedRequestId else {
            expect(false, "should have captured request id")
            return
        }

        // Second pass: confirm and check events
        let confirmCollector = EventCollector()
        coordinator.onEvent = confirmCollector.handler()
        _ = coordinator.confirmAction(requestId)

        expect(confirmCollector.events.contains(where: {
            if case .confirmed(let id) = $0 { return id == "action-3" } else { return false }
        }), "should emit confirmed event")

        expect(confirmCollector.events.contains(where: {
            if case .readyForGeneration(let id, _) = $0 { return id == "action-3" } else { return false }
        }), "should emit readyForGeneration after confirm")
    }

    func eventsAreEmittedForRejectAction() {
        let coordinator = makeCoordinator(hasPreviousConfirmation: false)
        let collector = EventCollector()
        coordinator.onEvent = collector.requestIdHandler()

        let candidate = makeCandidate()
        let ctx = makeContext(hasPreviousVisualAction: false)
        _ = coordinator.processCandidate(candidate, context: ctx)

        guard let requestId = collector.capturedRequestId else {
            expect(false, "should have captured request id")
            return
        }

        let rejectCollector = EventCollector()
        coordinator.onEvent = rejectCollector.handler()
        coordinator.rejectAction(requestId)

        expect(rejectCollector.events.contains(where: {
            if case .rejected(let id) = $0 { return id == "action-1" } else { return false }
        }), "should emit rejected event")
    }
}
