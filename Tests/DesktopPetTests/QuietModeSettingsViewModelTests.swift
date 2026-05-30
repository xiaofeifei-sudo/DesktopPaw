import Foundation
import DesktopPet

@MainActor
func runQuietModeSettingsViewModelTests() {
    let tests = QuietModeSettingsViewModelTests()
    tests.setQuietHoursEnabledCreatesQuietHours()
    tests.setQuietHoursDisabledClearsQuietHours()
    tests.setQuietHoursStartUpdatesStartTime()
    tests.setQuietHoursEndUpdatesEndTime()
    tests.setQuietHoursStartFiresCallback()
    tests.setQuietHoursEnabledFiresCallback()
}

@MainActor
private struct QuietModeSettingsViewModelTests {

    func setQuietHoursEnabledCreatesQuietHours() {
        let model = CompanionshipSettingsViewModel()
        expect(model.preferences.quietHours == nil, "quiet hours should start nil")

        model.setQuietHoursEnabled(true)

        expect(model.preferences.quietHours != nil, "enabling quiet hours should create QuietHours")
        expect(model.preferences.quietHours!.isEnabled, "created quiet hours should be enabled")
    }

    func setQuietHoursDisabledClearsQuietHours() {
        let model = CompanionshipSettingsViewModel(
            preferences: CompanionPreferences(quietHours: QuietHours(startMinuteOfDay: 22 * 60, endMinuteOfDay: 8 * 60))
        )

        model.setQuietHoursEnabled(false)

        expect(model.preferences.quietHours == nil, "disabling quiet hours should clear it")
    }

    func setQuietHoursStartUpdatesStartTime() {
        let model = CompanionshipSettingsViewModel(
            preferences: CompanionPreferences(quietHours: QuietHours(startMinuteOfDay: 22 * 60, endMinuteOfDay: 8 * 60))
        )

        model.setQuietHoursStart(20 * 60)

        expect(model.preferences.quietHours?.startMinuteOfDay == 20 * 60, "start should be updated to 20:00")
        expect(model.preferences.quietHours?.endMinuteOfDay == 8 * 60, "end should remain 08:00")
    }

    func setQuietHoursEndUpdatesEndTime() {
        let model = CompanionshipSettingsViewModel(
            preferences: CompanionPreferences(quietHours: QuietHours(startMinuteOfDay: 22 * 60, endMinuteOfDay: 8 * 60))
        )

        model.setQuietHoursEnd(6 * 60)

        expect(model.preferences.quietHours?.endMinuteOfDay == 6 * 60, "end should be updated to 06:00")
        expect(model.preferences.quietHours?.startMinuteOfDay == 22 * 60, "start should remain 22:00")
    }

    func setQuietHoursStartFiresCallback() {
        let model = CompanionshipSettingsViewModel(
            preferences: CompanionPreferences(quietHours: QuietHours(startMinuteOfDay: 22 * 60, endMinuteOfDay: 8 * 60))
        )
        var receivedQuietHours: QuietHours?
        model.onQuietHoursChanged = { receivedQuietHours = $0 }

        model.setQuietHoursStart(21 * 60)

        expect(receivedQuietHours?.startMinuteOfDay == 21 * 60, "callback should receive updated quiet hours")
    }

    func setQuietHoursEnabledFiresCallback() {
        let model = CompanionshipSettingsViewModel()
        var callbackCount = 0
        model.onQuietHoursChanged = { _ in callbackCount += 1 }

        model.setQuietHoursEnabled(true)
        model.setQuietHoursEnabled(false)

        expect(callbackCount == 2, "callback should fire for both enable and disable")
    }
}
