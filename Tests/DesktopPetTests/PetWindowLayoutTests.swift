import CoreGraphics
import Foundation
import DesktopPet

@MainActor
func runPetWindowLayoutTests() {
    let tests = PetWindowLayoutTests()
    tests.layoutWithoutBubbleEqualsPetSize()
    tests.layoutWithBubbleAddsHeight()
    tests.bubbleWidthClampedToMaxMultiplier()
    tests.bubbleWidthHonorsMinWidth()
    tests.petCenteredHorizontallyWhenBubbleNarrower()
    tests.petCenteredHorizontallyWhenBubbleWider()
    tests.bubbleSpacingIsPlacedAbovePet()
    tests.metricsExposeBubbleConstraints()
}

@MainActor
private struct PetWindowLayoutTests {
    func layoutWithoutBubbleEqualsPetSize() {
        let provider = DefaultPetWindowLayoutProvider(measureText: { _, _ in CGSize(width: 60, height: 24) })
        let layout = provider.layout(petSize: CGSize(width: 128, height: 128), bubble: nil)

        expect(layout.contentSize == CGSize(width: 128, height: 128), "content size should equal pet size when bubble is nil")
        expect(layout.petSize == CGSize(width: 128, height: 128), "layout should report given pet size")
        expect(layout.petOrigin == .zero, "pet origin should be zero when no bubble")
        expect(layout.bubbleSize == nil, "bubble size should be nil when no bubble")
        expect(layout.bubbleOrigin == nil, "bubble origin should be nil when no bubble")
    }

    func layoutWithBubbleAddsHeight() {
        let provider = DefaultPetWindowLayoutProvider(
            metrics: PetWindowLayoutMetrics(
                bubbleSpacing: 8,
                bubbleMinWidth: 48,
                bubbleMaxWidthMultiplier: 1.6,
                bubbleHorizontalPadding: 12,
                bubbleVerticalPadding: 6,
                bubbleMaxLines: 2
            ),
            measureText: { _, _ in CGSize(width: 60, height: 24) }
        )
        let layout = provider.layout(petSize: CGSize(width: 128, height: 128), bubble: makeBubble(text: "Hi"))

        expect(layout.contentSize.height == 128 + 8 + 24, "content height should equal pet + spacing + bubble height")
        expect(layout.contentSize.width == 128, "content width should match pet width when pet wider than bubble")
        expect(layout.bubbleSize == CGSize(width: 60, height: 24), "bubble size should reflect measured size when within bounds")
        expect(layout.petOrigin.y == 0, "pet should be anchored to bottom of content")
        expect(layout.bubbleOrigin?.y == 128 + 8, "bubble should sit above pet with spacing")
    }

    func bubbleWidthClampedToMaxMultiplier() {
        let provider = DefaultPetWindowLayoutProvider(
            metrics: .default,
            measureText: { _, _ in CGSize(width: 500, height: 24) }
        )
        let layout = provider.layout(petSize: CGSize(width: 100, height: 100), bubble: makeBubble(text: "long"))

        expect(layout.bubbleSize?.width == 160, "bubble width should clamp to petWidth * 1.6")
    }

    func bubbleWidthHonorsMinWidth() {
        let provider = DefaultPetWindowLayoutProvider(
            metrics: .default,
            measureText: { _, _ in CGSize(width: 30, height: 24) }
        )
        let layout = provider.layout(petSize: CGSize(width: 100, height: 100), bubble: makeBubble(text: "ok"))

        expect(layout.bubbleSize?.width == 48, "bubble width should respect min width even if measured smaller")
    }

    func petCenteredHorizontallyWhenBubbleNarrower() {
        let provider = DefaultPetWindowLayoutProvider(
            metrics: .default,
            measureText: { _, _ in CGSize(width: 60, height: 24) }
        )
        let layout = provider.layout(petSize: CGSize(width: 128, height: 128), bubble: makeBubble())

        expect(layout.contentSize.width == 128, "content width should match pet width when pet wider")
        expect(layout.petOrigin.x == 0, "pet should sit at zero x when pet wider than bubble")
        expect(layout.bubbleOrigin?.x == 34, "bubble should be horizontally centered above pet")
    }

    func petCenteredHorizontallyWhenBubbleWider() {
        let provider = DefaultPetWindowLayoutProvider(
            metrics: .default,
            measureText: { _, max in CGSize(width: max, height: 24) }
        )
        let layout = provider.layout(petSize: CGSize(width: 100, height: 100), bubble: makeBubble())

        expect(layout.contentSize.width == 160, "content width should grow to bubble width when bubble wider")
        expect(layout.bubbleOrigin?.x == 0, "bubble should anchor to content origin when as wide as content")
        expect(layout.petOrigin.x == 30, "pet should be centered horizontally when bubble is wider")
    }

    func bubbleSpacingIsPlacedAbovePet() {
        let provider = DefaultPetWindowLayoutProvider(
            metrics: PetWindowLayoutMetrics(
                bubbleSpacing: 12,
                bubbleMinWidth: 48,
                bubbleMaxWidthMultiplier: 1.6,
                bubbleHorizontalPadding: 12,
                bubbleVerticalPadding: 6,
                bubbleMaxLines: 2
            ),
            measureText: { _, _ in CGSize(width: 50, height: 24) }
        )
        let layout = provider.layout(petSize: CGSize(width: 100, height: 100), bubble: makeBubble())

        expect(layout.bubbleOrigin?.y == 100 + 12, "bubble origin should sit at pet height + spacing")
    }

    func metricsExposeBubbleConstraints() {
        let metrics = PetWindowLayoutMetrics.default
        expect(metrics.bubbleMaxWidthMultiplier == 1.6, "default max width multiplier should be 1.6")
        expect(metrics.bubbleMinWidth == 48, "default min width should be 48")
        expect(metrics.bubbleSpacing == 8, "default bubble spacing should be 8")
        expect(metrics.bubbleMaxLines == 2, "default max lines should be 2")
    }
}

@MainActor
private func makeBubble(text: String = "Hi") -> PetBubble {
    PetBubble(
        id: UUID(),
        text: text,
        priority: .interaction,
        createdAt: Date(timeIntervalSince1970: 0),
        expiresAt: Date(timeIntervalSince1970: 3)
    )
}
