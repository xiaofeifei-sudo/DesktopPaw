import Foundation

public protocol MemoryPromptComposing: Sendable {
    func composeMemoryContext(
        memories: [AIMemory],
        emotionalModel: AIEmotionalModel?
    ) -> MemoryPromptResult
}

public struct MemoryPromptResult: Sendable, Equatable {
    public let text: String
    public let usedMemoryIds: [String]
    public let tokenEstimate: Int

    public init(text: String, usedMemoryIds: [String], tokenEstimate: Int) {
        self.text = text
        self.usedMemoryIds = usedMemoryIds
        self.tokenEstimate = tokenEstimate
    }
}

public struct MemoryPromptComposer: MemoryPromptComposing, Equatable {
    private let maxInteractionCount: Int

    public init(maxInteractionCount: Int = 10) {
        self.maxInteractionCount = maxInteractionCount
    }

    public func composeMemoryContext(
        memories: [AIMemory],
        emotionalModel: AIEmotionalModel?
    ) -> MemoryPromptResult {
        let now = Date()
        let active = memories.filter { m in
            guard let expires = m.expiresAt else { return true }
            return expires > now
        }

        let nickname = active.filter { $0.category == .nickname }
        let preference = active.filter { $0.category == .preference }
        let routine = active.filter { $0.category == .routine }
        let emotion = active.filter { $0.category == .emotion }
        let milestone = active.filter { $0.category == .milestone }
        let custom = active.filter { $0.category == .custom }
        let topInteractions = active
            .filter { $0.category == .interaction }
            .sorted { interactionScore($0) > interactionScore($1) }
            .prefix(maxInteractionCount)

        var usedIds: [String] = []
        var sections: [String] = []

        let userMemories = nickname + preference + routine + emotion + Array(topInteractions)
        if !userMemories.isEmpty {
            let result = aboutUserSection(
                nickname: nickname,
                preference: preference,
                routine: routine,
                emotion: emotion,
                interactions: Array(topInteractions)
            )
            sections.append(result.text)
            usedIds.append(contentsOf: result.ids)
        }

        if let model = emotionalModel {
            sections.append(relationshipSection(model: model))
        }

        let important = milestone + custom
        if !important.isEmpty {
            let result = importantMemoriesSection(memories: important)
            sections.append(result.text)
            usedIds.append(contentsOf: result.ids)
        }

        let fullText = sections.joined(separator: "\n\n")
        return MemoryPromptResult(
            text: fullText,
            usedMemoryIds: usedIds,
            tokenEstimate: max(1, fullText.count / 2)
        )
    }

    // MARK: - Private

    private func interactionScore(_ memory: AIMemory) -> Double {
        memory.importance * Double(max(memory.accessCount, 1))
    }

    private func aboutUserSection(
        nickname: [AIMemory],
        preference: [AIMemory],
        routine: [AIMemory],
        emotion: [AIMemory],
        interactions: [AIMemory]
    ) -> (text: String, ids: [String]) {
        var lines: [String] = []
        var ids: [String] = []

        if !nickname.isEmpty {
            lines.append("- 昵称：\(nickname.map(\.content).joined(separator: "、"))")
            ids.append(contentsOf: nickname.map(\.id))
        }
        if !preference.isEmpty {
            lines.append("- 偏好：\(preference.map(\.content).joined(separator: "、"))")
            ids.append(contentsOf: preference.map(\.id))
        }
        if !routine.isEmpty {
            lines.append("- 习惯：\(routine.map(\.content).joined(separator: "、"))")
            ids.append(contentsOf: routine.map(\.id))
        }
        if !emotion.isEmpty {
            lines.append("- 近期状态：\(emotion.map(\.content).joined(separator: "、"))")
            ids.append(contentsOf: emotion.map(\.id))
        }
        for m in interactions {
            lines.append("- \(m.content)")
            ids.append(m.id)
        }

        return ("【关于用户】\n" + lines.joined(separator: "\n"), ids)
    }

    private func relationshipSection(model: AIEmotionalModel) -> String {
        var lines: [String] = []
        lines.append("- 关系阶段：\(Self.phaseName(model.relationshipPhase))")
        lines.append("- 互动风格：\(Self.styleName(model.interactionStyle))")
        if !model.topicsOfInterest.isEmpty {
            lines.append("- 用户的兴趣话题：\(model.topicsOfInterest.joined(separator: "、"))")
        }
        return "【关于我们的关系】\n" + lines.joined(separator: "\n")
    }

    private func importantMemoriesSection(memories: [AIMemory]) -> (text: String, ids: [String]) {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        let lines = memories.map { "- \(formatter.string(from: $0.createdAt)) \($0.content)" }
        return ("【重要回忆】\n" + lines.joined(separator: "\n"), memories.map(\.id))
    }

    private static func phaseName(_ phase: RelationshipPhase) -> String {
        switch phase {
        case .stranger: "初识"
        case .familiar: "熟悉"
        case .close: "亲密"
        case .bonded: "挚友"
        }
    }

    private static func styleName(_ style: InteractionStyle) -> String {
        switch style {
        case .casual: "轻松随意"
        case .formal: "正式认真"
        case .playful: "活泼调皮"
        }
    }
}
