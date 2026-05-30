import SwiftUI

public struct AIChatPanelView: View {
    @ObservedObject private var viewModel: ChatPanelViewModel

    public init(viewModel: ChatPanelViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 0) {
            messageList
            Divider()
            AIChatInputView(
                text: $viewModel.inputText,
                isSending: viewModel.isSending,
                onSend: { viewModel.sendMessage() }
            )
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(viewModel.messages) { message in
                        ChatMessageBubble(message: message)
                            .id(message.id)
                    }
                    if let streaming = viewModel.streamingText, !streaming.isEmpty {
                        ChatMessageBubble(
                            message: AIChatMessage(role: .assistant, content: streaming)
                        )
                        .id("streaming")
                    }
                }
                .padding(12)
            }
            .onChange(of: viewModel.messages.count) { _ in
                if let last = viewModel.messages.last {
                    withAnimation {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
            .onChange(of: viewModel.streamingText) { _ in
                withAnimation {
                    proxy.scrollTo("streaming", anchor: .bottom)
                }
            }
        }
    }
}

private struct ChatMessageBubble: View {
    let message: AIChatMessage

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 60) }
            Text(message.content)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(bubbleBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .foregroundStyle(bubbleForeground)
            if message.role == .assistant { Spacer(minLength: 60) }
        }
    }

    private var bubbleBackground: Color {
        switch message.role {
        case .user: Color.accentColor.opacity(0.15)
        case .assistant: Color(nsColor: .controlBackgroundColor)
        case .system: Color(nsColor: .separatorColor).opacity(0.3)
        }
    }

    private var bubbleForeground: Color {
        switch message.role {
        case .user: .primary
        case .assistant: .primary
        case .system: .secondary
        }
    }
}
