import AppKit
import Combine

/// 菜单栏控制器
///
/// 管理系统菜单栏上的 🐾 图标及其下拉菜单。
/// 菜单内容根据 AppMenuState 动态重建：
/// - 显示/隐藏宠物
/// - 抚摸/喂食/睡觉切换
/// - 动作子菜单（通过 ActionsMenuBuilder）
/// - 静音/气泡开关
/// - 聊天/设置/开机自启/退出
///
/// 每次菜单打开或状态变化时调用 rebuildMenu() 刷新。
@MainActor
public final class MenuBarController: NSObject {
    /// 应用协调器（命令路由）
    private let coordinator: AppCoordinator
    /// 系统状态栏项
    private let statusItem: NSStatusItem
    /// 动作菜单构建器
    private let actionsMenuBuilder: any ActionsMenuBuilding

    /// 聊天功能是否可用的外部提供者
    public var chatAvailableProvider: (@MainActor () -> Bool)?
    /// 当前宠物 ID 的外部提供者
    public var petIdProvider: (@MainActor () -> String)?
    /// 语言管理器（用于获取当前语言、监听变更）
    private let languageManager: LanguageManager?
    /// 语言变更观察 token
    private var languageChangeToken: AnyCancellable?

    public init(
        coordinator: AppCoordinator,
        statusItem: NSStatusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength),
        actionsMenuBuilder: any ActionsMenuBuilding = ActionsMenuBuilder(),
        languageManager: LanguageManager? = nil
    ) {
        self.coordinator = coordinator
        self.statusItem = statusItem
        self.actionsMenuBuilder = actionsMenuBuilder
        self.languageManager = languageManager
        super.init()

        // 同步语言并监听变更
        L10n.language = languageManager?.currentLanguage ?? .default
        languageChangeToken = languageManager?.objectWillChange.sink { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                L10n.language = self.languageManager?.currentLanguage ?? .default
                self.refresh()
            }
        }
    }

    // MARK: - 公共接口

    /// 初始化：配置状态栏按钮并构建菜单
    public func configure() {
        configureStatusButton()
        rebuildMenu()
    }

    /// 刷新菜单（状态变化时调用）
    public func refresh() {
        rebuildMenu()
    }

    // MARK: - 状态栏按钮

    /// 设置状态栏按钮图标为 pawprint.fill SF Symbol
    private func configureStatusButton() {
        guard let button = statusItem.button else {
            return
        }

        if let image = NSImage(systemSymbolName: "pawprint.fill", accessibilityDescription: "Desktop Pet") {
            image.isTemplate = true  // 跟随系统明暗模式自动调整
            button.image = image
        } else {
            button.title = "Pet"
        }
    }

    // MARK: - 菜单构建

    /// 根据当前 menuState 动态重建整个菜单
    private func rebuildMenu() {
        let menu = NSMenu()
        let state = coordinator.menuState

        // --- 显示/隐藏 ---
        if state.isPetVisible {
            menu.addItem(commandItem(title: L10n.Menu.hidePet, action: #selector(hidePet)))
        } else {
            menu.addItem(commandItem(title: L10n.Menu.showPet, action: #selector(showPet)))
        }

        menu.addItem(NSMenuItem.separator())

        // --- 基础交互 ---
        menu.addItem(commandItem(title: L10n.Menu.pet, action: #selector(pet)))
        menu.addItem(commandItem(title: L10n.Menu.feed, action: #selector(feed)))
        menu.addItem(commandItem(title: state.isSleeping ? L10n.Menu.wake : L10n.Menu.sleep, action: #selector(sleepOrWake)))

        // --- 动作子菜单 ---
        menu.addItem(actionsItem(for: state))
        menu.addItem(NSMenuItem.separator())

        // --- 静音 / 气泡控制 ---
        if state.isQuietModeActive {
            menu.addItem(commandItem(title: L10n.Menu.resumeBubbles, action: #selector(clearQuietMode)))
        } else {
            menu.addItem(commandItem(title: L10n.Menu.quietForOneHour, action: #selector(quietForOneHour)))
        }
        menu.addItem(commandItem(
            title: state.isSpeechBubbleEnabled ? L10n.Menu.hideBubbles : L10n.Menu.showBubbles,
            action: #selector(toggleSpeechBubbles)
        ))
        menu.addItem(NSMenuItem.separator())

        // --- 动作提示（如"宠物正忙"） ---
        if let actionNotice = state.actionNotice {
            menu.addItem(noticeItem(title: actionNotice))
        }

        // --- 工具 ---
        menu.addItem(commandItem(title: L10n.Menu.resetPosition, action: #selector(resetPosition)))
        if chatAvailableProvider?() == true {
            menu.addItem(commandItem(title: L10n.Menu.startChat, action: #selector(openChat)))
        }
        menu.addItem(commandItem(title: L10n.Menu.settings, action: #selector(openSettings)))

        // --- 开机自启（带勾选状态） ---
        let launchAtLoginItem = commandItem(title: L10n.Menu.launchAtLogin, action: #selector(toggleLaunchAtLogin))
        launchAtLoginItem.state = state.isLaunchAtLoginEnabled ? .on : .off
        menu.addItem(launchAtLoginItem)

        // --- 语言切换 ---
        if let lm = languageManager {
            menu.addItem(languageMenuItem(languageManager: lm))
        }

        menu.addItem(NSMenuItem.separator())

        // --- 退出 ---
        menu.addItem(commandItem(title: L10n.Menu.quit, action: #selector(quit)))

        statusItem.menu = menu
    }

    // MARK: - 辅助方法

    /// 创建带 target 的可点击菜单项
    private func commandItem(title: String, action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    /// 构建 Actions 子菜单（嵌套在 "Actions" 项下）
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

        // 睡觉状态下在子菜单底部追加提示
        if state.isSleeping {
            submenu.addItem(NSMenuItem.separator())
            submenu.addItem(noticeItem(title: ActionTriggerService.busyReason))
        }

        item.submenu = submenu
        return item
    }

    /// 创建禁用状态的提示项（灰色不可点击）
    private func noticeItem(title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    /// 构建语言切换子菜单
    private func languageMenuItem(languageManager lm: LanguageManager) -> NSMenuItem {
        let item = NSMenuItem(title: L10n.Menu.language, action: nil, keyEquivalent: "")
        let submenu = NSMenu(title: L10n.Menu.language)

        for language in AppLanguage.allCases {
            let langItem = NSMenuItem(
                title: language.displayName,
                action: #selector(selectLanguage(_:)),
                keyEquivalent: ""
            )
            langItem.target = self
            langItem.representedObject = language
            langItem.state = (lm.currentLanguage == language) ? .on : .off
            submenu.addItem(langItem)
        }

        item.submenu = submenu
        return item
    }

    @objc private func selectLanguage(_ sender: NSMenuItem) {
        guard let language = sender.representedObject as? AppLanguage else { return }
        coordinator.handle(.setAppLanguage(language))
    }

    /// 统一命令处理入口
    private func handle(_ command: AppCommand) {
        coordinator.handle(command)
        rebuildMenu()
    }

    // MARK: - @objc 动作方法

    @objc private func showPet() { handle(.showPet) }
    @objc private func hidePet() { handle(.hidePet) }
    @objc private func pet() { handle(.pet) }
    @objc private func feed() { handle(.feed) }
    @objc private func sleepOrWake() { handle(.sleepOrWake) }
    @objc private func resetPosition() { handle(.resetPosition) }
    @objc private func openSettings() { handle(.openSettings) }
    @objc private func quit() { coordinator.handle(.quit) }
    @objc private func quietForOneHour() { handle(.quietForOneHour) }
    @objc private func clearQuietMode() { handle(.clearQuietMode) }

    @objc private func toggleLaunchAtLogin() {
        handle(.setLaunchAtLogin(!coordinator.menuState.isLaunchAtLoginEnabled))
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
