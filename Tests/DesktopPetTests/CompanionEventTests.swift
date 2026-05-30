import Foundation
import DesktopPet

func runCompanionEventTests() {
    let tests = CompanionEventTests()
    tests.directInteractionKindsCoverClickPetFeed()
    tests.companionEventsRepresentDocumentedInputs()
    tests.directInteractionKindRoundTripsThroughCodable()
}

private struct CompanionEventTests {
    func directInteractionKindsCoverClickPetFeed() {
        expect(DirectInteractionKind.allCases == [.click, .pet, .feed], "direct interaction kinds should cover click, pet, feed")
        expect(DirectInteractionKind.click.rawValue == "click", "click raw value should be stable")
        expect(DirectInteractionKind.pet.rawValue == "pet", "pet raw value should be stable")
        expect(DirectInteractionKind.feed.rawValue == "feed", "feed raw value should be stable")
    }

    func companionEventsRepresentDocumentedInputs() {
        let now = Date(timeIntervalSince1970: 1_779_091_200)
        let actionId = ActionId(rawValue: "wave.default")!
        let optionId = MicroDialogOptionId(rawValue: "feed-now")

        let events: [CompanionEvent] = [
            .appBecameVisible(now),
            .dailyFirstVisit(now),
            .directInteraction(.click, now),
            .directInteraction(.pet, now),
            .directInteraction(.feed, now),
            .actionPlayed(actionId, now),
            .sleepRequested(now),
            .wakeRequested(now),
            .longAbsenceReturned(days: 3, now),
            .relationshipLevelChanged(from: .acquaintance, to: .familiar, now),
            .quietModeChanged(isActive: true, now),
            .microDialogCompleted(optionId, now)
        ]

        expect(events.contains(.directInteraction(.click, now)), "click should be represented as direct interaction")
        expect(events.contains(.directInteraction(.pet, now)), "pet should be represented as direct interaction")
        expect(events.contains(.directInteraction(.feed, now)), "feed should be represented as direct interaction")
        expect(events.contains(.actionPlayed(actionId, now)), "action played should carry action id")
        expect(events.contains(.longAbsenceReturned(days: 3, now)), "long absence should carry day count")
        expect(
            events.contains(.relationshipLevelChanged(from: .acquaintance, to: .familiar, now)),
            "relationship level change should carry old and new levels"
        )
        expect(events.contains(.microDialogCompleted(optionId, now)), "micro dialog completion should carry option id")
    }

    func directInteractionKindRoundTripsThroughCodable() {
        do {
            let data = try JSONEncoder().encode(DirectInteractionKind.feed)
            let decoded = try JSONDecoder().decode(DirectInteractionKind.self, from: data)
            expect(decoded == .feed, "direct interaction kind should be codable")
        } catch {
            fail("direct interaction kind should round-trip through codable: \(error)")
        }
    }
}
