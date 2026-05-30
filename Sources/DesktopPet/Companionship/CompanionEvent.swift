import Foundation

public enum CompanionEvent: Equatable, Sendable {
    case appBecameVisible(Date)
    case dailyFirstVisit(Date)
    case directInteraction(DirectInteractionKind, Date)
    case actionPlayed(ActionId, Date)
    case sleepRequested(Date)
    case wakeRequested(Date)
    case longAbsenceReturned(days: Int, Date)
    case relationshipLevelChanged(from: RelationshipLevel, to: RelationshipLevel, Date)
    case quietModeChanged(isActive: Bool, Date)
    case microDialogCompleted(MicroDialogOptionId, Date)
}

public enum DirectInteractionKind: String, CaseIterable, Codable, Equatable, Sendable {
    case click
    case pet
    case feed
}

public struct MicroDialogOptionId: RawRepresentable, Codable, Hashable, Equatable, Sendable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}
