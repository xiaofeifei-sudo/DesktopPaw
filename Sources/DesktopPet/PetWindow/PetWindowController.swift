@preconcurrency import AppKit

@MainActor
public protocol PetWindowFrameStoring: AnyObject {
    func loadPetWindowFrame() -> CGRect?
    func savePetWindowFrame(_ frame: CGRect)
}

public struct PetWindowDragSession: Equatable {
    public let startFrame: CGRect
    public let startMouseLocation: CGPoint

    public init(startFrame: CGRect, startMouseLocation: CGPoint) {
        self.startFrame = startFrame
        self.startMouseLocation = startMouseLocation
    }

    public func hasExceededThreshold(currentMouseLocation: CGPoint, threshold: CGFloat = 4) -> Bool {
        let delta = delta(to: currentMouseLocation)
        return hypot(delta.x, delta.y) >= threshold
    }

    public func frame(currentMouseLocation: CGPoint) -> CGRect {
        let delta = delta(to: currentMouseLocation)
        return CGRect(
            x: startFrame.minX + delta.x,
            y: startFrame.minY + delta.y,
            width: startFrame.width,
            height: startFrame.height
        )
    }

    private func delta(to currentMouseLocation: CGPoint) -> CGPoint {
        CGPoint(
            x: currentMouseLocation.x - startMouseLocation.x,
            y: currentMouseLocation.y - startMouseLocation.y
        )
    }
}

@MainActor
public final class UserDefaultsPetWindowFrameStore: PetWindowFrameStoring {
    private let userDefaults: UserDefaults
    private let key: String

    public init(
        userDefaults: UserDefaults = .standard,
        key: String = "petWindowFrame"
    ) {
        self.userDefaults = userDefaults
        self.key = key
    }

    public func loadPetWindowFrame() -> CGRect? {
        guard let value = userDefaults.string(forKey: key) else {
            return nil
        }

        let frame = NSRectFromString(value)
        return frame.isEmpty ? nil : frame
    }

    public func savePetWindowFrame(_ frame: CGRect) {
        userDefaults.set(NSStringFromRect(frame), forKey: key)
    }
}

@MainActor
public final class PetWindowController: PetWindowControlling {
    public typealias CommandHandler = (AppCommand) -> Void
    public typealias MenuStateProvider = () -> AppMenuState
    public typealias ScreenGeometryProvider = () -> ScreenGeometry
    public typealias ContentViewProvider = (CGRect) -> NSView
    public typealias BubbleLayoutObserver = (PetBubble?, PetWindowLayout) -> Void
    public typealias ActionCatalogProvider = () -> PetActionCatalog
    public typealias MicroDialogOptionsProvider = @MainActor () -> [MicroDialogOption]?

    private static let dragThreshold: CGFloat = 4

    private var frameSize: CGSize
    private let frameStore: PetWindowFrameStoring
    private let screenGeometryProvider: ScreenGeometryProvider
    private var contentViewProvider: ContentViewProvider?
    private let layoutProvider: PetWindowLayoutProviding
    private var currentBubble: PetBubble?
    private var currentLayout: PetWindowLayout
    private var currentInteractiveBubble: InteractiveBubble?
    private var interactiveFeedbackActive = false
    private var panel: PetPanel?
    private var hitTestView: PetHitTestView?
    private var dragSession: PetWindowDragSession?
    private var didStartDrag = false
    private var screenObserver: NSObjectProtocol?
    private let petContextMenuBuilder: PetContextMenuBuilding

    public private(set) var isPetVisible = true
    public var currentPanelFrame: CGRect { panel?.frame ?? .zero }
    public var commandHandler: CommandHandler?
    public var menuStateProvider: MenuStateProvider?
    public var actionCatalogProvider: ActionCatalogProvider?
    public var actionTriggerService: ActionTriggerServicing?
    public var onDragStarted: (() -> Void)?
    public var onDragEnded: (() -> Void)?
    public var onVisibilityChanged: ((Bool) -> Void)?
    public var onBubbleLayoutChanged: BubbleLayoutObserver?
    public var microDialogOptionsProvider: MicroDialogOptionsProvider?
    public var chatAvailableProvider: (@MainActor () -> Bool)?
    public var petIdProvider: (@MainActor () -> String)?

