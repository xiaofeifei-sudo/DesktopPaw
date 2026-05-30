import Foundation
import DesktopPet

func runWeightedIdleBehaviorSchedulerTests() {
    let tests = WeightedIdleBehaviorSchedulerTests()
    tests.translatesIdleScheduleContextToTagContext()
    tests.defaultSamplerCanSelectActionFromConvertedContext()
    tests.emptyPoolReturnsNilWithoutCallingSampler()
}

private struct WeightedIdleBehaviorSchedulerTests {
    func translatesIdleScheduleContextToTagContext() {
        let first = makeAction(id: "first", role: nil)
        let second = makeAction(id: "second", role: nil)
        let sampler = CapturingWeightedActionSampler(result: second)
        let rng = FixedRandomNumberGenerator(value: 0)
        let scheduler = WeightedIdleBehaviorScheduler(
            randomNumberGenerator: rng,
            sampler: sampler,
            calendar: calendar
        )
        let pendingAfterTag = tag("after.pet")
        let idleContext = IdleScheduleContext(
            now: date(year: 2026, month: 5, day: 13, hour: 9, minute: 0),
            mood: 0.7,
            pendingAfterTag: pendingAfterTag
        )

        let result = scheduler.nextAction(in: IdleBehaviorPool(candidates: [first, second]), context: idleContext)

        expect(result == second, "scheduler should return sampler result")
        expect(sampler.capturedCandidates == [first, second], "scheduler should pass pool candidates to sampler unchanged")
        expect(sampler.capturedContext?.moodLevel == .high, "scheduler should classify mood into high level")
        expect(sampler.capturedContext?.timeSlots == [.morning, .workday], "scheduler should classify date into morning + workday")
        expect(sampler.capturedContext?.pendingAfterTag == pendingAfterTag, "scheduler should pass pending after tag through")
        expect(sampler.capturedRng === rng, "scheduler should pass injected RNG to sampler")
    }

    func defaultSamplerCanSelectActionFromConvertedContext() {
        let low = makeAction(id: "low_only", role: nil, tags: [tag("mood:low")])
        let matching = makeAction(id: "matching", role: nil, tags: [
            tag("mood:high"),
            tag("time.morning"),
            tag("after.pet")
        ])
        let night = makeAction(id: "night_only", role: nil, tags: [tag("time.night")])
        let scheduler = WeightedIdleBehaviorScheduler(
            randomNumberGenerator: FixedRandomNumberGenerator(value: 0),
            calendar: calendar
        )
        let idleContext = IdleScheduleContext(
            now: date(year: 2026, month: 5, day: 13, hour: 9, minute: 0),
            mood: 0.8,
            pendingAfterTag: tag("after.pet")
        )

        let result = scheduler.nextAction(in: IdleBehaviorPool(candidates: [low, matching, night]), context: idleContext)

        expect(result == matching, "scheduler should select the action matching mood/time/pending context")
    }

    func emptyPoolReturnsNilWithoutCallingSampler() {
        let wouldReturn = makeAction(id: "would_return", role: nil)
        let sampler = CapturingWeightedActionSampler(result: wouldReturn)
        let scheduler = WeightedIdleBehaviorScheduler(
            randomNumberGenerator: FixedRandomNumberGenerator(value: 0),
            sampler: sampler,
            calendar: calendar
        )

        let result = scheduler.nextAction(
            in: IdleBehaviorPool(candidates: []),
            context: IdleScheduleContext(now: Date(timeIntervalSince1970: 0), mood: 0.5)
        )

        expect(result == nil, "empty pool should return nil")
        expect(sampler.capturedCandidates == nil, "empty pool should not call sampler")
    }

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 8 * 60 * 60)!
        return calendar
    }

    private func date(year: Int, month: Int, day: Int, hour: Int, minute: Int) -> Date {
        let components = DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        )
        guard let date = components.date else {
            fail("test date should be constructible")
        }
        return date
    }

    private func tag(_ rawValue: String) -> ActionTag {
        guard let tag = ActionTag(rawValue: rawValue) else {
            fail("test tag should be valid: \(rawValue)")
        }
        return tag
    }
}

private final class CapturingWeightedActionSampler: WeightedActionSampling {
    private let result: Action?
    private(set) var capturedCandidates: [Action]?
    private(set) var capturedContext: TagConditionContext?
    private(set) var capturedRng: RandomNumberGenerating?

    init(result: Action?) {
        self.result = result
    }

    func sample(
        _ candidates: [Action],
        context: TagConditionContext,
        rng: RandomNumberGenerating
    ) -> Action? {
        capturedCandidates = candidates
        capturedContext = context
        capturedRng = rng
        return result
    }
}
