import Foundation

@MainActor
public final class BubbleScheduler {
    public private(set) var currentBubble: PetBubble?
    public private(set) var lastAmbientAt: Date?
    public private(set) var lastRelationshipAt: Date?
    public private(set) var lastStateAt: Date?

    public init() {}

    public func expireIfNeeded(at date: Date) {
        if let bubble = currentBubble, bubble.isExpired(at: date) {
            currentBubble = nil
        }
    }

    public func canEmit(
        priority: BubblePriority,
        at date: Date,
        minimumInterval: TimeInterval
    ) -> Bool {
        if let current = currentBubble, current.priority > priority {
            return false
        }

        switch priority {
        case .interaction:
            return true
        case .state:
            if let last = lastStateAt, date.timeIntervalSince(last) < minimumInterval {
                return false
            }
            return true
        case .relationship:
            if let last = lastRelationshipAt, date.timeIntervalSince(last) < minimumInterval {
                return false
            }
            return true
        case .ambient:
            if let last = lastAmbientAt, date.timeIntervalSince(last) < minimumInterval {
                return false
            }
            return true
        case .decorative:
            if let last = lastAmbientAt, date.timeIntervalSince(last) < minimumInterval {
                return false
            }
            return true
        }
    }

    public func register(_ bubble: PetBubble) {
        currentBubble = bubble
        switch bubble.priority {
        case .ambient, .decorative:
            lastAmbientAt = bubble.createdAt
        case .relationship:
            lastRelationshipAt = bubble.createdAt
        case .state:
            lastStateAt = bubble.createdAt
        case .interaction:
            break
        }
    }

    public func clearCurrent() {
        currentBubble = nil
    }
}
