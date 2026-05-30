import Foundation
import DesktopPet

func runRelationshipStoreTests() {
    let tests = RelationshipStoreTests()
    tests.loadMissingStateReturnsDefaultLevelOne()
    tests.saveLoadRoundTripsPerPet()
    tests.resetOnlyAffectsRequestedPet()
    tests.corruptStateFallsBackToDefault()
    tests.deleteStateRemovesOnlyRequestedPet()
}

private struct RelationshipStoreTests {
    func loadMissingStateReturnsDefaultLevelOne() {
        let fixture = makeFixture()
        defer { fixture.cleanUp() }

        do {
            let state = try fixture.store.loadState(petId: "new-pet")
            expect(state == RelationshipState(), "missing relationship file should load default state")
            expect(state.currentLevel == .acquaintance, "missing relationship file should load Lv.1")
            expect(state.intimacyPoints == 0, "missing relationship file should load 0 points")
        } catch {
            fail("loading missing relationship state should not throw: \(error)")
        }
    }

    func saveLoadRoundTripsPerPet() {
        let fixture = makeFixture()
        defer { fixture.cleanUp() }

        let date = Date(timeIntervalSince1970: 1_779_091_200)
        var petAState = RelationshipState(
            intimacyPoints: 260,
            lastVisitDate: date,
            lastSeenAt: date,
            consecutiveVisitDays: 3,
            unlockedMilestoneIds: ["level-2"]
        )
        petAState.dailyCounters.petCount = 2
        petAState.cooldowns.lastPetAt = date
        petAState.summary.recordBubbleText("今天也在")

        let petBState = RelationshipState(intimacyPoints: 910)

        do {
            try fixture.store.saveState(petAState, petId: "pet-a")
            try fixture.store.saveState(petBState, petId: "pet-b")

            let petAFileURL = fixture.store.relationshipFileURL(for: "pet-a")
            let raw = try String(contentsOf: petAFileURL, encoding: .utf8)
            expect(raw.contains("\"schemaVersion\""), "saved relationship JSON should include schemaVersion")

            let loadedA = try fixture.store.loadState(petId: "pet-a")
            let loadedB = try fixture.store.loadState(petId: "pet-b")
            expect(loadedA == petAState, "pet-a relationship state should round trip")
            expect(loadedB == petBState, "pet-b relationship state should round trip")
            expect(loadedA.currentLevel == .close, "pet-a loaded state should preserve Lv.3 point mapping")
            expect(loadedB.currentLevel == .bonded, "pet-b loaded state should preserve Lv.5 point mapping")
        } catch {
            fail("relationship state save/load should succeed: \(error)")
        }
    }

    func resetOnlyAffectsRequestedPet() {
        let fixture = makeFixture()
        defer { fixture.cleanUp() }

        do {
            try fixture.store.saveState(RelationshipState(intimacyPoints: 260), petId: "pet-a")
            try fixture.store.saveState(RelationshipState(intimacyPoints: 910), petId: "pet-b")

            try fixture.store.resetState(petId: "pet-a")

            let petAState = try fixture.store.loadState(petId: "pet-a")
            let petBState = try fixture.store.loadState(petId: "pet-b")
            expect(petAState == RelationshipState(), "reset should restore only requested pet to default")
            expect(petBState == RelationshipState(intimacyPoints: 910), "reset should not affect other pets")
        } catch {
            fail("relationship reset should succeed: \(error)")
        }
    }

    func corruptStateFallsBackToDefault() {
        let fixture = makeFixture()
        defer { fixture.cleanUp() }

        let fileURL = fixture.store.relationshipFileURL(for: "corrupt-pet")
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try Data("{ not valid json".utf8).write(to: fileURL)

            let loaded = try fixture.store.loadState(petId: "corrupt-pet")
            expect(loaded == RelationshipState(), "corrupt relationship JSON should fall back to default state")
            expect(loaded.currentLevel == .acquaintance, "corrupt relationship JSON fallback should be Lv.1")
        } catch {
            fail("corrupt relationship JSON should not throw: \(error)")
        }
    }

    func deleteStateRemovesOnlyRequestedPet() {
        let fixture = makeFixture()
        defer { fixture.cleanUp() }

        do {
            try fixture.store.saveState(RelationshipState(intimacyPoints: 260), petId: "pet-a")
            try fixture.store.saveState(RelationshipState(intimacyPoints: 910), petId: "pet-b")

            try fixture.store.deleteState(petId: "pet-a")
            try fixture.store.deleteState(petId: "pet-a")

            expect(!FileManager.default.fileExists(atPath: fixture.store.relationshipFileURL(for: "pet-a").path), "deleteState should remove requested pet file")
            expect(FileManager.default.fileExists(atPath: fixture.store.relationshipFileURL(for: "pet-b").path), "deleteState should keep other pet files")
            let petAState = try fixture.store.loadState(petId: "pet-a")
            expect(petAState == RelationshipState(), "deleted state should load as default")
        } catch {
            fail("relationship deleteState should remove requested pet only and ignore missing files: \(error)")
        }
    }

    private func makeFixture() -> Fixture {
        let rootDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("RelationshipStoreTests-\(UUID().uuidString)", isDirectory: true)
        let store = RelationshipStore(rootDirectoryURL: rootDirectory)
        return Fixture(rootDirectory: rootDirectory, store: store)
    }
}

private struct Fixture {
    let rootDirectory: URL
    let store: RelationshipStore

    func cleanUp() {
        try? FileManager.default.removeItem(at: rootDirectory)
    }
}
