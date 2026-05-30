import Foundation

public enum BubbleMoodTag: String, Codable, Equatable, Hashable, Sendable, CaseIterable {
    case happy
    case sad
    case tired
    case energetic
    case hungry
    case full
    case lonely
    case playful
    case calm
    case sleepy
}

public struct BubblePhrase: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let text: String
    public let triggers: Set<BubbleTrigger>
    public let minRelationshipLevel: RelationshipLevel?
    public let maxRelationshipLevel: RelationshipLevel?
    public let moodTags: Set<BubbleMoodTag>
    public let timeTags: Set<CompanionTimeSlot>
    public let actionTags: Set<ActionTag>
    public let priority: BubblePriority
    public let weight: Double
    public let cooldownSeconds: TimeInterval?
    public let canStartMicroDialog: Bool

    public init(
        id: String,
        text: String,
        triggers: Set<BubbleTrigger>,
        minRelationshipLevel: RelationshipLevel? = nil,
        maxRelationshipLevel: RelationshipLevel? = nil,
        moodTags: Set<BubbleMoodTag> = [],
        timeTags: Set<CompanionTimeSlot> = [],
        actionTags: Set<ActionTag> = [],
        priority: BubblePriority = .ambient,
        weight: Double = 1.0,
        cooldownSeconds: TimeInterval? = nil,
        canStartMicroDialog: Bool = false
    ) {
        self.id = id
        self.text = text
        self.triggers = triggers
        self.minRelationshipLevel = minRelationshipLevel
        self.maxRelationshipLevel = maxRelationshipLevel
        self.moodTags = moodTags
        self.timeTags = timeTags
        self.actionTags = actionTags
        self.priority = priority
        self.weight = max(0, weight)
        self.cooldownSeconds = cooldownSeconds
        self.canStartMicroDialog = canStartMicroDialog
    }

    public func matchesTrigger(_ trigger: BubbleTrigger) -> Bool {
        triggers.contains(trigger)
    }

    public func matchesRelationshipLevel(_ level: RelationshipLevel) -> Bool {
        if let min = minRelationshipLevel, level < min {
            return false
        }
        if let max = maxRelationshipLevel, level > max {
            return false
        }
        return true
    }

    public func matchesTimeSlots(_ slots: Set<CompanionTimeSlot>) -> Bool {
        timeTags.isEmpty || !timeTags.isDisjoint(with: slots)
    }

    public func matchesMood(_ moodTags: Set<BubbleMoodTag>) -> Bool {
        self.moodTags.isEmpty || !self.moodTags.isDisjoint(with: moodTags)
    }

    public var effectiveDisplayDuration: TimeInterval {
        text.count > 6 ? 5 : 3
    }
}
