import Foundation
import DesktopPet

func runQuietModePolicyTests() {
    let tests = QuietModePolicyTests()
    tests.defaultPreferencesAreInactive()
    tests.temporaryQuietModeExpires()
    tests.temporaryQuietModeOverridesScheduledQuietHours()
    tests.sameDayQuietHoursUseConfiguredEnd()
    tests.crossMidnightQuietHoursAreActiveBeforeAndAfterMidnight()
    tests.disabledQuietHoursAreInactive()
}

private struct QuietModePolicyTests {
    func defaultPreferencesAreInactive() {
        let policy = QuietModePolicy(calendar: calendar)

        expect(
            policy.quietState(preferences: CompanionPreferences(), at: date(day: 13, hour: 10, minute: 0)) == .inactive,
            "default companion preferences should not be quiet"
        )
    }

    func temporaryQuietModeExpires() {
        let policy = QuietModePolicy(calendar: calendar)
        let now = date(day: 13, hour: 10, minute: 0)
        let until = date(day: 13, hour: 11, minute: 0)
        let preferences = CompanionPreferences(quietUntil: until)

        expect(
            policy.quietState(preferences: preferences, at: now) == .temporary(until: until),
            "temporary quiet should be active before quietUntil"
        )
        expect(
            policy.quietState(preferences: preferences, at: until) == .inactive,
            "temporary quiet should be inactive at quietUntil"
        )
    }

    func temporaryQuietModeOverridesScheduledQuietHours() {
        let policy = QuietModePolicy(calendar: calendar)
        let now = date(day: 13, hour: 23, minute: 0)
        let temporaryUntil = date(day: 14, hour: 0, minute: 0)
        let preferences = CompanionPreferences(
            quietUntil: temporaryUntil,
            quietHours: QuietHours(startMinuteOfDay: 22 * 60, endMinuteOfDay: 8 * 60)
        )

        expect(
            policy.quietState(preferences: preferences, at: now) == .temporary(until: temporaryUntil),
            "temporary quiet should take priority over scheduled quiet hours"
        )
    }

    func sameDayQuietHoursUseConfiguredEnd() {
        let policy = QuietModePolicy(calendar: calendar)
        let preferences = CompanionPreferences(
            quietHours: QuietHours(startMinuteOfDay: 9 * 60, endMinuteOfDay: 18 * 60)
        )
        let expectedUntil = date(day: 13, hour: 18, minute: 0)

        expect(
            policy.quietState(preferences: preferences, at: date(day: 13, hour: 10, minute: 0)) == .scheduled(until: expectedUntil),
            "09:00-18:00 should be active at 10:00"
        )
        expect(
            policy.quietState(preferences: preferences, at: date(day: 13, hour: 19, minute: 0)) == .inactive,
            "09:00-18:00 should be inactive at 19:00"
        )
    }

    func crossMidnightQuietHoursAreActiveBeforeAndAfterMidnight() {
        let policy = QuietModePolicy(calendar: calendar)
        let preferences = CompanionPreferences(
            quietHours: QuietHours(startMinuteOfDay: 22 * 60, endMinuteOfDay: 8 * 60)
        )

        expect(
            policy.quietState(preferences: preferences, at: date(day: 13, hour: 23, minute: 0)) == .scheduled(until: date(day: 14, hour: 8, minute: 0)),
            "22:00-08:00 should be active at 23:00 until next morning"
        )
        expect(
            policy.quietState(preferences: preferences, at: date(day: 14, hour: 7, minute: 0)) == .scheduled(until: date(day: 14, hour: 8, minute: 0)),
            "22:00-08:00 should be active at 07:00 until same morning"
        )
        expect(
            policy.quietState(preferences: preferences, at: date(day: 14, hour: 12, minute: 0)) == .inactive,
            "22:00-08:00 should be inactive at noon"
        )
    }

    func disabledQuietHoursAreInactive() {
        let policy = QuietModePolicy(calendar: calendar)
        let preferences = CompanionPreferences(
            quietHours: QuietHours(isEnabled: false, startMinuteOfDay: 22 * 60, endMinuteOfDay: 8 * 60)
        )

        expect(
            policy.quietState(preferences: preferences, at: date(day: 13, hour: 23, minute: 0)) == .inactive,
            "disabled quiet hours should not create scheduled quiet state"
        )
    }

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 8 * 60 * 60)!
        return calendar
    }

    private func date(day: Int, hour: Int, minute: Int) -> Date {
        let components = DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: 2026,
            month: 5,
            day: day,
            hour: hour,
            minute: minute
        )
        guard let date = components.date else {
            fail("test date should be constructible")
        }
        return date
    }
}
