import Foundation

public struct EmotionSignal: Sendable, Equatable {
    public let mood: EmotionalMood
    public let confidence: Double
    public let timestamp: Date

    public init(mood: EmotionalMood, confidence: Double, timestamp: Date = Date()) {
        self.mood = mood
        self.confidence = min(max(confidence, 0), 1)
        self.timestamp = timestamp
    }
}

public protocol EmotionalTrackingServicing: Sendable {
    func parseEmotionSignal(from response: String) -> EmotionSignal?
    func updateAfterSession(signals: [EmotionSignal], model: AIEmotionalModel) -> AIEmotionalModel
    func shouldRecalculatePatterns(model: AIEmotionalModel) -> Bool
    func detectCrisisSignal(from userMessage: String) -> Bool
}

public struct EmotionalTrackingService: EmotionalTrackingServicing, Sendable {
    public init() {}

    public func parseEmotionSignal(from response: String) -> EmotionSignal? {
        guard let range = response.range(of: #"\[EMOTION:([a-z]+):([0-9.]+)\]"#, options: .regularExpression) else {
            return nil
        }
        let tag = String(response[range])
        let inner = tag
            .replacingOccurrences(of: "[EMOTION:", with: "")
            .replacingOccurrences(of: "]", with: "")
        let parts = inner.split(separator: ":")
        guard parts.count == 2,
              let mood = EmotionalMood(rawValue: String(parts[0])),
              let confidence = Double(String(parts[1])) else {
            return nil
        }
        return EmotionSignal(mood: mood, confidence: confidence)
    }

    public func updateAfterSession(signals: [EmotionSignal], model: AIEmotionalModel) -> AIEmotionalModel {
        var updated = model
        updated.totalSessions += 1
        updated.lastUpdatedAt = Date()

        if let dominant = signals.max(by: { $0.confidence < $1.confidence }) {
            updated.currentMood = dominant.mood

            let today = Calendar.current.startOfDay(for: Date())
            let dailyEmotion = DailyEmotion(date: today, dominant: dominant.mood, confidence: dominant.confidence)

            if let todayIndex = updated.recentEmotions.firstIndex(where: { Calendar.current.isDate($0.date, inSameDayAs: today) }) {
                if dailyEmotion.confidence > updated.recentEmotions[todayIndex].confidence {
                    updated.recentEmotions[todayIndex] = dailyEmotion
                }
            } else {
                updated.recentEmotions.append(dailyEmotion)
            }
        }

        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
        updated.recentEmotions = updated.recentEmotions.filter { $0.date >= cutoff }

        updated.moodTrend = computeMoodTrend(recentEmotions: updated.recentEmotions)
        updated.relationshipPhase = evaluateRelationshipPhase(
            totalSessions: updated.totalSessions,
            patternsCount: updated.emotionalPatterns.count,
            current: model.relationshipPhase
        )

        return updated
    }

    public func shouldRecalculatePatterns(model: AIEmotionalModel) -> Bool {
        model.totalSessions > 0 && model.totalSessions % 5 == 0
    }

    public func detectCrisisSignal(from userMessage: String) -> Bool {
        let keywords = [
            "自杀", "想死", "不想活", "自残", "结束生命",
            "活不下去", "没有意义", "不如死了", "不想存在",
            "suicide", "kill myself", "end my life", "self-harm",
            "解脱", "了结",
        ]
        let lowercased = userMessage.lowercased()
        return keywords.contains { lowercased.contains($0) }
    }

    // MARK: - Private

    private func computeMoodTrend(recentEmotions: [DailyEmotion]) -> MoodTrend {
        guard recentEmotions.count >= 3 else { return .unknown }

        let sorted = recentEmotions.sorted { $0.date < $1.date }
        let recentSlice = Array(sorted.suffix(3))
        let olderSlice = Array(sorted.dropLast(3))

        guard !olderSlice.isEmpty else { return .stable }

        let recentAvg = recentSlice.map(\.dominant.valence).reduce(0, +) / Double(recentSlice.count)
        let olderAvg = olderSlice.map(\.dominant.valence).reduce(0, +) / Double(olderSlice.count)

        let diff = recentAvg - olderAvg
        if diff > 0.1 { return .improving }
        if diff < -0.1 { return .declining }
        return .stable
    }

    private func evaluateRelationshipPhase(totalSessions: Int, patternsCount: Int, current: RelationshipPhase) -> RelationshipPhase {
        let target: RelationshipPhase
        if totalSessions >= 60 && patternsCount >= 6 {
            target = .bonded
        } else if totalSessions >= 30 && patternsCount >= 3 {
            target = .close
        } else if totalSessions >= 10 {
            target = .familiar
        } else {
            target = .stranger
        }

        let phases: [RelationshipPhase] = [.stranger, .familiar, .close, .bonded]
        let currentIdx = phases.firstIndex(of: current) ?? 0
        let targetIdx = phases.firstIndex(of: target) ?? 0
        return phases[max(currentIdx, targetIdx)]
    }
}
