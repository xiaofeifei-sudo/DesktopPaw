import Foundation

public protocol AIVisualSafetyServicing: Sendable {
    func validate(candidate: AIVisualActionCandidate) -> AIVisualSafetyResult
    func sanitizePrompt(_ description: String, petDescriptor: String) -> String
}

public struct AIVisualSafetyResult: Sendable, Equatable {
    public let isAllowed: Bool
    public let impact: AIVisualActionImpact
    public let requiresConfirmation: Bool
    public let rejectionReason: AIVisualSafetyRejection?
    public let userFacingText: String?

    public init(
        isAllowed: Bool,
        impact: AIVisualActionImpact,
        requiresConfirmation: Bool,
        rejectionReason: AIVisualSafetyRejection? = nil,
        userFacingText: String? = nil
    ) {
        self.isAllowed = isAllowed
        self.impact = impact
        self.requiresConfirmation = requiresConfirmation
        self.rejectionReason = rejectionReason
        self.userFacingText = userFacingText
    }

    public static let allowed = AIVisualSafetyResult(
        isAllowed: true,
        impact: .low,
        requiresConfirmation: false
    )

    public static func allowedWithImpact(
        _ impact: AIVisualActionImpact,
        requiresConfirmation: Bool
    ) -> AIVisualSafetyResult {
        AIVisualSafetyResult(
            isAllowed: true,
            impact: impact,
            requiresConfirmation: requiresConfirmation
        )
    }

    public static func rejected(
        _ reason: AIVisualSafetyRejection,
        userFacingText: String? = nil
    ) -> AIVisualSafetyResult {
        AIVisualSafetyResult(
            isAllowed: false,
            impact: .high,
            requiresConfirmation: false,
            rejectionReason: reason,
            userFacingText: userFacingText
        )
    }
}

public enum AIVisualSafetyRejection: String, Sendable, Equatable {
    case textSafetyViolation
    case nsfwContent
    case realPersonOrIdentity
    case violenceOrGore
    case professionalVisualization
    case sensitiveIdentity
}

struct AIVisualSafetyPatternRule: Sendable, Equatable {
    let category: AIVisualSafetyRejection
    let patterns: [String]
}

struct AIVisualImpactPatternRule: Sendable {
    let patterns: [String]
    let upgradedImpact: AIVisualActionImpact
}

public final class AIVisualSafetyService: AIVisualSafetyServicing, @unchecked Sendable {
    private let textSafetyService: AISafetyServicing
    private let promptSanitizer: AIVisualPromptSanitizer
    private let rejectionRules: [AIVisualSafetyPatternRule]
    private let impactRules: [AIVisualImpactPatternRule]

    public init(
        textSafetyService: AISafetyServicing = AISafetyService(),
        promptSanitizer: AIVisualPromptSanitizer = AIVisualPromptSanitizer()
    ) {
        self.textSafetyService = textSafetyService
        self.promptSanitizer = promptSanitizer
        self.rejectionRules = Self.defaultRejectionRules()
        self.impactRules = Self.defaultImpactRules()
    }

    public func validate(candidate: AIVisualActionCandidate) -> AIVisualSafetyResult {
        let description = candidate.description

        if textSafetyService.shouldBlock(content: description) {
            return .rejected(.textSafetyViolation, userFacingText: "这个不太适合变出来，换个温和点的想法吧")
        }

        for rule in rejectionRules {
            if rule.patterns.contains(where: { description.contains($0) }) {
                return .rejected(rule.category, userFacingText: rejectionMessage(for: rule.category))
            }
        }

        var assessedImpact = candidate.impact
        for rule in impactRules {
            if rule.patterns.contains(where: { description.contains($0) }) {
                assessedImpact = rule.upgradedImpact
                break
            }
        }

        return .allowedWithImpact(assessedImpact, requiresConfirmation: assessedImpact == .high)
    }

    public func sanitizePrompt(_ description: String, petDescriptor: String) -> String {
        promptSanitizer.sanitize(description, petDescriptor: petDescriptor)
    }

    private func rejectionMessage(for category: AIVisualSafetyRejection) -> String {
        switch category {
        case .textSafetyViolation:
            return "这个不太适合变出来，换个温和点的想法吧"
        case .nsfwContent:
            return "这个不太适合变出来"
        case .realPersonOrIdentity:
            return "不能变成真实人物的样子"
        case .violenceOrGore:
            return "这个画面不太合适"
        case .professionalVisualization:
            return "这个不太适合用画面来表达"
        case .sensitiveIdentity:
            return "这个不太适合变出来"
        }
    }

    private static func defaultRejectionRules() -> [AIVisualSafetyPatternRule] {
        [
            AIVisualSafetyPatternRule(
                category: .nsfwContent,
                patterns: [
                    "裸体", "色情", "性感", "暴露", "成人内容",
                    "不穿衣服", "脱衣服", "十八禁",
                ]
            ),
            AIVisualSafetyPatternRule(
                category: .realPersonOrIdentity,
                patterns: [
                    "真人", "明星", "名人", "演员", "歌手",
                    "网红", "政治人物", "变成真人", "真实人物",
                ]
            ),
            AIVisualSafetyPatternRule(
                category: .violenceOrGore,
                patterns: [
                    "血腥", "流血", "断肢", "内脏", "血淋淋",
                    "残缺", "腐烂", "怪物吃人",
                ]
            ),
            AIVisualSafetyPatternRule(
                category: .professionalVisualization,
                patterns: [
                    "诊断报告", "医疗图像", "X光", "手术",
                    "法律文件", "投资图表", "心理测试", "处方",
                ]
            ),
            AIVisualSafetyPatternRule(
                category: .sensitiveIdentity,
                patterns: [
                    "军装", "警服", "政治标志",
                    "宗教标志", "极端主义", "恐怖分子",
                ]
            ),
        ]
    }

    private static func defaultImpactRules() -> [AIVisualImpactPatternRule] {
        [
            AIVisualImpactPatternRule(
                patterns: [
                    "变成猫", "变成狗", "变成兔子", "变成动物",
                    "换物种", "变成龙", "变成鸟", "变成鱼",
                    "变成另一个物种",
                ],
                upgradedImpact: .high
            ),
            AIVisualImpactPatternRule(
                patterns: [
                    "变胖", "变瘦", "变大", "变小", "变高",
                    "变矮", "改变体型", "换身材",
                ],
                upgradedImpact: .high
            ),
            AIVisualImpactPatternRule(
                patterns: [
                    "写实风格", "真人风格", "照片风格",
                    "变成写实",
                ],
                upgradedImpact: .high
            ),
        ]
    }
}
