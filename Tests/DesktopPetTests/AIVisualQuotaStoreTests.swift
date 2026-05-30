import Foundation
import DesktopPet

@MainActor
func runAIVisualQuotaStoreTests() {
    let tests = AIVisualQuotaStoreTests()
    tests.canReserveWhenQuotaAvailable()
    tests.canReserveDeniesWhenDailyAutonomousExceeded()
    tests.canReserveDeniesWhenDailyTotalExceeded()
    tests.canReserveDeniesWhenMonthlyTotalExceeded()
    tests.canReserveDeniesWhenDailyUserRequestExceeded()
    tests.reserveIncrementsCounters()
    tests.reserveThrowsWhenQuotaExceeded()
    tests.markSucceededUpdatesRecord()
    tests.markFailedDecrementsCounters()
    tests.markFailedThrowsForUnknownAction()
    tests.dailyQuotaResetsNextDay()
    tests.monthlyQuotaResetsNextMonth()
    tests.loadUsageReturnsCorrectSnapshot()
    tests.persistAndReload()
    tests.multiplePetsTrackedIndependently()
}

@MainActor
private struct AIVisualQuotaStoreTests {
    private let baseDate = Date()

    private func makeStore(
        config: AIVisualQuotaConfig = .default,
        now: @escaping () -> Date = { Date() }
    ) -> AIVisualQuotaStore {
        let defaults = UserDefaults(suiteName: "AIVisualQuotaStoreTests") ?? .standard
        defaults.removeObject(forKey: AIVisualQuotaStore.storeKey)
        return AIVisualQuotaStore(
            config: config,
            userDefaults: defaults,
            now: now
        )
    }

    func canReserveWhenQuotaAvailable() {
        let store = makeStore()
        let decision = store.canReserve(petId: "pet-1", source: .chat, at: baseDate)
        expect(decision == .allowed, "should allow when quota is available")
    }

    func canReserveDeniesWhenDailyAutonomousExceeded() {
        let config = AIVisualQuotaConfig(dailyAutonomousLimit: 2, dailyTotalLimit: 10, monthlyTotalLimit: 100)
        let store = makeStore(config: config)
        try! store.reserve(petId: "pet-1", actionId: "a1", source: .chat, at: baseDate)
        try! store.reserve(petId: "pet-1", actionId: "a2", source: .chat, at: baseDate)

        let decision = store.canReserve(petId: "pet-1", source: .chat, at: baseDate)
        expect(decision == .dailyAutonomousExceeded, "should deny when daily autonomous limit reached")
    }

    func canReserveDeniesWhenDailyTotalExceeded() {
        let config = AIVisualQuotaConfig(dailyAutonomousLimit: 10, dailyUserRequestLimit: 10, dailyTotalLimit: 2, monthlyTotalLimit: 100)
        let store = makeStore(config: config)
        try! store.reserve(petId: "pet-1", actionId: "a1", source: .chat, at: baseDate)
        try! store.reserve(petId: "pet-1", actionId: "a2", source: .userRequest, at: baseDate)

        let decision = store.canReserve(petId: "pet-1", source: .chat, at: baseDate)
        expect(decision == .dailyTotalExceeded, "should deny when daily total limit reached")
    }

    func canReserveDeniesWhenMonthlyTotalExceeded() {
        let config = AIVisualQuotaConfig(dailyTotalLimit: 100, monthlyTotalLimit: 2)
        let store = makeStore(config: config)
        try! store.reserve(petId: "pet-1", actionId: "a1", source: .chat, at: baseDate)
        try! store.reserve(petId: "pet-1", actionId: "a2", source: .chat, at: baseDate)

        let decision = store.canReserve(petId: "pet-1", source: .chat, at: baseDate)
        expect(decision == .monthlyTotalExceeded, "should deny when monthly limit reached")
    }

    func canReserveDeniesWhenDailyUserRequestExceeded() {
        let config = AIVisualQuotaConfig(dailyUserRequestLimit: 1, dailyTotalLimit: 10, monthlyTotalLimit: 100)
        let store = makeStore(config: config)
        try! store.reserve(petId: "pet-1", actionId: "a1", source: .userRequest, at: baseDate)

        let decision = store.canReserve(petId: "pet-1", source: .userRequest, at: baseDate)
        expect(decision == .dailyUserRequestExceeded, "should deny when daily user request limit reached")
    }

    func reserveIncrementsCounters() {
        let store = makeStore()
        try! store.reserve(petId: "pet-1", actionId: "a1", source: .chat, at: baseDate)

        let snapshot = store.loadUsage(petId: "pet-1", date: baseDate)
        expect(snapshot.dailyAutonomousCount == 1, "daily autonomous count should be 1")
        expect(snapshot.dailyTotalCount == 1, "daily total count should be 1")
        expect(snapshot.monthlyTotalCount == 1, "monthly total count should be 1")
    }

