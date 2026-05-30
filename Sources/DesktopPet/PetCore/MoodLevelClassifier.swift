public enum MoodLevel: String, CaseIterable, Equatable, Hashable, Sendable {
    case high
    case medium
    case low
}

public enum MoodLevelClassifier {
    public static let highThreshold = 0.66
    public static let lowThreshold = 0.33

    public static func level(for mood: Double) -> MoodLevel {
        if mood >= highThreshold {
            return .high
        }
        if mood >= lowThreshold {
            return .medium
        }
        return .low
    }
}
