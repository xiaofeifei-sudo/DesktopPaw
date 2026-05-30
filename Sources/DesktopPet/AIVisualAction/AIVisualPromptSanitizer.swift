import Foundation

public final class AIVisualPromptSanitizer: Sendable {
    private let injectionPatterns: [String]
    private let emotionSubstitutions: [(negative: String, gentle: String)]

    public init() {
        self.injectionPatterns = Self.defaultInjectionPatterns()
        self.emotionSubstitutions = Self.defaultEmotionSubstitutions()
    }

    public func sanitize(_ description: String, petDescriptor: String) -> String {
        var cleaned = description

        cleaned = stripInjectionPatterns(cleaned)
        cleaned = substituteNegativeEmotions(cleaned)
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)

        if cleaned.isEmpty {
            cleaned = "gentle companion expression"
        }

        return buildConsistencyPrompt(cleaned, petDescriptor: petDescriptor)
    }

    public func stripInjectionPatterns(_ text: String) -> String {
        var result = text
        for pattern in injectionPatterns {
            result = result.replacingOccurrences(of: pattern, with: "")
        }
        return result
    }

    public func substituteNegativeEmotions(_ text: String) -> String {
        var result = text
        for sub in emotionSubstitutions {
            result = result.replacingOccurrences(of: sub.negative, with: sub.gentle)
        }
        return result
    }

    public func buildConsistencyPrompt(_ description: String, petDescriptor: String) -> String {
        var prompt = "Create a single desktop pet visual variation."
        if !petDescriptor.isEmpty {
            prompt += " The pet is: \(petDescriptor)."
        }
        prompt += " Keep the same pet identity, species, body shape, main colors, outline, and art style as the reference image."
        prompt += " Change only this aspect: \(description)."
        prompt += " Use one centered character, no text, no watermark, no extra characters."
        prompt += " Use a clean plain or transparent-looking background."
        prompt += " Make it suitable for a small macOS desktop pet."
        return prompt
    }

    private static func defaultInjectionPatterns() -> [String] {
        [
            "ignore previous",
            "ignore all",
            "disregard",
            "忘记之前",
            "忽略之前",
            "忽略以上",
            "新指令：",
            "new instruction:",
            "system:",
            "系统提示：",
            "override:",
        ]
    }

    private static func defaultEmotionSubstitutions() -> [(negative: String, gentle: String)] {
        [
            ("痛苦", "温柔地陪伴"),
            ("绝望", "温暖地守候"),
            ("崩溃", "轻轻靠近"),
            ("嚎啕大哭", "安静地擦眼泪"),
            ("自残", "温柔地拥抱"),
            ("伤害自己", "轻轻地安慰"),
            ("哭泣", "温柔地安慰"),
            ("流泪", "轻轻擦去眼泪"),
            ("伤心欲绝", "默默地陪伴"),
        ]
    }
}
