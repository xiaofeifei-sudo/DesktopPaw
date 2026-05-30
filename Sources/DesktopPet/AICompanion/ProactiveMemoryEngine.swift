import Foundation

public enum ProactiveTriggerType: String, Sendable, Equatable {
    case milestoneFollowUp
    case emotionResponse
    case routineGreeting
    case anniversary
    case preferenceAdaptation
}

public struct ProactiveTrigger: Sendable, Equatable {
    public let type: ProactiveTriggerType
    public let relatedMemoryIds: [String]
    public let context: String

    public init(type: ProactiveTriggerType, relatedMemoryIds: [String], context: String) {
        self.type = type
        self.relatedMemoryIds = relatedMemoryIds
        self.context = context
    }
}

public protocol ProactiveMemoryProducing: Sendable {
    func checkTrigger(
        memories: [AIMemory],
        emotionalModel: AIEmotionalModel?,
        lastProactiveDate: Date?
    ) -> ProactiveTrigger?

    func composePrompt(for trigger: ProactiveTrigger) -> String

    func frequencyLimit(for phase: RelationshipPhase) -> Int
}

public struct ProactiveMemoryEngine: ProactiveMemoryProducing, Equatable {
    private let petId: String
    private let routineTimeMatcher: RoutineTimeMatching

    public init(petId: String, routineTimeMatcher: RoutineTimeMatching = .shared) {
        self.petId = petId
        self.routineTimeMatcher = routineTimeMatcher
    }

    public func checkTrigger(
        memories: [AIMemory],
        emotionalModel: AIEmotionalModel?,
        lastProactiveDate: Date?
    ) -> ProactiveTrigger? {
        let filtered = memories.filter { $0.petId == petId }
        guard !filtered.isEmpty || emotionalModel != nil else { return nil }

        let now = Date()
        let phase = emotionalModel?.relationshipPhase ?? .stranger
        let limitSeconds = frequencyLimit(for: phase)

        let candidates = allCandidates(memories: filtered, emotionalModel: emotionalModel, now: now)
        guard let best = highestPriorityCandidate(candidates) else { return nil }

        if let lastDate = lastProactiveDate {
            guard now.timeIntervalSince(lastDate) >= Double(limitSeconds) else { return nil }
        }

        return best
    }

    public func composePrompt(for trigger: ProactiveTrigger) -> String {
        switch trigger.type {
        case .milestoneFollowUp:
            return "用户之前提到了一件重要的事：\(trigger.context)。请用简短温暖的方式主动关心这件事的后续进展，不要过于正式。"
        case .emotionResponse:
            return "检测到用户近期情绪有所低落：\(trigger.context)。请用简短温柔的方式表达关心和陪伴，不要追问原因或给建议。"
        case .routineGreeting:
            return "根据用户的日常习惯，现在是一个合适的时机：\(trigger.context)。请用简短自然的方式打个招呼或送上关心。"
        case .anniversary:
            return "今天是关于用户的一个特别日子：\(trigger.context)。请用温暖的方式提及这个纪念日，表达你对这段关系的珍视。"
        case .preferenceAdaptation:
            return "根据用户的偏好：\(trigger.context)。请用个性化、简短的方式与用户互动，体现你对 TA 的了解。"
        }
    }

    public func frequencyLimit(for phase: RelationshipPhase) -> Int {
        switch phase {
        case .stranger: 7 * 24 * 3600
        case .familiar: 3 * 24 * 3600
        case .close: 1 * 24 * 3600
        case .bonded: 12 * 3600
        }
    }

    // MARK: - Private

    private func allCandidates(
        memories: [AIMemory],
        emotionalModel: AIEmotionalModel?,
        now: Date
    ) -> [ProactiveTrigger] {
        var candidates: [ProactiveTrigger] = []

        candidates.append(contentsOf: milestoneFollowUpTriggers(memories: memories, now: now))
        candidates.append(contentsOf: emotionResponseTriggers(emotionalModel: emotionalModel))
        candidates.append(contentsOf: routineGreetingTriggers(memories: memories, now: now))
        candidates.append(contentsOf: anniversaryTriggers(memories: memories, now: now))
        candidates.append(contentsOf: preferenceAdaptationTriggers(memories: memories))

        return candidates
    }

    private func highestPriorityCandidate(_ candidates: [ProactiveTrigger]) -> ProactiveTrigger? {
        let order: [ProactiveTriggerType] = [
            .anniversary,
            .milestoneFollowUp,
            .emotionResponse,
            .routineGreeting,
            .preferenceAdaptation
        ]
        for type in order {
            if let trigger = candidates.first(where: { $0.type == type }) {
                return trigger
            }
        }
        return candidates.first
    }

