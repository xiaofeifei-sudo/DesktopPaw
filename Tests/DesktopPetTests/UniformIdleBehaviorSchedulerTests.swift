import Foundation
import DesktopPet

func runUniformIdleBehaviorSchedulerTests() {
    let tests = UniformIdleBehaviorSchedulerTests()
    tests.emptyPoolReturnsNil()
    tests.singleCandidatePoolAlwaysReturnsThatCandidate()
    tests.threeCandidatePoolDistributionIsApproximatelyUniform()
    tests.mockRngSequenceProducesDeterministicSelection()
    tests.outOfRangeRngValueClampsToLastCandidate()
}

private struct UniformIdleBehaviorSchedulerTests {
    func emptyPoolReturnsNil() {
        let pool = IdleBehaviorPool(candidates: [])
        let rng = SequencedRandomNumberGenerator(values: [0.0, 0.5, 0.9])
        let scheduler = UniformIdleBehaviorScheduler(randomNumberGenerator: rng)

        expect(scheduler.nextAction(in: pool, context: makeContext()) == nil, "empty pool should yield nil")
        expect(rng.consumedCount == 0, "scheduler must not consume RNG when pool is empty")
    }

    func singleCandidatePoolAlwaysReturnsThatCandidate() {
        let walking = makeAction(id: "walk_default", role: .walking)
        let pool = IdleBehaviorPool(candidates: [walking])
        // Vary the RNG output to ensure even arbitrary values map to the lone candidate.
        let rng = SequencedRandomNumberGenerator(values: [0.0, 0.25, 0.5, 0.75, 0.999])
        let scheduler = UniformIdleBehaviorScheduler(randomNumberGenerator: rng)

        for _ in 0..<5 {
            let result = scheduler.nextAction(in: pool, context: makeContext())
            expect(result == walking, "single-candidate pool should always return that candidate")
        }
    }

    func threeCandidatePoolDistributionIsApproximatelyUniform() {
        let walking = makeAction(id: "walk_default", role: .walking)
        let extraA = makeAction(id: "extra_a", role: nil)
        let extraB = makeAction(id: "extra_b", role: nil)
        let pool = IdleBehaviorPool(candidates: [walking, extraA, extraB])
        // Use the system RNG with a deterministic seed-equivalent: just the live RNG; we have a wide tolerance.
        let scheduler = UniformIdleBehaviorScheduler(randomNumberGenerator: SystemRandomNumberGenerator())

        var counts: [ActionId: Int] = [:]
        let iterations = 1000
        for _ in 0..<iterations {
            guard let action = scheduler.nextAction(in: pool, context: makeContext()) else {
                fail("scheduler should never return nil for a non-empty pool")
            }
            counts[action.id, default: 0] += 1
        }

        let walkingCount = counts[walking.id, default: 0]
        let extraACount = counts[extraA.id, default: 0]
        let extraBCount = counts[extraB.id, default: 0]
        let totalCount = walkingCount + extraACount + extraBCount

        expect(totalCount == iterations, "all samples must hit one of the candidates")

        let lowerBound = 233
        let upperBound = 433
        expect(
            (lowerBound...upperBound).contains(walkingCount),
            "walking count \(walkingCount) should be within ±100 of 333 (uniform sampling)"
        )
        expect(
            (lowerBound...upperBound).contains(extraACount),
            "extra_a count \(extraACount) should be within ±100 of 333 (uniform sampling)"
        )
        expect(
            (lowerBound...upperBound).contains(extraBCount),
            "extra_b count \(extraBCount) should be within ±100 of 333 (uniform sampling)"
        )
    }

    func mockRngSequenceProducesDeterministicSelection() {
        let walking = makeAction(id: "walk_default", role: .walking)
        let extraA = makeAction(id: "extra_a", role: nil)
        let extraB = makeAction(id: "extra_b", role: nil)
        let pool = IdleBehaviorPool(candidates: [walking, extraA, extraB])
        let rng = SequencedRandomNumberGenerator(values: [0.05, 0.5, 0.95])
        let scheduler = UniformIdleBehaviorScheduler(randomNumberGenerator: rng)

        // 0.05 * 3 = 0.15 -> floor -> 0
        let first = scheduler.nextAction(in: pool, context: makeContext())
        expect(first == walking, "rng=0.05 should map to candidates[0]")

        // 0.5  * 3 = 1.5  -> floor -> 1
        let second = scheduler.nextAction(in: pool, context: makeContext())
        expect(second == extraA, "rng=0.5 should map to candidates[1]")

        // 0.95 * 3 = 2.85 -> floor -> 2
        let third = scheduler.nextAction(in: pool, context: makeContext())
        expect(third == extraB, "rng=0.95 should map to candidates[2]")
    }

    func outOfRangeRngValueClampsToLastCandidate() {
        let walking = makeAction(id: "walk_default", role: .walking)
        let extraA = makeAction(id: "extra_a", role: nil)
        let pool = IdleBehaviorPool(candidates: [walking, extraA])
        // value == 1.0 → 1.0 * 2 = 2.0 → floor → 2 → clamp to last (count - 1 == 1).
        let rng = SequencedRandomNumberGenerator(values: [1.0])
        let scheduler = UniformIdleBehaviorScheduler(randomNumberGenerator: rng)

        let action = scheduler.nextAction(in: pool, context: makeContext())
        expect(action == extraA, "rng=1.0 should clamp to the last candidate")
    }

    private func makeContext() -> IdleScheduleContext {
        IdleScheduleContext(now: Date(timeIntervalSince1970: 1_700_000_000), mood: 0.5, pendingAfterTag: nil)
    }

    private func makeAction(
        id rawId: String,
        role: ActionRole?,
        tags: [ActionTag] = []
    ) -> Action {
        Action(
            id: ActionId(rawValue: rawId)!,
            displayName: rawId,
            role: role,
            tags: tags,
            frames: [SpriteFrame(column: 0, row: 0)],
            frameDurationMs: 160,
            loop: true
        )
    }
}

private final class SequencedRandomNumberGenerator: RandomNumberGenerating {
    private let values: [Double]
    private var cursor: Int = 0

    init(values: [Double]) {
        self.values = values
    }

    var consumedCount: Int { cursor }

    func nextDouble(in range: ClosedRange<Double>) -> Double {
        guard !values.isEmpty else {
            fail("SequencedRandomNumberGenerator was asked for a value but no values were provided")
        }
        let raw = values[cursor % values.count]
        cursor += 1
        return min(max(raw, range.lowerBound), range.upperBound)
    }
}
