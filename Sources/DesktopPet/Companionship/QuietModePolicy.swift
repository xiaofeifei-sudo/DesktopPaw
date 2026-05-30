import Foundation

public protocol QuietModeEvaluating: Sendable {
    func quietState(preferences: CompanionPreferences, at date: Date) -> QuietModeState
}

public enum QuietModeState: Equatable, Sendable {
    case inactive
    case temporary(until: Date)
    case scheduled(until: Date)
}

public struct QuietModePolicy: QuietModeEvaluating {
    private let calendar: Calendar

    public init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    public func quietState(preferences: CompanionPreferences, at date: Date) -> QuietModeState {
        if let quietUntil = preferences.quietUntil, quietUntil > date {
            return .temporary(until: quietUntil)
        }

        guard let quietHours = preferences.quietHours,
              quietHours.isEnabled,
              !quietHours.isEmpty else {
            return .inactive
        }

        let minute = minuteOfDay(for: date)
        if quietHours.crossesMidnight {
            if minute >= quietHours.startMinuteOfDay {
                return .scheduled(until: quietEndDate(onSameDayAs: date, minuteOfDay: quietHours.endMinuteOfDay, dayOffset: 1))
            }

            if minute < quietHours.endMinuteOfDay {
                return .scheduled(until: quietEndDate(onSameDayAs: date, minuteOfDay: quietHours.endMinuteOfDay))
            }

            return .inactive
        }

        guard minute >= quietHours.startMinuteOfDay,
              minute < quietHours.endMinuteOfDay else {
            return .inactive
        }

        return .scheduled(until: quietEndDate(onSameDayAs: date, minuteOfDay: quietHours.endMinuteOfDay))
    }

    private func minuteOfDay(for date: Date) -> Int {
        calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)
    }

    private func quietEndDate(onSameDayAs date: Date, minuteOfDay: Int, dayOffset: Int = 0) -> Date {
        let startOfDay = calendar.startOfDay(for: date)
        let seconds = TimeInterval((dayOffset * 24 * 60 + minuteOfDay) * 60)
        return startOfDay.addingTimeInterval(seconds)
    }
}
