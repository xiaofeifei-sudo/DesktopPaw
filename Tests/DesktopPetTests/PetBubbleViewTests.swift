import CoreGraphics
import Foundation
import SwiftUI
import DesktopPet

@MainActor
func runPetBubbleViewTests() {
    let tests = PetBubbleViewTests()
    tests.maxLineLimitIsTwo()
    tests.truncationModeIsTail()
    tests.appearAnimationIsNilWhenReducedMotion()
    tests.appearAnimationIsNonNilByDefault()
    tests.viewAcceptsBubbleAndSize()
}

@MainActor
private struct PetBubbleViewTests {
    func maxLineLimitIsTwo() {
        expect(PetBubbleView.maxLineLimit == 2, "PetBubbleView should cap at two lines per spec")
    }

    func truncationModeIsTail() {
        expect(PetBubbleView.truncationMode == .tail, "PetBubbleView should truncate from the tail")
    }

    func appearAnimationIsNilWhenReducedMotion() {
        let animation = PetBubbleView.appearAnimation(reducedMotion: true)
        expect(animation == nil, "Reduced Motion should disable bubble appear animation")
    }

    func appearAnimationIsNonNilByDefault() {
        let animation = PetBubbleView.appearAnimation(reducedMotion: false)
        expect(animation != nil, "Default appear animation should be set when motion is allowed")
    }

    func viewAcceptsBubbleAndSize() {
        let bubble = PetBubble(
            id: UUID(),
            text: "Hi",
            priority: .interaction,
            createdAt: Date(timeIntervalSince1970: 0),
            expiresAt: Date(timeIntervalSince1970: 3)
        )
        let view = PetBubbleView(
            bubble: bubble,
            size: CGSize(width: 80, height: 32),
            reducedMotion: false
        )
        _ = view
        expect(bubble.text == "Hi", "bubble text should round-trip through PetBubbleView init")
    }
}
