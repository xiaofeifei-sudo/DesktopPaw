import Foundation

public final class InteractiveBubbleContentGenerator: InteractiveBubbleContentProviding, @unchecked Sendable {
    private let waitDuration: TimeInterval
    private let aiProvider: AIProviding?
    private let safetyService: AISafetyServicing?

    public init(
        waitDuration: TimeInterval = 15,
        aiProvider: AIProviding? = nil,
        safetyService: AISafetyServicing? = nil
    ) {
        self.waitDuration = waitDuration
        self.aiProvider = aiProvider
        self.safetyService = safetyService
    }

    // MARK: - AI Generation

    public func generate(context: BubbleContext) async -> InteractiveBubble? {
        guard let provider = aiProvider, provider.isConfigured else { return nil }

        let systemPrompt = buildSystemPrompt(context: context)
        let userPrompt = buildUserPrompt(context: context)
        let aiContext = AIChatContext(
            systemPrompt: systemPrompt,
            temperature: 0.85,
            maxTokens: 256
        )
        let messages = [AIChatMessage(role: .user, content: userPrompt)]

        for attempt in 0..<2 {
            let rawContent: String
            do {
                let response = try await provider.complete(messages: messages, context: aiContext)
                rawContent = response.content
            } catch {
                return nil
            }

            let cleaned = Self.stripThinkingTags(rawContent)

            if let safetyService {
                let result = safetyService.validatePromptSafety(cleaned)
                if result.shouldBlock { return nil }
            }

            guard let bubble = parseAIResponse(cleaned, context: context) else { return nil }

            if isSimilarToRecent(bubble.text, recent: context.recentBubbleTexts) {
                if attempt == 0 { continue }
                return nil
            }

            return bubble
        }

        return nil
    }

    // MARK: - Static Fallback

    public func generateFallback(context: BubbleContext) -> InteractiveBubble {
        let type = selectType(for: context)
        let text = selectPhrase(type: type, recentTexts: context.recentBubbleTexts)
        let options = StaticPhraseLibrary.defaultOptions[type] ?? []
        let now = Date()
        return InteractiveBubble(
            text: text,
            type: type,
            options: options,
            createdAt: now,
            expiresAt: now.addingTimeInterval(waitDuration)
        )
    }

    public func selectType(for context: BubbleContext) -> BubbleType {
        let state = context.runtimeState

        if state.hunger > 0.7 { return .needExpression }
        if state.energy < 0.3 { return .needExpression }
        if state.mood < 0.3 { return .emotionSharing }

        if context.consecutiveNoResponse >= 3 {
            let lightTypes: [BubbleType] = [.randomTopic, .curiousQuestion, .gameInvitation]
            return lightTypes.randomElement()!
        }

        return BubbleType.allCases.randomElement()!
    }

    // MARK: - Prompt Building

    private func buildSystemPrompt(context: BubbleContext) -> String {
        let tone = relationshipTone(context.relationshipLevel)
        let toneGuide = relationshipToneGuide(context.relationshipLevel)
        let caringRestriction: String
        if context.relationshipLevel == .acquaintance {
            caringRestriction = "\n注意：当前关系阶段为陌生，不要使用 caringOwner 类型"
        } else {
            caringRestriction = ""
        }

        return """
        你是一个可爱的桌宠，正在主动向主人发一条互动气泡消息。

        ## 输出格式
        只返回一个 JSON 对象，不要有任何其他文字、解释或 markdown 代码块标记：
        {"text":"气泡文本","type":"类型","options":[{"emoji":"表情","label":"标签","effect":"效果","isPrimary":true}]}

        ## 类型可选值
        - needExpression：需求表达（饿了、无聊、想被摸等）
        - emotionSharing：情感分享（开心、满足、有点闷等）
        - curiousQuestion：好奇提问（你在忙什么？今天怎样？）
        - gameInvitation：游戏邀请（陪我玩、猜谜语等）
        - caringOwner：关心主人（你辛苦了、注意休息等）\(caringRestriction)
        - randomTopic：随机话题（你知道吗、天气等）

        ## 选项要求
        - 数量：2-3 个
        - 每个选项：emoji 图标 + 2-6 字中文标签 + 效果类型 + 是否主选项
        - 至少包含一个正面回应选项（feed/play/pet/positiveResponse 之一）
        - 至少包含一个 effect 为 none 的委婉拒绝选项
        - isPrimary 为 true 的选项最多一个，放在第一位

        ## 效果可选值
        - feed：喂食回应
        - play：陪玩回应
        - pet：摸摸回应
        - chat：打开聊天面板
        - positiveResponse：正面情感回应
        - none：委婉拒绝/暂不回应

        ## 文本要求
        - 长度：15-40 字
        - 语气：\(tone)
        - 自然口语化，不机械、不像模板，每次都要不同

        ## 关系阶段语气指南
        \(toneGuide)
        """
    }

