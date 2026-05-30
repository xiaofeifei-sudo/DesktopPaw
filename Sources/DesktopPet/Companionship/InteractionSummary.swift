import Foundation

public struct InteractionSummary: Codable, Equatable, Sendable {
    public var summaryDateKey: String?
    public var todayPetCount: Int
    public var todayFeedCount: Int
    public var todayActionPlayCount: Int
    public var todayMicroDialogCount: Int
    public var recentBubbleTexts: [String]
    public var lastInteractionAt: Date?

    public init(
        summaryDateKey: String? = nil,
        todayPetCount: Int = 0,
        todayFeedCount: Int = 0,
        todayActionPlayCount: Int = 0,
        todayMicroDialogCount: Int = 0,
        recentBubbleTexts: [String] = [],
        lastInteractionAt: Date? = nil
    ) {
        self.summaryDateKey = summaryDateKey
        self.todayPetCount = todayPetCount
        self.todayFeedCount = todayFeedCount
        self.todayActionPlayCount = todayActionPlayCount
        self.todayMicroDialogCount = todayMicroDialogCount
        self.recentBubbleTexts = recentBubbleTexts
        self.lastInteractionAt = lastInteractionAt
    }

    public var lastBubbleText: String? {
        recentBubbleTexts.last
    }

    public mutating func recordBubbleText(_ text: String, limit: Int = 10) {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty, limit > 0 else {
            return
        }

        recentBubbleTexts.append(trimmedText)
        if recentBubbleTexts.count > limit {
            recentBubbleTexts = Array(recentBubbleTexts.suffix(limit))
        }
    }
}
