import Foundation
import DesktopPet

@MainActor
func runCompanionEventRouterTests() {
    let tests = CompanionEventRouterTests()
    tests.appVisibleTriggersDailyFirstVisitOnlyOncePerDay()
    tests.appVisibleTriggersLongAbsenceReturnFromPreviousVisitDate()
    tests.directInteractionsActionsAndCareEventsUpdateRelationship()
    tests.relationshipLevelChangeIsGeneratedForBubbleConsumers()
    tests.switchPetRefreshesCurrentContext()
    tests.resetRelationshipRefreshesContextAndSettings()
}

@MainActor
private struct CompanionEventRouterTests {
    private let calendar = TestCalendar.utc
    private let now = TestCalendar.utcDate(year: 2026, month: 5, day: 16, hour: 9, minute: 0)

    func appVisibleTriggersDailyFirstVisitOnlyOncePerDay() {
        let harness = makeHarness()
        let runtimeState = PetRuntimeState.defaultState(at: now)

        let first = harness.router.handle(.appBecameVisible(now), runtimeState: runtimeState)
        let second = harness.router.handle(.appBecameVisible(now.addingTimeInterval(3_600)), runtimeState: runtimeState)

        expect(first.generatedEvents == [.dailyFirstVisit(now)], "first app visible event should generate dailyFirstVisit")
        expect(first.relationshipUpdate?.state.intimacyPoints == 3, "daily first visit should add relationship points")
        expect(first.shouldRefreshSettings, "daily first visit should refresh relationship settings")
        expect(second.generatedEvents.isEmpty, "app visible should not generate dailyFirstVisit twice on the same day")
        expect(second.relationshipUpdate == nil, "duplicate daily first visit should not return a relationship update")
        expect(harness.relationshipStore.statesByPetId["pet-a"]?.intimacyPoints == 3, "daily first visit should persist only once")
    }

    func appVisibleTriggersLongAbsenceReturnFromPreviousVisitDate() {
        var state = RelationshipState(intimacyPoints: 10)
        state.lastVisitDate = TestCalendar.utcDate(year: 2026, month: 5, day: 12, hour: 9, minute: 0)
        let harness = makeHarness(statesByPetId: ["pet-a": state])

        let result = harness.router.handle(.appBecameVisible(now), runtimeState: .defaultState(at: now))

        expect(
            result.generatedEvents == [
                .dailyFirstVisit(now),
                .longAbsenceReturned(days: 4, now)
            ],
            "app visible after a multi-day absence should generate daily and long absence events"
        )
        expect(harness.relationshipStore.statesByPetId["pet-a"]?.intimacyPoints == 15, "daily first visit and long absence should both add points")
        expect(harness.relationshipStore.statesByPetId["pet-a"]?.dailyCounters.longAbsenceReturnCount == 1, "long absence should be counted once")
    }

    func directInteractionsActionsAndCareEventsUpdateRelationship() {
        let harness = makeHarness()
        let actionId = ActionId(rawValue: "wave.default")!
        let runtimeState = PetRuntimeState.defaultState(at: now)

        let click = harness.router.handle(.directInteraction(.click, now), runtimeState: runtimeState)
        let pet = harness.router.handle(.directInteraction(.pet, now.addingTimeInterval(601)), runtimeState: runtimeState)
        let feed = harness.router.handle(
            .directInteraction(.feed, now.addingTimeInterval(1_202)),
            runtimeState: hungryRuntimeState(at: now.addingTimeInterval(1_202))
        )
        let action = harness.router.handle(.actionPlayed(actionId, now.addingTimeInterval(1_803)), runtimeState: runtimeState)
        let sleep = harness.router.handle(.sleepRequested(now.addingTimeInterval(1_904)), runtimeState: runtimeState)
        let wake = harness.router.handle(.wakeRequested(now.addingTimeInterval(2_005)), runtimeState: runtimeState)

        expect(click.relationshipUpdate?.pointsAdded == 1, "click should route to the click relationship rule")
        expect(pet.relationshipUpdate?.pointsAdded == 2, "pet should route to the pet relationship rule")
        expect(feed.relationshipUpdate?.pointsAdded == 3, "feed should route to the feed relationship rule with high hunger bonus")
        expect(action.relationshipUpdate?.pointsAdded == 1, "actionPlayed should route to the action relationship rule")
        expect(sleep.relationshipUpdate?.pointsAdded == 1, "sleep should route to the care relationship rule")
        expect(wake.relationshipUpdate?.pointsAdded == 1, "wake should route to the care relationship rule")
        expect(harness.relationshipStore.statesByPetId["pet-a"]?.intimacyPoints == 9, "all accepted interaction events should persist relationship points")
    }

