import Foundation

public protocol RelationshipProgressing: Sendable {
    func apply(
        event: CompanionEvent,
        to state: RelationshipState,
        context: RelationshipRuleContext
    ) -> RelationshipUpdate
}

public struct RelationshipRuleContext: Equatable, Sendable {
    public let runtimeState: PetRuntimeState
    public let calendar: Calendar
    public let highHungerThreshold: Double

    public init(
        runtimeState: PetRuntimeState,
        calendar: Calendar = .current,
        highHungerThreshold: Double = 0.75
    ) {
        self.runtimeState = runtimeState
        self.calendar = calendar
        self.highHungerThreshold = min(max(highHungerThreshold, 0), 1)
    }
}

public struct RelationshipLevelChange: Equatable, Sendable {
    public let from: RelationshipLevel
    public let to: RelationshipLevel
    public let date: Date

    public init(from: RelationshipLevel, to: RelationshipLevel, date: Date) {
        self.from = from
        self.to = to
        self.date = date
    }
}

public struct RelationshipUpdate: Equatable, Sendable {
    public let previousState: RelationshipState
    public let state: RelationshipState
    public let pointsAdded: Int
    public let appliedRule: RelationshipRule?
    public let levelChange: RelationshipLevelChange?

    public init(
        previousState: RelationshipState,
        state: RelationshipState,
        pointsAdded: Int,
        appliedRule: RelationshipRule?,
        levelChange: RelationshipLevelChange?
    ) {
        self.previousState = previousState
        self.state = state
        self.pointsAdded = max(0, pointsAdded)
        self.appliedRule = appliedRule
        self.levelChange = levelChange
    }

    public var generatedEvents: [CompanionEvent] {
        guard let levelChange else {
            return []
        }

        return [
            .relationshipLevelChanged(
                from: levelChange.from,
                to: levelChange.to,
                levelChange.date
            )
        ]
    }
}

public enum RelationshipRule: Equatable, Sendable {
    case dailyFirstVisit
    case longAbsenceReturn
    case click
    case pet
    case feed
    case actionPlayed
    case sleepCare
    case wakeCare
    case microDialog

    public static func rule(for event: CompanionEvent) -> RelationshipRule? {
        switch event {
        case .dailyFirstVisit:
            return .dailyFirstVisit
        case .longAbsenceReturned:
            return .longAbsenceReturn
        case .directInteraction(let kind, _):
            switch kind {
            case .click:
                return .click
            case .pet:
                return .pet
            case .feed:
                return .feed
            }
        case .actionPlayed:
            return .actionPlayed
        case .sleepRequested:
            return .sleepCare
        case .wakeRequested:
            return .wakeCare
        case .microDialogCompleted:
            return .microDialog
        case .appBecameVisible,
             .relationshipLevelChanged,
             .quietModeChanged:
            return nil
        }
    }

    public func apply(
        event: CompanionEvent,
        to state: RelationshipState,
        context: RelationshipRuleContext
    ) -> RelationshipUpdate {
        guard Self.rule(for: event) == self else {
            return RelationshipUpdate(
                previousState: state,
                state: state,
                pointsAdded: 0,
                appliedRule: nil,
                levelChange: nil
            )
        }

        let date = event.relationshipRuleDate
        let previousLevel = state.currentLevel
        var nextState = Self.preparingDailyBuckets(in: state, at: date, context: context)
        let pointsAdded = applyAcceptedEvent(event, to: &nextState, at: date, context: context)

        if pointsAdded > 0 {
            nextState.intimacyPoints = max(0, nextState.intimacyPoints + pointsAdded)
            nextState.lastSeenAt = date
        }

        let nextLevel = nextState.currentLevel
        let levelChange = previousLevel == nextLevel
            ? nil
            : RelationshipLevelChange(from: previousLevel, to: nextLevel, date: date)

        return RelationshipUpdate(
            previousState: state,
            state: nextState,
            pointsAdded: pointsAdded,
            appliedRule: pointsAdded > 0 ? self : nil,
            levelChange: levelChange
        )
    }

