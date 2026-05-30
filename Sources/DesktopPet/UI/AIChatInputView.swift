import SwiftUI

public struct AIChatInputView: View {
    @Binding var text: String
    let isSending: Bool
    let onSend: () -> Void

    public init(text: Binding<String>, isSending: Bool, onSend: @escaping () -> Void) {
        self._text = text
        self.isSending = isSending
        self.onSend = onSend
    }

    public var body: some View {
        HStack(spacing: 8) {
            TextField("Say something...", text: $text, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...4)
                .onSubmit { sendIfReady() }

            Button(action: sendIfReady) {
                if isSending {
                    ProgressView()
                        .controlSize(.small)
                        .frame(width: 20, height: 20)
                } else {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                }
            }
            .buttonStyle(.plain)
            .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func sendIfReady() {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !isSending else { return }
        onSend()
    }
}
