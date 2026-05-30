import Foundation

public protocol AIPersonalityEngineProtocol: Sendable {
    func buildSystemPrompt(
        profile: AIPersonalityProfile,
        context: CompanionContext,
        memoryContext: String?
    ) -> String

    func validateResponseStyle(
        _ response: String,
        profile: AIPersonalityProfile
    ) -> AIStyleCheckResult
}

public final class AIPersonalityEngine: AIPersonalityEngineProtocol, @unchecked Sendable {
    private let composer: AIPromptComposer

    public init(composer: AIPromptComposer = AIPromptComposer()) {
        self.composer = composer
    }

    public func buildSystemPrompt(
        profile: AIPersonalityProfile,
        context: CompanionContext,
        memoryContext: String?
    ) -> String {
        return composer.compose(profile: profile, context: context, memoryContext: memoryContext)
    }

    public func validateResponseStyle(
        _ response: String,
        profile: AIPersonalityProfile
    ) -> AIStyleCheckResult {
        var violations: [String] = []

        let bubbleText = Self.extractTag(response, tag: "BUBBLE")
        let panelText = Self.extractTag(response, tag: "PANEL")

        if let bubble = bubbleText {
            let charCount = bubble.count
            if charCount > profile.responseMaxLength {
                violations.append("气泡文本\(charCount)字超过限制\(profile.responseMaxLength)字")
            }
        }

        if let panel = panelText {
            let charCount = panel.count
            if charCount > profile.panelResponseMaxLength {
                violations.append("面板文本\(charCount)字超过限制\(profile.panelResponseMaxLength)字")
            }
        }

        return AIStyleCheckResult(isValid: violations.isEmpty, violations: violations)
    }

    public static func parseBubbleText(from response: String) -> String? {
        return extractTag(response, tag: "BUBBLE")?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public static func parsePanelText(from response: String) -> String? {
        return extractTag(response, tag: "PANEL")?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public static func parseMemoryUpdate(from response: String) -> String? {
        return extractTag(response, tag: "MEMORY")?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Private

    private static func extractTag(_ text: String, tag: String) -> String? {
        let openTag = "[\(tag)]"
        let closeTag = "[/\(tag)]"
        guard let openRange = text.range(of: openTag),
              let closeRange = text.range(of: closeTag, range: openRange.upperBound..<text.endIndex)
        else { return nil }
        return String(text[openRange.upperBound..<closeRange.lowerBound])
    }
}
