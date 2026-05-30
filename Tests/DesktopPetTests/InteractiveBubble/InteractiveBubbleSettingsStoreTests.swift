import Foundation
import DesktopPet

@MainActor
func runInteractiveBubbleSettingsStoreTests() {
    let tests = InteractiveBubbleSettingsStoreTests()
    tests.defaultIsEnabled()
    tests.defaultActivityLevel()
    tests.persistIsEnabled()
    tests.persistActivityLevel()
    tests.invalidActivityLevelFallsBack()
    tests.intervalRangeLow()
    tests.intervalRangeMedium()
    tests.intervalRangeHigh()
    tests.changingActivityLevelUpdatesIntervals()
    tests.persistenceAcrossInstances()
    tests.defaultOptionWaitDuration()
    tests.defaultSilentPeriod()
    tests.defaultIsAdvancedMode()
    tests.persistAdvancedIntervalsWhenAdvancedModeEnabled()
    tests.persistOptionWaitDuration()
    tests.persistSilentPeriodComponents()
    tests.persistAdvancedMode()
    tests.enterAdvancedModeCopiesCurrentActivityRange()
    tests.exitAdvancedModeMapsIntervalsToNearestActivityLevel()
    tests.maxIntervalClampsToMinInterval()
    tests.minIntervalRaiseClampsExistingMaxInterval()
}

@MainActor
private struct InteractiveBubbleSettingsStoreTests {
    private func makeStore() -> InteractiveBubbleSettingsStore {
        InteractiveBubbleSettingsStore(defaults: UserDefaults(suiteName: UUID().uuidString)!)
    }

    func defaultIsEnabled() {
        let store = makeStore()
        expect(store.isEnabled == true, "default isEnabled should be true")
    }

    func defaultActivityLevel() {
        let store = makeStore()
        expect(store.activityLevel == .medium, "default activityLevel should be medium")
    }

    func persistIsEnabled() {
        let store = makeStore()
        store.isEnabled = false
        expect(store.isEnabled == false, "isEnabled should persist false")

        store.isEnabled = true
        expect(store.isEnabled == true, "isEnabled should persist true")
    }

    func persistActivityLevel() {
        let store = makeStore()
        store.activityLevel = .high
        expect(store.activityLevel == .high, "activityLevel should persist high")

        store.activityLevel = .low
        expect(store.activityLevel == .low, "activityLevel should persist low")
    }

    func invalidActivityLevelFallsBack() {
        let suite = UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defaults.set("invalidLevel", forKey: "interactiveBubbleActivityLevel")

        let store = InteractiveBubbleSettingsStore(defaults: defaults)
        expect(store.activityLevel == .medium, "invalid activityLevel should fall back to medium")
    }

    func intervalRangeLow() {
        let store = makeStore()
        store.activityLevel = .low
        expect(store.minInterval == 1800, "low minInterval should be 1800")
        expect(store.maxInterval == 7200, "low maxInterval should be 7200")
    }

    func intervalRangeMedium() {
        let store = makeStore()
        store.activityLevel = .medium
        expect(store.minInterval == 600, "medium minInterval should be 600")
        expect(store.maxInterval == 3600, "medium maxInterval should be 3600")
    }

    func intervalRangeHigh() {
        let store = makeStore()
        store.activityLevel = .high
        expect(store.minInterval == 300, "high minInterval should be 300")
        expect(store.maxInterval == 1800, "high maxInterval should be 1800")
    }

    func changingActivityLevelUpdatesIntervals() {
        let store = makeStore()

        store.activityLevel = .low
        expect(store.minInterval == 1800, "low minInterval")

        store.activityLevel = .high
        expect(store.minInterval == 300, "high minInterval after switch")
    }

    func persistenceAcrossInstances() {
        let suite = UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!

        let store1 = InteractiveBubbleSettingsStore(defaults: defaults)
        store1.isEnabled = false
        store1.activityLevel = .high

        let store2 = InteractiveBubbleSettingsStore(defaults: defaults)
        expect(store2.isEnabled == false, "isEnabled should persist across instances")
        expect(store2.activityLevel == .high, "activityLevel should persist across instances")
    }

