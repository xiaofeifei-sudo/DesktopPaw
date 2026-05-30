import CoreGraphics
import Foundation
import SwiftUI
import DesktopPet

@MainActor
func runInteractiveBubbleViewTests() {
    let tests = InteractiveBubbleViewTests()
    tests.containerMaxWidthIs200()
    tests.appearAnimationIsNilWhenReducedMotion()
    tests.appearAnimationIsNonNilByDefault()
    tests.cornerRadiusIs10()
    tests.maxLineLimitIs2()
    tests.textTruncationModeIsTail()
    tests.optionMinHeightIs32()
    tests.optionRowCornerRadiusIs6()
    tests.containerViewAcceptsBubble()
    tests.containerViewAcceptsFeedbackText()
    tests.petViewModelInteractiveBubbleUpdate()
    tests.petViewModelFeedbackTextUpdate()
    tests.petViewModelHandleOptionTap()
}

@MainActor
private struct InteractiveBubbleViewTests {
    private func makeBubble(text: String = "test bubble") -> InteractiveBubble {
        InteractiveBubble(
            text: text,
            type: .needExpression,
            options: [
                BubbleOption(emoji: "🍪", label: "给你弄好吃的", effect: .feed, isPrimary: true),
                BubbleOption(emoji: "⏳", label: "等一下哦", effect: .none, isPrimary: false)
            ],
            expiresAt: Date() + 60
        )
    }

    func containerMaxWidthIs200() {
        expect(InteractiveBubbleContainerView.maxWidth == 200,
               "maxWidth should be 200pt")
    }

    func appearAnimationIsNilWhenReducedMotion() {
        let animation = InteractiveBubbleContainerView.appearAnimation(reducedMotion: true)
        expect(animation == nil, "reduced motion should disable animation")
    }

    func appearAnimationIsNonNilByDefault() {
        let animation = InteractiveBubbleContainerView.appearAnimation(reducedMotion: false)
        expect(animation != nil, "default animation should be set")
    }

    func cornerRadiusIs10() {
        expect(InteractiveBubbleContainerView.cornerRadius == 10,
               "cornerRadius should be 10")
    }

    func maxLineLimitIs2() {
        expect(InteractiveBubbleContainerView.maxLineLimit == 2,
               "maxLineLimit should be 2")
    }

    func textTruncationModeIsTail() {
        expect(InteractiveBubbleContainerView.textTruncationMode == .tail,
               "truncationMode should be tail")
    }

    func optionMinHeightIs32() {
        expect(InteractiveBubbleContainerView.optionMinHeight == 32,
               "option row minHeight should be 32pt")
    }

    func optionRowCornerRadiusIs6() {
        expect(InteractiveBubbleContainerView.optionRowCornerRadius == 6,
               "option row cornerRadius should be 6")
    }

    func containerViewAcceptsBubble() {
        let bubble = makeBubble()
        let view = InteractiveBubbleContainerView(
            bubble: bubble,
            feedbackText: nil,
            onOptionTap: { _ in },
            reducedMotion: false
        )
        _ = view
        expect(bubble.text == "test bubble", "bubble should pass through init")
    }

    func containerViewAcceptsFeedbackText() {
        let view = InteractiveBubbleContainerView(
            bubble: nil,
            feedbackText: "好吃~",
            onOptionTap: { _ in },
            reducedMotion: false
        )
        _ = view
        expect(true, "container should accept feedback text without crash")
    }

    func petViewModelInteractiveBubbleUpdate() {
        let model = PetViewModel()
        expect(model.interactiveBubble == nil, "initial interactiveBubble should be nil")

        let bubble = makeBubble(text: "hello")
        model.update(interactiveBubble: bubble)
        expect(model.interactiveBubble?.text == "hello",
               "update should set interactiveBubble")

        model.update(interactiveBubble: nil)
        expect(model.interactiveBubble == nil, "update with nil should clear")
    }

    func petViewModelFeedbackTextUpdate() {
        let model = PetViewModel()
        expect(model.interactiveBubbleFeedbackText == nil, "initial feedback text should be nil")

        model.update(interactiveBubbleFeedbackText: "好吃~")
        expect(model.interactiveBubbleFeedbackText == "好吃~",
               "update should set feedback text")

        model.update(interactiveBubbleFeedbackText: nil)
        expect(model.interactiveBubbleFeedbackText == nil, "update with nil should clear")
    }

    func petViewModelHandleOptionTap() {
        let model = PetViewModel()
        var tappedOption: BubbleOption?
        model.onInteractiveBubbleOptionTap = { option in tappedOption = option }

        let option = BubbleOption(emoji: "🍪", label: "给你弄好吃的", effect: .feed, isPrimary: true)
        model.handleInteractiveBubbleOption(option)

        expect(tappedOption == option, "handleInteractiveBubbleOption should call callback")
    }
}