    func reserveThrowsWhenQuotaExceeded() {
        let config = AIVisualQuotaConfig(dailyTotalLimit: 1)
        let store = makeStore(config: config)
        try! store.reserve(petId: "pet-1", actionId: "a1", source: .chat, at: baseDate)

        var threw = false
        do {
            try store.reserve(petId: "pet-1", actionId: "a2", source: .chat, at: baseDate)
        } catch {
            threw = true
        }
        expect(threw, "should throw when quota exceeded")
    }

    func markSucceededUpdatesRecord() {
        let store = makeStore()
        try! store.reserve(petId: "pet-1", actionId: "a1", source: .chat, at: baseDate)
        try! store.markSucceeded(actionId: "a1", providerId: "mock", assetId: "asset-1", at: baseDate)

        let snapshot = store.loadUsage(petId: "pet-1", date: baseDate)
        expect(snapshot.dailyAutonomousCount == 1, "succeeded should not change count")
    }

    func markFailedDecrementsCounters() {
        let store = makeStore()
        try! store.reserve(petId: "pet-1", actionId: "a1", source: .chat, at: baseDate)
        try! store.markFailed(actionId: "a1", providerId: "mock", errorCode: "timeout", at: baseDate)

        let snapshot = store.loadUsage(petId: "pet-1", date: baseDate)
        expect(snapshot.dailyAutonomousCount == 0, "failed should decrement autonomous count")
        expect(snapshot.dailyTotalCount == 0, "failed should decrement total count")
        expect(snapshot.monthlyTotalCount == 0, "failed should decrement monthly count")
    }

    func markFailedThrowsForUnknownAction() {
        let store = makeStore()
        var threw = false
        do {
            try store.markFailed(actionId: "unknown", providerId: "mock", errorCode: "err", at: baseDate)
        } catch {
            threw = true
        }
        expect(threw, "should throw for unknown actionId")
    }

    func dailyQuotaResetsNextDay() {
        let config = AIVisualQuotaConfig(dailyTotalLimit: 1)
        let store = makeStore(config: config)

        let today = baseDate
        let tomorrow = baseDate.addingTimeInterval(86400)

        try! store.reserve(petId: "pet-1", actionId: "a1", source: .chat, at: today)

        let decisionTomorrow = store.canReserve(petId: "pet-1", source: .chat, at: tomorrow)
        expect(decisionTomorrow == .allowed, "should allow next day after daily limit reached")
    }

    func monthlyQuotaResetsNextMonth() {
        let config = AIVisualQuotaConfig(dailyTotalLimit: 100, monthlyTotalLimit: 1)
        let store = makeStore(config: config)

        let thisMonth = baseDate
        let nextMonth = Calendar.current.date(byAdding: .month, value: 1, to: baseDate)!
        try! store.reserve(petId: "pet-1", actionId: "a1", source: .chat, at: thisMonth)

        let decisionNextMonth = store.canReserve(petId: "pet-1", source: .chat, at: nextMonth)
        expect(decisionNextMonth == .allowed, "should allow next month after monthly limit reached")
    }

    func loadUsageReturnsCorrectSnapshot() {
        let store = makeStore()
        try! store.reserve(petId: "pet-1", actionId: "a1", source: .chat, at: baseDate)
        try! store.reserve(petId: "pet-1", actionId: "a2", source: .userRequest, at: baseDate)

        let snapshot = store.loadUsage(petId: "pet-1", date: baseDate)
        expect(snapshot.petId == "pet-1", "snapshot should have correct petId")
        expect(snapshot.dailyAutonomousCount == 1, "autonomous count should be 1")
        expect(snapshot.dailyUserRequestCount == 1, "user request count should be 1")
        expect(snapshot.dailyTotalCount == 2, "total count should be 2")
        expect(snapshot.monthlyTotalCount == 2, "monthly count should be 2")
        expect(snapshot.lastAutonomousAt != nil, "should have lastAutonomousAt")
        expect(snapshot.pendingCount == 2, "pending count should be 2")
    }

    func persistAndReload() {
        let defaults = UserDefaults(suiteName: "AIVisualQuotaStoreTests")!
        defaults.removeObject(forKey: AIVisualQuotaStore.storeKey)
        let config = AIVisualQuotaConfig(dailyTotalLimit: 5)

        let store1 = AIVisualQuotaStore(config: config, userDefaults: defaults)
        try! store1.reserve(petId: "pet-1", actionId: "a1", source: .chat, at: baseDate)

        let store2 = AIVisualQuotaStore(config: config, userDefaults: defaults)
        let snapshot = store2.loadUsage(petId: "pet-1", date: baseDate)
        expect(snapshot.dailyAutonomousCount == 1, "should persist and reload data")
    }

    func multiplePetsTrackedIndependently() {
        let store = makeStore()
        try! store.reserve(petId: "pet-1", actionId: "a1", source: .chat, at: baseDate)
        try! store.reserve(petId: "pet-1", actionId: "a2", source: .chat, at: baseDate)

        let decision = store.canReserve(petId: "pet-2", source: .chat, at: baseDate)
        expect(decision == .allowed, "different pet should have independent quota")
    }
}
