import AppKit
import SwiftUI

@MainActor
public protocol PreviewPresenting: AnyObject {
    func showPreview(
        asset: PetVisualAsset,
        referencePreviewURL: URL,
        actions: PreviewActions
    )

    func dismissPreview()
}

@MainActor
public final class PreviewPresenter: PreviewPresenting {
    private var panel: NSPanel?
    private var currentActions: PreviewActions?
    private let getWindowFrame: @MainActor () -> NSRect?

    public init(getWindowFrame: @escaping @MainActor () -> NSRect? = { nil }) {
        self.getWindowFrame = getWindowFrame
    }

    public func showPreview(
        asset: PetVisualAsset,
        referencePreviewURL: URL,
        actions: PreviewActions
    ) {
        dismissPreview()

        currentActions = actions

        let previewView = AIVisualPreviewView(
            asset: asset,
            referencePreviewURL: referencePreviewURL,
            onApply: { [weak self] in
                guard let actions = self?.currentActions else { return }
                Task { await actions.onApply() }
                self?.dismissPreview()
            },
            onDiscard: { [weak self] in
                guard let actions = self?.currentActions else { return }
                Task { await actions.onDiscard() }
                self?.dismissPreview()
            },
            onRetry: { [weak self] in
                guard let actions = self?.currentActions else { return }
                Task { await actions.onRetry() }
                self?.dismissPreview()
            },
            onFeedback: { [weak self] type in
                guard let actions = self?.currentActions else { return }
                Task { await actions.onFeedback(type) }
            }
        )

        let newPanel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 380),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        newPanel.title = "预览生成结果"
        newPanel.isReleasedWhenClosed = false
        newPanel.level = .floating
        newPanel.contentView = NSHostingView(rootView: previewView)

        if let frame = getWindowFrame() {
            newPanel.setFrameOrigin(NSPoint(
                x: frame.midX - 240,
                y: frame.maxY + 10
            ))
        }

        newPanel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        panel = newPanel
    }

    public func dismissPreview() {
        panel?.orderOut(nil)
        panel = nil
        currentActions = nil
    }
}
