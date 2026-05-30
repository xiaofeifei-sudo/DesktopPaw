import Foundation
import DesktopPet

func runMoodSnapshotProviderTests() {
    let tests = MoodSnapshotProviderTests()
    tests.snapshotClassifiesHighMood()
    tests.snapshotInstanceValuesDoNotChange()
    tests.usesInjectedNowProvider()
}

private struct MoodSnapshotProviderTests {
    func snapshotClassifiesHighMood() {
        let capturedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let provider = SystemMoodSnapshot(nowProvider: { capturedAt })

        let snapshot = provider.snapshot(currentMood: 0.7)

        expect(snapshot.mood == 0.7, "snapshot should preserve the sampled mood")
        expect(snapshot.level == .high, "mood 0.7 should classify as high")
        expect(snapshot.capturedAt == capturedAt, "snapshot should record the sampling time")
    }

    func snapshotInstanceValuesDoNotChange() {
        let firstDate = Date(timeIntervalSince1970: 1_800_000_001)
        let secondDate = Date(timeIntervalSince1970: 1_800_000_002)
        var dates = [firstDate, secondDate]
        let provider = SystemMoodSnapshot(nowProvider: {
            if dates.isEmpty {
                fail("now provider should not be called when reading an existing snapshot")
            }
            return dates.removeFirst()
        })

        let snapshot = provider.snapshot(currentMood: 0.7)
        let originalSnapshot = snapshot

        let secondSnapshot = provider.snapshot(currentMood: 0.2)

        expect(snapshot == originalSnapshot, "existing snapshot value should remain unchanged")
        expect(snapshot.mood == 0.7, "existing snapshot mood should not change after later sampling")
        expect(snapshot.level == .high, "existing snapshot level should not change after later sampling")
        expect(snapshot.capturedAt == firstDate, "existing snapshot capturedAt should not change after later sampling")
        expect(secondSnapshot.mood == 0.2, "later snapshot should use the later mood")
        expect(secondSnapshot.level == .low, "later snapshot should classify the later mood independently")
        expect(secondSnapshot.capturedAt == secondDate, "later snapshot should use the later timestamp")
    }

    func usesInjectedNowProvider() {
        let injectedDate = Date(timeIntervalSince1970: 1_800_000_003)
        var callCount = 0
        let provider = SystemMoodSnapshot(nowProvider: {
            callCount += 1
            return injectedDate
        })

        let snapshot = provider.snapshot(currentMood: 0.5)

        expect(snapshot.capturedAt == injectedDate, "snapshot should use injected now provider")
        expect(callCount == 1, "now provider should be called once per snapshot")
        expect(snapshot.level == .medium, "mood 0.5 should classify as medium")
    }
}
