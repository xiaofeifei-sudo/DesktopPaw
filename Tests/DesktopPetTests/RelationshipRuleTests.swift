import Foundation
import DesktopPet

func runRelationshipRuleTests() {
    let tests = RelationshipRuleTests()
    tests.dailyFirstVisitAddsThreePointsOncePerDay()
    tests.petAndClickInteractionsRespectTenMinuteCooldowns()
    tests.feedAddsHungerBonusInsideSharedCooldown()
    tests.actionPlayedUsesThirtyMinuteCooldown()
    tests.careEventsAreLimitedToTwoPerDay()
    tests.microDialogCompletionIsLimitedToFivePerDay()
    tests.longAbsenceAddsPointsWithoutPenalty()
}

private struct RelationshipRuleTests {
    private let baseDate = Date(timeIntervalSince1970: 1_779_091_200)

    func dailyFirstVisitAddsThreePointsOncePerDay() {
        let context = makeContext(at: baseDate)

        let first = RelationshipRule.dailyFirstVisit.apply(
            event: .dailyFirstVisit(baseDate),
            to: RelationshipState(),
            context: context
        )
        let second = RelationshipRule.dailyFirstVisit.apply(
            event: .dailyFirstVisit(baseDate.addingTimeInterval(3_600)),
            to: first.state,
            context: makeContext(at: baseDate.addingTimeInterval(3_600))
        )

        expect(first.pointsAdded == 3, "daily first visit should add 3 points")
        expect(first.state.intimacyPoints == 3, "daily first visit should update intimacy points")
        expect(first.state.dailyCounters.dailyFirstVisitCount == 1, "daily first visit should update the daily counter")
        expect(first.state.consecutiveVisitDays == 1, "first daily visit should start the visit streak")
        expect(second.pointsAdded == 0, "daily first visit should not add points twice on the same day")
        expect(second.state.intimacyPoints == 3, "duplicate daily first visit should not change points")
    }

    func petAndClickInteractionsRespectTenMinuteCooldowns() {
        let context = makeContext(at: baseDate)

        let petFirst = RelationshipRule.pet.apply(
            event: .directInteraction(.pet, baseDate),
            to: RelationshipState(),
            context: context
        )
        let petDuringCooldown = RelationshipRule.pet.apply(
            event: .directInteraction(.pet, baseDate.addingTimeInterval(60)),
            to: petFirst.state,
            context: makeContext(at: baseDate.addingTimeInterval(60))
        )
        let petAfterCooldown = RelationshipRule.pet.apply(
            event: .directInteraction(.pet, baseDate.addingTimeInterval(601)),
            to: petDuringCooldown.state,
            context: makeContext(at: baseDate.addingTimeInterval(601))
        )
        let clickFirst = RelationshipRule.click.apply(
            event: .directInteraction(.click, baseDate),
            to: RelationshipState(),
            context: context
        )

        expect(petFirst.pointsAdded == 2, "pet interaction should add 2 points")
        expect(petFirst.state.summary.todayPetCount == 1, "pet interaction should update today's pet summary")
        expect(petDuringCooldown.pointsAdded == 0, "pet interaction should not add points inside the 10 minute cooldown")
        expect(petAfterCooldown.pointsAdded == 2, "pet interaction should add points after the cooldown")
        expect(clickFirst.pointsAdded == 1, "click interaction should add 1 point")
        expect(clickFirst.state.cooldowns.lastClickAt == baseDate, "click interaction should update its cooldown")
    }

    func feedAddsHungerBonusInsideSharedCooldown() {
        let hungryContext = makeContext(at: baseDate, hunger: 0.82)

        let first = RelationshipRule.feed.apply(
            event: .directInteraction(.feed, baseDate),
            to: RelationshipState(),
            context: hungryContext
        )
        let duringCooldown = RelationshipRule.feed.apply(
            event: .directInteraction(.feed, baseDate.addingTimeInterval(120)),
            to: first.state,
            context: makeContext(at: baseDate.addingTimeInterval(120), hunger: 0.9)
        )
        let notHungryAfterCooldown = RelationshipRule.feed.apply(
            event: .directInteraction(.feed, baseDate.addingTimeInterval(601)),
            to: duringCooldown.state,
            context: makeContext(at: baseDate.addingTimeInterval(601), hunger: 0.3)
        )

        expect(first.pointsAdded == 3, "feed should add 2 base points plus 1 high hunger bonus")
        expect(first.state.summary.todayFeedCount == 1, "feed should update today's feed summary")
        expect(duringCooldown.pointsAdded == 0, "feed should not add base or bonus points inside cooldown")
        expect(notHungryAfterCooldown.pointsAdded == 2, "feed should add only base points when hunger is not high")
    }

