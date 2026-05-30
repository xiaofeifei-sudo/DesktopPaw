import Foundation

public struct BubblePhraseCatalog: Codable, Equatable, Sendable {
    public let phrases: [BubblePhrase]

    public init(phrases: [BubblePhrase] = []) {
        self.phrases = phrases
    }

    public func phrases(for trigger: BubbleTrigger) -> [BubblePhrase] {
        phrases.filter { $0.matchesTrigger(trigger) }
    }

    public func phrases(for trigger: BubbleTrigger, relationshipLevel: RelationshipLevel) -> [BubblePhrase] {
        phrases.filter {
            $0.matchesTrigger(trigger) && $0.matchesRelationshipLevel(relationshipLevel)
        }
    }

    public func phrase(withId id: String) -> BubblePhrase? {
        phrases.first { $0.id == id }
    }

    public var isEmpty: Bool {
        phrases.isEmpty
    }

    public func merging(with other: BubblePhraseCatalog) -> BubblePhraseCatalog {
        let existingIds = Set(phrases.map(\.id))
        let newPhrases = other.phrases.filter { !existingIds.contains($0.id) }
        return BubblePhraseCatalog(phrases: phrases + newPhrases)
    }

    public static func defaultPriority(for trigger: BubbleTrigger) -> BubblePriority {
        switch trigger {
        case .clicked, .pet, .feed:
            return .interaction
        case .hungry, .tired, .happy, .quietModeNotice:
            return .state
        case .dailyGreeting, .longAbsenceReturn, .relationshipLevelUp, .microDialogPrompt:
            return .relationship
        case .idle, .walking, .sleeping, .actionLine:
            return .ambient
        }
    }
}
