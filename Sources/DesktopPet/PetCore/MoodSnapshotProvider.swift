import Foundation

public struct MoodSnapshot: Equatable, Sendable {
    public let mood: Double
    public let level: MoodLevel
    public let capturedAt: Date

    public init(mood: Double, level: MoodLevel, capturedAt: Date) {
        self.mood = mood
        self.level = level
        self.capturedAt = capturedAt
    }
}

public protocol MoodSnapshotProviding {
    func snapshot(currentMood: Double) -> MoodSnapshot
}

public struct SystemMoodSnapshot: MoodSnapshotProviding {
    private let nowProvider: () -> Date

    public init(nowProvider: @escaping () -> Date = { Date() }) {
        self.nowProvider = nowProvider
    }

    public func snapshot(currentMood: Double) -> MoodSnapshot {
        MoodSnapshot(
            mood: currentMood,
            level: MoodLevelClassifier.level(for: currentMood),
            capturedAt: nowProvider()
        )
    }
}
