import Foundation
import DesktopPet

@MainActor
func runAIVisualSettingsViewModelTests() {
    let tests = AIVisualSettingsViewModelTests()
    tests.defaultPreferencesAreDisabled()
    tests.requestEnableShowsNotice()
    tests.confirmEnableSetsEnabled()
    tests.disableSetsDisabled()
    tests.setAutonomousFrequencyUpdatesPreference()
    tests.setDurationPresetUpdatesPreference()
    tests.setIntensityUpdatesPreference()
    tests.selectProviderUpdatesCurrentId()
    tests.manualGenerationCallsCallback()
    tests.restoreCallsCallback()
    tests.refreshUsageUpdatesSnapshot()
    tests.dailyUsedTextFormatsCorrectly()
    tests.monthlyUsedTextFormatsCorrectly()
    tests.feedbackCanBeShownAndCleared()
    tests.providerQuotaTextReturnsNilWhenNone()
    tests.providerQuotaTextFormatsRemainingCount()
    tests.updatePreferencesReflectsExternalChange()
    tests.initializesConsistencyPreferenceControls()
    tests.setConsistencyPreferenceUpdatesStateAndCallback()
    tests.setPetVisualNotesUpdatesStateAndCallback()
    tests.creativeRiskNoticeOnlyShowsForCreativePreference()
    tests.updateConsistencyControlsReflectsPetSwitch()
}

@MainActor
private struct AIVisualSettingsViewModelTests {
    private func makeViewModel(
        preferences: AIVisualPreferences = AIVisualPreferences(),
        petId: String = "test-pet",
        consistencyPreference: ConsistencyPreference = .conservative,
        petVisualNotes: String = ""
    ) -> AIVisualSettingsViewModel {
        let defaults = UserDefaults(suiteName: "AIVisualSettingsViewModelTests") ?? .standard
        defaults.removeObject(forKey: AIVisualPreferencesStore.preferencesKey)
        defaults.removeObject(forKey: AIVisualQuotaStore.storeKey)

        let quotaStore = AIVisualQuotaStore(
            config: .default,
            userDefaults: defaults
        )

        return AIVisualSettingsViewModel(
            preferences: preferences,
            consistencyPreference: consistencyPreference,
            petVisualNotes: petVisualNotes,
            petId: petId,
            quotaStore: quotaStore
        )
    }

    func defaultPreferencesAreDisabled() {
        let vm = makeViewModel()
        expect(!vm.isEnabled, "visual expression should be disabled by default")
        expect(vm.preferences.autonomousFrequency == .low, "default frequency should be low")
        expect(vm.preferences.durationPreset == .short, "default duration should be short")
        expect(vm.preferences.intensity == .light, "default intensity should be light")
    }

    func requestEnableShowsNotice() {
        let vm = makeViewModel()
        expect(!vm.showEnableNotice, "should start hidden")
        vm.requestEnable()
        expect(vm.showEnableNotice, "notice should be shown after request")
    }

    func confirmEnableSetsEnabled() {
        let vm = makeViewModel()
        var enabledValue: Bool?
        vm.onEnabledChanged = { enabledValue = $0 }

        vm.requestEnable()
        vm.confirmEnable()

        expect(vm.isEnabled, "should be enabled after confirm")
        expect(!vm.showEnableNotice, "notice should be hidden after confirm")
        expect(enabledValue == true, "callback should fire with true")
    }

    func disableSetsDisabled() {
        let vm = makeViewModel(preferences: AIVisualPreferences(isEnabled: true))
        var enabledValue: Bool?
        vm.onEnabledChanged = { enabledValue = $0 }

        vm.disable()

        expect(!vm.isEnabled, "should be disabled")
        expect(enabledValue == false, "callback should fire with false")
    }

    func setAutonomousFrequencyUpdatesPreference() {
        let vm = makeViewModel()
        var frequency: AIVisualAutonomousFrequency?
        vm.onAutonomousFrequencyChanged = { frequency = $0 }

        vm.setAutonomousFrequency(.medium)
        expect(vm.preferences.autonomousFrequency == .medium, "frequency should be medium")
        expect(frequency == .medium, "callback should fire with medium")

        vm.setAutonomousFrequency(.off)
        expect(vm.preferences.autonomousFrequency == .off, "frequency should be off")
    }

    func setDurationPresetUpdatesPreference() {
        let vm = makeViewModel()
        var preset: AIVisualDurationPreset?
        vm.onDurationPresetChanged = { preset = $0 }

        vm.setDurationPreset(.long)
        expect(vm.preferences.durationPreset == .long, "duration should be long")
        expect(preset == .long, "callback should fire with long")
    }

    func setIntensityUpdatesPreference() {
        let vm = makeViewModel()
        var intensity: AIVisualIntensity?
        vm.onIntensityChanged = { intensity = $0 }

        vm.setIntensity(.pronounced)
        expect(vm.preferences.intensity == .pronounced, "intensity should be pronounced")
        expect(intensity == .pronounced, "callback should fire with pronounced")
    }

