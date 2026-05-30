import Foundation
import DesktopPet

func runRelationshipResetTests() {
    let tests = RelationshipResetTests()
    tests.resetReturnsDefaultSnapshot()
    tests.resetClearsIntimacyPoints()
    tests.resetClearsDailyCounters()
    tests.resetClearsCooldowns()
    tests.resetClearsMilestones()
    tests.resetClearsInteractionSummary()
    tests.resetOnlyAffectsTargetPet()
    tests.growthWorksAfterReset()
    tests.resetDoesNotAffectOtherPetGrowth()
}

private struct RelationshipResetTests {
    private func makeFixture() -> Fixture {
        let rootDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("RelationshipResetTests-\(UUID().uuidString)", isDirectory: true)
        let store = RelationshipStore(rootDirectoryURL: rootDirectory)
        let service = RelationshipService(store: store)
        return Fixture(rootDirectory: rootDirectory, store: store, service: service)
    }

    func resetReturnsDefaultSnapshot() {
        let fixture = makeFixture()
        defer { fixture.cleanUp() }

        do {
            try fixture.store.saveState(
                RelationshipState(intimacyPoints: 500, unlockedMilestoneIds: ["level-2"]),
                petId: "pet-a"
            )

            let snapshot = try fixture.service.reset(petId: "pet-a")

            expect(snapshot.intimacyPoints == 0, "reset should return 0 points")
            expect(snapshot.currentLevel == .acquaintance, "reset should return Lv.1")
        } catch {
            fail("reset should not throw: \(error)")
        }
    }

    func resetClearsIntimacyPoints() {
        let fixture = makeFixture()
        defer { fixture.cleanUp() }

        do {
            try fixture.store.saveState(RelationshipState(intimacyPoints: 910), petId: "pet-a")
            _ = try fixture.service.reset(petId: "pet-a")

            let loaded = try fixture.store.loadState(petId: "pet-a")
            expect(loaded.intimacyPoints == 0, "reset should clear intimacy points")
            expect(loaded.currentLevel == .acquaintance, "reset should return to Lv.1")
        } catch {
            fail("reset should not throw: \(error)")
        }
    }

    func resetClearsDailyCounters() {
        let fixture = makeFixture()
        defer { fixture.cleanUp() }

        do {
            var state = RelationshipState(intimacyPoints: 100)
            state.dailyCounters = RelationshipDailyCounters(
                dateKey: "2026-05-16",
                dailyFirstVisitCount: 1,
                petCount: 5,
                feedCount: 3,
                actionPlayedCount: 2,
                microDialogCount: 4
            )
            try fixture.store.saveState(state, petId: "pet-a")
            _ = try fixture.service.reset(petId: "pet-a")

            let loaded = try fixture.store.loadState(petId: "pet-a")
            expect(loaded.dailyCounters == RelationshipDailyCounters(), "reset should clear daily counters")
        } catch {
            fail("reset should not throw: \(error)")
        }
    }

    func resetClearsCooldowns() {
        let fixture = makeFixture()
        defer { fixture.cleanUp() }

        do {
            let now = Date()
            var state = RelationshipState(intimacyPoints: 100)
            state.cooldowns = RelationshipCooldowns(
                lastClickAt: now,
                lastPetAt: now,
                lastFeedAt: now,
                lastActionPlayedAt: now,
                lastSleepCareAt: now,
                lastMicroDialogAt: now
            )
            try fixture.store.saveState(state, petId: "pet-a")
            _ = try fixture.service.reset(petId: "pet-a")

            let loaded = try fixture.store.loadState(petId: "pet-a")
            expect(loaded.cooldowns == RelationshipCooldowns(), "reset should clear cooldowns")
        } catch {
            fail("reset should not throw: \(error)")
        }
    }