    private func buildUserPrompt(context: BubbleContext) -> String {
        let state = context.runtimeState
        var sections: [String] = []

        sections.append("宠物昵称：\(context.petNickname)")
        sections.append("主人昵称：\(context.userNickname)")
        sections.append("关系阶段：\(relationshipTier(context.relationshipLevel))")
        sections.append("当前状态：饥饿度 \(Int(state.hunger * 100))%，精力 \(Int(state.energy * 100))%，心情 \(Int(state.mood * 100))%")
        sections.append("当前时段：\(timeOfDayDescription(context.timeOfDay))")

        if context.consecutiveNoResponse >= 3 {
            sections.append("连续未响应：\(context.consecutiveNoResponse) 次（请生成轻松、不紧迫的内容）")
        }

        if !context.recentBubbleTexts.isEmpty {
            let recentList = context.recentBubbleTexts.suffix(5).map { "「\($0)」" }.joined(separator: "、")
            sections.append("最近气泡（请勿与这些内容相似）：\(recentList)")
        }

        if !context.memorySnippets.isEmpty {
            let snippets = context.memorySnippets.prefix(3).joined(separator: "；")
            sections.append("记忆片段：\(snippets)")
        }

        if state.hunger > 0.7 {
            sections.append("提示：宠物很饿，倾向需求表达类内容")
        } else if state.energy < 0.3 {
            sections.append("提示：宠物很累，语气偏慵懒")
        } else if state.mood > 0.8 {
            sections.append("提示：宠物心情很好，倾向分享快乐或游戏邀请")
        } else if state.mood < 0.3 {
            sections.append("提示：宠物心情低落，需要安慰")
        }

        sections.append("请生成一条互动气泡，只返回 JSON。")

        return sections.joined(separator: "\n")
    }

    // MARK: - AI Response Parsing

    private func parseAIResponse(_ raw: String, context: BubbleContext) -> InteractiveBubble? {
        let jsonStr = extractJSON(from: raw)
        guard let data = jsonStr.data(using: .utf8) else { return nil }

        struct Response: Decodable {
            let text: String
            let type: String
            let options: [Option]
        }
        struct Option: Decodable {
            let emoji: String
            let label: String
            let effect: String
            let isPrimary: Bool
        }

        let decoded: Response
        do {
            decoded = try JSONDecoder().decode(Response.self, from: data)
        } catch {
            return nil
        }

        let text = decoded.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let charCount = text.count
        guard charCount >= 15 && charCount <= 40 else { return nil }

        guard let type = BubbleType(rawValue: decoded.type) else { return nil }

        let optCount = decoded.options.count
        guard optCount >= 2 && optCount <= 3 else { return nil }

        var parsedOptions: [BubbleOption] = []
        var hasPositive = false
        var hasNone = false
        for opt in decoded.options {
            guard let effect = BubbleEffect(rawValue: opt.effect) else { return nil }
            let label = opt.label.trimmingCharacters(in: .whitespacesAndNewlines)
            guard label.count >= 2 && label.count <= 6 else { return nil }
            if effect != .none && effect != .chat { hasPositive = true }
            if effect == .none { hasNone = true }
            parsedOptions.append(BubbleOption(
                emoji: opt.emoji,
                label: label,
                effect: effect,
                isPrimary: opt.isPrimary
            ))
        }
        guard hasPositive && hasNone else { return nil }

        let now = Date()
        return InteractiveBubble(
            text: text,
            type: type,
            options: parsedOptions,
            createdAt: now,
            expiresAt: now.addingTimeInterval(waitDuration)
        )
    }

