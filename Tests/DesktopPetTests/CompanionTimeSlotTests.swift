import Foundation
import DesktopPet

func runCompanionTimeSlotTests() {
    let tests = CompanionTimeSlotTests()
    tests.classifiesDocumentedWeekdayMorning()
    tests.classifiesDocumentedWeekendNight()
    tests.classifiesTimeSlotBoundaries()
    tests.injectableClockSuppliesDateAndCalendar()
}

private struct CompanionTimeSlotTests {
    func classifiesDocumentedWeekdayMorning() {
        expect(
            CompanionTimeSlot.slots(for: date(year: 2026, month: 5, day: 13, hour: 9, minute: 0), calendar: calendar) == [.morning, .workday],
            "2026-05-13 09:00 should be morning + workday"
        )
    }

    func classifiesDocumentedWeekendNight() {
        expect(
            CompanionTimeSlot.slots(for: date(year: 2026, month: 5, day: 17, hour: 23, minute: 30), calendar: calendar) == [.night, .weekend],
            "2026-05-17 23:30 should be night + weekend"
        )
    }

    func classifiesTimeSlotBoundaries() {
        assertSlots(hour: 4, minute: 59, expected: [.night, .workday])
        assertSlots(hour: 5, minute: 0, expected: [.morning, .workday])
        assertSlots(hour: 11, minute: 59, expected: [.morning, .workday])
        assertSlots(hour: 12, minute: 0, expected: [.afternoon, .workday])
        assertSlots(hour: 17, minute: 59, expected: [.afternoon, .workday])
        assertSlots(hour: 18, minute: 0, expected: [.evening, .workday])
        assertSlots(hour: 22, minute: 59, expected: [.evening, .workday])
        assertSlots(hour: 23, minute: 0, expected: [.night, .workday])
    }

    func injectableClockSuppliesDateAndCalendar() {
        let now = date(year: 2026, month: 5, day: 16, hour: 14, minute: 15)
        let clock = FixedCompanionClock(now: now, calendar: calendar)

        expect(clock.now == now, "fixed companion clock should expose injected date")
        expect(clock.calendar.timeZone == calendar.timeZone, "fixed companion clock should expose injected calendar")
        expect(
            CompanionTimeSlot.slots(for: clock.now, calendar: clock.calendar) == [.afternoon, .weekend],
            "fixed companion clock should support deterministic time slot tests"
        )
    }

    private var calendar: Calendar {
        makeCalendar()
    }

    private func assertSlots(hour: Int, minute: Int, expected: Set<CompanionTimeSlot>) {
        let slots = CompanionTimeSlot.slots(
            for: date(year: 2026, month: 5, day: 13, hour: hour, minute: minute),
            calendar: calendar
        )
        expect(slots == expected, "hour boundary \(hour):\(minute) should classify as \(expected)")
    }

    private func date(year: Int, month: Int, day: Int, hour: Int, minute: Int) -> Date {
        makeDate(year: year, month: month, day: day, hour: hour, minute: minute, calendar: calendar)
    }
}

private func makeCalendar() -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 8 * 60 * 60)!
    return calendar
}

private func makeDate(year: Int, month: Int, day: Int, hour: Int, minute: Int, calendar: Calendar) -> Date {
    let components = DateComponents(
        calendar: calendar,
        timeZone: calendar.timeZone,
        year: year,
        month: month,
        day: day,
        hour: hour,
        minute: minute
    )
    guard let date = components.date else {
        fail("test date should be constructible")
    }
    return date
}
