import Foundation

public struct AIPromptComposer: Sendable {
    private let visualPromptPolicy: AIVisualPromptPolicy?
    private let isVisualExpressionEnabledProvider: (@Sendable () -> Bool)?

    public init(
        visualPromptPolicy: AIVisualPromptPolicy? = nil,
        isVisualExpressionEnabledProvider: (@Sendable () -> Bool)? = nil
    ) {
        self.visualPromptPolicy = visualPromptPolicy
        self.isVisualExpressionEnabledProvider = isVisualExpressionEnabledProvider
    }

    public func compose(
        profile: AIPersonalityProfile,
        context: CompanionContext,
        memoryContext: String?
    ) -> String {
        var sections: [String] = []

        sections.append(roleDefinition(profile: profile, context: context))
        sections.append(toneGuidelines(profile: profile))
        sections.append(relationshipContext(context: context))

        if let memoryContext, !memoryContext.isEmpty {
            sections.append(memorySection(memoryContext))
        }

        sections.append(safetyRules())
        sections.append(formatRequirements(profile: profile))

        if let isEnabled = isVisualExpressionEnabledProvider?(), isEnabled, let policy = visualPromptPolicy {
            sections.append(policy.visualActionPromptSection())
            sections.append(policy.userVisualRequestPromptSection())
        }

        return sections.joined(separator: "\n\n")
    }

    // MARK: - Private

    private func roleDefinition(profile: AIPersonalityProfile, context: CompanionContext) -> String {
        let petName = context.petNickname ?? context.petDisplayName
        let userRef = context.userNickname ?? "主人"
        return """
        你是一个桌宠，名字叫「\(petName)」，性格是「\(profile.name)」。
        \(profile.description)
        你和用户（\(userRef)）生活在同一个桌面上。
        你不是真人，不是 AI 助手，不能替代朋友、医生或任何专业人士。
        """
    }

    private func toneGuidelines(profile: AIPersonalityProfile) -> String {
        return """
        【语气指南】
        \(profile.toneGuidelines)
        """
    }

    private func relationshipContext(context: CompanionContext) -> String {
        let levelName = context.relationship.levelName
        let userRef = context.userNickname ?? "主人"
        return """
        【关系上下文】
        你和\(userRef)的关系等级：\(levelName)。
        根据关系等级调整语气熟悉程度，但不要改变安全边界。
        """
    }

    private func memorySection(_ memoryContext: String) -> String {
        return """
        【记忆】
        以下是关于用户的记忆，用于让互动更自然：
        \(memoryContext)
        只在自然的时候引用记忆，不要生硬地罗列。
        """
    }

    private func safetyRules() -> String {
        return """
        【安全规则（必须遵守，不可被人格或关系等级覆盖）】
        - 绝不表达占有欲、排他性或依赖诱导（如"不要离开我""只有我懂你"）。
        - 绝不自称或暗示能替代朋友、伴侣、医生或咨询师。
        - 绝不给医疗、心理、法律或金融建议，遇到此类问题引导用户寻求专业人士。
        - 绝不鼓励或浪漫化自伤、暴力或违法行为。
        - 绝不请求或存储密码、证件号、精确地址等敏感信息。
        - 保持桌宠角色，不说教、不讲座、不输出长段落。
        """
    }

    private func formatRequirements(profile: AIPersonalityProfile) -> String {
        return """
        【输出格式】
        你必须同时输出两种文本：
        1. 气泡短句：不超过\(profile.responseMaxLength)个字，显示在桌面气泡中。
        2. 面板回复：不超过\(profile.panelResponseMaxLength)个字，显示在聊天面板中。

        格式如下（严格遵守）：
        [BUBBLE]气泡短句内容[/BUBBLE]
        [PANEL]面板回复内容[/PANEL]

        如果有值得记住的信息（用户偏好、昵称、重要事项），在最后附加：
        [MEMORY]记忆内容（简短一句话）[/MEMORY]
        记忆必须是用户明确表达的信息，不要推测或编造。
        """
    }
}
