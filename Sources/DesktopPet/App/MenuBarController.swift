import AppKit

@MainActor
public final class MenuBarController: NSObject {
    private let coordinator: AppCoordinator
    private let statusItem: NSStatusItem
    private let actionsMenuBuilder: any ActionsMenuBuilding
    public var chatAvailableProvider: (@MainActor () -> Bool)?
    public var petIdProvider: (@MainActor () -> String)?

    public init(
        coordinator: AppCoordinator,
        statusItem: NSStatusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength),
        actionsMenuBuilder: any ActionsMenuBuilding = ActionsMenuBuilder()
    ) {
        self.coordinator = coordinator
        self.statusItem = statusItem
        self.actionsMenuBuilder = actionsMenuBuilder
        super.init()
    }

    public func configure() {
        configureStatusButton()
        rebuildMenu()
    }

    public func refresh() {
        rebuildMenu()
    }

    private func configureStatusButton() {
        guard let button = statusItem.button else {
            return
        }

        if let image = NSImage(systemSymbolName: "pawprint.fill", accessibilityDescription: "Desktop Pet") {
            image.isTemplate = true
            button.image = image
        } else {
            button.title = "Pet"
        }
    }

    private func rebuildMenu() {
        let menu = NSMenu()
        let state = coordinator.menuState

        if state.isPetVisible {
            menu.addItem(commandItem(title: "Hide Pet", action: #selector(hidePet)))
        } else {
            menu.addItem(commandItem(title: "Show Pet", action: #selector(showPet)))
        }

        menu.addItem(NSMenuItem.separator())
        menu.addItem(commandItem(title: "Pet", action: #selector(pet)))
        menu.addItem(commandItem(title: "Feed", action: #selector(feed)))
        menu.addItem(commandItem(title: state.isSleeping ? "Wake" : "Sleep", action: #selector(sleepOrWake)))
        menu.addItem(actionsItem(for: state))
        menu.addItem(NSMenuItem.separator())
        if state.isQuietModeActive {
            menu.addItem(commandItem(title: "Resume Bubbles", action: #selector(clearQuietMode)))
        } else {
            menu.addItem(commandItem(title: "Quiet for 1 Hour", action: #selector(quietForOneHour)))
        }
        menu.addItem(commandItem(
            title: state.isSpeechBubbleEnabled ? "Hide Bubbles" : "Show Bubbles",
            action: #selector(toggleSpeechBubbles)
        ))
        menu.addItem(NSMenuItem.separator())
        if let actionNotice = state.actionNotice {
            menu.addItem(noticeItem(title: actionNotice))
        }
        menu.addItem(commandItem(title: "Reset Position", action: #selector(resetPosition)))
        if chatAvailableProvider?() == true {
            menu.addItem(commandItem(title: "Start Chat", action: #selector(openChat)))
        }
        menu.addItem(commandItem(title: "Settings", action: #selector(openSettings)))

        let launchAtLoginItem = commandItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin))
        launchAtLoginItem.state = state.isLaunchAtLoginEnabled ? .on : .off
        menu.addItem(launchAtLoginItem)

        menu.addItem(NSMenuItem.separator())
        menu.addItem(commandItem(title: "Quit", action: #selector(quit)))

        statusItem.menu = menu
    }

    private func commandItem(title: String, action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    private func actionsItem(for state: AppMenuState) -> NSMenuItem {
        let item = NSMenuItem(title: "Actions", action: nil, keyEquivalent: "")
        let submenu = actionsMenuBuilder.buildMenu(
            catalog: coordinator.actionCatalog,
            eligibility: { [weak coordinator] actionId in
                coordinator?.eligibility(for: actionId) ?? .rejectedUnknownActionId
            },
            trigger: { [weak self] actionId in
                self?.handle(.playAction(actionId))
            }
        )

        if state.isSleeping {
            submenu.addItem(NSMenuItem.separator())
            submenu.addItem(noticeItem(title: ActionTriggerService.busyReason))
        }

        item.submenu = submenu
        return item
    }

    private func noticeItem(title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    private func handle(_ command: AppCommand) {
        coordinator.handle(command)
        rebuildMenu()
    }

    @objc private func showPet() {
        handle(.showPet)
    }

    @objc private func hidePet() {
        handle(.hidePet)
    }

    @objc private func pet() {
        handle(.pet)
    }

    @objc private func feed() {
        handle(.feed)
    }

    @objc private func sleepOrWake() {
        handle(.sleepOrWake)
    }

    @objc private func resetPosition() {
        handle(.resetPosition)
    }

    @objc private func openSettings() {
        handle(.openSettings)
    }

    @objc private func toggleLaunchAtLogin() {
        handle(.setLaunchAtLogin(!coordinator.menuState.isLaunchAtLoginEnabled))
    }

    @objc private func quit() {
        coordinator.handle(.quit)
    }

    @objc private func quietForOneHour() {
        handle(.quietForOneHour)
    }

    @objc private func clearQuietMode() {
        handle(.clearQuietMode)
    }

    @objc private func toggleSpeechBubbles() {
        let currentlyEnabled = coordinator.menuState.isSpeechBubbleEnabled
        handle(.setSpeechBubbleEnabled(!currentlyEnabled))
    }

    @objc private func openChat() {
        let petId = petIdProvider?() ?? ""
        handle(.openChatPanel(petId: petId))
    }
}
