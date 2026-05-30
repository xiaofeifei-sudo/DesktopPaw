import SwiftUI

@MainActor
public struct AIVisualPreviewView: View {
    let asset: PetVisualAsset
    let referencePreviewURL: URL
    let onApply: () -> Void
    let onDiscard: () -> Void
    let onRetry: () -> Void
    let onFeedback: (PreviewFeedbackType) -> Void

    @State private var isApplying = false
    @State private var showFeedbackMenu = false
    @State private var feedbackGiven = false
    @State private var feedbackMessage: String?

    public init(
        asset: PetVisualAsset,
        referencePreviewURL: URL,
        onApply: @escaping () -> Void,
        onDiscard: @escaping () -> Void,
        onRetry: @escaping () -> Void,
        onFeedback: @escaping (PreviewFeedbackType) -> Void
    ) {
        self.asset = asset
        self.referencePreviewURL = referencePreviewURL
        self.onApply = onApply
        self.onDiscard = onDiscard
        self.onRetry = onRetry
        self.onFeedback = onFeedback
    }

    public var body: some View {
        VStack(spacing: 16) {
            comparisonSection

            if let hint = gateHintText {
                hintBanner(text: hint)
            }

            actionButtons

            if let message = feedbackMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .frame(width: 480)
    }

    private var comparisonSection: some View {
        HStack(spacing: 16) {
            imageColumn(title: "原始形象", url: referencePreviewURL)
            Divider()
            imageColumn(title: "生成结果", url: asset.localURL)
        }
        .frame(height: 200)
    }

    private func imageColumn(title: String, url: URL) -> some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            if let image = NSImage(contentsOf: url) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                Image(systemName: "photo")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private var gateHintText: String? {
        guard let gate = asset.gateResult else { return nil }
        switch gate.autoAction {
        case .requirePreview:
            if gate.overall == .warn {
                return "这次变化可能和原形象有差异，请确认是否应用。"
            }
            return nil
        default:
            return nil
        }
    }

    private func hintBanner(text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle")
                .font(.caption)
            Text(text)
                .font(.caption)
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private var actionButtons: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                Button {
                    isApplying = true
                    onApply()
                    isApplying = false
                } label: {
                    if isApplying {
                        ProgressView()
                            .controlSize(.small)
                    }
                    Text("应用")
                }
                .buttonStyle(.borderedProminent)
                .disabled(isApplying)
                .keyboardShortcut(.defaultAction)

                Button("放弃") {
                    onDiscard()
                }
                .keyboardShortcut(.cancelAction)

                Button("再试一次") {
                    onRetry()
                }
            }

            restoreHint

            if !feedbackGiven {
                feedbackSection
            }
        }
    }

    private var restoreHint: some View {
        HStack(spacing: 4) {
            Image(systemName: "arrow.uturn.backward")
                .font(.caption2)
            Text("应用后可以随时恢复原样")
                .font(.caption2)
        }
        .foregroundStyle(.tertiary)
    }

    private var feedbackSection: some View {
        VStack(spacing: 6) {
            Button {
                showFeedbackMenu.toggle()
            } label: {
                Label("标记反馈", systemImage: "hand.thumbsup")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .popover(isPresented: $showFeedbackMenu) {
                feedbackMenu
            }
        }
    }

    private var feedbackMenu: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(PreviewFeedbackType.allCases, id: \.self) { type in
                Button(type.displayText) {
                    feedbackGiven = true
                    feedbackMessage = "已记录，之后会更偏向保持原样。"
                    onFeedback(type)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            }
        }
        .padding(8)
    }
}
