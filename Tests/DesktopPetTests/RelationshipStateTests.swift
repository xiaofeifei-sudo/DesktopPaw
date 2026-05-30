import Foundation
import DesktopPet

func runRelationshipStateTests() {
    let tests = RelationshipStateTests()
    tests.newStateDefaultsToLevelOneWithZeroPoints()
    tests.currentLevelTracksPointThresholds()
    tests.snapshotContainsReadOnlyRelationshipSurface()
    tests.stateRoundTripsThroughCodableWithSchemaVersion()
}

private struct RelationshipStateTests {
    func newStateDefaultsToLevelOneWithZeroPoints() {
        let state = RelationshipState()

        expect(state.schemaVersion == RelationshipState.currentSchemaVersion, "new relationship state should use current schema version")
        expect(state.intimacyPoints == 0, "new relationship state should start at 0 points")
        expect(state.currentLevel == .acquaintance, "new relationship state should start at Lv.1")
        expect(state.consecutiveVisitDays == 0, "new relationship state should not assume visit streaks")
        expect(state.unlockedMilestoneIds.isEmpty, "new relationship state should not unlock milestones")
        expect(state.dailyCounters == RelationshipDailyCounters(), "new relationship state should start with empty counters")
        expect(state.cooldowns == RelationshipCooldowns(), "new relationship state should start with empty cooldowns")
        expect(state.summary == InteractionSummary(), "new relationship state should start with an empty summary")
    }

    func currentLevelTracksPointThresholds() {
        var state = RelationshipState(intimacyPoints: 249)
        expect(state.currentLevel == .familiar, "249 points should be Lv.2")

        state.intimacyPoints = 250
        expect(state.currentLevel == .close, "current level should update when points cross into Lv.3")

        state.intimacyPoints = 900
        expect(state.currentLevel == .bonded, "current level should update when points cross into Lv.5")
    }

    func snapshotContainsReadOnlyRelationshipSurface() {
        var state = RelationshipState(intimacyPoints: 120)
        state.dailyCounters.petCount = 3

        let snapshot = state.snapshot
        expect(snapshot.intimacyPoints == 120, "snapshot should include intimacy points")
        expect(snapshot.currentLevel == .familiar, "snapshot should include current level")
        expect(snapshot.levelName == "熟悉", "snapshot should include display name")
        expect(snapshot.levelNumber == 2, "snapshot should include level number")
        expect(snapshot.nextLevelMinimumPoints == 250, "snapshot should include next level threshold")
        expect(
            Mirror(reflecting: snapshot).children.allSatisfy { $0.label != "dailyCounters" },
            "snapshot should not expose mutable daily counters"
        )

        state.dailyCounters.petCount = 7
        expect(snapshot.intimacyPoints == 120, "snapshot should not change after state mutation")
    }

    func stateRoundTripsThroughCodableWithSchemaVersion() {
        let date = Date(timeIntervalSince1970: 1_779_091_200)
        var state = RelationshipState(
            intimacyPoints: 510,
            lastVisitDate: date,
            lastSeenAt: date,
            consecutiveVisitDays: 4,
            unlockedMilestoneIds: ["level-2", "level-3"]
        )
        state.dailyCounters.feedCount = 2
        state.cooldowns.lastFeedAt = date
        state.summary.recordBubbleText("欢迎回来")

        do {
            let data = try JSONEncoder().encode(state)
            let decoded = try JSONDecoder().decode(RelationshipState.self, from: data)
            expect(decoded == state, "relationship state should encode and decode without losing data")
            expect(decoded.schemaVersion == RelationshipState.currentSchemaVersion, "decoded state should preserve schema version")
            expect(decoded.currentLevel == .trusted, "decoded state should compute Lv.4 from 510 points")
        } catch {
            fail("relationship state should be codable: \(error)")
        }
    }
}
