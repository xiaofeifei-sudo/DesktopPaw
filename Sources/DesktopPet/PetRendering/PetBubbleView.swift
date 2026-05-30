import SwiftUI

@MainActor
public struct PetBubbleView: View {
    public static let maxLineLimit: Int = 2
    public static let truncationMode: Text.TruncationMode = .tail
    public static let appearAnimationDuration: Double = 0.18
    public static let cornerRadius: CGFloat = 10

    private let bubble: PetBubble
    private let size: CGSize
    private let reducedMotion: Bool

    public init(
        bubble: PetBubble,
        size: CGSize,
        reducedMotion: Bool = false
    ) {
        self.bubble = bubble
        self.size = size
        self.reducedMotion = reducedMotion
    }

    public var body: some View {
        Text(bubble.text)
            .font(.system(size: 13))
            .lineLimit(Self.maxLineLimit)
            .truncationMode(Self.truncationMode)
            .multilineTextAlignment(.center)
            .frame(width: size.width, height: size.height, alignment: .center)
            .background(
                RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
                    .fill(Color(NSColor.windowBackgroundColor).opacity(0.92))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
                    .stroke(Color.black.opacity(0.06), lineWidth: 0.5)
            )
            .shadow(color: Color.black.opacity(0.12), radius: 2, x: 0, y: 1)
            .transition(.opacity)
            .animation(Self.appearAnimation(reducedMotion: reducedMotion), value: bubble.id)
    }

    public static func appearAnimation(reducedMotion: Bool) -> Animation? {
        reducedMotion ? nil : .easeOut(duration: appearAnimationDuration)
    }
}
