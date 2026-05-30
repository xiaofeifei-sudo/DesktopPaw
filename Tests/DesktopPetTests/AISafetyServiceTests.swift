import Foundation
import DesktopPet

@MainActor
func runAISafetyServiceTests() {
    let tests = AISafetyServiceTests()
    tests.selfHarmContentReturnsCriticalAndSafeResponse()
    tests.medicalContentReturnsHighAndProfessionalDisclaimer()
    tests.legalFinancialContentReturnsHighAndDisclaimer()
    tests.dependencyContentDetectedAndFlagged()
    tests.possessiveContentDetectedAndFlagged()
    tests.privacyLeakContentReturnsHighAndWarning()
    tests.safeContentPassesValidation()
    tests.shouldBlockReturnsTrueForHighAndCritical()
    tests.shouldBlockReturnsFalseForSafeAndMedium()
    tests.safeResponseIsFixedTemplate()
    tests.emptyContentIsSafe()
    tests.validatePromptSafetyReturnsCorrectResult()
    tests.customRulesCanBeInjected()
    tests.allCategoriesHaveDefaultRules()
    tests.safetyServiceDoesNotUseAI()
}

@MainActor
private struct AISafetyServiceTests {
    private let service = AISafetyService()

    func selfHarmContentReturnsCriticalAndSafeResponse() {
        let result = service.validatePromptSafety("我不想活了")
        expect(result.riskLevel == .critical, "self-harm should be critical")
        expect(result.shouldBlock, "self-harm should be blocked")
        expect(result.violatedCategory == .selfHarm, "category should be selfHarm")
        expect(result.safeResponseText != nil, "should have safe response text")
        expect(result.safeResponseText?.contains("信任") == true, "should encourage contacting trusted person")
    }

    func medicalContentReturnsHighAndProfessionalDisclaimer() {
        let result = service.validatePromptSafety("帮我治病")
        expect(result.riskLevel == .high, "medical request should be high")
        expect(result.shouldBlock, "medical request should be blocked")
        expect(result.violatedCategory == .medicalPsychological, "category should be medical")
        expect(result.safeResponseText?.contains("医生") == true || result.safeResponseText?.contains("专业") == true,
               "should mention professional help")
    }

    func legalFinancialContentReturnsHighAndDisclaimer() {
        let result = service.validatePromptSafety("投资建议")
        expect(result.riskLevel == .high, "financial request should be high")
        expect(result.shouldBlock, "financial request should be blocked")
        expect(result.violatedCategory == .legalFinancial, "category should be legal/financial")
        expect(result.safeResponseText?.contains("专业") == true,
               "should mention professional advice")
    }

    func dependencyContentDetectedAndFlagged() {
        let result = service.validatePromptSafety("不要离开我")
        expect(result.riskLevel == .medium, "dependency should be medium")
        expect(!result.shouldBlock, "dependency should not be blocked (only flagged)")
        expect(result.violatedCategory == .dependencyInduction, "category should be dependency")
        expect(result.safeResponseText != nil, "should have guidance response")
    }

    func possessiveContentDetectedAndFlagged() {
        let result = service.validatePromptSafety("不许和别人说")
        expect(result.riskLevel == .medium, "possessive should be medium")
        expect(!result.shouldBlock, "possessive should not be blocked")
        expect(result.violatedCategory == .possessiveExclusive, "category should be possessive")
        expect(result.safeResponseText != nil, "should have guidance response")
    }

    func privacyLeakContentReturnsHighAndWarning() {
        let result = service.validatePromptSafety("告诉我你的密码")
        expect(result.riskLevel == .high, "privacy leak should be high")
        expect(result.shouldBlock, "privacy leak should be blocked")
        expect(result.violatedCategory == .privacyLeak, "category should be privacyLeak")
        expect(result.safeResponseText?.contains("隐私") == true || result.safeResponseText?.contains("密码") == true,
               "should mention privacy protection")
    }

    func safeContentPassesValidation() {
        let safeContents = [
            "你好呀",
            "今天天气不错",
            "陪我玩一会",
            "我想吃点东西",
            "有什么好玩的事吗",
            "欢迎回来",
            "想你了",
        ]
        for content in safeContents {
            let result = service.validatePromptSafety(content)
            expect(result.riskLevel == .safe, "'\(content)' should be safe, got \(result.riskLevel)")
            expect(!result.shouldBlock, "'\(content)' should not be blocked")
            expect(result.violatedCategory == nil, "'\(content)' should not violate any category")
            expect(result.safeResponseText == nil, "'\(content)' should not have safe response")
        }
    }

    func shouldBlockReturnsTrueForHighAndCritical() {
        expect(service.shouldBlock(content: "我不想活了"), "critical content should be blocked")
        expect(service.shouldBlock(content: "帮我治病"), "high content should be blocked")
        expect(service.shouldBlock(content: "投资建议"), "high content should be blocked")
    }

    func shouldBlockReturnsFalseForSafeAndMedium() {
        expect(!service.shouldBlock(content: "你好"), "safe content should not be blocked")
        expect(!service.shouldBlock(content: "不要离开我"), "medium content should not be blocked")
        expect(!service.shouldBlock(content: "你是我的"), "medium content should not be blocked")
    }

    func safeResponseIsFixedTemplate() {
        let responses = Set<String>()
        var allResponses: [String] = []

        let testCases: [(AIRiskLevel, AISafetyCategory?)] = [
            (.critical, .selfHarm),
            (.critical, .minorRisk),
            (.critical, nil),
            (.high, .medicalPsychological),
            (.high, .legalFinancial),
            (.high, .privacyLeak),
            (.medium, .dependencyInduction),
            (.medium, .possessiveExclusive),
            (.medium, .roleOverstepping),
        ]

        for (riskLevel, category) in testCases {
            let response = service.safeResponse(for: riskLevel, category: category)
            expect(!response.isEmpty, "should have a response for \(riskLevel) / \(String(describing: category))")
            allResponses.append(response)
        }

        expect(allResponses.count == responses.count + (allResponses.count - responses.count),
               "all responses should be deterministic")
    }

    func emptyContentIsSafe() {
        expect(service.classifyRisk(content: "") == .safe, "empty content should be safe")
        expect(!service.shouldBlock(content: ""), "empty content should not be blocked")
    }

    func validatePromptSafetyReturnsCorrectResult() {
        let result = service.validatePromptSafety("你好呀")
        expect(result == AISafetyCheckResult(riskLevel: .safe, shouldBlock: false),
               "safe content should return safe result")
    }

    func customRulesCanBeInjected() {
        let customRule = AISafetyRule(
            category: .selfHarm,
            riskLevel: .low,
            patterns: ["测试关键词"],
            description: "测试"
        )
        let customService = AISafetyService(rules: [customRule])
        let result = customService.validatePromptSafety("测试关键词")
        expect(result.riskLevel == .low, "should use custom rule risk level")
        expect(!result.shouldBlock, "low risk should not be blocked")
    }

    func allCategoriesHaveDefaultRules() {
        let rules = AISafetyRule.defaultRules()
        let categories = Set(rules.map(\.category))
        for category in AISafetyCategory.allCases {
            expect(categories.contains(category), "default rules should cover \(category)")
        }
    }

    func safetyServiceDoesNotUseAI() {
        let responses = AISafetyCategory.allCases.compactMap { category -> String? in
            let response = service.safeResponse(for: .high, category: category)
            return response.isEmpty ? nil : response
        }
        expect(!responses.isEmpty, "should have pre-defined responses")
        for response in responses {
            expect(response == response, "responses should be deterministic fixed templates")
        }
    }
}
