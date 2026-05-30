import Foundation

public enum CompanionTimeSlot: String, CaseIterable, Codable, Equatable, Hashable, Sendable {
    case morning
    case afternoon
    case evening
    case night
    case workday
    case weekend

    public static func slots(for date: Date, calendar: Calendar = .current) -> Set<CompanionTimeSlot> {
        let hour = calendar.component(.hour, from: date)
        let daySlot: CompanionTimeSlot
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

        let weekSlot: CompanionTimeSlot = calendar.isDateInWeekend(date) ? .weekend : .workday
        return [daySlot, weekSlot]
    }
}