    func relationshipLevelChangeIsGeneratedForBubbleConsumers() {
        let harness = makeHarness(statesByPetId: ["pet-a": RelationshipState(intimacyPoints: 99)])

        let result = harness.router.handle(.directInteraction(.click, now), runtimeState: .defaultState(at: now))

        expect(
            result.generatedEvents == [.relationshipLevelChanged(from: .acquaintance, to: .familiar, now)],
            "relationship level changes should be generated for downstream bubble consumers"
        )
        expect(result.relationshipUpdate?.levelChange?.to == .familiar, "relationship update should expose the new level")
    }

    func switchPetRefreshesCurrentContext() {
        let preferences = CompanionPreferences(petNicknamesByPetId: ["pet-b": "Nori"], userNickname: "Alex")
        let harness = makeHarness(
            statesByPetId: [
                "pet-a": RelationshipState(intimacyPoints: 100),
                "pet-b": RelationshipState(intimacyPoints: 260)
            ],
            preferences: preferences
        )

        harness.router.switchPet(id: "pet-b", displayName: "Custom Pet")
        let context = harness.router.context(runtimeState: .defaultState(at: now))

        expect(context.petId == "pet-b", "context should use the switched pet id")
        expect(context.petDisplayName == "Custom Pet", "context should use the switched display name")
        expect(context.petNickname == "Nori", "context should use the switched pet nickname")
        expect(context.userNickname == "Alex", "context should include global user nickname")
        expect(context.relationship.currentLevel == .close, "context should load the switched pet relationship")
    }

    func resetRelationshipRefreshesContextAndSettings() {
        let harness = makeHarness(statesByPetId: ["pet-a": RelationshipState(intimacyPoints: 260)])

        let result = harness.router.resetRelationship(runtimeState: .defaultState(at: now))
        let context = harness.router.context(runtimeState: .defaultState(at: now))

        expect(result.shouldRefreshSettings, "reset relationship should refresh settings")
        expect(result.relationshipUpdate == nil, "reset relationship should not pretend to be a growth update")
        expect(harness.relationshipStore.statesByPetId["pet-a"] == RelationshipState(), "reset should restore the current pet relationship")
        expect(context.relationship.currentLevel == .acquaintance, "context should reflect the reset relationship level")
        expect(context.relationship.intimacyPoints == 0, "context should reflect reset relationship points")
    }

    private func makeHarness(
        statesByPetId: [String: RelationshipState] = [:],
        preferences: CompanionPreferences = CompanionPreferences()
    ) -> CompanionRouterHarness {
        let relationshipStore = RouterRelationshipStore(statesByPetId: statesByPetId)
        let preferencesStore = RouterPreferencesStore(preferences: preferences)
        let clock = FixedCompanionClock(now: now, calendar: calendar)
        let router = CompanionEventRouter(
            petId: "pet-a",
            petDisplayName: "Starter Pet",
            relationshipStore: relationshipStore,
            preferencesStore: preferencesStore,
            clock: clock
        )

        return CompanionRouterHarness(
            router: router,
            relationshipStore: relationshipStore,
            preferencesStore: preferencesStore
        )
    }

    private func hungryRuntimeState(at date: Date) -> PetRuntimeState {
        PetRuntimeState(
            currentState: .idle,
            mood: 0.8,
            hunger: 0.9,
            energy: 0.8,
            lastInteractionAt: date,
            isDragging: false,
            scale: 1.0
        )
    }
}

