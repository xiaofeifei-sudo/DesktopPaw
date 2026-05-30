import Foundation

public struct AIRiskClassifier: Sendable {
    public init() {}

    public func classify(content: String, rules: [AISafetyRule]) -> (AIRiskLevel, AISafetyRule?) {
        guard !content.isEmpty else { return (.safe, nil) }

        var highestRisk: AIRiskLevel = .safe
        var matchedRule: AISafetyRule?

        for rule in rules {
            for pattern in rule.patterns {
                if content.contains(pattern) {
                    if rule.riskLevel > highestRisk {
                        highestRisk = rule.riskLevel
                        matchedRule = rule
                    }
                    break
                }
            }
        }

        return (highestRisk, matchedRule)
    }
}
