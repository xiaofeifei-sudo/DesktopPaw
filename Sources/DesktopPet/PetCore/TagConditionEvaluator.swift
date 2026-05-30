public struct TagConditionContext: Equatable, Sendable {
    public let moodLevel: MoodLevel
    public let timeSlots: Set<TimeSlot>
    public let pendingAfterTag: ActionTag?

    public init(
        moodLevel: MoodLevel,
        timeSlots: Set<TimeSlot>,
        pendingAfterTag: ActionTag? = nil
    ) {
        self.moodLevel = moodLevel
        self.timeSlots = timeSlots
        self.pendingAfterTag = pendingAfterTag
    }
}

public protocol TagConditionEvaluating {
    func weight(for action: Action, context: TagConditionContext) -> Double
}

public struct DefaultTagConditionEvaluator: TagConditionEvaluating, Sendable {
    private static let knownAfterValues: Set<String> = ["click", "pet", "feed"]

    public init() {}

    public func weight(for action: Action, context: TagConditionContext) -> Double {
        action.tags.reduce(1.0) { weight, tag in
            guard weight > 0 else {
                return 0
            }
            return weight * multiplier(for: tag, context: context)
        }
    }

    private func multiplier(for tag: ActionTag, context: TagConditionContext) -> Double {
        guard let prefix = tag.prefix else {
            return 1
        }

        switch prefix {
        case .mood:
            return moodMultiplier(for: tag, moodLevel: context.moodLevel)
        case .after:
            return afterMultiplier(for: tag, pendingAfterTag: context.pendingAfterTag)
        case .time:
            return timeMultiplier(for: tag, timeSlots: context.timeSlots)
        }
    }

    private func moodMultiplier(for tag: ActionTag, moodLevel: MoodLevel) -> Double {
        guard let value = tag.value else {
            return 1
        }
        if value == "any" {
            return 1
        }
        guard MoodLevel(rawValue: value) != nil else {
            return 1
        }
        return value == moodLevel.rawValue ? 3 : 0
    }

    private func afterMultiplier(for tag: ActionTag, pendingAfterTag: ActionTag?) -> Double {
        guard let value = tag.value else { return 1 }
        guard let pendingAfterTag else {
            return 1
        }
        if pendingAfterTag == tag {
            return 3
        }
        guard Self.knownAfterValues.contains(value) else {
            return 1
        }
        guard
            pendingAfterTag.prefix == .after,
            let pendingValue = pendingAfterTag.value,
            Self.knownAfterValues.contains(pendingValue)
        else {
            return 1
        }

        return 0
    }

    private func timeMultiplier(for tag: ActionTag, timeSlots: Set<TimeSlot>) -> Double {
        guard let value = tag.value, let slot = TimeSlot(rawValue: value) else {
            return 1
        }
        return timeSlots.contains(slot) ? 3 : 0
    }
}