    func actionPlayedUsesThirtyMinuteCooldown() {
        let actionId = ActionId(rawValue: "wave.default")!
        let first = RelationshipRule.actionPlayed.apply(
            event: .actionPlayed(actionId, baseDate),
            to: RelationshipState(),
            context: makeContext(at: baseDate)
        )
        let duringCooldown = RelationshipRule.actionPlayed.apply(
            event: .actionPlayed(actionId, baseDate.addingTimeInterval(1_200)),
            to: first.state,
            context: makeContext(at: baseDate.addingTimeInterval(1_200))
        )
        let afterCooldown = RelationshipRule.actionPlayed.apply(
            event: .actionPlayed(actionId, baseDate.addingTimeInterval(1_801)),
            to: duringCooldown.state,
            context: makeContext(at: baseDate.addingTimeInterval(1_801))
        )

        expect(first.pointsAdded == 1, "action played should add 1 point")
        expect(duringCooldown.pointsAdded == 0, "action played should not add points inside the 30 minute cooldown")
        expect(afterCooldown.pointsAdded == 1, "action played should add points after the cooldown")
        expect(afterCooldown.state.summary.todayActionPlayCount == 2, "accepted action plays should update today's summary")
    }

    func careEventsAreLimitedToTwoPerDay() {
        let sleep = RelationshipRule.sleepCare.apply(
            event: .sleepRequested(baseDate),
            to: RelationshipState(),
            context: makeContext(at: baseDate)
        )
        let wake = RelationshipRule.wakeCare.apply(
            event: .wakeRequested(baseDate.addingTimeInterval(60)),
            to: sleep.state,
            context: makeContext(at: baseDate.addingTimeInterval(60))
        )
        let thirdCare = RelationshipRule.sleepCare.apply(
            event: .sleepRequested(baseDate.addingTimeInterval(120)),
            to: wake.state,
            context: makeContext(at: baseDate.addingTimeInterval(120))
        )

        expect(sleep.pointsAdded == 1, "sleep care should add 1 point")
        expect(wake.pointsAdded == 1, "wake care should add 1 point")
        expect(thirdCare.pointsAdded == 0, "care events should stop adding points after two per day")
        expect(thirdCare.state.dailyCounters.careCount == 2, "care counter should count only accepted care events")
    }

    func microDialogCompletionIsLimitedToFivePerDay() {
        var state = RelationshipState()
        let optionId = MicroDialogOptionId(rawValue: "pet-now")
        var lastUpdate: RelationshipUpdate?

        for offset in 0..<6 {
            let date = baseDate.addingTimeInterval(TimeInterval(offset * 60))
            let update = RelationshipRule.microDialog.apply(
                event: .microDialogCompleted(optionId, date),
                to: state,
                context: makeContext(at: date)
            )
            state = update.state
            lastUpdate = update
        }

        expect(state.intimacyPoints == 5, "only five micro dialogs should add points per day")
        expect(state.dailyCounters.microDialogCount == 5, "micro dialog daily counter should stop at five")
        expect(state.summary.todayMicroDialogCount == 5, "micro dialog summary should stop at five")
        expect(lastUpdate?.pointsAdded == 0, "sixth micro dialog completion should not add points")
    }

    func longAbsenceAddsPointsWithoutPenalty() {
        let initialState = RelationshipState(intimacyPoints: 40)
        let update = RelationshipRule.longAbsenceReturn.apply(
            event: .longAbsenceReturned(days: 4, baseDate),
            to: initialState,
            context: makeContext(at: baseDate)
        )

        expect(update.pointsAdded == 2, "long absence return should add 2 points")
        expect(update.state.intimacyPoints == 42, "long absence return should only increase points")
        expect(update.state.intimacyPoints >= initialState.intimacyPoints, "long absence return must not penalize the relationship")
    }

    private func makeContext(at date: Date, hunger: Double = 0.2) -> RelationshipRuleContext {
        RelationshipRuleContext(
            runtimeState: PetRuntimeState(
                currentState: .idle,
                mood: 0.8,
                hunger: hunger,
                energy: 0.8,
                lastInteractionAt: date,
                isDragging: false,
                scale: 1.0
            ),
            calendar: Self.gregorianUTCCalendar()
        )
    }

    private static func gregorianUTCCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }
}