    func selectProviderUpdatesCurrentId() {
        let infos = [
            ProviderInfo(providerId: "mock", displayName: "Mock", isConfigured: true, capabilities: .basic),
            ProviderInfo(providerId: "minimax-cli", displayName: "MiniMax CLI", isConfigured: false, capabilities: .basic)
        ]
        let vm = AIVisualSettingsViewModel(
            preferences: AIVisualPreferences(),
            providerInfos: infos,
            currentProviderId: "mock",
            isProviderConfigured: true,
            petId: "pet"
        )
        var providerId: String?
        vm.onProviderChanged = { providerId = $0 }

        vm.selectProvider("minimax-cli")
        expect(vm.currentProviderId == "minimax-cli", "provider should be minimax-cli")
        expect(!vm.isProviderConfigured, "minimax-cli is not configured")
        expect(providerId == "minimax-cli", "callback should fire")
    }

    func manualGenerationCallsCallback() {
        let vm = makeViewModel(preferences: AIVisualPreferences(isEnabled: true))
        var requested = false
        vm.onManualGenerationRequested = { requested = true }

        vm.requestManualGeneration()

        expect(requested, "manual generation callback should fire")
    }

    func restoreCallsCallback() {
        let vm = makeViewModel()
        vm.updateHasActiveOverlay(true)
        var restored = false
        vm.onRestoreRequested = { restored = true }

        vm.restoreVisual()
        expect(restored, "restore callback should fire")
    }

    func refreshUsageUpdatesSnapshot() {
        let vm = makeViewModel()
        expect(vm.usageSnapshot == nil, "should start nil")

        vm.refreshUsage()

        let snapshot = vm.usageSnapshot
        expect(snapshot != nil, "should have snapshot after refresh")
        expect(snapshot?.dailyTotalCount == 0, "should start with 0 used")
    }

    func dailyUsedTextFormatsCorrectly() {
        let vm = makeViewModel()
        vm.refreshUsage()
        let text = vm.dailyUsedText
        expect(text == "0 / 5", "should show 0 / 5 for default config")
    }

    func monthlyUsedTextFormatsCorrectly() {
        let vm = makeViewModel()
        vm.refreshUsage()
        let text = vm.monthlyUsedText
        expect(text == "0 / 80", "should show 0 / 80 for default config")
    }

    func feedbackCanBeShownAndCleared() {
        let vm = makeViewModel()
        expect(vm.feedbackMessage == nil, "should start nil")

        vm.showFeedback("test message")
        expect(vm.feedbackMessage == "test message", "should show message")

        vm.clearFeedback()
        expect(vm.feedbackMessage == nil, "should clear message")
    }

    func providerQuotaTextReturnsNilWhenNone() {
        let vm = makeViewModel()
        expect(vm.providerQuotaText == nil, "should be nil without quota snapshot")
    }

    func providerQuotaTextFormatsRemainingCount() {
        let vm = AIVisualSettingsViewModel(
            providerQuotaSnapshot: VisualProviderQuotaSnapshot(
                providerId: "minimax-cli",
                dailyLimit: 120,
                dailyUsed: 1
            )
        )
        expect(vm.providerQuotaText == "Token Plan: 119 remaining today", "should show remaining count without Optional wrapper")
    }

    func updatePreferencesReflectsExternalChange() {
        let vm = makeViewModel()
        let newPrefs = AIVisualPreferences(isEnabled: true, autonomousFrequency: .off)
        vm.updatePreferences(newPrefs)
        expect(vm.isEnabled, "should reflect external enable")
        expect(vm.preferences.autonomousFrequency == .off, "should reflect external frequency")
    }

    func initializesConsistencyPreferenceControls() {
        let vm = makeViewModel(
            consistencyPreference: .balanced,
            petVisualNotes: "pink-white fox"
        )

        expect(vm.consistencyPreference == .balanced, "should expose initial consistency preference")
        expect(vm.petVisualNotes == "pink-white fox", "should expose initial visual notes")
        expect(vm.consistencyPreferenceDescription == ConsistencyPreference.balanced.userDescription, "should expose selected preference description")
    }

    func setConsistencyPreferenceUpdatesStateAndCallback() {
        let vm = makeViewModel()
        var selected: ConsistencyPreference?
        vm.onConsistencyPreferenceChanged = { selected = $0 }

        vm.setConsistencyPreference(.creative)

        expect(vm.consistencyPreference == .creative, "preference should update to creative")
        expect(selected == .creative, "callback should fire with creative preference")
    }

    func setPetVisualNotesUpdatesStateAndCallback() {
        let vm = makeViewModel()
        var notes: String?
        vm.onPetVisualNotesChanged = { notes = $0 }

        vm.setPetVisualNotes("pink-white fox, 2D sprite")

        expect(vm.petVisualNotes == "pink-white fox, 2D sprite", "visual notes should update")
        expect(notes == "pink-white fox, 2D sprite", "callback should fire with visual notes")
    }

    func creativeRiskNoticeOnlyShowsForCreativePreference() {
        let vm = makeViewModel()
        expect(vm.creativePreferenceNotice == nil, "non-creative preference should not show risk notice")

        vm.setConsistencyPreference(.creative)

        expect(
            vm.creativePreferenceNotice == "此模式可能带来更明显变化，但仍会保持当前桌宠身份。",
            "creative preference should expose product risk notice"
        )
    }

    func updateConsistencyControlsReflectsPetSwitch() {
        let vm = makeViewModel(
            consistencyPreference: .creative,
            petVisualNotes: "old pet notes"
        )

        vm.updateConsistencyControls(
            preference: .balanced,
            petVisualNotes: "new pet notes"
        )

        expect(vm.consistencyPreference == .balanced, "pet switch should refresh consistency preference")
        expect(vm.petVisualNotes == "new pet notes", "pet switch should refresh visual notes")
    }
}