    func resetClearsMilestones() {
        let fixture = makeFixture()
        defer { fixture.cleanUp() }

        do {
            var state = RelationshipState(intimacyPoints: 500)
            state.unlockedMilestoneIds = ["level-2", "level-3", "level-4"]
            try fixture.store.saveState(state, petId: "pet-a")
            _ = try fixture.service.reset(petId: "pet-a")

            let loaded = try fixture.store.loadState(petId: "pet-a")
            expect(loaded.unlockedMilestoneIds.isEmpty, "reset should clear milestones")
        } catch {
            fail("reset should not throw: \(error)")
        }
    }

    func resetClearsInteractionSummary() {
        let fixture = makeFixture()
        defer { fixture.cleanUp() }

        do {
            var state = RelationshipState(intimacyPoints: 100)
            state.summary.recordBubbleText("hello")
            state.summary.recordBubbleText("goodbye")
            try fixture.store.saveState(state, petId: "pet-a")
            _ = try fixture.service.reset(petId: "pet-a")

            let loaded = try fixture.store.loadState(petId: "pet-a")
            expect(loaded.summary == InteractionSummary(), "reset should clear interaction summary")
        } catch {
            fail("reset should not throw: \(error)")
        }
    }

    func resetOnlyAffectsTargetPet() {
        let fixture = makeFixture()
        defer { fixture.cleanUp() }

        do {
            try fixture.store.saveState(RelationshipState(intimacyPoints: 500), petId: "pet-a")
            try fixture.store.saveState(RelationshipState(intimacyPoints: 910), petId: "pet-b")

            _ = try fixture.service.reset(petId: "pet-a")

            let petA = try fixture.store.loadState(petId: "pet-a")
            let petB = try fixture.store.loadState(petId: "pet-b")
            expect(petA.intimacyPoints == 0, "pet-a should be reset")
            expect(petA.currentLevel == .acquaintance, "pet-a should be Lv.1 after reset")
            expect(petB.intimacyPoints == 910, "pet-b should be unaffected")
            expect(petB.currentLevel == .bonded, "pet-b should remain Lv.5")
        } catch {
            fail("reset should not throw: \(error)")
        }
    }

    func growthWorksAfterReset() {
        let fixture = makeFixture()
        defer { fixture.cleanUp() }

        do {
            try fixture.store.saveState(RelationshipState(intimacyPoints: 500), petId: "pet-a")
            _ = try fixture.service.reset(petId: "pet-a")

            let now = Date()
            let context = RelationshipRuleContext(
                runtimeState: .defaultState(at: now),
                calendar: Calendar(identifier: .gregorian),
                highHungerThreshold: 0.3
            )
            let update = try fixture.service.handle(
                event: .directInteraction(.pet, now),
                petId: "pet-a",
                context: context
            )

            expect(update.pointsAdded == 2, "pet interaction should add 2 points after reset")
            expect(update.state.intimacyPoints == 2, "intimacy should grow from 0 after reset")
        } catch {
            fail("growth after reset should not throw: \(error)")
        }
    }

    func resetDoesNotAffectOtherPetGrowth() {
        let fixture = makeFixture()
        defer { fixture.cleanUp() }

        do {
            try fixture.store.saveState(RelationshipState(intimacyPoints: 500), petId: "pet-a")
            try fixture.store.saveState(RelationshipState(intimacyPoints: 100), petId: "pet-b")

            _ = try fixture.service.reset(petId: "pet-a")

            let now = Date()
            let context = RelationshipRuleContext(
                runtimeState: .defaultState(at: now),
                calendar: Calendar(identifier: .gregorian),
                highHungerThreshold: 0.3
            )
            let update = try fixture.service.handle(
                event: .directInteraction(.pet, now),
                petId: "pet-b",
                context: context
            )

            expect(update.state.intimacyPoints == 102, "pet-b should continue growing normally")
        } catch {
            fail("pet-b growth after pet-a reset should not throw: \(error)")
        }
    }
}

private struct Fixture {
    let rootDirectory: URL
    let store: RelationshipStore
    let service: RelationshipService

    func cleanUp() {
        try? FileManager.default.removeItem(at: rootDirectory)
    }
}
