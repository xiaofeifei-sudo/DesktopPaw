@preconcurrency import AppKit
import CoreGraphics
import Foundation

public struct PetWindowLayout: Equatable, Sendable {
    public let petSize: CGSize
    public let bubbleSize: CGSize?
    public let contentSize: CGSize
    public let petOrigin: CGPoint
    public let bubbleOrigin: CGPoint?

    public init(
        petSize: CGSize,
        bubbleSize: CGSize?,
        contentSize: CGSize,
        petOrigin: CGPoint,
        bubbleOrigin: CGPoint?
    ) {
        self.petSize = petSize
        self.bubbleSize = bubbleSize
        self.contentSize = contentSize
        self.petOrigin = petOrigin
        self.bubbleOrigin = bubbleOrigin
    }
}

public struct PetWindowLayoutMetrics: Equatable, Sendable {
    public let bubbleSpacing: CGFloat
    public let bubbleMinWidth: CGFloat
    public let bubbleMaxWidthMultiplier: CGFloat
    public let bubbleHorizontalPadding: CGFloat
    public let bubbleVerticalPadding: CGFloat
    public let bubbleMaxLines: Int

    public init(
        bubbleSpacing: CGFloat,
        bubbleMinWidth: CGFloat,
        bubbleMaxWidthMultiplier: CGFloat,
        bubbleHorizontalPadding: CGFloat,
        bubbleVerticalPadding: CGFloat,
        bubbleMaxLines: Int
    ) {
        self.bubbleSpacing = bubbleSpacing
        self.bubbleMinWidth = bubbleMinWidth
        self.bubbleMaxWidthMultiplier = bubbleMaxWidthMultiplier
        self.bubbleHorizontalPadding = bubbleHorizontalPadding
        self.bubbleVerticalPadding = bubbleVerticalPadding
        self.bubbleMaxLines = bubbleMaxLines
    }

    public static let `default` = PetWindowLayoutMetrics(
        bubbleSpacing: 8,
        bubbleMinWidth: 48,
        bubbleMaxWidthMultiplier: 1.6,
        bubbleHorizontalPadding: 12,
        bubbleVerticalPadding: 6,
        bubbleMaxLines: 2
    )
}

public protocol PetWindowLayoutProviding: AnyObject {
    func layout(petSize: CGSize, bubble: PetBubble?) -> PetWindowLayout
}

public final class DefaultPetWindowLayoutProvider: PetWindowLayoutProviding {
    public typealias TextMeasurer = (String, CGFloat) -> CGSize

    public let metrics: PetWindowLayoutMetrics
    private let measureText: TextMeasurer

    public init(
        metrics: PetWindowLayoutMetrics = .default,
        measureText: @escaping TextMeasurer = DefaultPetWindowLayoutProvider.systemTextMeasurer()
    ) {
        self.metrics = metrics
        self.measureText = measureText
    }

    public func layout(petSize: CGSize, bubble: PetBubble?) -> PetWindowLayout {
        guard let bubble else {
            return PetWindowLayout(
                petSize: petSize,
                bubbleSize: nil,
                contentSize: petSize,
                petOrigin: .zero,
                bubbleOrigin: nil
            )
        }

        let maxBubbleWidth = max(metrics.bubbleMinWidth, petSize.width * metrics.bubbleMaxWidthMultiplier)
        let measured = measureText(bubble.text, maxBubbleWidth)
        let clampedWidth = min(max(measured.width, metrics.bubbleMinWidth), maxBubbleWidth)
        let bubbleSize = CGSize(width: clampedWidth, height: measured.height)

        let contentWidth = max(petSize.width, bubbleSize.width)
        let contentHeight = petSize.height + metrics.bubbleSpacing + bubbleSize.height
        let contentSize = CGSize(width: contentWidth, height: contentHeight)

        let petOrigin = CGPoint(x: (contentWidth - petSize.width) / 2, y: 0)
        let bubbleOrigin = CGPoint(
            x: (contentWidth - bubbleSize.width) / 2,
            y: petSize.height + metrics.bubbleSpacing
        )

        return PetWindowLayout(
            petSize: petSize,
            bubbleSize: bubbleSize,
            contentSize: contentSize,
            petOrigin: petOrigin,
            bubbleOrigin: bubbleOrigin
        )
    }

    public static func systemTextMeasurer(font: NSFont = .systemFont(ofSize: 13)) -> TextMeasurer {
        let metrics = PetWindowLayoutMetrics.default
        return { text, maxBubbleWidth in
            let availableTextWidth = max(0, maxBubbleWidth - metrics.bubbleHorizontalPadding * 2)
            let attributes: [NSAttributedString.Key: Any] = [.font: font]
            let attributed = NSAttributedString(string: text, attributes: attributes)

            let lineHeight = font.ascender - font.descender + font.leading
            let maxTextHeight = lineHeight * CGFloat(metrics.bubbleMaxLines)

            let bbox = attributed.boundingRect(
                with: CGSize(width: availableTextWidth, height: maxTextHeight),
                options: [.usesLineFragmentOrigin]
            )

            let textWidth = min(ceil(bbox.width), availableTextWidth)
            let textHeight = min(ceil(bbox.height), maxTextHeight)

            return CGSize(
                width: textWidth + metrics.bubbleHorizontalPadding * 2,
                height: textHeight + metrics.bubbleVerticalPadding * 2
            )
        }
    }
}
