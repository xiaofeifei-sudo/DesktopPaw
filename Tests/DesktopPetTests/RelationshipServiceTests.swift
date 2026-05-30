import Foundation
import DesktopPet

func runRelationshipServiceTests() {
    let tests = RelationshipServiceTests()
    tests.handleLoadsAppliesAndPersistsRelationshipState()
    tests.relationshipUpgradeReturnsGeneratedEventOnlyWhenCrossingLevel()
    tests.snapshotReadsStoredRelationshipState()
    tests.resetRestoresOnlyRequestedPet()
}

private struct RelationshipServiceTests {
    private let baseDate = Date(timeIntervalSince1970: 1_779_091_200)

    func handleLoadsAppliesAndPersistsRelationshipState() {
        let store = InMemoryRelationshipStore()
        let service = RelationshipService(store: store)

        do {
            let update = try service.handle(
                event: .directInteraction(.feed, baseDate),
                petId: "pet-a",
                context: makeContext(at: baseDate, hunger: 0.9)
            )

            expect(update.pointsAdded == 3, "service should apply feed base points and hunger bonus")
            expect(update.state.intimacyPoints == 3, "service should return the updated relationship state")
            expect(store.statesByPetId["pet-a"]?.intimacyPoints == 3, "service should persist the updated relationship state")
            expect(store.statesByPetId["pet-a"]?.summary.todayFeedCount == 1, "service should persist interaction summary changes")
        } catch {
            fail("relationship service should handle and persist events: \(error)")
        }
    }

    func relationshipUpgradeReturnsGeneratedEventOnlyWhenCrossingLevel() {
        let store = InMemoryRelationshipStore(statesByPetId: [
            "near-level-up": RelationshipState(intimacyPoints: 99),
            "already-level-two": RelationshipState(intimacyPoints: 100)
        ])
        let service = RelationshipService(store: store)

        do {
            let levelUp = try service.handle(
                event: .directInteraction(.click, baseDate),
                petId: "near-level-up",
                context: makeContext(at: baseDate)
            )
            let noLevelUp = try service.handle(
                event: .directInteraction(.click, baseDate),
                petId: "already-level-two",
                context: makeContext(at: baseDate)
            )

            expect(levelUp.pointsAdded == 1, "click should add the point needed to cross into Lv.2")
            expect(levelUp.levelChange?.from == .acquaintance, "level change should record the previous level")
            expect(levelUp.levelChange?.to == .familiar, "level change should record the new level")
            expect(
                levelUp.generatedEvents == [.relationshipLevelChanged(from: .acquaintance, to: .familiar, baseDate)],
                "level crossing should generate a relationshipLevelChanged event"
            )
            expect(noLevelUp.levelChange == nil, "updates within the same level should not report a level change")
            expect(noLevelUp.generatedEvents.isEmpty, "updates within the same level should not generate relationship events")
        } catch {
            fail("relationship service should report level changes: \(error)")
        }
    }

    func snapshotReadsStoredRelationshipState() {
        let store = InMemoryRelationshipStore(statesByPetId: [
            "pet-a": RelationshipState(intimacyPoints: 260)
        ])
        let service = RelationshipService(store: store)

        do {
            let snapshot = try service.snapshot(petId: "pet-a")

            expect(snapshot.intimacyPoints == 260, "snapshot should expose stored intimacy points")
            expect(snapshot.currentLevel == .close, "snapshot should expose the stored relationship level")
            expect(snapshot.levelName == "亲近", "snapshot should expose the localized relationship level name")
        } catch {
            fail("relationship service should read snapshots: \(error)")
        }
    }

    func resetRestoresOnlyRequestedPet() {
        let store = InMemoryRelationshipStore(statesByPetId: [
            "pet-a": RelationshipState(intimacyPoints: 260),
            "pet-b": RelationshipState(intimacyPoints: 910)
        ])
        let service = RelationshipService(store: store)

        do {
            let snapshot = try service.reset(petId: "pet-a")

            expect(snapshot.currentLevel == .acquaintance, "reset snapshot should return Lv.1")
            expect(snapshot.intimacyPoints == 0, "reset snapshot should return 0 points")
            expect(store.statesByPetId["pet-a"] == RelationshipState(), "reset should restore only the requested pet")
            expect(store.statesByPetId["pet-b"] == RelationshipState(intimacyPoints: 910), "reset should not change other pets")
        } catch {
            fail("relationship service should reset requested pet only: \(error)")
        }
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

private final class InMemoryRelationshipStore: RelationshipStoring, @unchecked Sendable {
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