    func defaultOptionWaitDuration() {
        let store = makeStore()
        expect(store.optionWaitDuration == 15, "default optionWaitDuration should be 15")
    }

    func defaultSilentPeriod() {
        let store = makeStore()
        expect(store.silentPeriodStart.hour == 0 && store.silentPeriodStart.minute == 0,
               "default silentPeriodStart should be 0:00")
        expect(store.silentPeriodEnd.hour == 9 && store.silentPeriodEnd.minute == 0,
               "default silentPeriodEnd should be 9:00")
    }

    func defaultIsAdvancedMode() {
        let store = makeStore()
        expect(store.isAdvancedMode == false, "default isAdvancedMode should be false")
    }

    func persistAdvancedIntervalsWhenAdvancedModeEnabled() {
        let suite = UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        let store1 = InteractiveBubbleSettingsStore(defaults: defaults)

        store1.isAdvancedMode = true
        store1.minInterval = 900
        store1.maxInterval = 4200

        let store2 = InteractiveBubbleSettingsStore(defaults: defaults)
        expect(store2.isAdvancedMode, "advanced mode should persist before reading custom intervals")
        expect(store2.minInterval == 900, "minInterval should persist in advanced mode")
        expect(store2.maxInterval == 4200, "maxInterval should persist in advanced mode")
    }

    func persistOptionWaitDuration() {
        let suite = UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        let store1 = InteractiveBubbleSettingsStore(defaults: defaults)

        store1.optionWaitDuration = 22

        let store2 = InteractiveBubbleSettingsStore(defaults: defaults)
        expect(store2.optionWaitDuration == 22, "option wait duration should persist")
    }

    func persistSilentPeriodComponents() {
        let suite = UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        let store1 = InteractiveBubbleSettingsStore(defaults: defaults)

        store1.silentPeriodStart = DateComponents(hour: 23, minute: 15)
        store1.silentPeriodEnd = DateComponents(hour: 7, minute: 45)

        let store2 = InteractiveBubbleSettingsStore(defaults: defaults)
        expect(store2.silentPeriodStart.hour == 23 && store2.silentPeriodStart.minute == 15,
               "silent start should persist hour and minute")
        expect(store2.silentPeriodEnd.hour == 7 && store2.silentPeriodEnd.minute == 45,
               "silent end should persist hour and minute")
    }

    func persistAdvancedMode() {
        let suite = UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        let store1 = InteractiveBubbleSettingsStore(defaults: defaults)

        store1.isAdvancedMode = true

        let store2 = InteractiveBubbleSettingsStore(defaults: defaults)
        expect(store2.isAdvancedMode, "advanced mode should persist true")
    }

    func enterAdvancedModeCopiesCurrentActivityRange() {
        let store = makeStore()
        store.activityLevel = .low

        store.enterAdvancedMode()

        expect(store.isAdvancedMode, "enterAdvancedMode should enable advanced mode")
        expect(store.minInterval == 1800, "enterAdvancedMode should copy low min interval")
        expect(store.maxInterval == 7200, "enterAdvancedMode should copy low max interval")
    }

    func exitAdvancedModeMapsIntervalsToNearestActivityLevel() {
        let store = makeStore()
        store.enterAdvancedMode()
        store.minInterval = 240
        store.maxInterval = 1500

        store.exitAdvancedMode()

        expect(!store.isAdvancedMode, "exitAdvancedMode should disable advanced mode")
        expect(store.activityLevel == .high, "custom interval center should map to nearest high activity")
        expect(store.minInterval == 300, "basic mode min interval should reflect mapped high activity")
        expect(store.maxInterval == 1800, "basic mode max interval should reflect mapped high activity")
    }

    func maxIntervalClampsToMinInterval() {
        let store = makeStore()
        store.enterAdvancedMode()
        store.minInterval = 1200
        store.maxInterval = 900

        expect(store.maxInterval == 1200, "maxInterval should clamp up to minInterval")
    }

    func minIntervalRaiseClampsExistingMaxInterval() {
        let store = makeStore()
        store.enterAdvancedMode()
        store.maxInterval = 1200
        store.minInterval = 1800

        expect(store.minInterval == 1800, "minInterval should persist raised value")
        expect(store.maxInterval == 1800, "raising minInterval should clamp existing maxInterval")
    }
}
