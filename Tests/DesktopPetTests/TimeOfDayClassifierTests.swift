import Foundation
import DesktopPet

func runTimeOfDayClassifierTests() {
    let tests = TimeOfDayClassifierTests()
    tests.classifiesDocumentedWeekdayMorning()
    tests.classifiesDocumentedWeekendNight()
    tests.classifiesDocumentedWeekdayEarlyNight()
    tests.classifiesDocumentedWeekdayEvening()
    tests.classifiesTimeSlotBoundaries()
}

private struct TimeOfDayClassifierTests {
    func classifiesDocumentedWeekdayMorning() {
        expect(
            TimeOfDayClassifier.slots(for: date(year: 2026, month: 5, day: 13, hour: 9, minute: 0), calendar: calendar) == [.morning, .workday],
            "2026-05-13 09:00 should be morning + workday"
        )
    }

    func classifiesDocumentedWeekendNight() {
        expect(
            TimeOfDayClassifier.slots(for: date(year: 2026, month: 5, day: 17, hour: 23, minute: 30), calendar: calendar) == [.night, .weekend],
            "2026-05-17 23:30 should be night + weekend"
        )
    }

    func classifiesDocumentedWeekdayEarlyNight() {
        expect(
            TimeOfDayClassifier.slots(for: date(year: 2026, month: 5, day: 13, hour: 3, minute: 0), calendar: calendar) == [.night, .workday],
            "2026-05-13 03:00 should be night + workday"
        )
    }

    func classifiesDocumentedWeekdayEvening() {
        expect(
            TimeOfDayClassifier.slots(for: date(year: 2026, month: 5, day: 13, hour: 18, minute: 0), calendar: calendar) == [.evening, .workday],
            "2026-05-13 18:00 should be evening + workday"
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

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 8 * 60 * 60)!
        return calendar
    }

    private func assertSlots(hour: Int, minute: Int, expected: Set<TimeSlot>) {
        let slots = TimeOfDayClassifier.slots(
            for: date(year: 2026, month: 5, day: 13, hour: hour, minute: minute),
            calendar: calendar
        )
        expect(slots == expected, "hour boundary \(hour):\(minute) should classify as \(expected)")
    }

    private func date(year: Int, month: Int, day: Int, hour: Int, minute: Int) -> Date {
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
}
