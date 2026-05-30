import Foundation
import DesktopPet

func runCompanionContextTests() {
    let tests = CompanionContextTests()
    tests.contextAggregatesRuntimeRelationshipPreferencesAndRecentEvent()
    tests.contextCanBeConstructedWithArbitraryDateDerivedTimeSlots()
}

private struct CompanionContextTests {
    func contextAggregatesRuntimeRelationshipPreferencesAndRecentEvent() {
        let now = Date(timeIntervalSince1970: 1_779_091_200)
        var runtimeState = PetRuntimeState.defaultState(at: now)
        runtimeState.hunger = 0.7
        let relationship = RelationshipState(intimacyPoints: 260).snapshot
        let preferences = CompanionPreferences(
            showRelationshipPrompts: false,
            petNicknamesByPetId: ["pet-a": "Mochi"],
            userNickname: "Alex",
            quietUntil: now.addingTimeInterval(600),
            microDialogsEnabled: false
        )
        let lastEvent = CompanionEvent.directInteraction(.pet, now)

        let context = CompanionContext(
            petId: "pet-a",
            petDisplayName: "Starter Pet",
            petNickname: "Mochi",
            userNickname: "Alex",
            runtimeState: runtimeState,
            relationship: relationship,
            preferences: preferences,
            timeSlots: [.morning, .workday],
            recentBubbleTexts: ["你好", "今天也在"],
            lastCompanionEvent: lastEvent
        )

        expect(context.petId == "pet-a", "context should include pet id")
        expect(context.petDisplayName == "Starter Pet", "context should include pet display name")
        expect(context.petNickname == "Mochi", "context should include pet nickname")
        expect(context.userNickname == "Alex", "context should include user nickname")
        expect(context.runtimeState == runtimeState, "context should include runtime state")
        expect(context.relationship.currentLevel == .close, "context should include relationship snapshot")
        expect(context.preferences == preferences, "context should include companion preferences")
        expect(context.timeSlots == [.morning, .workday], "context should include companion time slots")
        expect(context.recentBubbleTexts == ["你好", "今天也在"], "context should include recent bubble text")
        expect(context.lastCompanionEvent == lastEvent, "context should include the latest companion event")
    }

    func contextCanBeConstructedWithArbitraryDateDerivedTimeSlots() {
        let calendar = calendar()
        let date = date(year: 2026, month: 5, day: 16, hour: 23, minute: 30, calendar: calendar)

        let context = CompanionContext(
            petId: "pet-b",
            petDisplayName: "Custom Pet",
            runtimeState: .defaultState(at: date),
            relationship: RelationshipState(intimacyPoints: 0).snapshot,
            preferences: CompanionPreferences(),
            timeSlots: CompanionTimeSlot.slots(for: date, calendar: calendar)
        )

        expect(context.petNickname == nil, "pet nickname should be optional")
        expect(context.userNickname == nil, "user nickname should be optional")
        expect(context.timeSlots == [.night, .weekend], "context should accept arbitrary date-derived slots")
        expect(context.recentBubbleTexts.isEmpty, "recent bubble texts should default to empty")
        expect(context.lastCompanionEvent == nil, "last companion event should default to nil")
    }

    private func calendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 8 * 60 * 60)!
        return calendar
    }

    private func date(year: Int, month: Int, day: Int, hour: Int, minute: Int, calendar: Calendar) -> Date {
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
}
