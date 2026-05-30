import Foundation
import DesktopPet

func runWeightedActionSamplerTests() {
    let tests = WeightedActionSamplerTests()
    tests.emptyCandidatesReturnNilWithoutConsumingRng()
    tests.allZeroWeightsReturnNilWithoutConsumingRng()
    tests.samplerAsksEvaluatorForEveryCandidate()
    tests.requestsRngAcrossClosedTotalWeightRange()
    tests.deterministicWeightedBoundariesSelectExpectedCandidates()
    tests.upperBoundaryClampsToLastPositiveCandidate()
    tests.moodHighLowNeutralDistributionIsApproximatelyWeighted()
    tests.sameRoleHappyHighMoodChoosesHighOnly()
    tests.sameRoleHappyLowMoodChoosesLowOnly()
    tests.sameRoleAllZeroReturnsNilForFallback()
    tests.afterTagHitConsumesState()
    tests.nonAfterHitDoesNotConsumeState()
    tests.unknownAfterTagHitDoesNotConsumeState()
    tests.motionPlaybackMetadataDoesNotParticipateInSampling()
}

private struct WeightedActionSamplerTests {
    func emptyCandidatesReturnNilWithoutConsumingRng() {
        let rng = RecordingWeightedRandomNumberGenerator(values: [])
        let sampler = DefaultWeightedActionSampler()

        let result = sampler.sample([], context: context(), rng: rng)

        expect(result == nil, "empty candidate list should return nil")
        expect(rng.consumedCount == 0, "empty candidate list should not consume RNG")
    }

    func allZeroWeightsReturnNilWithoutConsumingRng() {
        let candidates = [
            action("low_only", tags: ["mood:low"]),
            action("night_only", tags: ["time.night"])
        ]
        let rng = RecordingWeightedRandomNumberGenerator(values: [])
        let sampler = DefaultWeightedActionSampler()

        let result = sampler.sample(candidates, context: context(moodLevel: .high, timeSlots: [.morning, .workday]), rng: rng)

        expect(result == nil, "all zero weights should return nil for fallback")
        expect(rng.consumedCount == 0, "all zero weights should not consume RNG")
    }

    func samplerAsksEvaluatorForEveryCandidate() {
        let first = action("first")
        let second = action("second")
        let evaluator = StubWeightedTagConditionEvaluator(weights: [
            first.id: 1,
            second.id: 2
        ])
        let sampler = DefaultWeightedActionSampler(evaluator: evaluator)
        let rng = RecordingWeightedRandomNumberGenerator(values: [0])

        let result = sampler.sample([first, second], context: context(), rng: rng)

        expect(result == first, "rng threshold 0 should select the first positive weighted candidate")
        expect(evaluator.calls == [first.id, second.id], "sampler should ask evaluator for every candidate in order")
    }

    func requestsRngAcrossClosedTotalWeightRange() {
        let neutral = action("neutral")
        let high = action("high", tags: ["mood:high"])
        let rng = RecordingWeightedRandomNumberGenerator(values: [0])
        let sampler = DefaultWeightedActionSampler()

        _ = sampler.sample([neutral, high], context: context(moodLevel: .high), rng: rng)

        expect(rng.requestedRanges.count == 1, "sampler should request one RNG value")
        let range = rng.requestedRanges[0]
        expect(range.lowerBound == 0, "weighted RNG range should start at zero")
        expect(range.upperBound == 4, "weighted RNG range should end at total weight")
    }

    func deterministicWeightedBoundariesSelectExpectedCandidates() {
        let first = action("first")
        let second = action("second", tags: ["mood:high"])
        let third = action("third", tags: ["time.morning"])
        let sampler = DefaultWeightedActionSampler()
        let rng = RecordingWeightedRandomNumberGenerator(values: [0, 1, 3.99, 4, 6.999])
        let candidates = [first, second, third]
        let tagContext = context(moodLevel: .high, timeSlots: [.morning, .workday])

        expect(sampler.sample(candidates, context: tagContext, rng: rng) == first, "threshold 0 should hit first weight bucket")
        expect(sampler.sample(candidates, context: tagContext, rng: rng) == second, "threshold at first boundary should move to second bucket")
        expect(sampler.sample(candidates, context: tagContext, rng: rng) == second, "threshold before second boundary should stay in second bucket")
        expect(sampler.sample(candidates, context: tagContext, rng: rng) == third, "threshold at second boundary should move to third bucket")
        expect(sampler.sample(candidates, context: tagContext, rng: rng) == third, "threshold near total should hit third bucket")
    }

