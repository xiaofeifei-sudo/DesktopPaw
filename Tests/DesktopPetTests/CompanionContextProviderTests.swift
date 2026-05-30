import Foundation
import DesktopPet

@MainActor
func runCompanionContextProviderTests() {
    let tests = CompanionContextProviderTests()
    tests.initialContextUsesDefaultRelationshipPreferencesAndClockTimeSlots()
    tests.contextReflectsLatestRelationshipUpdateAndLastEvent()
    tests.contextIncludesRecentBubbleTextsFromRelationshipState()
}

@MainActor
private struct CompanionContextProviderTests {
    private let calendar = TestCalendar.utc
    private let now = TestCalendar.utcDate(year: 2026, month: 5, day: 16, hour: 14, minute: 30)

    func initialContextUsesDefaultRelationshipPreferencesAndClockTimeSlots() {
        let preferences = CompanionPreferences(
            showRelationshipPrompts: false,
            petNicknamesByPetId: ["pet-a": "Mochi"],
            userNickname: "Alex",
            microDialogsEnabled: false
        )
        let harness = makeHarness(preferences: preferences)

        let context = harness.router.context(runtimeState: .defaultState(at: now))

        expect(context.petId == "pet-a", "initial context should expose current pet id")
        expect(context.petDisplayName == "Starter Pet", "initial context should expose current pet display name")
        expect(context.petNickname == "Mochi", "initial context should include current pet nickname")
        expect(context.userNickname == "Alex", "initial context should include user nickname")
        expect(context.relationship.currentLevel == .acquaintance, "missing relationship state should produce default Lv.1 context")
        expect(context.preferences == preferences, "context should include loaded companion preferences")
        expect(context.timeSlots == [.afternoon, .weekend], "context should derive time slots from the injected clock")
        expect(context.recentBubbleTexts.isEmpty, "initial context should default to no recent bubble text")
    }

    func contextReflectsLatestRelationshipUpdateAndLastEvent() {
        let harness = makeHarness()
        let event = CompanionEvent.directInteraction(.feed, now)

        _ = harness.router.handle(event, runtimeState: hungryRuntimeState(at: now))
        let context = harness.router.context(runtimeState: .defaultState(at: now))

        expect(context.relationship.intimacyPoints == 3, "context should reflect the latest persisted relationship update")
        expect(context.lastCompanionEvent == event, "context should expose the latest handled companion event")
    }

    func contextIncludesRecentBubbleTextsFromRelationshipState() {
        var state = RelationshipState(intimacyPoints: 260)
        state.summary.recordBubbleText("你好")
        state.summary.recordBubbleText("今天也在")
        let harness = makeHarness(statesByPetId: ["pet-a": state])

        let context = harness.router.context(runtimeState: .defaultState(at: now))

        expect(context.relationship.currentLevel == .close, "context should include the stored relationship snapshot")
        expect(context.recentBubbleTexts == ["你好", "今天也在"], "context should include recent bubble texts from relationship summary")
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

@MainActor
struct CompanionRouterHarness {
    let router: CompanionEventRouter
    let relationshipStore: RouterRelationshipStore
    let preferencesStore: RouterPreferencesStore
}

final class RouterRelationshipStore: RelationshipStoring, @unchecked Sendable {
    var statesByPetId: [String: RelationshipState]

    init(statesByPetId: [String: RelationshipState] = [:]) {
        self.statesByPetId = statesByPetId
    }

    func loadState(petId: String) throws -> RelationshipState {
        statesByPetId[petId] ?? RelationshipState()
    }

    func saveState(_ state: RelationshipState, petId: String) throws {
        statesByPetId[petId] = state
    }

    func resetState(petId: String) throws {
        statesByPetId[petId] = RelationshipState()
    }
}

final class RouterPreferencesStore: CompanionPreferencesStoring, @unchecked Sendable {
    private(set) var preferences: CompanionPreferences

    init(preferences: CompanionPreferences) {
        self.preferences = preferences
    }

    func loadPreferences() -> CompanionPreferences {
        preferences
    }

    func savePreferences(_ preferences: CompanionPreferences) {
        self.preferences = preferences
    }
}

enum TestCalendar {
    static var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    static func utcDate(year: Int, month: Int, day: Int, hour: Int, minute: Int) -> Date {
        let components = DateComponents(
            calendar: utc,
            timeZone: utc.timeZone,
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
}
