import AppKit
import SwiftUI

@MainActor
public protocol ChatPanelControlling: AnyObject {
    func showChatPanel(petId: String)
    func closeChatPanel()
    func sendMessage(_ text: String, petId: String)
    var isPanelVisible: Bool { get }
}

@MainActor
public final class ChatPanelController: ChatPanelControlling {
    private var window: NSPanel?
    private var viewModel: ChatPanelViewModel?

    private let chatEngine: AIChatEngining
    private let bubbleBridge: AIBubbleBridging?
    private let visualActionMediator: AIVisualActionMediating?
    private let getPetWindowFrame: @MainActor () -> CGRect?
    private let screenGeometryProvider: @MainActor () -> ScreenGeometry

    public init(
        chatEngine: AIChatEngining,
        bubbleBridge: AIBubbleBridging? = nil,
        visualActionMediator: AIVisualActionMediating? = nil,
        getPetWindowFrame: @escaping @MainActor () -> CGRect? = { nil },
        screenGeometryProvider: @escaping @MainActor () -> ScreenGeometry = { .current() }
    ) {
        self.chatEngine = chatEngine
        self.bubbleBridge = bubbleBridge
        self.visualActionMediator = visualActionMediator
        self.getPetWindowFrame = getPetWindowFrame
        self.screenGeometryProvider = screenGeometryProvider
    }

    public var isPanelVisible: Bool {
        window?.isVisible == true
    }

    public func showChatPanel(petId: String) {
        let window = existingOrCreateWindow(petId: petId)
        positionWindowNearPet(window)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        viewModel?.loadSession()
    }

    public func closeChatPanel() {
        window?.orderOut(nil)
    }

    public func sendMessage(_ text: String, petId: String) {
        _ = existingOrCreateWindow(petId: petId)
        viewModel?.inputText = text
        viewModel?.sendMessage()
    }

    private func existingOrCreateWindow(petId: String) -> NSPanel {
        if let window {
            return window
        }

        let vm = ChatPanelViewModel(chatEngine: chatEngine, petId: petId)
        vm.onBubbleEmitted = { [weak self] response in
            _ = self?.bubbleBridge?.emitBubble(from: response, petId: petId)
            if !response.visualActionCandidates.isEmpty {
                self?.visualActionMediator?.handleCandidates(from: response, petId: petId)
            }
        }
        self.viewModel = vm

        let contentView = NSHostingView(rootView: AIChatPanelView(viewModel: vm))
        contentView.frame = NSRect(x: 0, y: 0, width: 340, height: 440)

        let panel = NSPanel(
            contentRect: contentView.frame,
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        panel.title = "Chat"
        panel.contentView = contentView
        panel.isReleasedWhenClosed = false
        panel.level = .floating

        self.window = panel
        return panel
    }

    private func positionWindowNearPet(_ window: NSPanel) {
        let panelSize = window.frame.size
        let petFrame = getPetWindowFrame()
        let geometry = screenGeometryProvider()
        guard let visible = geometry.visibleFrames.first else { return }

        let position: CGPoint
        if let petFrame = petFrame {
            let offset: CGFloat = 20
            var x = petFrame.maxX + offset
            var y = petFrame.minY

            if x + panelSize.width > visible.maxX {
                x = petFrame.minX - offset - panelSize.width
            }
            if x < visible.minX {
                x = petFrame.maxX + offset
            }
            if y + panelSize.height > visible.maxY {
                y = visible.maxY - panelSize.height
            }
            if y < visible.minY {
                y = visible.minY
            }
            position = CGPoint(x: x, y: y)
        } else {
            position = CGPoint(
                x: visible.maxX - panelSize.width - 20,
                y: visible.minY + 20
            )
        }

        window.setFrameOrigin(position)
    }
}