    public init(
        frameSize: CGSize = CGSize(width: 128, height: 128),
        initiallyVisible: Bool = true,
        frameStore: PetWindowFrameStoring = UserDefaultsPetWindowFrameStore(),
        screenGeometryProvider: @escaping ScreenGeometryProvider = { ScreenGeometry.current() },
        contentViewProvider: ContentViewProvider? = nil,
        layoutProvider: PetWindowLayoutProviding = DefaultPetWindowLayoutProvider(),
        petContextMenuBuilder: PetContextMenuBuilding = PetContextMenuBuilder()
    ) {
        self.frameSize = frameSize
        self.isPetVisible = initiallyVisible
        self.frameStore = frameStore
        self.screenGeometryProvider = screenGeometryProvider
        self.contentViewProvider = contentViewProvider
        self.layoutProvider = layoutProvider
        self.currentLayout = layoutProvider.layout(petSize: frameSize, bubble: nil)
        self.petContextMenuBuilder = petContextMenuBuilder
        observeScreenChanges()
    }

    deinit {
        if let screenObserver {
            NotificationCenter.default.removeObserver(screenObserver)
        }
    }

    public func showPet() {
        isPetVisible = true
        DesktopPetLog.window.debug("Showing pet window.")
        onVisibilityChanged?(true)
        let panel = existingOrCreatePanel()
        panel.orderFrontRegardless()
    }

    public func hidePet() {
        isPetVisible = false
        DesktopPetLog.window.debug("Hiding pet window.")
        onVisibilityChanged?(false)
        panel?.orderOut(nil)
    }

    public func resetPosition() {
        let petFrame = screenGeometryProvider().defaultPetFrame(frameSize: frameSize)
        let layout = currentWindowLayout()
        let panelFrame = panelFrame(forPetFrame: petFrame, layout: layout)
        let clampedPanelFrame = screenGeometryProvider().clamp(frame: panelFrame)
        DesktopPetLog.window.info("Resetting pet window position.")
        let panel = existingOrCreatePanel()
        panel.setFrame(clampedPanelFrame, display: true)
        hitTestView?.frame = CGRect(origin: .zero, size: layout.contentSize)
        updateInteractiveHitTestRegion(for: layout)
        currentLayout = layout
        savePetFrame(panelFrame: clampedPanelFrame, layout: layout)
        notifyBubbleLayoutChanged(layout: layout)
    }

    public func saveStateBeforeQuit() {
        guard let panel else {
            return
        }

        savePetFrame(panelFrame: panel.frame, layout: currentLayout)
    }

    public func updateFrameSize(_ frameSize: CGSize) {
        guard frameSize.width > 0, frameSize.height > 0, self.frameSize != frameSize else {
            return
        }

        self.frameSize = frameSize
        applyLayoutPreservingPetAnchor()
    }

    public func updateBubble(_ bubble: PetBubble?) {
        guard currentBubble != bubble else {
            return
        }

        currentBubble = bubble
        applyLayoutPreservingPetAnchor()
    }

    public func updateInteractiveBubble(_ bubble: InteractiveBubble?) {
        currentInteractiveBubble = bubble
        applyLayoutPreservingPetAnchor()
    }

    public func updateInteractiveFeedback(_ text: String?) {
        interactiveFeedbackActive = text != nil
        applyLayoutPreservingPetAnchor()
    }

    public func updateContentView(_ provider: @escaping ContentViewProvider) {
        contentViewProvider = provider

        guard let hitTestView else {
            return
        }

        for subview in hitTestView.subviews {
            subview.removeFromSuperview()
        }

        let contentView = provider(hitTestView.bounds)
        contentView.frame = hitTestView.bounds
        contentView.autoresizingMask = [.width, .height]
        hitTestView.addSubview(contentView)
    }

