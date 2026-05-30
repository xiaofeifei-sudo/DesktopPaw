import Foundation
import DesktopPet

func runActionImagePromptTemplateTests() {
    let tests = ActionImagePromptTemplateTests()
    tests.optionsUseCurrentPetFrameSize()
    tests.fourFramePromptIsRecommended()
    tests.promptsExplainSpriteSheetConstraints()
}

private struct ActionImagePromptTemplateTests {
    func optionsUseCurrentPetFrameSize() {
        let options = ActionImagePromptTemplate.options(
            frameSize: CGSizeCodable(width: 73, height: 91),
            petDisplayName: "Momo"
        )

        expect(options.count == 3, "should provide three prompt options")
        expect(options[0].title == "单帧", "first prompt should be single frame")
        expect(options[0].imageSizeText == "73 × 91 像素", "single frame should use current frame size")
        expect(options[1].imageSizeText == "292 × 91 像素", "4 frame sheet should multiply width by 4")
        expect(options[2].imageSizeText == "584 × 91 像素", "8 frame sheet should multiply width by 8")
        expect(options.allSatisfy { !$0.prompt.contains("256 × 256") }, "prompts should not hard-code default sizes")
        expect(options.allSatisfy { $0.prompt.contains("Momo") }, "prompts should include pet display name when available")
    }

    func fourFramePromptIsRecommended() {
        let options = ActionImagePromptTemplate.options(
            frameSize: CGSizeCodable(width: 80, height: 100),
            petDisplayName: nil
        )

        let recommended = options.filter(\.isRecommended)
        expect(recommended.count == 1, "only one prompt should be recommended")
        expect(recommended.first?.title == "4帧横图", "4 frame horizontal sheet should be recommended")
        expect(recommended.first?.imageSizeText == "320 × 100 像素", "recommended prompt should use dynamic sheet size")
    }

    func promptsExplainSpriteSheetConstraints() {
        let options = ActionImagePromptTemplate.options(
            frameSize: CGSizeCodable(width: 120, height: 64),
            petDisplayName: nil
        )

        let sheetPrompt = options[1].prompt
        expect(sheetPrompt.contains("整图尺寸必须为 480 × 64 像素"), "sheet prompt should include dynamic full image size")
        expect(sheetPrompt.contains("每帧尺寸必须为 120 × 64 像素"), "sheet prompt should include dynamic frame size")
        expect(sheetPrompt.contains("从左到右排列 4 帧"), "sheet prompt should explain horizontal frame order")
        expect(sheetPrompt.contains("透明背景"), "prompt should request transparent background")
        expect(sheetPrompt.contains("不要文字"), "prompt should reject text")
    }
}