    private func applyAcceptedEvent(
        _ event: CompanionEvent,
        to state: inout RelationshipState,
        at date: Date,
        context: RelationshipRuleContext
    ) -> Int {
        switch self {
        case .dailyFirstVisit:
            guard state.dailyCounters.dailyFirstVisitCount == 0 else {
                return 0
            }
            state.dailyCounters.dailyFirstVisitCount = 1
            Self.recordVisit(on: &state, at: date, calendar: context.calendar)
            return 3

        case .longAbsenceReturn:
            state.dailyCounters.longAbsenceReturnCount += 1
            return 2

        case .click:
            guard Self.isOutsideCooldown(state.cooldowns.lastClickAt, at: date, seconds: 600) else {
                return 0
            }
            state.dailyCounters.clickCount += 1
            state.cooldowns.lastClickAt = date
            state.summary.lastInteractionAt = date
            return 1

        case .pet:
            guard Self.isOutsideCooldown(state.cooldowns.lastPetAt, at: date, seconds: 600) else {
                return 0
            }
            state.dailyCounters.petCount += 1
            state.cooldowns.lastPetAt = date
            state.summary.todayPetCount += 1
            state.summary.lastInteractionAt = date
            return 2

        case .feed:
            guard Self.isOutsideCooldown(state.cooldowns.lastFeedAt, at: date, seconds: 600) else {
                return 0
            }
            state.dailyCounters.feedCount += 1
            state.cooldowns.lastFeedAt = date
            state.summary.todayFeedCount += 1
            state.summary.lastInteractionAt = date
            return context.runtimeState.hunger >= context.highHungerThreshold ? 3 : 2

        case .actionPlayed:
            guard Self.isOutsideCooldown(state.cooldowns.lastActionPlayedAt, at: date, seconds: 1_800) else {
                return 0
            }
            state.dailyCounters.actionPlayedCount += 1
            state.cooldowns.lastActionPlayedAt = date
            state.summary.todayActionPlayCount += 1
            state.summary.lastInteractionAt = date
            return 1

        case .sleepCare:
            guard state.dailyCounters.careCount < 2 else {
                return 0
            }
            state.dailyCounters.careCount += 1
            state.cooldowns.lastSleepCareAt = date
            state.summary.lastInteractionAt = date
            return 1

        case .wakeCare:
            guard state.dailyCounters.careCount < 2 else {
                return 0
            }
            state.dailyCounters.careCount += 1
            state.cooldowns.lastWakeCareAt = date
            state.summary.lastInteractionAt = date
            return 1

        case .microDialog:
            guard state.dailyCounters.microDialogCount < 5 else {
                return 0
            }
            state.dailyCounters.microDialogCount += 1
            state.cooldowns.lastMicroDialogAt = date
            state.summary.todayMicroDialogCount += 1
            state.summary.lastInteractionAt = date
            return 1
        }
    }

    private static func preparingDailyBuckets(
        in state: RelationshipState,
        at date: Date,
        context: RelationshipRuleContext
    ) -> RelationshipState {
        let dateKey = Self.dateKey(for: date, calendar: context.calendar)
        var state = state

        if state.dailyCounters.dateKey != dateKey {
            state.dailyCounters = RelationshipDailyCounters(dateKey: dateKey)
        }

        if state.summary.summaryDateKey != dateKey {
            state.summary = InteractionSummary(
                summaryDateKey: dateKey,
                recentBubbleTexts: state.summary.recentBubbleTexts,
                lastInteractionAt: state.summary.lastInteractionAt
            )
        }

        return state
    }

    private static func recordVisit(on state: inout RelationshipState, at date: Date, calendar: Calendar) {
        defer {
            state.lastVisitDate = date
        }

        guard let lastVisitDate = state.lastVisitDate else {
            state.consecutiveVisitDays = 1
            return
        }

        if calendar.isDate(lastVisitDate, inSameDayAs: date) {
            state.consecutiveVisitDays = max(1, state.consecutiveVisitDays)
            return
        }

        let startOfToday = calendar.startOfDay(for: date)
        let startOfLastVisit = calendar.startOfDay(for: lastVisitDate)
        let dayDifference = calendar.dateComponents([.day], from: startOfLastVisit, to: startOfToday).day
        state.consecutiveVisitDays = dayDifference == 1 ? state.consecutiveVisitDays + 1 : 1
    }

    private static func isOutsideCooldown(_ lastDate: Date?, at date: Date, seconds: TimeInterval) -> Bool {
        guard let lastDate else {
            return true
        }

        return date.timeIntervalSince(lastDate) >= seconds
    }

    private static func dateKey(for date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let year = components.year ?? 0
        let month = components.month ?? 0
        let day = components.day ?? 0
        return String(format: "%04d-%02d-%02d", year, month, day)
    }
}

private extension CompanionEvent {
    var relationshipRuleDate: Date {
        switch self {
        case .appBecameVisible(let date),
             .dailyFirstVisit(let date),
             .directInteraction(_, let date),
             .actionPlayed(_, let date),
             .sleepRequested(let date),
             .wakeRequested(let date),
             .longAbsenceReturned(_, let date),
             .relationshipLevelChanged(_, _, let date),
             .quietModeChanged(_, let date),
             .microDialogCompleted(_, let date):
            return date
        }
    }
}
