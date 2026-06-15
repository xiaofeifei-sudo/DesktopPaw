import AppKit

/// 应用入口代理
///
/// 负责应用生命周期管理，在 applicationDidFinishLaunching 中：
/// 1. 设置为 accessory 模式（无 Dock 图标，仅菜单栏）
/// 2. 创建依赖注入容器 AppDependencyContainer
/// 3. 组装 AppCoordinator → MenuBarController → SettingsWindowController
/// 4. 绑定 PetWindow 的各种回调和交互
///
/// 这是整个应用的「装配线」，把所有组件连接在一起。
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// 依赖注入容器（持有所有核心服务）
    private var dependencies: AppDependencyContainer?
    /// 应用协调器（命令路由中枢）
    private var coordinator: AppCoordinator?
    /// 菜单栏控制器
    private var menuBarController: MenuBarController?
    /// 设置窗口控制器
    private var settingsWindowController: SettingsWindowController?

    // MARK: - 应用生命周期

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 设置为 accessory 模式：无 Dock 图标，仅菜单栏可见
        NSApp.setActivationPolicy(.accessory)
        configureMainMenu()

        // 1. 创建语言管理器（最先创建，供后续所有组件共享）
        let languageManager = LanguageManager()

        // 2. 创建依赖注入容器（内部完成所有服务的初始化）
        let dependencies = AppDependencyContainer()

        // 3. 创建设置窗口
        let settingsWindowController = SettingsWindowController(
            viewModel: dependencies.settingsViewModel,
            companionModel: dependencies.companionSettingsViewModel,
            interactiveBubbleModel: dependencies.interactiveBubbleSettingsViewModel,
            aiModel: dependencies.aiSettingsViewModel,
            aiVisualModel: dependencies.aiVisualSettingsViewModel,
            libraryViewModel: dependencies.libraryViewModel,
            importViewModel: dependencies.importViewModel,
            petdexURLImportViewModel: dependencies.petdexURLImportViewModel,
            actionLibraryViewModel: dependencies.actionLibraryViewModel,
            languageManager: languageManager
        )

        // 4. 创建协调器（命令路由中枢）
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
            speechBubbleEnabled: dependencies.settingsViewModel.isSpeechBubbleEnabled,
            languageManager: languageManager
        )

        // 5. 创建菜单栏控制器
        let menuBarController = MenuBarController(
            coordinator: coordinator,
            languageManager: languageManager
        )
        let petId = dependencies.currentDefinition.id
        menuBarController.chatAvailableProvider = { true }
        menuBarController.petIdProvider = { petId }

        // 6. 配置宠物窗口的回调和交互
        dependencies.petWindow.chatAvailableProvider = { true }
        dependencies.petWindow.petIdProvider = { petId }
        dependencies.petWindow.menuStateProvider = { [weak coordinator] in
            coordinator?.menuState
                ?? AppMenuState(isPetVisible: true, isSleeping: false, isLaunchAtLoginEnabled: false)
        }
        // 窗口命令路由
        dependencies.petWindow.commandHandler = { [weak coordinator, weak menuBarController] command in
            coordinator?.handle(command)
            menuBarController?.refresh()
        }
        // 拖拽回调
        dependencies.petWindow.onDragStarted = { [weak dependencies] in
            dependencies?.petCommands.dragStarted()
        }
        dependencies.petWindow.onDragEnded = { [weak dependencies] in
            dependencies?.petCommands.dragEnded()
        }

        // 7. 持有引用，防止被释放
        self.dependencies = dependencies
        self.settingsWindowController = settingsWindowController
        self.coordinator = coordinator
        self.menuBarController = menuBarController

        // 8. 完成配置并启动
        dependencies.configureSettingsActions(coordinator: coordinator, menuBarController: menuBarController)
        menuBarController.configure()
        coordinator.start()
    }

    /// 关闭最后一个窗口不退出应用（宠物是桌面悬浮窗，不视为传统窗口）
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    /// 应用退出前保存状态
    func applicationWillTerminate(_ notification: Notification) {
        dependencies?.stop()
        coordinator?.prepareForTermination()
    }

    // MARK: - 主菜单

    /// 配置应用主菜单（Edit 菜单 + Quit 项）
    private func configureMainMenu() {
        let mainMenu = NSMenu()

        // App 菜单
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

        // Edit 菜单（标准编辑操作）
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
