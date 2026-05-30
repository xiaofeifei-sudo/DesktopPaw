import Foundation

public protocol WeightedActionSampling {
    func sample(
        _ candidates: [Action],
        context: TagConditionContext,
        rng: RandomNumberGenerating
    ) -> Action?
}

public final class DefaultWeightedActionSampler: WeightedActionSampling {
    private static let consumableAfterTagRawValues: Set<String> = [
        "after.click",
        "after.feed",
        "after.pet"
    ]

    private let evaluator: TagConditionEvaluating
    private let afterTagState: AfterTagStateMaintaining?

    public init(
        evaluator: TagConditionEvaluating = DefaultTagConditionEvaluator(),
        afterTagState: AfterTagStateMaintaining? = nil
    ) {
        self.evaluator = evaluator
        self.afterTagState = afterTagState
    }

    public func sample(
        _ candidates: [Action],
        context: TagConditionContext,
        rng: RandomNumberGenerating
    ) -> Action? {
        guard !candidates.isEmpty else {
            return nil
        }

        let weightedCandidates = candidates.map { action -> (action: Action, weight: Double) in
            let weight = evaluator.weight(for: action, context: context)
            return (action: action, weight: weight.isFinite && weight > 0 ? weight : 0)
        }
        let totalWeight = weightedCandidates.reduce(0) { $0 + $1.weight }
        guard totalWeight > 0 else {
            return nil
        }

        let rawThreshold = rng.nextDouble(in: 0...totalWeight)
        let threshold = rawThreshold.isFinite ? min(max(rawThreshold, 0), totalWeight) : totalWeight

        var cumulativeWeight = 0.0
        var lastPositiveAction: Action?
        for candidate in weightedCandidates where candidate.weight > 0 {
            lastPositiveAction = candidate.action
            cumulativeWeight += candidate.weight
            if threshold < cumulativeWeight {
                consumeAfterTagIfNeeded(for: candidate.action)
                return candidate.action
            }
        }

        if let lastPositiveAction {
            consumeAfterTagIfNeeded(for: lastPositiveAction)
            return lastPositiveAction
        }
        return nil
    }

    private func consumeAfterTagIfNeeded(for action: Action) {
        guard action.tags.contains(where: { Self.consumableAfterTagRawValues.contains($0.rawValue) }) else {
            return
        }
        afterTagState?.consume()
    }
}

public final class WeightedIdleBehaviorScheduler: IdleBehaviorScheduling {
    private let sampler: WeightedActionSampling
    private let randomNumberGenerator: RandomNumberGenerating
    private let calendar: Calendar

    public init(
        randomNumberGenerator: RandomNumberGenerating,
        evaluator: TagConditionEvaluating = DefaultTagConditionEvaluator(),
        sampler: WeightedActionSampling? = nil,
        afterTagState: AfterTagStateMaintaining? = nil,
        calendar: Calendar = .current
    ) {
        self.sampler = sampler ?? DefaultWeightedActionSampler(
            evaluator: evaluator,
            afterTagState: afterTagState
        )
        self.randomNumberGenerator = randomNumberGenerator
        self.calendar = calendar
    }

    public func nextAction(
        in pool: IdleBehaviorPool,
        context: IdleScheduleContext
    ) -> Action? {
        guard !pool.isEmpty else {
            return nil
        }

        let tagContext = TagConditionContext(
            moodLevel: context.moodLevel ?? MoodLevelClassifier.level(for: context.mood),
            timeSlots: context.timeSlots ?? TimeOfDayClassifier.slots(for: context.now, calendar: calendar),
            pendingAfterTag: context.pendingAfterTag
        )
        return sampler.sample(pool.candidates, context: tagContext, rng: randomNumberGenerator)
    }
}
