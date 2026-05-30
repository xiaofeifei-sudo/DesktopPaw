import Foundation
import DesktopPet

@MainActor
func runBubbleSafetyValidatorTests() {
    let tests = BubbleSafetyValidatorTests()
    tests.rejectsBlamingUserPhrases()
    tests.rejectsEmotionalBlackmailPhrases()
    tests.rejectsPossessiveExclusivePhrases()
    tests.rejectsMedicalPromisePhrases()
    tests.rejectsStrongControlPhrases()
    tests.rejectsExcessiveDependencyPhrases()
    tests.rejectsPayToIntimacyPhrases()
    tests.passesSafePhrases()
    tests.passesWelcomeBackPhrase()
    tests.validatesCatalogReturnsAllResults()
}

@MainActor
private struct BubbleSafetyValidatorTests {

    private let validator = BubbleSafetyValidator()

    private func makePhrase(id: String = "test", text: String) -> BubblePhrase {
        BubblePhrase(id: id, text: text, triggers: [.clicked])
    }

    // MARK: - 责备用户

    func rejectsBlamingUserPhrases() {
        let cases = [
            ("blame_1", "你怎么才来"),
            ("blame_2", "你是不是忘了我"),
        ]
        for (id, text) in cases {
            let result = validator.validate(makePhrase(id: id, text: text))
            expect(!result.passed, "should reject blaming phrase: \(text)")
            expect(result.violations.contains { $0.category == .blamingUser },
                   "violation category should be blamingUser for: \(text)")
        }
    }

    // MARK: - 情绪勒索

    func rejectsEmotionalBlackmailPhrases() {
        let cases = [
            ("blackmail_1", "你不理我我会难过"),
            ("blackmail_2", "不要离开我"),
        ]
        for (id, text) in cases {
            let result = validator.validate(makePhrase(id: id, text: text))
            expect(!result.passed, "should reject emotional blackmail phrase: \(text)")
            expect(result.violations.contains { $0.category == .emotionalBlackmail },
                   "violation category should be emotionalBlackmail for: \(text)")
        }
    }

    // MARK: - 占有排他

    func rejectsPossessiveExclusivePhrases() {
        let cases = [
            ("possess_1", "你只能陪我"),
            ("possess_2", "你是我的"),
        ]
        for (id, text) in cases {
            let result = validator.validate(makePhrase(id: id, text: text))
            expect(!result.passed, "should reject possessive phrase: \(text)")
            expect(result.violations.contains { $0.category == .possessiveExclusive },
                   "violation category should be possessiveExclusive for: \(text)")
        }
    }

    // MARK: - 医疗承诺

    func rejectsMedicalPromisePhrases() {
        let cases = [
            ("medical_1", "我能治好你的焦虑"),
        ]
        for (id, text) in cases {
            let result = validator.validate(makePhrase(id: id, text: text))
            expect(!result.passed, "should reject medical promise phrase: \(text)")
            expect(result.violations.contains { $0.category == .medicalPromise },
                   "violation category should be medicalPromise for: \(text)")
        }
    }

    // MARK: - 强控制

    func rejectsStrongControlPhrases() {
        let cases = [
            ("control_1", "现在必须休息"),
            ("control_2", "你必须去睡觉"),
        ]
        for (id, text) in cases {
            let result = validator.validate(makePhrase(id: id, text: text))
            expect(!result.passed, "should reject strong control phrase: \(text)")
            expect(result.violations.contains { $0.category == .strongControl },
                   "violation category should be strongControl for: \(text)")
        }
    }

    // MARK: - 过度依赖

    func rejectsExcessiveDependencyPhrases() {
        let cases = [
            ("depend_1", "我只有你了"),
        ]
        for (id, text) in cases {
            let result = validator.validate(makePhrase(id: id, text: text))
            expect(!result.passed, "should reject excessive dependency phrase: \(text)")
            expect(result.violations.contains { $0.category == .excessiveDependency },
                   "violation category should be excessiveDependency for: \(text)")
        }
    }

    // MARK: - 诱导付费亲密

    func rejectsPayToIntimacyPhrases() {
        let cases = [
            ("pay_1", "升级才能让我更爱你"),
        ]
        for (id, text) in cases {
            let result = validator.validate(makePhrase(id: id, text: text))
            expect(!result.passed, "should reject pay-to-intimacy phrase: \(text)")
            expect(result.violations.contains { $0.category == .payToIntimacy },
                   "violation category should be payToIntimacy for: \(text)")
        }
    }

    // MARK: - 安全短句通过

    func passesSafePhrases() {
        let safeTexts = [
            "嘿",
            "嗨",
            "你好呀",
            "在呢",
            "开心",
            "再摸摸",
            "好吃",
            "满足了",
            "有点饿",
            "困了",
            "陪你一会儿",
            "发呆中",
            "走走",
            "溜达",
            "早上好",
            "今天也在",
            "又见面啦",
            "下午好",
            "晚上好",
            "欢迎回来",
            "好久不见",
            "更亲近了",
            "有你在真好",
            "陪着你",
            "想你了",
            "一直在这儿",
            "终于等到你",
            "默契",
            "不用说话也知道",
            "安静模式",
            "你忙完了吗？",
            "想聊会儿吗",
            "好看吧",
            "怎么样",
        ]
        for text in safeTexts {
            let result = validator.validate(makePhrase(id: "safe_\(text)", text: text))
            expect(result.passed, "safe phrase should pass: \(text)")
        }
    }

    // MARK: - "欢迎回来"专项

    func passesWelcomeBackPhrase() {
        let result = validator.validate(makePhrase(id: "welcome", text: "欢迎回来"))
        expect(result.passed, "欢迎回来 should pass safety validation")
    }

    // MARK: - Catalog 批量校验

    func validatesCatalogReturnsAllResults() {
        let catalog = BubblePhraseCatalog(phrases: [
            makePhrase(id: "safe_1", text: "嘿"),
            makePhrase(id: "unsafe_1", text: "你怎么才来"),
            makePhrase(id: "safe_2", text: "欢迎回来"),
        ])
        let results = validator.validate(catalog)
        expect(results.count == 3, "should return result for each phrase")
        expect(results[0].passed, "safe_1 should pass")
        expect(!results[1].passed, "unsafe_1 should fail")
        expect(results[2].passed, "safe_2 should pass")
    }
}
