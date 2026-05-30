import Foundation
import DesktopPet

@MainActor
func runAIVisualDiagnosticsStoreTests() {
    let tests = AIVisualDiagnosticsStoreTests()
    tests.recordAndRetrieve()
    tests.eventsForActionTracesPipeline()
    tests.clearAllRemovesEverything()
    tests.maxEventsTrimsOldest()
    tests.persistAndReload()
    tests.summaryComputesCorrectMetrics()
    tests.exportAnonymousSummaryNoSensitiveData()
    tests.summaryWithNoEvents()
    tests.providerErrorDistribution()
    tests.restoreRateCalculation()
    tests.filterClosure()
}

@MainActor
private struct AIVisualDiagnosticsStoreTests {
    private func makeStore() -> AIVisualDiagnosticsStore {
        let defaults = UserDefaults(suiteName: "AIVisualDiagnosticsStoreTests") ?? .standard
        defaults.removeObject(forKey: AIVisualDiagnosticsStore.storeKey)
        return AIVisualDiagnosticsStore(userDefaults: defaults)
    }

    func recordAndRetrieve() {
        let store = makeStore()
        let event = AIVisualMetricEvent(
            type: .candidateParsed,
            actionId: "a1",
            petId: "pet-1"
        )
        store.record(event)

        let all = store.events()
        expect(all.count == 1, "should have 1 event after recording")
        expect(all[0].type == .candidateParsed, "event type should match")
        expect(all[0].actionId == "a1", "actionId should match")
        expect(all[0].petId == "pet-1", "petId should match")
    }

    func eventsForActionTracesPipeline() {
        let store = makeStore()
        let actionId = "action-xyz"

        store.record(AIVisualMetricEvent(type: .candidateParsed, actionId: actionId, petId: "pet-1"))
        store.record(AIVisualMetricEvent(type: .policyDenied, actionId: actionId, petId: "pet-1", denyReason: "quietMode"))
        store.record(AIVisualMetricEvent(type: .candidateParsed, actionId: "other", petId: "pet-1"))

        let traced = store.eventsForAction(actionId)
        expect(traced.count == 2, "should trace 2 events for action-xyz")
        expect(traced[0].type == .candidateParsed, "first event should be candidateParsed")
        expect(traced[1].type == .policyDenied, "second event should be policyDenied")
    }

    func clearAllRemovesEverything() {
        let store = makeStore()
        store.record(AIVisualMetricEvent(type: .candidateParsed, actionId: "a1", petId: "pet-1"))
        store.record(AIVisualMetricEvent(type: .generationStarted, actionId: "a1", petId: "pet-1"))

        store.clearAll()

        let all = store.events()
        expect(all.isEmpty, "clearAll should remove all events")
    }

    func maxEventsTrimsOldest() {
        let defaults = UserDefaults(suiteName: "AIVisualDiagnosticsStoreTests") ?? .standard
        defaults.removeObject(forKey: AIVisualDiagnosticsStore.storeKey)
        let store = AIVisualDiagnosticsStore(userDefaults: defaults)

        for i in 0..<1010 {
            store.record(AIVisualMetricEvent(
                type: .candidateParsed,
                actionId: "a\(i)",
                petId: "pet-1"
            ))
        }

        let all = store.events()
        expect(all.count == 1000, "should cap at 1000 events")
        expect(all.first?.actionId == "a10", "oldest events should be trimmed")
        expect(all.last?.actionId == "a1009", "newest event should be present")
    }

    func persistAndReload() {
        let defaults = UserDefaults(suiteName: "AIVisualDiagnosticsStoreTests")!
        defaults.removeObject(forKey: AIVisualDiagnosticsStore.storeKey)

        let store1 = AIVisualDiagnosticsStore(userDefaults: defaults)
        store1.record(AIVisualMetricEvent(type: .generationSucceeded, actionId: "a1", petId: "pet-1", providerId: "mock", durationSeconds: 5.2))

        let store2 = AIVisualDiagnosticsStore(userDefaults: defaults)
        let events = store2.events()
        expect(events.count == 1, "should reload persisted event")
        expect(events[0].type == .generationSucceeded, "reloaded event type should match")
        expect(events[0].providerId == "mock", "reloaded providerId should match")
        expect(events[0].durationSeconds == 5.2, "reloaded duration should match")
    }

