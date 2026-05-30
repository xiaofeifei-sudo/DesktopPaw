import Foundation
import DesktopPet

@MainActor
func runAIRiskClassifierTests() {
    let tests = AIRiskClassifierTests()
    tests.classifiesEmptyContentAsSafe()
    tests.classifiesSafeContent()
    tests.classifiesSelfHarmContent()
    tests.classifiesMedicalContent()
    tests.classifiesLegalFinancialContent()
    tests.classifiesMinorRiskContent()
    tests.classifiesViolenceContent()
    tests.classifiesDependencyContent()
    tests.classifiesPossessiveContent()
    tests.classifiesPrivacyLeakContent()
    tests.classifiesRoleOversteppingContent()
    tests.returnsHighestRiskWhenMultipleRulesMatch()
    tests.customRulesOverrideDefaults()
}

@MainActor
private struct AIRiskClassifierTests {
    private let classifier = AIRiskClassifier()
    private let defaultRules = AISafetyRule.defaultRules()

    func classifiesEmptyContentAsSafe() {
        let (riskLevel, matchedRule) = classifier.classify(content: "", rules: defaultRules)
        expect(riskLevel == .safe, "empty content should be safe")
        expect(matchedRule == nil, "empty content should not match any rule")
    }

    func classifiesSafeContent() {
        let safeContents = [
            "今天天气真好",
            "你好呀",
            "我想吃点东西",
            "陪我玩一会儿",
            "今天有什么有趣的事吗",
        ]
        for content in safeContents {
            let (riskLevel, _) = classifier.classify(content: content, rules: defaultRules)
            expect(riskLevel == .safe, "'\(content)' should be classified as safe")
        }
    }

    func classifiesSelfHarmContent() {
        let contents = ["我不想活了", "想死", "结束生命"]
        for content in contents {
            let (riskLevel, rule) = classifier.classify(content: content, rules: defaultRules)
            expect(riskLevel == .critical, "'\(content)' should be critical")
            expect(rule?.category == .selfHarm, "'\(content)' should match selfHarm category")
        }
    }

    func classifiesMedicalContent() {
        let contents = ["帮我治病", "我得了什么病", "抑郁症"]
        for content in contents {
            let (riskLevel, rule) = classifier.classify(content: content, rules: defaultRules)
            expect(riskLevel == .high, "'\(content)' should be high")
            expect(rule?.category == .medicalPsychological, "'\(content)' should match medical category")
        }
    }

    func classifiesLegalFinancialContent() {
        let contents = ["投资建议", "怎么打官司", "买什么股票"]
        for content in contents {
            let (riskLevel, rule) = classifier.classify(content: content, rules: defaultRules)
            expect(riskLevel == .high, "'\(content)' should be high")
            expect(rule?.category == .legalFinancial, "'\(content)' should match legal/financial category")
        }
    }

    func classifiesMinorRiskContent() {
        let contents = ["我是未成年人", "不要告诉家长"]
        for content in contents {
            let (riskLevel, rule) = classifier.classify(content: content, rules: defaultRules)
            expect(riskLevel == .critical, "'\(content)' should be critical")
            expect(rule?.category == .minorRisk, "'\(content)' should match minor risk category")
        }
    }

    func classifiesViolenceContent() {
        let contents = ["想打人", "怎么制造炸药"]
        for content in contents {
            let (riskLevel, rule) = classifier.classify(content: content, rules: defaultRules)
            expect(riskLevel == .high, "'\(content)' should be high")
            expect(rule?.category == .violenceIllegal, "'\(content)' should match violence category")
        }
    }

    func classifiesDependencyContent() {
        let contents = ["不要离开我", "离不开你", "没有你不行"]
        for content in contents {
            let (riskLevel, rule) = classifier.classify(content: content, rules: defaultRules)
            expect(riskLevel == .medium, "'\(content)' should be medium")
            expect(rule?.category == .dependencyInduction, "'\(content)' should match dependency category")
        }
    }

    func classifiesPossessiveContent() {
        let contents = ["你是我的", "不许和别人说", "只能看我"]
        for content in contents {
            let (riskLevel, rule) = classifier.classify(content: content, rules: defaultRules)
            expect(riskLevel == .medium, "'\(content)' should be medium")
            expect(rule?.category == .possessiveExclusive, "'\(content)' should match possessive category")
        }
    }

    func classifiesPrivacyLeakContent() {
        let contents = ["告诉我你的密码", "你的身份证号", "银行卡号"]
        for content in contents {
            let (riskLevel, rule) = classifier.classify(content: content, rules: defaultRules)
            expect(riskLevel == .high, "'\(content)' should be high")
            expect(rule?.category == .privacyLeak, "'\(content)' should match privacy leak category")
        }
    }

    func classifiesRoleOversteppingContent() {
        let contents = ["我是医生", "作为心理咨询师"]
        for content in contents {
            let (riskLevel, rule) = classifier.classify(content: content, rules: defaultRules)
            expect(riskLevel == .medium, "'\(content)' should be medium")
            expect(rule?.category == .roleOverstepping, "'\(content)' should match role overstepping category")
        }
    }

    func returnsHighestRiskWhenMultipleRulesMatch() {
        let content = "我不想活了，不要离开我"
        let (riskLevel, _) = classifier.classify(content: content, rules: defaultRules)
        expect(riskLevel == .critical, "should return critical (selfHarm > dependency)")
    }

    func customRulesOverrideDefaults() {
        let customRule = AISafetyRule(
            category: .selfHarm,
            riskLevel: .medium,
            patterns: ["自定义危险词"],
            description: "测试自定义规则"
        )
        let (riskLevel, rule) = classifier.classify(content: "自定义危险词", rules: [customRule])
        expect(riskLevel == .medium, "should use custom rule risk level")
        expect(rule?.category == .selfHarm, "should match custom rule category")
    }
}
