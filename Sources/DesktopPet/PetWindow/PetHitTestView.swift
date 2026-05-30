import AppKit

@MainActor
public final class PetHitTestView: NSView {
    public var onMouseDown: ((NSEvent) -> Void)?
    public var onMouseDragged: ((NSEvent) -> Void)?
    public var onMouseUp: ((NSEvent) -> Void)?
    public var onRightMouseDown: ((NSEvent) -> Void)?
    public var drawsFallbackSymbol = true
    public var interactiveHitTestRegion: CGRect?
    public private(set) var isHovering = false

    private var hoverTrackingArea: NSTrackingArea?

    public override var acceptsFirstResponder: Bool { true }

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        nil
    }

    public override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    public override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let hoverTrackingArea {
            removeTrackingArea(hoverTrackingArea)
        }

        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
        hoverTrackingArea = trackingArea
    }

    public override func hitTest(_ point: NSPoint) -> NSView? {
        guard bounds.contains(point) else {
            return nil
        }

        guard interactiveHitTestRegion?.contains(point) == true else {
            return self
        }

        return super.hitTest(point) ?? self
    }

    public override func mouseDown(with event: NSEvent) {
        onMouseDown?(event)
    }

    public override func mouseDragged(with event: NSEvent) {
        onMouseDragged?(event)
    }

    public override func mouseUp(with event: NSEvent) {
        onMouseUp?(event)
    }

    public override func rightMouseDown(with event: NSEvent) {
        onRightMouseDown?(event)
    }

    public override func mouseEntered(with event: NSEvent) {
        applyHoverFeedback(true)
    }

    public override func mouseExited(with event: NSEvent) {
        applyHoverFeedback(false)
    }

    public func applyHoverFeedback(_ hovering: Bool) {
        isHovering = hovering
        alphaValue = hovering ? 0.92 : 1.0
    }

    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard drawsFallbackSymbol else {
            return
        }

        guard let symbol = NSImage(systemSymbolName: "pawprint.fill", accessibilityDescription: nil) else {
            return
        }

        let symbolSize = min(bounds.width, bounds.height) * 0.52
        let rect = NSRect(
            x: bounds.midX - symbolSize / 2,
            y: bounds.midY - symbolSize / 2,
            width: symbolSize,
            height: symbolSize
        )

        NSColor.controlAccentColor.withAlphaComponent(0.75).set()
        symbol.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 0.85)
    }
}
