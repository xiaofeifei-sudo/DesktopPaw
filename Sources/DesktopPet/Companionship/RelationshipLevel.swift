import Foundation

public enum RelationshipLevel: Int, CaseIterable, Codable, Comparable, Sendable {
    case acquaintance = 1
    case familiar = 2
    case close = 3
    case trusted = 4
    case bonded = 5

    public var levelNumber: Int {
        rawValue
    }

    public var displayName: String {
        switch self {
        case .acquaintance:
            return "初识"
        case .familiar:
            return "熟悉"
        case .close:
            return "亲近"
        case .trusted:
            return "信赖"
        case .bonded:
            return "默契"
        }
    }

    public var minimumPoints: Int {
        switch self {
        case .acquaintance:
            return 0
        case .familiar:
            return 100
        case .close:
            return 250
        case .trusted:
            return 500
        case .bonded:
            return 900
        }
    }

    public var nextLevelMinimumPoints: Int? {
        switch self {
        case .acquaintance:
            return RelationshipLevel.familiar.minimumPoints
        case .familiar:
            return RelationshipLevel.close.minimumPoints
        case .close:
            return RelationshipLevel.trusted.minimumPoints
        case .trusted:
            return RelationshipLevel.bonded.minimumPoints
        case .bonded:
            return nil
        }
    }

    public static func level(for intimacyPoints: Int) -> RelationshipLevel {
        switch max(0, intimacyPoints) {
        case 0..<100:
            return .acquaintance
        case 100..<250:
            return .familiar
        case 250..<500:
            return .close
        case 500..<900:
            return .trusted
        default:
            return .bonded
        }
    }

    public static func < (lhs: RelationshipLevel, rhs: RelationshipLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
