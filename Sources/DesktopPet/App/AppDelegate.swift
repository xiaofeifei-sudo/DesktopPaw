import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var dependencies: AppDependencyContainer?
    private var coordinator: AppCoordinator?
    private var menuBarController: MenuBarController?
    private var settingsWindowController: SettingsWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        configureMainMenu()

        let dependencies = AppDependencyContainer()
        let settingsWindowController = SettingsWindowController(
            viewModel: dependencies.settingsViewModel,
            companionModel: dependencies.companionSettingsViewModel,
            interactiveBubbleModel: dependencies.interactiveBubbleSettingsViewModel,
            aiModel: dependencies.aiSettingsViewModel,
            aiVisualModel: dependencies.aiVisualSettingsViewModel,
            libraryViewModel: dependencies.libraryViewModel,
            importViewModel: dependencies.importViewModel,
            petdexURLImportViewModel: dependencies.petdexURLImportViewModel,
            actionLibraryViewModel: dependencies.actionLibraryViewModel
        )
        let coordinator = AppCoordinator(
            petWindow: dependencies.petWindow,
            petCommands: dependencies.petCommands,
            settingsWindow: settingsWindowController,
            launchAtLogin: dependencies.launchAtLogin,
            soundPlayer: dependencies.soundPlayer,
            application: NSApplicationTerminator(),
            actionTriggerService: dependencies.actionTriggerService,
            library: dependencies.library,
            bubble: dependencies.bubble,
            companionRouter: dependencies.companionEventRouter,
            microDialogService: dependencies.microDialogService,
            chatPanel: dependencies.chatPanelController,
            aiPreferencesStore: dependencies.aiPreferencesStore,
            aiMemoryStore: dependencies.aiMemoryStore,
            contentPackManager: dependencies.contentPackManager,
            onContentPacksChanged: { [weak dependencies] in
                dependencies?.refreshContentPackIntegrations()
            },
            speechBubbleEnabled: dependencies.settingsViewModel.isSpeechBubbleEnabled
        )
        let menuBarController = MenuBarController(coordinator: coordinator)
        let petId = dependencies.currentDefinition.id
        menuBarController.chatAvailableProvider = { true }
        menuBarController.petIdProvider = { petId }
        dependencies.petWindow.chatAvailableProvider = { true }
        dependencies.petWindow.petIdProvider = { petId }
        dependencies.petWindow.menuStateProvider = { [weak coordinator] in
            coordinator?.menuState
                ?? AppMenuState(isPetVisible: true, isSleeping: false, isLaunchAtLoginEnabled: false)
        }
        dependencies.petWindow.commandHandler = { [weak coordinator, weak menuBarController] command in
            coordinator?.handle(command)
            menuBarController?.refresh()
        }
        dependencies.petWindow.onDragStarted = { [weak dependencies] in
            dependencies?.petCommands.dragStarted()
        }
        dependencies.petWindow.onDragEnded = { [weak dependencies] in
            dependencies?.petCommands.dragEnded()
        }

        self.dependencies = dependencies
        self.settingsWindowController = settingsWindowController
        self.coordinator = coordinator
        self.menuBarController = menuBarController

        dependencies.configureSettingsActions(coordinator: coordinator, menuBarController: menuBarController)
        menuBarController.configure()
        coordinator.start()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationWillTerminate(_ notification: Notification) {
        dependencies?.stop()
        coordinator?.prepareForTermination()
    }

    private func configureMainMenu() {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(
            NSMenuItem(
                title: "Quit Desktop Pet",
                action: #selector(NSApplication.terminate(_:)),
                keyEquivalent: "q"
            )
        )
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(NSMenuItem(title: "Undo", action: Selector(("undo:")), keyEquivalent: "z"))
        editMenu.addItem(NSMenuItem(title: "Redo", action: Selector(("redo:")), keyEquivalent: "Z"))
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(NSMenuItem(title: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        editMenu.addItem(NSMenuItem(title: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        editMenu.addItem(NSMenuItem(title: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        editMenu.addItem(NSMenuItem(title: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        NSApp.mainMenu = mainMenu
    }
}
