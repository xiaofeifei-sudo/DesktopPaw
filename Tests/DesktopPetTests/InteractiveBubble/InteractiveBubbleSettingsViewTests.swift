import Foundation
import DesktopPet

@MainActor
func runInteractiveBubbleSettingsViewTests() {
    let tests = InteractiveBubbleSettingsViewTests()
    tests.showsAIGuidanceWhenAIIsNotConfigured()
    tests.hidesAIGuidanceWhenAIIsConfigured()
    tests.openAISettingsDispatchesShortcut()
    tests.togglingSmartBubblesPersistsToSettings()
    tests.changingActivityLevelPersistsToSettings()
    tests.expandingAdvancedSettingsPersistsAdvancedModeAndDisablesActivityLevel()
    tests.collapsingAdvancedSettingsMapsBackToNearestActivityLevel()
    tests.updatingMinIntervalClampsExistingMaxInterval()
    tests.updatingMaxIntervalNeverDropsBelowMinInterval()
    tests.updatingOptionWaitDurationPersistsClampedSeconds()
    tests.updatingSilentPeriodDatesPersistsHourAndMinute()
}

@MainActor
private struct InteractiveBubbleSettingsViewTests {
    private func makeStore() -> InteractiveBubbleSettingsStore {
        InteractiveBubbleSettingsStore(defaults: UserDefaults(suiteName: UUID().uuidString)!)
    }

    func showsAIGuidanceWhenAIIsNotConfigured() {
        let model = InteractiveBubbleSettingsViewModel(
            settings: makeStore(),
            isAIConfigured: false
        )

        expect(model.shouldShowAIGuidance,
               "interactive bubble settings should show AI guidance when AI is not configured")
        expect(L10n.SmartBubble.aiGuidance == "Smart bubbles need AI support. Configure a model and API key in AI Settings first.",
               "AI guidance copy should explain the required model and API key setup")
        expect(L10n.SmartBubble.openAISettings == "Open AI Settings",
               "AI guidance should expose a shortcut to AI settings")
    }

    func hidesAIGuidanceWhenAIIsConfigured() {
        let model = InteractiveBubbleSettingsViewModel(
            settings: makeStore(),
            isAIConfigured: true
        )

        expect(!model.shouldShowAIGuidance,
               "interactive bubble settings should hide AI guidance when AI is configured")
    }

    func openAISettingsDispatchesShortcut() {
        let model = InteractiveBubbleSettingsViewModel(
            settings: makeStore(),
            isAIConfigured: false
        )
        var didOpenAISettings = false
        model.onOpenAISettings = {
            didOpenAISettings = true
        }

        model.openAISettings()

        expect(didOpenAISettings,
               "Open AI Settings shortcut should dispatch its callback")
    }

    func togglingSmartBubblesPersistsToSettings() {
        let store = makeStore()
        let model = InteractiveBubbleSettingsViewModel(
            settings: store,
            isAIConfigured: true
        )

        model.setEnabled(false)

        expect(!model.isEnabled,
               "view model should update enabled state")
        expect(!store.isEnabled,
               "view model should persist enabled state to settings store")
    }

    func changingActivityLevelPersistsToSettings() {
        let store = makeStore()
        let model = InteractiveBubbleSettingsViewModel(
            settings: store,
            isAIConfigured: true
        )

        model.setActivityLevel(.high)

        expect(model.activityLevel == .high,
               "view model should update activity level")
        expect(store.activityLevel == .high,
               "view model should persist activity level to settings store")
    }

    func expandingAdvancedSettingsPersistsAdvancedModeAndDisablesActivityLevel() {
        let store = makeStore()
        store.activityLevel = .low
        let model = InteractiveBubbleSettingsViewModel(
            settings: store,
            isAIConfigured: true
        )

        model.setAdvancedModeExpanded(true)

        expect(model.isAdvancedMode,
               "view model should expose expanded advanced settings")
        expect(store.isAdvancedMode,
               "expanding advanced settings should persist advanced mode")
        expect(model.minIntervalMinutes == 30,
               "advanced settings should copy low activity minimum interval")
        expect(model.maxIntervalMinutes == 120,
               "advanced settings should copy low activity maximum interval")
        expect(model.isActivityLevelControlDisabled,
               "activity level control should be disabled while advanced settings are expanded")
    }