    private func applyLayoutPreservingPetAnchor() {
        let layout = currentWindowLayout()

        guard let panel else {
            currentLayout = layout
            updateInteractiveHitTestRegion(for: layout)
            notifyBubbleLayoutChanged(layout: layout)
            return
        }

        let oldLayout = currentLayout
        let oldPanelOrigin = panel.frame.origin
        let petScreenOrigin = CGPoint(
            x: oldPanelOrigin.x + oldLayout.petOrigin.x,
            y: oldPanelOrigin.y + oldLayout.petOrigin.y
        )
        let newPanelOrigin = CGPoint(
            x: petScreenOrigin.x - layout.petOrigin.x,
            y: petScreenOrigin.y - layout.petOrigin.y
        )
        let newPanelFrame = CGRect(origin: newPanelOrigin, size: layout.contentSize)
        let clampedFrame = screenGeometryProvider().clamp(frame: newPanelFrame)
        if clampedFrame != newPanelFrame {
            DesktopPetLog.window.info("Pet window layout was clamped into visible bounds.")
        }

        panel.setFrame(clampedFrame, display: true)
        hitTestView?.frame = CGRect(origin: .zero, size: layout.contentSize)
        updateInteractiveHitTestRegion(for: layout)
        currentLayout = layout
        savePetFrame(panelFrame: clampedFrame, layout: layout)
        notifyBubbleLayoutChanged(layout: layout)
    }

    private func currentWindowLayout() -> PetWindowLayout {
        if let ib = currentInteractiveBubble {
            return interactiveBubbleLayout(ib)
        } else if interactiveFeedbackActive {
            let syntheticBubble = PetBubble(
                id: UUID(), text: "feedback",
                priority: .interaction,
                createdAt: Date(), expiresAt: Date().addingTimeInterval(3)
            )
            return layoutProvider.layout(petSize: frameSize, bubble: syntheticBubble)
        } else {
            return layoutProvider.layout(petSize: frameSize, bubble: currentBubble)
        }
    }

    private func updateInteractiveHitTestRegion(for layout: PetWindowLayout) {
        guard currentInteractiveBubble != nil,
              let bubbleOrigin = layout.bubbleOrigin,
              let bubbleSize = layout.bubbleSize else {
            hitTestView?.interactiveHitTestRegion = nil
            return
        }

        hitTestView?.interactiveHitTestRegion = CGRect(origin: bubbleOrigin, size: bubbleSize)
    }

    private func interactiveBubbleLayout(_ bubble: InteractiveBubble) -> PetWindowLayout {
        let spacing: CGFloat = 8
        let bubbleWidth = max(frameSize.width, InteractiveBubbleContainerView.maxWidth)

        let textHeight: CGFloat = 16 * CGFloat(InteractiveBubbleContainerView.maxLineLimit) + 6
        let optionCount = CGFloat(bubble.options.count)
        let optionsHeight = optionCount * InteractiveBubbleContainerView.optionMinHeight
            + max(0, optionCount - 1) * 2 + 6
        let bubbleHeight = textHeight + 4 + optionsHeight

        let contentWidth = bubbleWidth
        let contentHeight = frameSize.height + spacing + bubbleHeight

        let petOrigin = CGPoint(x: (contentWidth - frameSize.width) / 2, y: 0)
        let bubbleOrigin = CGPoint(x: (contentWidth - bubbleWidth) / 2, y: frameSize.height + spacing)

        return PetWindowLayout(
            petSize: frameSize,
            bubbleSize: CGSize(width: bubbleWidth, height: bubbleHeight),
            contentSize: CGSize(width: contentWidth, height: contentHeight),
            petOrigin: petOrigin,
            bubbleOrigin: bubbleOrigin
        )
    }

    private func panelFrame(forPetFrame petFrame: CGRect, layout: PetWindowLayout) -> CGRect {
        let panelOrigin = CGPoint(
            x: petFrame.origin.x - layout.petOrigin.x,
            y: petFrame.origin.y - layout.petOrigin.y
        )
        return CGRect(origin: panelOrigin, size: layout.contentSize)
    }

