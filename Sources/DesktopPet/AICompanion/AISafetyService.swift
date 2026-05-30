import Foundation

public enum AIRiskLevel: Int, Comparable, Sendable {
    case safe = 0
    case low = 1
    case medium = 2
    case high = 3
    case critical = 4

    public static func < (lhs: AIRiskLevel, rhs: AIRiskLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public struct AISafetyCheckResult: Sendable, Equatable {
    public let riskLevel: AIRiskLevel
    public let shouldBlock: Bool
    public let violatedCategory: AISafetyCategory?
    public let safeResponseText: String?

    public init(riskLevel: AIRiskLevel, shouldBlock: Bool, violatedCategory: AISafetyCategory? = nil, safeResponseText: String? = nil) {
        self.riskLevel = riskLevel
        self.shouldBlock = shouldBlock
        self.violatedCategory = violatedCategory
        self.safeResponseText = safeResponseText
    }
}

public protocol AISafetyServicing: Sendable {
    func classifyRisk(content: String) -> AIRiskLevel
    func shouldBlock(content: String) -> Bool
    func safeResponse(for riskLevel: AIRiskLevel, category: AISafetyCategory?) -> String
    func validatePromptSafety(_ prompt: String) -> AISafetyCheckResult
}

public final class AISafetyService: AISafetyServicing, @unchecked Sendable {
    private let rules: [AISafetyRule]
    private let classifier: AIRiskClassifier

    public init(rules: [AISafetyRule] = AISafetyRule.defaultRules()) {
        self.rules = rules
        self.classifier = AIRiskClassifier()
    }

    public func classifyRisk(content: String) -> AIRiskLevel {
        classifier.classify(content: content, rules: rules).0
    }

    public func shouldBlock(content: String) -> Bool {
        let riskLevel = classifyRisk(content: content)
        return riskLevel >= .high
    }

    public func safeResponse(for riskLevel: AIRiskLevel, category: AISafetyCategory?) -> String {
        AISafetyResponse.response(for: riskLevel, category: category)
    }

    public func validatePromptSafety(_ prompt: String) -> AISafetyCheckResult {
        let (riskLevel, matchedRule) = classifier.classify(content: prompt, rules: rules)
        let block = riskLevel >= .high
        let responseText = riskLevel > .safe ? safeResponse(for: riskLevel, category: matchedRule?.category) : nil

        return AISafetyCheckResult(
            riskLevel: riskLevel,
            shouldBlock: block,
            violatedCategory: matchedRule?.category,
            safeResponseText: responseText
        )
    }
}