    func collapsingAdvancedSettingsMapsBackToNearestActivityLevel() {
        let store = makeStore()
        store.enterAdvancedMode()
        store.minInterval = 300
        store.maxInterval = 1800
        let model = InteractiveBubbleSettingsViewModel(
            settings: store,
            isAIConfigured: true
        )

        model.setAdvancedModeExpanded(false)

        expect(!model.isAdvancedMode,
               "collapsing advanced settings should update view model mode")
        expect(!store.isAdvancedMode,
               "collapsing advanced settings should persist basic mode")
        expect(model.activityLevel == .high,
               "collapsing should map custom interval center to nearest activity level")
        expect(!model.isActivityLevelControlDisabled,
               "activity level control should be enabled after advanced settings collapse")
    }

    func updatingMinIntervalClampsExistingMaxInterval() {
        let store = makeStore()
        let model = InteractiveBubbleSettingsViewModel(
            settings: store,
            isAIConfigured: true
        )
        model.setAdvancedModeExpanded(true)
        model.setMaxIntervalMinutes(20)

        model.setMinIntervalMinutes(45)

        expect(model.minIntervalMinutes == 45,
               "minimum interval should update in minutes")
        expect(model.maxIntervalMinutes == 45,
               "raising min interval should clamp existing max interval")
        expect(store.minInterval == 2700,
               "minimum interval should persist as seconds")
        expect(store.maxInterval == 2700,
               "clamped maximum interval should persist as seconds")
    }

    func updatingMaxIntervalNeverDropsBelowMinInterval() {
        let store = makeStore()
        let model = InteractiveBubbleSettingsViewModel(
            settings: store,
            isAIConfigured: true
        )
        model.setAdvancedModeExpanded(true)
        model.setMinIntervalMinutes(30)

        model.setMaxIntervalMinutes(15)

        expect(model.maxIntervalMinutes == 30,
               "maximum interval should not drop below minimum interval")
        expect(store.maxInterval == 1800,
               "clamped maximum interval should persist as seconds")
    }

    func updatingOptionWaitDurationPersistsClampedSeconds() {
        let store = makeStore()
        let model = InteractiveBubbleSettingsViewModel(
            settings: store,
            isAIConfigured: true
        )

        model.setOptionWaitDurationSeconds(8)

        expect(model.optionWaitDurationSeconds == 10,
               "option wait duration should clamp to the lower display bound")
        expect(store.optionWaitDuration == 10,
               "lower-clamped option wait duration should persist")

        model.setOptionWaitDurationSeconds(32)

        expect(model.optionWaitDurationSeconds == 30,
               "option wait duration should clamp to the upper display bound")
        expect(store.optionWaitDuration == 30,
               "upper-clamped option wait duration should persist")
    }

    func updatingSilentPeriodDatesPersistsHourAndMinute() {
        let store = makeStore()
        let model = InteractiveBubbleSettingsViewModel(
            settings: store,
            isAIConfigured: true
        )

        model.setSilentPeriodStart(timeDate(hour: 23, minute: 30))
        model.setSilentPeriodEnd(timeDate(hour: 7, minute: 45))

        expect(model.silentPeriodStartHour == 23 && model.silentPeriodStartMinute == 30,
               "view model should expose updated silent start hour and minute")
        expect(model.silentPeriodEndHour == 7 && model.silentPeriodEndMinute == 45,
               "view model should expose updated silent end hour and minute")
        expect(store.silentPeriodStart.hour == 23 && store.silentPeriodStart.minute == 30,
               "silent period start should persist hour and minute")
        expect(store.silentPeriodEnd.hour == 7 && store.silentPeriodEnd.minute == 45,
               "silent period end should persist hour and minute")
    }

    private func timeDate(hour: Int, minute: Int) -> Date {
        Calendar.current.date(from: DateComponents(hour: hour, minute: minute)) ?? Date()
    }
}