    private func milestoneFollowUpTriggers(memories: [AIMemory], now: Date) -> [ProactiveTrigger] {
        let oneDay: TimeInterval = 86400
        let threeDays: TimeInterval = 3 * oneDay

        return memories
            .filter { $0.category == .milestone }
            .filter { m in
                let elapsed = now.timeIntervalSince(m.updatedAt)
                return elapsed >= oneDay && elapsed <= threeDays
            }
            .map { m in
                ProactiveTrigger(
                    type: .milestoneFollowUp,
                    relatedMemoryIds: [m.id],
                    context: m.content
                )
            }
    }

    private func emotionResponseTriggers(emotionalModel: AIEmotionalModel?) -> [ProactiveTrigger] {
        guard let model = emotionalModel, model.moodTrend == .declining else { return [] }
        return [ProactiveTrigger(
            type: .emotionResponse,
            relatedMemoryIds: [],
            context: "用户近期情绪趋势下降，当前状态：\(model.currentMood.rawValue)"
        )]
    }

    private func routineGreetingTriggers(memories: [AIMemory], now: Date) -> [ProactiveTrigger] {
        let routines = memories.filter { $0.category == .routine }
        return routines
            .filter { routineTimeMatcher.matchesCurrentTime(routine: $0.content, now: now) }
            .map { m in
                ProactiveTrigger(
                    type: .routineGreeting,
                    relatedMemoryIds: [m.id],
                    context: m.content
                )
            }
    }

    private func anniversaryTriggers(memories: [AIMemory], now: Date) -> [ProactiveTrigger] {
        let calendar = Calendar.current

        return memories
            .filter { $0.category == .milestone }
            .filter { m in
                let years = calendar.dateComponents([.year], from: m.createdAt, to: now).year ?? 0
                guard years >= 1 else { return false }
                let createdDay = calendar.dateComponents([.month, .day], from: m.createdAt)
                let nowDay = calendar.dateComponents([.month, .day], from: now)
                return createdDay.month == nowDay.month && createdDay.day == nowDay.day
            }
            .map { m in
                let years = calendar.dateComponents([.year], from: m.createdAt, to: now).year ?? 0
                return ProactiveTrigger(
                    type: .anniversary,
                    relatedMemoryIds: [m.id],
                    context: "\(years)年前的今天：\(m.content)"
                )
            }
    }

    private func preferenceAdaptationTriggers(memories: [AIMemory]) -> [ProactiveTrigger] {
        let prefs = memories.filter { $0.category == .preference }
        guard !prefs.isEmpty else { return [] }
        return [ProactiveTrigger(
            type: .preferenceAdaptation,
            relatedMemoryIds: prefs.prefix(3).map(\.id),
            context: prefs.prefix(3).map(\.content).joined(separator: "、")
        )]
    }
}

public struct RoutineTimeMatching: Sendable, Equatable {
    public static let shared = RoutineTimeMatching()

    public init() {}

    public func matchesCurrentTime(routine description: String, now: Date) -> Bool {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: now)
        let isWeekend = calendar.isDateInWeekend(now)

        let lowercased = description.lowercased()

        if lowercased.contains("上午") || lowercased.contains("早上") || lowercased.contains("早晨") {
            return hour >= 6 && hour < 12
        }
        if lowercased.contains("下午") {
            return hour >= 12 && hour < 18
        }
        if lowercased.contains("晚上") || lowercased.contains("夜晚") || lowercased.contains("夜间") {
            return hour >= 18 && hour < 24
        }
        if lowercased.contains("深夜") || lowercased.contains("凌晨") {
            return hour >= 0 && hour < 6
        }

        if let match = extractHour(from: lowercased) {
            return abs(hour - match) <= 1
        }

        if lowercased.contains("工作日") && !isWeekend {
            return true
        }
        if lowercased.contains("周末") && isWeekend {
            return true
        }

        return false
    }

    private func extractHour(from text: String) -> Int? {
        let patterns = [
            (try? NSRegularExpression(pattern: "(\\d{1,2})点", options: []))!,
            (try? NSRegularExpression(pattern: "(\\d{1,2})[:：]", options: []))!
        ]
        let nsRange = NSRange(text.startIndex..., in: text)
        for pattern in patterns {
            if let match = pattern.firstMatch(in: text, range: nsRange),
               let range = Range(match.range(at: 1), in: text),
               let hour = Int(text[range]) {
                return (0...23).contains(hour) ? hour : nil
            }
        }
        return nil
    }
}
