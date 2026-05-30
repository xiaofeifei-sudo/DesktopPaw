import Foundation
import DesktopPet

@MainActor
func runAIVisualActionParserTests() {
    let tests = AIVisualActionParserTests()
    tests.parseValidAction()
    tests.parseValidAccessoryAction()
    tests.parseRemovesVisualActionTags()
    tests.parseInvalidJSONReturnsWarning()
    tests.parseUnknownKindReturnsWarning()
    tests.parseEmptyDescriptionReturnsWarning()
    tests.parseDescriptionTooLongReturnsWarning()
    tests.parseNoActionReturnsEmptyCandidates()
    tests.parseMultipleActions()
    tests.parseActionWithDefaults()
    tests.parseResultIsEquatable()
}

@MainActor
private struct AIVisualActionParserTests {
    private let parser = AIVisualActionParser()

    func parseValidAction() {
        let response = """
        [BUBBLE]我来换个表情[/BUBBLE]
        [PANEL]让我给你看看开心的样子[/PANEL]
        [VISUAL_ACTION]
        {
          "kind": "expression",
          "description": "开心微笑的表情",
          "renderMode": "replaceWholeImage",
          "durationSeconds": 60,
          "impact": "low"
        }
        [/VISUAL_ACTION]
        """
        let result = parser.parse(from: response, petId: "pet-1", source: .chat)

        expect(result.candidates.count == 1, "should parse one candidate")
        expect(result.candidates.first?.kind == .expression, "should be expression kind")
        expect(result.candidates.first?.description == "开心微笑的表情", "should parse description")
        expect(result.candidates.first?.renderMode == .replaceWholeImage, "should parse renderMode")
        expect(result.candidates.first?.impact == .low, "should parse impact")
        expect(result.candidates.first?.petId == "pet-1", "should use provided petId")
        expect(result.candidates.first?.source == .chat, "should use provided source")
        expect(result.parseWarnings.isEmpty, "should have no warnings for valid action")
    }

    func parseValidAccessoryAction() {
        let response = """
        [BUBBLE]戴顶帽子吧[/BUBBLE]
        [PANEL]给你看看我戴圣诞帽的样子[/PANEL]
        [VISUAL_ACTION]
        {
          "kind": "accessory",
          "description": "戴一顶红色圣诞帽",
          "renderMode": "overlayImage",
          "durationSeconds": 120,
          "impact": "low"
        }
        [/VISUAL_ACTION]
        """
        let result = parser.parse(from: response, petId: "pet-1", source: .smartBubble)

        expect(result.candidates.count == 1, "should parse one candidate")
        expect(result.candidates.first?.kind == .accessory, "should be accessory kind")
        expect(result.candidates.first?.renderMode == .overlayImage, "should be overlayImage")
        expect(result.candidates.first?.source == .smartBubble, "should use smartBubble source")
    }

    func parseRemovesVisualActionTags() {
        let response = """
        [BUBBLE]我准备好了[/BUBBLE]
        [PANEL]让我换个造型[/PANEL]
        [VISUAL_ACTION]
        {"kind": "expression", "description": "微笑", "renderMode": "replaceWholeImage", "impact": "low"}
        [/VISUAL_ACTION]
        """
        let result = parser.parse(from: response, petId: "pet-1", source: .chat)

        expect(!result.cleanedResponse.contains("[VISUAL_ACTION]"), "cleaned response should not contain open tag")
        expect(!result.cleanedResponse.contains("[/VISUAL_ACTION]"), "cleaned response should not contain close tag")
        expect(result.cleanedResponse.contains("[BUBBLE]"), "should preserve BUBBLE tags")
        expect(result.cleanedResponse.contains("[PANEL]"), "should preserve PANEL tags")
    }

    func parseInvalidJSONReturnsWarning() {
        let response = """
        [BUBBLE]你好[/BUBBLE]
        [VISUAL_ACTION]{not valid json}[/VISUAL_ACTION]
        """
        let result = parser.parse(from: response, petId: "pet-1", source: .chat)

        expect(result.candidates.isEmpty, "should not produce candidates for invalid JSON")
        expect(result.parseWarnings.count == 1, "should have one warning")
        expect(!result.cleanedResponse.contains("[VISUAL_ACTION]"), "should still clean tags")
    }

