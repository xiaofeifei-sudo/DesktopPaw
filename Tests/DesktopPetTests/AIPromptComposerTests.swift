import Foundation
import DesktopPet

@MainActor
func runAIPromptComposerTests() {
    let tests = AIPromptComposerTests()
    tests.promptContainsRoleDefinition()
    tests.promptContainsToneGuidelines()
    tests.promptContainsRelationshipContext()
    tests.promptContainsMemorySection()
    tests.promptOmitsMemorySectionWhenEmpty()
    tests.promptContainsSafetyRules()
    tests.promptContainsFormatRequirements()
    tests.promptUsesNicknameWhenAvailable()
    tests.promptUsesDisplayNameWhenNoNickname()
    tests.promptUsesUserNickname()
    tests.memorySectionUsesPrecomposedText()
    tests.differentProfilesProduceDifferentPrompts()
    tests.promptIncludesVisualActionWhenEnabled()
    tests.promptOmitsVisualActionWhenDisabled()
}

@MainActor
private struct AIPromptComposerTests {
    private let composer = AIPromptComposer()

    private func makeContext(petNickname: String? = nil, userNickname: String? = nil) -> CompanionContext {
        CompanionContext(
            petId: "test-pet",
            petDisplayName: "小猫咪",
            petNickname: petNickname,
            userNickname: userNickname,
            runtimeState: .defaultState(),
            relationship: RelationshipSnapshot(intimacyPoints: 100, currentLevel: .familiar),
            preferences: CompanionPreferences(),
            timeSlots: [],
            recentBubbleTexts: [],
            lastCompanionEvent: nil
        )
    }

    func promptContainsRoleDefinition() {
        let prompt = composer.compose(
            profile: .gentle,
            context: makeContext(),
            memoryContext: nil
        )
        expect(prompt.contains("桌宠"), "should contain role definition mentioning 桌宠")
        expect(prompt.contains("小猫咪"), "should contain pet name")
        expect(prompt.contains("温柔"), "should contain personality name")
    }

    func promptContainsToneGuidelines() {
        let prompt = composer.compose(
            profile: .gentle,
            context: makeContext(),
            memoryContext: nil
        )
        expect(prompt.contains("语气指南"), "should contain tone guidelines section")
        expect(prompt.contains("温柔体贴"), "should contain tone description from profile")
    }

    func promptContainsRelationshipContext() {
        let prompt = composer.compose(
            profile: .gentle,
            context: makeContext(),
            memoryContext: nil
        )
        expect(prompt.contains("关系上下文"), "should contain relationship context section")
        expect(prompt.contains("熟悉"), "should contain relationship level name")
    }

    func promptContainsMemorySection() {
        let memoryContext = "【关于用户】\n- 昵称：小明"
        let prompt = composer.compose(
            profile: .gentle,
            context: makeContext(),
            memoryContext: memoryContext
        )
        expect(prompt.contains("记忆"), "should contain memory section")
        expect(prompt.contains("小明"), "should contain memory content")
    }

    func promptOmitsMemorySectionWhenEmpty() {
        let prompt = composer.compose(
            profile: .gentle,
            context: makeContext(),
            memoryContext: nil
        )
        expect(!prompt.contains("以下是关于"), "should not contain memory section when nil")
    }

    func promptContainsSafetyRules() {
        let prompt = composer.compose(
            profile: .gentle,
            context: makeContext(),
            memoryContext: nil
        )
        expect(prompt.contains("安全规则"), "should contain safety rules section")
        expect(prompt.contains("占有欲"), "should mention possessiveness prohibition")
        expect(prompt.contains("医疗"), "should mention medical prohibition")
        expect(prompt.contains("密码"), "should mention password prohibition")
    }

    func promptContainsFormatRequirements() {
        let prompt = composer.compose(
            profile: .gentle,
            context: makeContext(),
            memoryContext: nil
        )
        expect(prompt.contains("[BUBBLE]"), "should contain BUBBLE tag instruction")
        expect(prompt.contains("[PANEL]"), "should contain PANEL tag instruction")
        expect(prompt.contains("[MEMORY]"), "should contain MEMORY tag instruction")
        expect(prompt.contains("12"), "should mention bubble max length 12")
        expect(prompt.contains("200"), "should mention panel max length 200")
    }

    func promptUsesNicknameWhenAvailable() {
        let prompt = composer.compose(
            profile: .gentle,
            context: makeContext(petNickname: "咪咪"),
            memoryContext: nil
        )
        expect(prompt.contains("咪咪"), "should use pet nickname")
        expect(!prompt.contains("小猫咪"), "should not use display name when nickname exists")
    }

    func promptUsesDisplayNameWhenNoNickname() {
        let prompt = composer.compose(
            profile: .gentle,
            context: makeContext(petNickname: nil),
            memoryContext: nil
        )
        expect(prompt.contains("小猫咪"), "should use display name when no nickname")
    }

    func promptUsesUserNickname() {
        let prompt = composer.compose(
            profile: .gentle,
            context: makeContext(userNickname: "小明"),
            memoryContext: nil
        )
        expect(prompt.contains("小明"), "should use user nickname in prompt")
    }

    func memorySectionUsesPrecomposedText() {
        let memoryContext = "【关于用户】\n- 偏好：偏好0\n- 偏好：偏好1"
        let prompt = composer.compose(
            profile: .gentle,
            context: makeContext(),
            memoryContext: memoryContext
        )
        expect(prompt.contains("偏好0"), "should contain first memory content")
        expect(prompt.contains("偏好1"), "should contain second memory content")
    }

    func differentProfilesProduceDifferentPrompts() {
        let context = makeContext()
        let gentlePrompt = composer.compose(profile: .gentle, context: context, memoryContext: nil)
        let livelyPrompt = composer.compose(profile: .lively, context: context, memoryContext: nil)
        let quietPrompt = composer.compose(profile: .quiet, context: context, memoryContext: nil)
        let playfulPrompt = composer.compose(profile: .playful, context: context, memoryContext: nil)
        expect(gentlePrompt != livelyPrompt, "gentle and lively prompts should differ")
        expect(gentlePrompt != quietPrompt, "gentle and quiet prompts should differ")
        expect(livelyPrompt != playfulPrompt, "lively and playful prompts should differ")
    }

    func promptIncludesVisualActionWhenEnabled() {
        let enabledComposer = AIPromptComposer(
            visualPromptPolicy: AIVisualPromptPolicy(),
            isVisualExpressionEnabledProvider: { true }
        )
        let prompt = enabledComposer.compose(
            profile: .gentle,
            context: makeContext(),
            memoryContext: nil
        )
        expect(prompt.contains("[VISUAL_ACTION]"), "should contain VISUAL_ACTION tag instruction")
        expect(prompt.contains("视觉表达"), "should contain visual expression section header")
        expect(prompt.contains("expression"), "should mention expression kind")
        expect(prompt.contains("accessory"), "should mention accessory kind")
        expect(prompt.contains("用户视觉请求"), "should contain user visual request section")
    }

    func promptOmitsVisualActionWhenDisabled() {
        let disabledComposer = AIPromptComposer(
            visualPromptPolicy: AIVisualPromptPolicy(),
            isVisualExpressionEnabledProvider: { false }
        )
        let prompt = disabledComposer.compose(
            profile: .gentle,
            context: makeContext(),
            memoryContext: nil
        )
        expect(!prompt.contains("[VISUAL_ACTION]"), "should not contain VISUAL_ACTION when disabled")
        expect(!prompt.contains("视觉表达"), "should not contain visual expression section when disabled")
    }
}
