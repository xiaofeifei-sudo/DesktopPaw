import Foundation
import DesktopPet

@MainActor
func runAIPersonalityEngineTests() {
    let tests = AIPersonalityEngineTests()
    tests.buildSystemPromptReturnsNonEmpty()
    tests.buildSystemPromptIncludesAllSections()
    tests.validateResponseStylePassesForValidResponse()
    tests.validateResponseStyleFailsForLongBubble()
    tests.validateResponseStyleFailsForLongPanel()
    tests.validateResponseStylePassesForEmptyResponse()
    tests.parseBubbleTextExtractsCorrectly()
    tests.parsePanelTextExtractsCorrectly()
    tests.parseMemoryUpdateExtractsCorrectly()
    tests.parseReturnsNilForMissingTags()
    tests.personalitySwitchChangesPrompt()
    tests.engineCanUseCustomComposer()
}

@MainActor
private struct AIPersonalityEngineTests {
    private let engine = AIPersonalityEngine()

    private func makeContext() -> CompanionContext {
        CompanionContext(
            petId: "test-pet",
            petDisplayName: "小猫咪",
            petNickname: nil,
            userNickname: nil,
            runtimeState: .defaultState(),
            relationship: RelationshipSnapshot(intimacyPoints: 100, currentLevel: .familiar),
            preferences: CompanionPreferences(),
            timeSlots: [],
            recentBubbleTexts: [],
            lastCompanionEvent: nil
        )
    }

    func buildSystemPromptReturnsNonEmpty() {
        let prompt = engine.buildSystemPrompt(
            profile: .gentle,
            context: makeContext(),
            memoryContext: nil
        )
        expect(!prompt.isEmpty, "system prompt should not be empty")
    }

    func buildSystemPromptIncludesAllSections() {
        let memoryContext = "【关于用户】\n- 偏好：喜欢安静"
        let prompt = engine.buildSystemPrompt(
            profile: .gentle,
            context: makeContext(),
            memoryContext: memoryContext
        )
        expect(prompt.contains("桌宠"), "should contain role definition")
        expect(prompt.contains("语气指南"), "should contain tone guidelines")
        expect(prompt.contains("关系上下文"), "should contain relationship context")
        expect(prompt.contains("记忆"), "should contain memory section")
        expect(prompt.contains("喜欢安静"), "should contain memory content")
        expect(prompt.contains("安全规则"), "should contain safety rules")
        expect(prompt.contains("[BUBBLE]"), "should contain format requirements")
    }

    func validateResponseStylePassesForValidResponse() {
        let response = "[BUBBLE]我在呢[/BUBBLE]\n[PANEL]我一直在这里陪着你哦[/PANEL]"
        let result = engine.validateResponseStyle(response, profile: .gentle)
        expect(result.isValid, "valid response should pass")
        expect(result.violations.isEmpty, "should have no violations")
    }

    func validateResponseStyleFailsForLongBubble() {
        let longBubble = String(repeating: "啊", count: 20)
        let response = "[BUBBLE]\(longBubble)[/BUBBLE]\n[PANEL]好的[/PANEL]"
        let result = engine.validateResponseStyle(response, profile: .gentle)
        expect(!result.isValid, "long bubble should fail")
        expect(result.violations.contains(where: { $0.contains("气泡") }),
               "violation should mention bubble")
    }

    func validateResponseStyleFailsForLongPanel() {
        let longPanel = String(repeating: "这是一段很长的文字", count: 30)
        let response = "[BUBBLE]好的[/BUBBLE]\n[PANEL]\(longPanel)[/PANEL]"
        let result = engine.validateResponseStyle(response, profile: .gentle)
        expect(!result.isValid, "long panel should fail")
        expect(result.violations.contains(where: { $0.contains("面板") }),
               "violation should mention panel")
    }

    func validateResponseStylePassesForEmptyResponse() {
        let result = engine.validateResponseStyle("", profile: .gentle)
        expect(result.isValid, "empty response should pass (no tags to validate)")
    }

    func parseBubbleTextExtractsCorrectly() {
        let response = "[BUBBLE]我在这里哦～[/BUBBLE]\n[PANEL]我一直都在[/PANEL]"
        let bubble = AIPersonalityEngine.parseBubbleText(from: response)
        expect(bubble == "我在这里哦～", "should extract bubble text")
    }

    func parsePanelTextExtractsCorrectly() {
        let response = "[BUBBLE]好的[/BUBBLE]\n[PANEL]我一直在这里陪着你[/PANEL]"
        let panel = AIPersonalityEngine.parsePanelText(from: response)
        expect(panel == "我一直在这里陪着你", "should extract panel text")
    }

    func parseMemoryUpdateExtractsCorrectly() {
        let response = "[BUBBLE]好的[/BUBBLE]\n[PANEL]嗯嗯[/PANEL]\n[MEMORY]用户喜欢喝咖啡[/MEMORY]"
        let memory = AIPersonalityEngine.parseMemoryUpdate(from: response)
        expect(memory == "用户喜欢喝咖啡", "should extract memory update")
    }

    func parseReturnsNilForMissingTags() {
        let response = "no tags here"
        expect(AIPersonalityEngine.parseBubbleText(from: response) == nil,
               "should return nil for missing BUBBLE tag")
        expect(AIPersonalityEngine.parsePanelText(from: response) == nil,
               "should return nil for missing PANEL tag")
        expect(AIPersonalityEngine.parseMemoryUpdate(from: response) == nil,
               "should return nil for missing MEMORY tag")
    }

    func personalitySwitchChangesPrompt() {
        let context = makeContext()
        let gentlePrompt = engine.buildSystemPrompt(profile: .gentle, context: context, memoryContext: nil)
        let playfulPrompt = engine.buildSystemPrompt(profile: .playful, context: context, memoryContext: nil)
        expect(gentlePrompt != playfulPrompt,
               "switching personality should produce different prompt")
        expect(gentlePrompt.contains("温柔"), "gentle prompt should mention 温柔")
        expect(playfulPrompt.contains("调皮"), "playful prompt should mention 调皮")
    }

    func engineCanUseCustomComposer() {
        let engine = AIPersonalityEngine()
        let prompt = engine.buildSystemPrompt(
            profile: .gentle,
            context: makeContext(),
            memoryContext: nil
        )
        expect(!prompt.isEmpty, "engine with default composer should produce non-empty prompt")
    }
}
