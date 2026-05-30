import SwiftUI

@MainActor
public struct AIVisualConfirmationView: View {
    let reason: String
    let description: String
    let onConfirm: () -> Void
    let onCancel: () -> Void

    public init(
        reason: String,
        description: String,
        onConfirm: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.reason = reason
        self.description = description
        self.onConfirm = onConfirm
        self.onCancel = onCancel
    }

    public var body: some View {
        VStack(spacing: 16) {
            Text("视觉变化请求")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                Text(reason)
                    .font(.callout)
                    .foregroundStyle(.secondary)

                Text(description)
                    .font(.callout)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            VStack(alignment: .leading, spacing: 4) {
                confirmationNote(icon: "clock", text: "这是临时变化，到期后会自动恢复原样。")
                confirmationNote(icon: "arrow.uturn.backward", text: "你可以随时手动恢复原来的样子。")
            }

            HStack(spacing: 16) {
                Button("取消") {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)

                Button("允许") {
                    onConfirm()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 340)
    }

    private func confirmationNote(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
