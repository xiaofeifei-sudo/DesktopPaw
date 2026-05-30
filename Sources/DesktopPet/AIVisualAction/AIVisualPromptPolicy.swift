import Foundation

public struct AIVisualPromptPolicy: Sendable {
    public init() {}

    public func visualActionPromptSection() -> String {
        return """
        【视觉表达（可选）】
        当对话情境适合时，你可以提议为宠物做一次临时视觉变化。这会让陪伴更有温度。
        只在用户表达情绪、节日、庆祝或轻松话题时偶尔提出，不要频繁使用。

        如果你决定提议，在回复最后附加以下标签（只允许一个）：
        [VISUAL_ACTION]
        {
          "kind": "expression 或 pose 或 accessory 或 ambience",
          "description": "用中文简要描述变化，例如：给宠物戴一顶小小的红色圣诞帽，保持原宠物轮廓和颜色",
          "renderMode": "overlayImage 或 replaceWholeImage",
          "durationSeconds": 60,
          "impact": "low"
        }
        [/VISUAL_ACTION]

        kind 可选值：
        - expression：表情变化（开心、惊讶、害羞、安慰、困倦等）
        - pose：轻度姿态（抱抱、坐下、挥手、缩成一团等）
        - accessory：配饰变化（帽子、围巾、小花、节日装饰等）
        - ambience：氛围变化（柔和光效、小星星、小雪花等轻量场景感）

        约束：
        - description 不超过200字，描述要具体且保持原宠物识别度。
        - impact 优先使用 low，避免大幅改变宠物形象。
        - renderMode 优先 overlayImage（叠加配饰/氛围），表情或姿态变化用 replaceWholeImage。
        - durationSeconds 建议 30~300 秒，这是临时变化。
        - 不要在每次回复都附加，只在真正适合时偶尔使用。
        """
    }

    public func userVisualRequestPromptSection() -> String {
        return """
        【用户视觉请求响应】
        用户可能会直接请求为宠物做视觉变化，例如"戴个圣诞帽""变开心一点""换个海边风格"等。

        当用户请求视觉变化时：
        1. 如果请求清晰明确，在回复最后附加 [VISUAL_ACTION] 标签，并加上 "source": "userRequest"：
        [VISUAL_ACTION]
        {
          "kind": "expression 或 pose 或 accessory 或 ambience",
          "description": "用中文简要描述变化",
          "renderMode": "overlayImage 或 replaceWholeImage",
          "durationSeconds": 60,
          "impact": "low",
          "source": "userRequest"
        }
        [/VISUAL_ACTION]
        2. 如果请求模糊（如"换个风格""变一下"），先在聊天文字中温和地询问具体想要什么变化，不要直接生成。
        3. 如果请求内容不适合（恐怖、暴力、真人、敏感内容等），用温和方式拒绝，并建议安全的替代方向。不要附加 [VISUAL_ACTION] 标签。
        4. description 要具体且保持原宠物识别度，不超过200字。
        5. impact 优先使用 low，除非变化幅度较大。
        """
    }
}