    func summaryComputesCorrectMetrics() {
        let store = makeStore()

        store.record(AIVisualMetricEvent(type: .candidateParsed, actionId: "a1", petId: "pet-1"))
        store.record(AIVisualMetricEvent(type: .generationStarted, actionId: "a1", petId: "pet-1"))
        store.record(AIVisualMetricEvent(type: .generationSucceeded, actionId: "a1", petId: "pet-1", providerId: "mock", durationSeconds: 3.0))
        store.record(AIVisualMetricEvent(type: .overlayApplied, actionId: "a1", petId: "pet-1"))
        store.record(AIVisualMetricEvent(type: .generationFailed, actionId: "a2", petId: "pet-1", providerId: "cli", errorCode: "timeout", durationSeconds: 90.0))
        store.record(AIVisualMetricEvent(type: .quotaExceeded, actionId: "a3", petId: "pet-1"))
        store.record(AIVisualMetricEvent(type: .safetyRejected, actionId: "a4", petId: "pet-1"))
        store.record(AIVisualMetricEvent(type: .favoriteCreated, actionId: "a1", petId: "pet-1"))

        let s = store.summary()
        expect(s.totalEvents == 8, "total events should be 8")
        expect(s.generationSuccessCount == 1, "success count should be 1")
        expect(s.generationFailureCount == 1, "failure count should be 1")
        expect(s.averageGenerationDurationSeconds == 3.0, "avg duration should be 3.0 (only succeeded)")
        expect(s.favoriteCount == 1, "favorite count should be 1")
        expect(s.quotaExceededCount == 1, "quota exceeded count should be 1")
        expect(s.safetyRejectedCount == 1, "safety rejected count should be 1")
        expect(s.userRestoreRate == 0.0, "restore rate should be 0 (no restores)")
    }

    func exportAnonymousSummaryNoSensitiveData() {
        let store = makeStore()

        store.record(AIVisualMetricEvent(type: .generationStarted, actionId: "a1", petId: "pet-1"))
        store.record(AIVisualMetricEvent(type: .generationSucceeded, actionId: "a1", petId: "pet-1", providerId: "mock", durationSeconds: 2.5))
        store.record(AIVisualMetricEvent(type: .generationFailed, actionId: "a2", petId: "pet-1", providerId: "cli", errorCode: "timeout"))

        let exported = store.exportAnonymousSummary()
        expect(!exported.contains("pet-1"), "exported summary should not contain petId")
        expect(!exported.contains("apiKey"), "exported summary should not contain apiKey")
        expect(exported.contains("Generation:"), "exported summary should contain generation stats")
        expect(exported.contains("timeout"), "exported summary should contain error code for diagnosis")
    }

    func summaryWithNoEvents() {
        let store = makeStore()
        let s = store.summary()
        expect(s.totalEvents == 0, "empty store should have 0 total events")
        expect(s.generationSuccessCount == 0, "empty store should have 0 successes")
        expect(s.generationFailureCount == 0, "empty store should have 0 failures")
        expect(s.averageGenerationDurationSeconds == nil, "empty store should have nil avg duration")
        expect(s.userRestoreRate == 0, "empty store should have 0 restore rate")
    }

    func providerErrorDistribution() {
        let store = makeStore()

        store.record(AIVisualMetricEvent(type: .generationFailed, actionId: "a1", petId: "pet-1", errorCode: "timeout"))
        store.record(AIVisualMetricEvent(type: .generationFailed, actionId: "a2", petId: "pet-1", errorCode: "timeout"))
        store.record(AIVisualMetricEvent(type: .generationFailed, actionId: "a3", petId: "pet-1", errorCode: "notConfigured"))

        let s = store.summary()
        expect(s.providerErrorCounts["timeout"] == 2, "should count 2 timeout errors")
        expect(s.providerErrorCounts["notConfigured"] == 1, "should count 1 notConfigured error")
    }

    func restoreRateCalculation() {
        let store = makeStore()

        store.record(AIVisualMetricEvent(type: .overlayApplied, actionId: "a1", petId: "pet-1"))
        store.record(AIVisualMetricEvent(type: .overlayApplied, actionId: "a2", petId: "pet-1"))
        store.record(AIVisualMetricEvent(type: .overlayRestored, actionId: "a1", petId: "pet-1"))

        let s = store.summary()
        expect(s.userRestoreRate == 0.5, "restore rate should be 1/2 = 0.5")
    }

    func filterClosure() {
        let store = makeStore()

        store.record(AIVisualMetricEvent(type: .candidateParsed, actionId: "a1", petId: "pet-1"))
        store.record(AIVisualMetricEvent(type: .generationStarted, actionId: "a1", petId: "pet-1"))
        store.record(AIVisualMetricEvent(type: .candidateParsed, actionId: "a2", petId: "pet-2"))

        let pet1Events = store.events(filter: { $0.petId == "pet-1" })
        expect(pet1Events.count == 2, "should filter to pet-1 events")

        let parsedEvents = store.events(filter: { $0.type == .candidateParsed })
        expect(parsedEvents.count == 2, "should filter to candidateParsed events")
    }
}