    func upperBoundaryClampsToLastPositiveCandidate() {
        let first = action("first")
        let second = action("second", tags: ["mood:high"])
        let zero = action("zero", tags: ["mood:low"])
        let sampler = DefaultWeightedActionSampler()
        let rng = RecordingWeightedRandomNumberGenerator(values: [4])

        let result = sampler.sample([first, second, zero], context: context(moodLevel: .high), rng: rng)

        expect(result == second, "threshold equal to total weight should clamp to the last positive candidate")
    }

    func moodHighLowNeutralDistributionIsApproximatelyWeighted() {
        let high = action("high", tags: ["mood:high"])
        let low = action("low", tags: ["mood:low"])
        let neutral = action("neutral")
        let sampler = DefaultWeightedActionSampler()
        let rng = FractionWeightedRandomNumberGenerator(modulus: 1000)
        let candidates = [high, low, neutral]
        let tagContext = context(moodLevel: .high)

        var counts: [ActionId: Int] = [:]
        for _ in 0..<1000 {
            guard let result = sampler.sample(candidates, context: tagContext, rng: rng) else {
                fail("weighted sampler should select a candidate when total weight is positive")
            }
            counts[result.id, default: 0] += 1
        }

        let highCount = counts[high.id, default: 0]
        let lowCount = counts[low.id, default: 0]
        let neutralCount = counts[neutral.id, default: 0]
        expect((650...850).contains(highCount), "mood:high should be sampled near 75%, got \(highCount)")
        expect(lowCount == 0, "mood:low should never be sampled at high mood")
        expect((150...350).contains(neutralCount), "untagged action should be sampled near 25%, got \(neutralCount)")
    }

    func sameRoleHappyHighMoodChoosesHighOnly() {
        let high = action("happy_high", role: .happy, tags: ["mood:high"])
        let low = action("happy_low", role: .happy, tags: ["mood:low"])
        let sampler = DefaultWeightedActionSampler()
        let rng = RecordingWeightedRandomNumberGenerator(values: [2.99])

        let result = sampler.sample([high, low], context: context(moodLevel: .high), rng: rng)

        expect(result == high, "high mood should only sample the happy action tagged mood:high")
    }

    func sameRoleHappyLowMoodChoosesLowOnly() {
        let high = action("happy_high", role: .happy, tags: ["mood:high"])
        let low = action("happy_low", role: .happy, tags: ["mood:low"])
        let sampler = DefaultWeightedActionSampler()
        let rng = RecordingWeightedRandomNumberGenerator(values: [0])

        let result = sampler.sample([high, low], context: context(moodLevel: .low), rng: rng)

        expect(result == low, "low mood should only sample the happy action tagged mood:low")
    }

    func sameRoleAllZeroReturnsNilForFallback() {
        let night = action("happy_night", role: .happy, tags: ["time.night"])
        let low = action("happy_low", role: .happy, tags: ["mood:low"])
        let sampler = DefaultWeightedActionSampler()
        let rng = RecordingWeightedRandomNumberGenerator(values: [])

        let result = sampler.sample([night, low], context: context(moodLevel: .high, timeSlots: [.morning, .workday]), rng: rng)

        expect(result == nil, "same-role all-zero candidates should return nil so the caller can run fallback")
        expect(rng.consumedCount == 0, "same-role all-zero candidates should not consume RNG")
    }

    func afterTagHitConsumesState() {
        let after = action("after_pet", tags: ["after.pet"])
        let afterState = TrackingAfterTagState(pending: tag("after.pet"))
        let sampler = DefaultWeightedActionSampler(afterTagState: afterState)
        let rng = RecordingWeightedRandomNumberGenerator(values: [0])

        let result = sampler.sample([after], context: context(pendingAfterTag: tag("after.pet")), rng: rng)

        expect(result == after, "after-tag action should be selected")
        expect(afterState.consumeCount == 1, "known after-tag hit should consume after state")
        expect(afterState.pending == nil, "known after-tag consume should clear pending state")
    }

    func nonAfterHitDoesNotConsumeState() {
        let neutral = action("neutral")
        let after = action("after_pet", tags: ["after.pet"])
        let afterState = TrackingAfterTagState(pending: tag("after.pet"))
        let sampler = DefaultWeightedActionSampler(afterTagState: afterState)
        let rng = RecordingWeightedRandomNumberGenerator(values: [0.5])

        let result = sampler.sample([neutral, after], context: context(pendingAfterTag: tag("after.pet")), rng: rng)

        expect(result == neutral, "neutral action should be selected by threshold inside first bucket")
        expect(afterState.consumeCount == 0, "non-after hit should not consume after state")
        expect(afterState.pending == tag("after.pet"), "non-after hit should leave pending after state intact")
    }

