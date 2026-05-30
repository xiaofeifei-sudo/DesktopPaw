import Foundation
import DesktopPet

@MainActor
func runBubbleSchedulerTests() {
    let tests = BubbleSchedulerTests()
    tests.expiresStaleBubble()
    tests.keepsLiveBubble()
    tests.canEmitInteractionAlways()
    tests.throttlesAmbientUntilIntervalElapsed()
    tests.throttlesStateUntilIntervalElapsed()
    tests.rejectsLowerPriorityWhenHigherActive()
    tests.allowsHigherPriorityToReplaceLower()
    tests.clearCurrentRemovesActiveBubble()
}

@MainActor
private struct BubbleSchedulerTests {
    func expiresStaleBubble() {
        let scheduler = BubbleScheduler()
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let bubble = makeBubble(priority: .ambient, createdAt: start, duration: 3)
        scheduler.register(bubble)

        scheduler.expireIfNeeded(at: start.addingTimeInterval(4))
        expect(scheduler.currentBubble == nil, "expired bubble should be cleared")
    }

    func keepsLiveBubble() {
        let scheduler = BubbleScheduler()
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let bubble = makeBubble(priority: .state, createdAt: start, duration: 3)
        scheduler.register(bubble)

        scheduler.expireIfNeeded(at: start.addingTimeInterval(1))
        expect(scheduler.currentBubble == bubble, "live bubble should remain")
    }

    func canEmitInteractionAlways() {
        let scheduler = BubbleScheduler()
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        scheduler.register(makeBubble(priority: .ambient, createdAt: now, duration: 60))

        let allowed = scheduler.canEmit(priority: .interaction, at: now, minimumInterval: 60)
        expect(allowed, "interaction priority should override ambient")
    }

    func throttlesAmbientUntilIntervalElapsed() {
        let scheduler = BubbleScheduler()
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        scheduler.register(makeBubble(priority: .ambient, createdAt: start, duration: 1))
        scheduler.expireIfNeeded(at: start.addingTimeInterval(2))

        let earlyAllowed = scheduler.canEmit(priority: .ambient, at: start.addingTimeInterval(30), minimumInterval: 60)
        expect(!earlyAllowed, "ambient should be throttled before interval elapses")

        let lateAllowed = scheduler.canEmit(priority: .ambient, at: start.addingTimeInterval(61), minimumInterval: 60)
        expect(lateAllowed, "ambient should be allowed once interval elapses")
    }

    func throttlesStateUntilIntervalElapsed() {
        let scheduler = BubbleScheduler()
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        scheduler.register(makeBubble(priority: .state, createdAt: start, duration: 1))
        scheduler.expireIfNeeded(at: start.addingTimeInterval(2))

        let earlyAllowed = scheduler.canEmit(priority: .state, at: start.addingTimeInterval(10), minimumInterval: 60)
        expect(!earlyAllowed, "state priority should respect throttle interval")

        let lateAllowed = scheduler.canEmit(priority: .state, at: start.addingTimeInterval(60), minimumInterval: 60)
        expect(lateAllowed, "state should be allowed after interval elapses")
    }

    func rejectsLowerPriorityWhenHigherActive() {
        let scheduler = BubbleScheduler()
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        scheduler.register(makeBubble(priority: .interaction, createdAt: now, duration: 60))

        let allowed = scheduler.canEmit(priority: .ambient, at: now, minimumInterval: 60)
        expect(!allowed, "ambient should not replace interaction")
    }

    func allowsHigherPriorityToReplaceLower() {
        let scheduler = BubbleScheduler()
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        scheduler.register(makeBubble(priority: .ambient, createdAt: now, duration: 60))

        let stateAllowed = scheduler.canEmit(priority: .state, at: now, minimumInterval: 60)
        expect(stateAllowed, "state should replace ambient")

        let interactionAllowed = scheduler.canEmit(priority: .interaction, at: now, minimumInterval: 60)
        expect(interactionAllowed, "interaction should replace ambient")
    }

    func clearCurrentRemovesActiveBubble() {
        let scheduler = BubbleScheduler()
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        scheduler.register(makeBubble(priority: .state, createdAt: now, duration: 60))

        scheduler.clearCurrent()
        expect(scheduler.currentBubble == nil, "clearCurrent should remove the active bubble")
    }
}

private func makeBubble(priority: BubblePriority, createdAt: Date, duration: TimeInterval) -> PetBubble {
    PetBubble(
        id: UUID(),
        text: "phrase",
        priority: priority,
        createdAt: createdAt,
        expiresAt: createdAt.addingTimeInterval(duration)
    )
}