    private func savePetFrame(panelFrame: CGRect, layout: PetWindowLayout) {
        let petFrame = CGRect(
            origin: CGPoint(
                x: panelFrame.origin.x + layout.petOrigin.x,
                y: panelFrame.origin.y + layout.petOrigin.y
            ),
            size: frameSize
        )
        frameStore.savePetWindowFrame(petFrame)
    }

    private func notifyBubbleLayoutChanged(layout: PetWindowLayout) {
        onBubbleLayoutChanged?(currentBubble, layout)
    }

    private func existingOrCreatePanel() -> PetPanel {
        if let panel {
            return panel
        }

        let savedFrame = frameStore.loadPetWindowFrame()
        let resolvedPetFrame = screenGeometryProvider().startupFrame(
            savedFrame: savedFrame,
            frameSize: frameSize
        )
        let layout = currentWindowLayout()
        let initialPanelFrame = panelFrame(
            forPetFrame: CGRect(origin: resolvedPetFrame.origin, size: frameSize),
            layout: layout
        )
        let clampedPanelFrame = screenGeometryProvider().clamp(frame: initialPanelFrame)

        let panel = PetPanel(contentRect: clampedPanelFrame)
        let hitTestView = makeHitTestView(frame: CGRect(origin: .zero, size: layout.contentSize))
        panel.contentView = hitTestView
        self.panel = panel
        self.hitTestView = hitTestView
        updateInteractiveHitTestRegion(for: layout)
        currentLayout = layout
        savePetFrame(panelFrame: clampedPanelFrame, layout: layout)
        notifyBubbleLayoutChanged(layout: layout)
        return panel
    }

    private func makeHitTestView(frame: CGRect) -> PetHitTestView {
        let view = PetHitTestView(frame: frame)

        if let contentViewProvider {
            let contentView = contentViewProvider(view.bounds)
            contentView.frame = view.bounds
            contentView.autoresizingMask = [.width, .height]
            view.drawsFallbackSymbol = false
            view.addSubview(contentView)
        }

        view.onMouseDown = { [weak self] event in
            self?.handleMouseDown(event)
        }
        view.onMouseDragged = { [weak self] event in
            self?.handleMouseDragged(event)
        }
        view.onMouseUp = { [weak self] event in
            self?.handleMouseUp(event)
        }
        view.onRightMouseDown = { [weak self] event in
            self?.showContextMenu(for: event)
        }

        return view
    }

    private func handleMouseDown(_ event: NSEvent) {
        guard let panel else {
            return
        }

        dragSession = PetWindowDragSession(
            startFrame: panel.frame,
            startMouseLocation: NSEvent.mouseLocation
        )
        didStartDrag = false
    }

    private func handleMouseDragged(_ event: NSEvent) {
        guard let panel, let dragSession else {
            return
        }

        let currentLocation = NSEvent.mouseLocation

        if !didStartDrag && dragSession.hasExceededThreshold(
            currentMouseLocation: currentLocation,
            threshold: Self.dragThreshold
        ) {
            didStartDrag = true
            onDragStarted?()
        }

        guard didStartDrag else {
            return
        }

        let nextFrame = dragSession.frame(currentMouseLocation: currentLocation)
        panel.setFrame(nextFrame, display: true)
    }

    private func handleMouseUp(_ event: NSEvent) {
        defer {
            dragSession = nil
            didStartDrag = false
        }

        guard dragSession != nil else {
            return
        }

        guard didStartDrag else {
            commandHandler?(.clicked)
            return
        }

        guard let panel else {
            return
        }

        let clampedFrame = screenGeometryProvider().clamp(frame: panel.frame)
        if clampedFrame != panel.frame {
            DesktopPetLog.window.info("Dragged pet window frame was clamped into visible bounds.")
        }
        panel.setFrame(clampedFrame, display: true)
        savePetFrame(panelFrame: clampedFrame, layout: currentLayout)
        onDragEnded?()
    }

