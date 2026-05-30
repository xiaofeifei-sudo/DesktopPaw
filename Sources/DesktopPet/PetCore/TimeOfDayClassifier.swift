import Foundation

public enum TimeSlot: String, CaseIterable, Equatable, Hashable, Sendable {
    case morning
    case afternoon
    case evening
    case night
    case workday
    case weekend
}

public enum TimeOfDayClassifier {
    public static func slots(for date: Date, calendar: Calendar = .current) -> Set<TimeSlot> {
        let hour = calendar.component(.hour, from: date)
        let daySlot: TimeSlot
        switch hour {
        case 5..<12:
            daySlot = .morning
        case 12..<18:
            daySlot = .afternoon
        case 18..<23:
            daySlot = .evening
        default:
            daySlot = .night
        }

        let weekSlot: TimeSlot = calendar.isDateInWeekend(date) ? .weekend : .workday
        return [daySlot, weekSlot]
    }
}
