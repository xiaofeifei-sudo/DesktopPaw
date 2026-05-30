import Foundation

public enum BubblePriority: Int, Comparable, Codable, Sendable {
    case decorative = 0
    case ambient = 1
    case relationship = 2
    case state = 3
    case interaction = 4

    public static func < (lhs: BubblePriority, rhs: BubblePriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public struct PetBubble: Equatable, Identifiable, Sendable {
    public let id: UUID
    public let text: String
    public let priority: BubblePriority
    public let createdAt: Date
    public let expiresAt: Date
    public let microDialogId: MicroDialogId?

    public init(
        id: UUID,
        text: String,
        priority: BubblePriority,
        createdAt: Date,
        expiresAt: Date,
        microDialogId: MicroDialogId? = nil
    ) {
        self.id = id
        self.text = text
        self.priority = priority
        self.createdAt = createdAt
        self.expiresAt = expiresAt
        self.microDialogId = microDialogId
    }

    public func isExpired(at date: Date) -> Bool {
        expiresAt <= date
    }
}