    func parseUnknownKindReturnsWarning() {
        let response = """
        [VISUAL_ACTION]
        {"kind": "transformation", "description": "变成龙", "renderMode": "replaceWholeImage", "impact": "high"}
        [/VISUAL_ACTION]
        """
        let result = parser.parse(from: response, petId: "pet-1", source: .chat)

        expect(result.candidates.isEmpty, "should not produce candidates for unknown kind")
        expect(result.parseWarnings.count == 1, "should have one warning for unknown kind")
    }

    func parseEmptyDescriptionReturnsWarning() {
        let response = """
        [VISUAL_ACTION]
        {"kind": "expression", "description": "", "renderMode": "replaceWholeImage", "impact": "low"}
        [/VISUAL_ACTION]
        """
        let result = parser.parse(from: response, petId: "pet-1", source: .chat)

        expect(result.candidates.isEmpty, "should not produce candidates for empty description")
        expect(result.parseWarnings.count == 1, "should have one warning for empty description")
    }

    func parseDescriptionTooLongReturnsWarning() {
        let longDescription = String(repeating: "很长的描述", count: 50)
        let response = """
        [VISUAL_ACTION]
        {"kind": "expression", "description": "\(longDescription)", "renderMode": "replaceWholeImage", "impact": "low"}
        [/VISUAL_ACTION]
        """
        let result = parser.parse(from: response, petId: "pet-1", source: .chat)

        expect(result.candidates.isEmpty, "should not produce candidates for too long description")
        expect(result.parseWarnings.count == 1, "should have one warning for too long description")
    }

    func parseNoActionReturnsEmptyCandidates() {
        let response = """
        [BUBBLE]你好呀[/BUBBLE]
        [PANEL]今天天气真好[/PANEL]
        """
        let result = parser.parse(from: response, petId: "pet-1", source: .chat)

        expect(result.candidates.isEmpty, "should have no candidates when no visual action tag")
        expect(result.parseWarnings.isEmpty, "should have no warnings")
        expect(result.cleanedResponse == response.trimmingCharacters(in: .whitespacesAndNewlines),
               "cleaned response should match original")
    }

    func parseMultipleActions() {
        let response = """
        [VISUAL_ACTION]
        {"kind": "expression", "description": "开心", "renderMode": "replaceWholeImage", "impact": "low"}
        [/VISUAL_ACTION]
        一些文字
        [VISUAL_ACTION]
        {"kind": "accessory", "description": "戴帽子", "renderMode": "overlayImage", "impact": "low"}
        [/VISUAL_ACTION]
        """
        let result = parser.parse(from: response, petId: "pet-1", source: .chat)

        expect(result.candidates.count == 2, "should parse two candidates")
        expect(result.candidates[0].kind == .expression, "first should be expression")
        expect(result.candidates[1].kind == .accessory, "second should be accessory")
    }

    func parseActionWithDefaults() {
        let response = """
        [VISUAL_ACTION]
        {"kind": "ambience", "description": "柔和的光效"}
        [/VISUAL_ACTION]
        """
        let result = parser.parse(from: response, petId: "pet-1", source: .chat)

        expect(result.candidates.count == 1, "should parse candidate with minimal fields")
        let candidate = result.candidates.first!
        expect(candidate.renderMode == .replaceWholeImage, "default renderMode should be replaceWholeImage")
        expect(candidate.impact == .low, "default impact should be low")
        expect(candidate.requestedDurationSeconds == 60, "default duration should be 60")
    }

    func parseResultIsEquatable() {
        let response = "[VISUAL_ACTION]{\"kind\": \"expression\", \"description\": \"开心\", \"renderMode\": \"replaceWholeImage\", \"impact\": \"low\"}[/VISUAL_ACTION]"
        let result1 = parser.parse(from: response, petId: "pet-1", source: .chat)
        let result2 = parser.parse(from: response, petId: "pet-1", source: .chat)

        expect(result1.candidates.count == result2.candidates.count, "should have same count")
        expect(result1.cleanedResponse == result2.cleanedResponse, "should have same cleaned response")
        expect(result1.parseWarnings == result2.parseWarnings, "should have same warnings")
    }
}