    private func showContextMenu(for event: NSEvent) {
        guard let view = hitTestView else {
            return
        }

        let menu = makeContextMenu()
        NSMenu.popUpContextMenu(menu, with: event, for: view)
    }

    public func contextMenuTitlesForCurrentState() -> [String] {
        makeContextMenu().items.map { item in
            item.isSeparatorItem ? "-" : item.title
        }
    }

    private func makeContextMenu() -> NSMenu {
        if let catalog = actionCatalogProvider?(), let actionTriggerService {
            let menu = petContextMenuBuilder.buildMenu(
                catalog: catalog,
                eligibility: { actionId in
                    actionTriggerService.eligibility(for: actionId)
                },
                trigger: { [weak self] actionId in
                    if let commandHandler = self?.commandHandler {
                        commandHandler(.playAction(actionId))
                    } else {
                        _ = actionTriggerService.trigger(actionId: actionId)
                    }
                }
            )
            appendMicroDialogOptions(to: menu)
            menu.addItem(NSMenuItem.separator())
            if chatAvailableProvider?() == true {
                menu.addItem(commandItem(title: "Start Chat", command: .openChatPanel(petId: petIdProvider?() ?? "")))
            }
            menu.addItem(commandItem(title: "Settings", command: .openSettings))
            menu.addItem(commandItem(title: "Quit", command: .quit))
            return menu
        }

        let state = menuStateProvider?()
            ?? AppMenuState(isPetVisible: isPetVisible, isSleeping: false, isLaunchAtLoginEnabled: false)
        let menu = NSMenu()

        appendMicroDialogOptions(to: menu)

        menu.addItem(commandItem(title: "Pet", command: .pet))
        menu.addItem(commandItem(title: "Feed", command: .feed))
        menu.addItem(commandItem(title: state.isSleeping ? "Wake" : "Sleep", command: .sleepOrWake))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(commandItem(title: "Hide Pet", command: .hidePet))
        menu.addItem(commandItem(title: "Reset Position", command: .resetPosition))
        if chatAvailableProvider?() == true {
            menu.addItem(commandItem(title: "Start Chat", command: .openChatPanel(petId: petIdProvider?() ?? "")))
        }
        menu.addItem(commandItem(title: "Settings", command: .openSettings))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(commandItem(title: "Quit", command: .quit))

        return menu
    }

    private func appendMicroDialogOptions(to menu: NSMenu) {
        guard let options = microDialogOptionsProvider?(), !options.isEmpty else { return }
        for option in options {
            menu.addItem(commandItem(title: option.title, command: .selectMicroDialogOption(option.id)))
        }
        menu.addItem(NSMenuItem.separator())
    }

    public func buildContextMenu() -> NSMenu {
        makeContextMenu()
    }

    private func commandItem(title: String, command: AppCommand) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: #selector(handleContextMenuItem(_:)), keyEquivalent: "")
        item.target = self
        item.representedObject = CommandBox(command)
        return item
    }

    @objc private func handleContextMenuItem(_ sender: NSMenuItem) {
        guard let box = sender.representedObject as? CommandBox else {
            return
        }

        commandHandler?(box.command)
    }

    private func observeScreenChanges() {
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.clampToVisibleScreenIfNeeded()
            }
        }
    }

    private func clampToVisibleScreenIfNeeded() {
        guard let panel else {
            return
        }

        let geometry = screenGeometryProvider()
        let clampedFrame = geometry.clamp(frame: panel.frame)
        if clampedFrame != panel.frame {
            DesktopPetLog.window.info("Screen change moved pet window back into visible bounds.")
            panel.setFrame(clampedFrame, display: true)
            savePetFrame(panelFrame: clampedFrame, layout: currentLayout)
        }
    }
}

private final class CommandBox: NSObject {
    let command: AppCommand

    init(_ command: AppCommand) {
        self.command = command
    }
}
