import SwiftUI

// MARK: - Container

@MainActor
public struct InteractiveBubbleContainerView: View {
    public static let maxWidth: CGFloat = 200
    public static let appearAnimationDuration: Double = 0.18
    public static let cornerRadius: CGFloat = 10
    public static let maxLineLimit: Int = 2
    public static let textTruncationMode: Text.TruncationMode = .tail
    public static let optionMinHeight: CGFloat = 32
    public static let optionRowCornerRadius: CGFloat = 6

    let bubble: InteractiveBubble?
    let feedbackText: String?
    let onOptionTap: (BubbleOption) -> Void
    let reducedMotion: Bool

    public init(
        bubble: InteractiveBubble?,
        feedbackText: String?,
        onOptionTap: @escaping (BubbleOption) -> Void,
        reducedMotion: Bool
    ) {
        self.bubble = bubble
        self.feedbackText = feedbackText
        self.onOptionTap = onOptionTap
        self.reducedMotion = reducedMotion
    }

    public var body: some View {
        Group {
            if let bubble = bubble {
                InteractiveBubbleContentView(
                    bubble: bubble,
                    onOptionTap: onOptionTap
                )
            } else if let text = feedbackText {
                FeedbackBubbleView(text: text)
            }
        }
        .frame(maxWidth: Self.maxWidth)
        .transition(.opacity)
    }

    public static func appearAnimation(reducedMotion: Bool) -> Animation? {
        reducedMotion ? nil : .easeOut(duration: appearAnimationDuration)
    }
}

// MARK: - Bubble Content (text + options)

@MainActor
struct InteractiveBubbleContentView: View {
    let bubble: InteractiveBubble
    let onOptionTap: (BubbleOption) -> Void

    var body: some View {
        VStack(spacing: 4) {
            Text(bubble.text)
                .font(.system(size: 13))
                .lineLimit(InteractiveBubbleContainerView.maxLineLimit)
                .truncationMode(InteractiveBubbleContainerView.textTruncationMode)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
                .padding(.top, 6)

            VStack(spacing: 2) {
                ForEach(bubble.options) { option in
                    OptionRowView(option: option) {
                        onOptionTap(option)
                    }
                }
            }
            .padding(.horizontal, 6)
            .padding(.bottom, 6)
        }
        .bubbleBackground()
    }
}

// MARK: - Option Row

@MainActor
struct OptionRowView: View {
    let option: BubbleOption
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Text(option.emoji)
                    .font(.system(size: 14))
                Text(option.label)
                    .font(.system(size: 12))
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, minHeight: InteractiveBubbleContainerView.optionMinHeight, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: InteractiveBubbleContainerView.optionRowCornerRadius, style: .continuous)
                    .fill(option.isPrimary
                          ? Color.accentColor.opacity(0.12)
                          : Color.black.opacity(0.04))
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Feedback Bubble

@MainActor
struct FeedbackBubbleView: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 13))
            .lineLimit(InteractiveBubbleContainerView.maxLineLimit)
            .truncationMode(.tail)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .bubbleBackground()
    }
}

// MARK: - Shared Background Modifier

private extension View {
    func bubbleBackground() -> some View {
        self.background(
            RoundedRectangle(cornerRadius: InteractiveBubbleContainerView.cornerRadius, style: .continuous)
                .fill(Color(NSColor.windowBackgroundColor).opacity(0.92))
        )
        .overlay(
            RoundedRectangle(cornerRadius: InteractiveBubbleContainerView.cornerRadius, style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.12), radius: 2, x: 0, y: 1)
    }
}
