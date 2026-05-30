import Foundation

public protocol CompanionClock: Sendable {
    var now: Date { get }
    var calendar: Calendar { get }
}

public struct SystemCompanionClock: CompanionClock {
    public let calendar: Calendar

    public init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    public var now: Date {
        Date()
    }
}

public struct FixedCompanionClock: CompanionClock {
    public let now: Date
    public let calendar: Calendar

    public init(now: Date, calendar: Calendar = .current) {
        self.now = now
        self.calendar = calendar
    }
}
