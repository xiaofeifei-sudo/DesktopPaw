import Foundation

public enum BubbleTrigger: String, Codable, Equatable, Sendable, CaseIterable {
    // Original triggers
    case clicked
    case pet
    case feed
    case hungry
    case tired
    case happy
    case idle
    case walking
    case sleeping

    // Companion triggers
    case dailyGreeting
    case longAbsenceReturn
    case relationshipLevelUp
    case actionLine
    case microDialogPrompt
    case quietModeNotice
}

public struct BubbleProfile: Codable, Equatable, Sendable {
    public let phrases: [BubbleTrigger: [String]]
    public let minimumIntervalSeconds: Double
    public let displayDurationSeconds: Double

    public init(
        phrases: [BubbleTrigger: [String]],
        minimumIntervalSeconds: Double,
        displayDurationSeconds: Double
    ) {
        self.phrases = phrases
        self.minimumIntervalSeconds = minimumIntervalSeconds
        self.displayDurationSeconds = displayDurationSeconds
    }

    public func phrases(for trigger: BubbleTrigger) -> [String] {
        phrases[trigger] ?? []
    }

    private enum CodingKeys: String, CodingKey {
        case phrases
        case minimumIntervalSeconds
        case displayDurationSeconds
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawPhrases = try container.decode([String: [String]].self, forKey: .phrases)
        self.phrases = try Dictionary(uniqueKeysWithValues: rawPhrases.map { key, list in
            guard let trigger = BubbleTrigger(rawValue: key) else {
                throw DecodingError.dataCorruptedError(
                    forKey: .phrases,
                    in: container,
                    debugDescription: "Unknown bubble trigger: \(key)"
                )
            }
            return (trigger, list)
        })
        self.minimumIntervalSeconds = try container.decode(Double.self, forKey: .minimumIntervalSeconds)
        self.displayDurationSeconds = try container.decode(Double.self, forKey: .displayDurationSeconds)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        let raw = Dictionary(uniqueKeysWithValues: phrases.map { ($0.key.rawValue, $0.value) })
        try container.encode(raw, forKey: .phrases)
        try container.encode(minimumIntervalSeconds, forKey: .minimumIntervalSeconds)
        try container.encode(displayDurationSeconds, forKey: .displayDurationSeconds)
    }
}

public enum BubbleProfileDefaults {
    public static func defaultProfile() -> BubbleProfile {
        BubbleProfile(
            phrases: [
                .clicked: ["你好", "嗨"],
                .pet: ["开心", "再摸摸"],
                .feed: ["好吃", "满足了"],
                .hungry: ["有点饿"],
                .tired: ["困了"],
                .happy: ["开心"],
                .idle: ["陪你一会儿"],
                .walking: ["走走"],
                .sleeping: ["zzz"]
            ],
            minimumIntervalSeconds: 60,
            displayDurationSeconds: 3
        )
    }
}