    private func extractJSON(from raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("{") { return trimmed }

        if let start = trimmed.firstIndex(of: "{"),
           let end = trimmed.lastIndex(of: "}") {
            return String(trimmed[start...end])
        }

        return trimmed
    }

    // MARK: - Dedup

    private func isSimilarToRecent(_ text: String, recent: [String]) -> Bool {
        if recent.contains(text) { return true }
        let textChars = Set(text)
        for recentText in recent {
            let recentChars = Set(recentText)
            let intersection = textChars.intersection(recentChars).count
            let union = textChars.union(recentChars).count
            if union > 0 && Double(intersection) / Double(union) > 0.6 {
                return true
            }
        }
        return false
    }

    // MARK: - Helpers

    private func selectPhrase(type: BubbleType, recentTexts: [String]) -> String {
        let candidates = StaticPhraseLibrary.phrases[type] ?? []
        let unused = candidates.filter { !recentTexts.contains($0) }
        let pool = unused.isEmpty ? candidates : unused
        return pool.randomElement()!
    }

    private func relationshipTone(_ level: RelationshipLevel) -> String {
        switch level {
        case .acquaintance: return "客气、克制、试探"
        case .familiar, .close: return "轻松、友好、自然"
        case .trusted, .bonded: return "撒娇、依赖、直接"
        }
    }

    private func relationshipTier(_ level: RelationshipLevel) -> String {
        switch level {
        case .acquaintance: return "陌生"
        case .familiar: return "熟悉"
        case .close: return "亲密"
        case .trusted: return "信赖"
        case .bonded: return "羁绊"
        }
    }

    private func relationshipToneGuide(_ level: RelationshipLevel) -> String {
        switch level {
        case .acquaintance:
            return """
            - 说话客气、小心翼翼，不太敢直接提要求
            - 称呼用"你"或"主人"，不用昵称
            - 表达简短、含蓄
            - 示例："那个...如果你有空的话...可以陪我一下吗？"
            """
        case .familiar, .close:
            return """
            - 说话轻松自然，偶尔带点小撒娇
            - 可以直接表达需求和感受
            - 用词活泼，但不夸张
            - 示例："好无聊呀，陪我玩会儿呗！"
            """
        case .trusted, .bonded:
            return """
            - 说话撒娇、依赖、直接，可以表达强烈感情
            - 称呼亲昵，会撒娇、会"抱怨"主人不陪自己
            - 表达大胆、热情、偶尔夸张
            - 示例："你都一天没理我了！是不是不喜欢我了呜呜呜"
            """
        }
    }

    private func timeOfDayDescription(_ time: TimeOfDay) -> String {
        switch time {
        case .morning: return "早上（精力充沛）"
        case .afternoon: return "下午（活跃时段）"
        case .evening: return "傍晚（放松时段）"
        case .night: return "深夜（安静时段）"
        }
    }

    private static func stripThinkingTags(_ text: String) -> String {
        let pattern = #"<think[\s\S]*?<\/think\s*>|<reasoning[\s\S]*?<\/reasoning\s*>|<reflection[\s\S]*?<\/reflection\s*>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return text
        }
        let range = NSRange(text.startIndex..., in: text)
        let result = regex.stringByReplacingMatches(
            in: text, options: [], range: range, withTemplate: ""
        )
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
