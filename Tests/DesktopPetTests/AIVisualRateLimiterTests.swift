import Foundation
import DesktopPet

@MainActor
func runAIVisualRateLimiterTests() {
    let tests = AIVisualRateLimiterTests()
    tests.canTriggerWhenNoPreviousTrigger()
    tests.canTriggerDeniesWithinInterval()
    tests.canTriggerAllowsAfterInterval()
    tests.canTriggerAlwaysAllowsUserRequest()
    tests.recordTriggerUpdatesLastTime()
    tests.nextAllowedTimeReturnsNilWhenNotRateLimited()
    tests.nextAllowedTimeReturnsFutureDate()
    tests.nextAllowedTimeReturnsNilForUserRequest()
    tests.differentSourcesTrackedIndependently()
    tests.setLastAutonomousAtOverridesState()
}

@MainActor
private struct AIVisualRateLimiterTests {
    private let baseDate = Date()

    private func makeLimiter(interval: TimeInterval = 30 * 60) -> AIVisualRateLimiter {
        AIVisualRateLimiter(autonomousMinInterval: interval)
    }

    func canTriggerWhenNoPreviousTrigger() {
        let limiter = makeLimiter()
        expect(limiter.canTrigger(source: .chat, at: baseDate), "should allow when no previous trigger")
    }

    func canTriggerDeniesWithinInterval() {
        let limiter = makeLimiter(interval: 60)
        limiter.recordTrigger(source: .chat, at: baseDate)

        let withinInterval = baseDate.addingTimeInterval(30)
        expect(!limiter.canTrigger(source: .chat, at: withinInterval), "should deny within interval")
    }

    func canTriggerAllowsAfterInterval() {
        let limiter = makeLimiter(interval: 60)
        limiter.recordTrigger(source: .chat, at: baseDate)

        let afterInterval = baseDate.addingTimeInterval(60)
        expect(limiter.canTrigger(source: .chat, at: afterInterval), "should allow after interval")
    }

    func canTriggerAlwaysAllowsUserRequest() {
        let limiter = makeLimiter(interval: 60)
        limiter.recordTrigger(source: .chat, at: baseDate)

        let withinInterval = baseDate.addingTimeInterval(1)
        expect(limiter.canTrigger(source: .userRequest, at: withinInterval), "user request should bypass rate limit")
    }

    func recordTriggerUpdatesLastTime() {
        let limiter = makeLimiter(interval: 100)
        limiter.recordTrigger(source: .chat, at: baseDate)

        let justAfter = baseDate.addingTimeInterval(50)
        expect(!limiter.canTrigger(source: .chat, at: justAfter), "rate limit should be active after recording")

        let afterInterval = baseDate.addingTimeInterval(100)
        expect(limiter.canTrigger(source: .chat, at: afterInterval), "should allow after full interval")
    }

    func nextAllowedTimeReturnsNilWhenNotRateLimited() {
        let limiter = makeLimiter()
        expect(limiter.nextAllowedTime(source: .chat, at: baseDate) == nil, "should return nil when not rate limited")
    }

    func nextAllowedTimeReturnsFutureDate() {
        let limiter = makeLimiter(interval: 60)
        limiter.recordTrigger(source: .chat, at: baseDate)

        let checkAt = baseDate.addingTimeInterval(10)
        let nextAllowed = limiter.nextAllowedTime(source: .chat, at: checkAt)
        expect(nextAllowed != nil, "should return a date when rate limited")

        let expected = baseDate.addingTimeInterval(60)
        if let next = nextAllowed {
            expect(abs(next.timeIntervalSince(expected)) < 1, "next allowed time should be baseDate + interval")
        }
    }

    func nextAllowedTimeReturnsNilForUserRequest() {
        let limiter = makeLimiter()
        limiter.recordTrigger(source: .chat, at: baseDate)

        let result = limiter.nextAllowedTime(source: .userRequest, at: baseDate)
        expect(result == nil, "user request should not be rate limited")
    }

    func differentSourcesTrackedIndependently() {
        let limiter = makeLimiter(interval: 60)
        limiter.recordTrigger(source: .chat, at: baseDate)

        let withinInterval = baseDate.addingTimeInterval(10)
        expect(!limiter.canTrigger(source: .chat, at: withinInterval), "chat should be rate limited")
        expect(limiter.canTrigger(source: .userRequest, at: withinInterval), "user request should not be rate limited")

        expect(!limiter.canTrigger(source: .smartBubble, at: withinInterval), "smartBubble should be rate limited like chat")
        expect(!limiter.canTrigger(source: .relationshipEvent, at: withinInterval), "relationshipEvent should be rate limited like chat")
    }

    func setLastAutonomousAtOverridesState() {
        let limiter = makeLimiter(interval: 60)
        limiter.recordTrigger(source: .chat, at: baseDate)

        let pastDate = baseDate.addingTimeInterval(-120)
        limiter.setLastAutonomousAt(pastDate)

        expect(limiter.canTrigger(source: .chat, at: baseDate), "should allow after resetting to past date")
    }
}
