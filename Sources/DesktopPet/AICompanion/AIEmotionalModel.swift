import Foundation

public enum EmotionalMood: String, Codable, Sendable, CaseIterable {
    case happy, relaxed, neutral, tired, stressed, sad, anxious, excited

    public var valence: Double {
        switch self {
        case .excited: 0.9
        case .happy: 0.8
        case .relaxed: 0.6
        case .neutral: 0.5
        case .tired: 0.3
        case .stressed: 0.2
        case .anxious: 0.15
        case .sad: 0.1
        }
    }
}

public enum MoodTrend: String, Codable, Sendable {
    case improving, stable, declining, unknown
}

public struct DailyEmotion: Codable, Sendable, Equatable {
    public let date: Date
    public let dominant: EmotionalMood
    public let confidence: Double

    public init(date: Date, dominant: EmotionalMood, confidence: Double) {
        self.date = date
        self.dominant = dominant
        self.confidence = confidence
    }
}

public struct EmotionalPattern: Codable, Sendable, Equatable {
    public let pattern: String
    public var confidence: Double
    public var evidence: Int

    public init(pattern: String, confidence: Double, evidence: Int) {
        self.pattern = pattern
        self.confidence = confidence
        self.evidence = evidence
    }
}

public enum RelationshipPhase: String, Codable, Sendable, CaseIterable {
    case stranger, familiar, close, bonded
}

public enum InteractionStyle: String, Codable, Sendable {
    case casual, formal, playful
}

public struct AIEmotionalModel: Codable, Sendable, Equatable {
    public var currentMood: EmotionalMood
    public var moodTrend: MoodTrend
    public var recentEmotions: [DailyEmotion]
    public var emotionalPatterns: [EmotionalPattern]
    public var relationshipPhase: RelationshipPhase
    public var interactionStyle: InteractionStyle
    public var topicsOfInterest: [String]
    public var totalSessions: Int
    public var lastUpdatedAt: Date

    public init(
        currentMood: EmotionalMood = .neutral,
        moodTrend: MoodTrend = .unknown,
        recentEmotions: [DailyEmotion] = [],
        emotionalPatterns: [EmotionalPattern] = [],
        relationshipPhase: RelationshipPhase = .stranger,
        interactionStyle: InteractionStyle = .casual,
        topicsOfInterest: [String] = [],
        totalSessions: Int = 0,
        lastUpdatedAt: Date = Date()
    ) {
        self.currentMood = currentMood
        self.moodTrend = moodTrend
        self.recentEmotions = recentEmotions
        self.emotionalPatterns = emotionalPatterns
        self.relationshipPhase = relationshipPhase
        self.interactionStyle = interactionStyle
        self.topicsOfInterest = topicsOfInterest
        self.totalSessions = totalSessions
        self.lastUpdatedAt = lastUpdatedAt
    }
}
