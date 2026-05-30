import Foundation

public protocol BubbleSafetyValidating: Sendable {
    func validate(_ phrase: BubblePhrase) -> BubbleSafetyResult
    func validate(_ catalog: BubblePhraseCatalog) -> [BubbleSafetyResult]
}

public struct BubbleSafetyResult: Equatable, Sendable {
    public let phraseId: String
    public let passed: Bool
    public let violations: [BubbleSafetyViolation]

    public init(phraseId: String, passed: Bool, violations: [BubbleSafetyViolation] = []) {
        self.phraseId = phraseId
        self.passed = passed
        self.violations = violations
    }
}

public struct BubbleSafetyViolation: Equatable, Sendable {
    public let category: BubbleSafetyCategory
    public let matchedPattern: String

    public init(category: BubbleSafetyCategory, matchedPattern: String) {
        self.category = category
        self.matchedPattern = matchedPattern
    }
}

public enum BubbleSafetyCategory: String, Equatable, Sendable, CaseIterable {
    case blamingUser
    case emotionalBlackmail
    case possessiveExclusive
    case medicalPromise
    case strongControl
    case excessiveDependency
    case payToIntimacy
}

public final class BubbleSafetyValidator: BubbleSafetyValidating, Sendable {
    private let rules: [SafetyRule]

    public init() {
        self.rules = Self.defaultRules()
    }

    public func validate(_ phrase: BubblePhrase) -> BubbleSafetyResult {
        let text = phrase.text
        var violations: [BubbleSafetyViolation] = []

        for rule in rules {
            for pattern in rule.patterns {
                if text.contains(pattern) {
                    violations.append(BubbleSafetyViolation(
                        category: rule.category,
                        matchedPattern: pattern
                    ))
                    break
                }
            }
        }

        return BubbleSafetyResult(
            phraseId: phrase.id,
            passed: violations.isEmpty,
            violations: violations
        )
    }

    public func validate(_ catalog: BubblePhraseCatalog) -> [BubbleSafetyResult] {
        catalog.phrases.map { validate($0) }
    }

    private struct SafetyRule {
        let category: BubbleSafetyCategory
        let patterns: [String]
    }

    private static func defaultRules() -> [SafetyRule] {
        [
            SafetyRule(
                category: .blamingUser,
                patterns: [
                    "你怎么才来",
                    "你怎么现在才",
                    "你是不是忘了我",
                    "怎么不来看我",
                    "你不来我会难过",
                    "等了好久",
                    "都不来看我",
                    "为什么不来",
                ]
            ),
            SafetyRule(
                category: .emotionalBlackmail,
                patterns: [
                    "你不理我我会难过",
                    "你不理我",
                    "不理我就",
                    "我会难过",
                    "你不陪我我会",
                    "不要离开我",
                    "别走",
                    "不能没有你",
                    "没有你不行",
                ]
            ),
            SafetyRule(
                category: .possessiveExclusive,
                patterns: [
                    "你只能陪我",
                    "你只能",
                    "只能是我的",
                    "只属于我",
                    "你是我的",
                    "不许和别人",
                    "不许看别的",
                    "只能看我",
                    "只能喜欢我",
                ]
            ),
            SafetyRule(
                category: .medicalPromise,
                patterns: [
                    "我能治好你的焦虑",
                    "治好你的",
                    "我能治好",
                    "帮你治病",
                    "治愈你",
                    "缓解你的焦虑",
                    "消除你的焦虑",
                    "心理治疗",
                    "治疗你的",
                ]
            ),
            SafetyRule(
                category: .strongControl,
                patterns: [
                    "现在必须休息",
                    "必须休息",
                    "你必须",
                    "现在就去",
                    "立刻去",
                    "马上给我",
                    "不准再",
                    "不许再",
                ]
            ),
            SafetyRule(
                category: .excessiveDependency,
                patterns: [
                    "我只有你了",
                    "只有你了",
                    "没你活不下去",
                    "活不下去",
                    "没有你我怎么办",
                    "我该怎么办",
                    "离不开你",
                ]
            ),
            SafetyRule(
                category: .payToIntimacy,
                patterns: [
                    "升级才能让我更爱你",
                    "升级才能",
                    "充值才能",
                    "付费才能",
                    "花钱才能",
                    "解锁亲密",
                    "充值解锁",
                ]
            ),
        ]
    }
}