    func unknownAfterTagHitDoesNotConsumeState() {
        let unknown = action("after_play", tags: ["after.play"])
        let afterState = TrackingAfterTagState(pending: tag("after.play"))
        let sampler = DefaultWeightedActionSampler(afterTagState: afterState)
        let rng = RecordingWeightedRandomNumberGenerator(values: [0])

        let result = sampler.sample([unknown], context: context(pendingAfterTag: tag("after.play")), rng: rng)

        expect(result == unknown, "unknown after tag can still be selected as a normal weighted action")
        expect(afterState.consumeCount == 0, "unknown after tag should not trigger one-shot consume")
        expect(afterState.pending == tag("after.play"), "unknown after tag should leave pending state intact")
    }

    func motionPlaybackMetadataDoesNotParticipateInSampling() {
        let matching = makeAction(
            id: "matching_motion_metadata",
            role: nil,
            tags: [tag("mood:high")],
            frames: [SpriteFrame(column: 0, row: 0), SpriteFrame(column: 1, row: 0)],
            frameDurationMs: 1_000,
            loop: false
        )
        let mismatching = makeAction(
            id: "mismatching_motion_metadata",
            role: nil,
            tags: [tag("mood:low")],
            frames: [SpriteFrame(column: 0, row: 1)],
            frameDurationMs: 10,
            loop: true
        )
        let sampler = DefaultWeightedActionSampler()
        let rng = RecordingWeightedRandomNumberGenerator(values: [2.99])

        let result = sampler.sample([matching, mismatching], context: context(moodLevel: .high), rng: rng)

        expect(result == matching, "sampling should depend on tag weights, not playback or reduced-motion metadata")
    }

    private func action(
        _ rawId: String,
        role: ActionRole? = nil,
        tags rawTags: [String] = []
    ) -> Action {
        makeAction(id: rawId, role: role, tags: rawTags.map(tag))
    }

    private func context(
        moodLevel: MoodLevel = .medium,
        timeSlots: Set<TimeSlot> = [.afternoon, .workday],
        pendingAfterTag: ActionTag? = nil
    ) -> TagConditionContext {
        TagConditionContext(
            moodLevel: moodLevel,
            timeSlots: timeSlots,
            pendingAfterTag: pendingAfterTag
        )
    }

    private func tag(_ rawValue: String) -> ActionTag {
        guard let tag = ActionTag(rawValue: rawValue) else {
            fail("test tag should be valid: \(rawValue)")
        }
        return tag
    }
}

private final class StubWeightedTagConditionEvaluator: TagConditionEvaluating {
    private let weights: [ActionId: Double]
    private(set) var calls: [ActionId] = []

    init(weights: [ActionId: Double]) {
        self.weights = weights
    }

    func weight(for action: Action, context: TagConditionContext) -> Double {
        calls.append(action.id)
        return weights[action.id] ?? 0
    }
}

private final class RecordingWeightedRandomNumberGenerator: RandomNumberGenerating {
    private let values: [Double]
    private var index = 0
    private(set) var requestedRanges: [ClosedRange<Double>] = []

    init(values: [Double]) {
        self.values = values
    }

    var consumedCount: Int {
        index
    }

    func nextDouble(in range: ClosedRange<Double>) -> Double {
        guard !values.isEmpty else {
            fail("RecordingWeightedRandomNumberGenerator was consumed without a configured value")
        }
        requestedRanges.append(range)
        let raw = values[min(index, values.count - 1)]
        index += 1
        return min(max(raw, range.lowerBound), range.upperBound)
    }
}

private final class FractionWeightedRandomNumberGenerator: RandomNumberGenerating {
    private let modulus: Int
    private var index = 0

    init(modulus: Int) {
        precondition(modulus > 0, "modulus must be positive")
        self.modulus = modulus
    }

    func nextDouble(in range: ClosedRange<Double>) -> Double {
        let fraction = Double(index % modulus) / Double(modulus)
        index += 1
        return range.lowerBound + fraction * (range.upperBound - range.lowerBound)
    }
}

private final class TrackingAfterTagState: AfterTagStateMaintaining {
    private(set) var consumeCount = 0
    var pending: ActionTag?

    init(pending: ActionTag?) {
        self.pending = pending
    }

    func mark(after reaction: PetState) {}

    func consume() {
        consumeCount += 1
        pending = nil
    }

    func cancel() {
        pending = nil
    }
}
