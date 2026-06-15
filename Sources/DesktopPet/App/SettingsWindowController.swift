import AppKit
import SwiftUI

/// 设置窗口控制器
///
/// 管理设置面板 NSWindow 的生命周期：
/// - 首次打开时创建窗口（含所有设置 Tab 的 SwiftUI View）
/// - 后续打开复用已有窗口
/// - 使用 `isReleasedWhenClosed = false` 防止关闭后窗口被释放
@MainActor
public final class SettingsWindowController: SettingsWindowControlling {
    private let viewModel: SettingsViewModel
    private let companionModel: CompanionshipSettingsViewModel?
    private let interactiveBubbleModel: InteractiveBubbleSettingsViewModel?
    private let aiModel: AISettingsViewModel?
    private let aiVisualModel: AIVisualSettingsViewModel?
    private let libraryViewModel: PetLibraryViewModel?
    private let importViewModel: PetImportViewModel?
    private let petdexURLImportViewModel: PetdexURLImportViewModel?
    private let actionLibraryViewModel: ActionLibraryViewModel?
    private let languageManager: LanguageManager?

    /// 持有的设置窗口引用（单例复用）
    private var window: NSWindow?
    /// 创建的窗口计数（用于调试）
    public private(set) var createdWindowCount = 0

    public init(
        viewModel: SettingsViewModel = SettingsViewModel(),
        companionModel: CompanionshipSettingsViewModel? = nil,
        interactiveBubbleModel: InteractiveBubbleSettingsViewModel? = nil,
        aiModel: AISettingsViewModel? = nil,
        aiVisualModel: AIVisualSettingsViewModel? = nil,
        libraryViewModel: PetLibraryViewModel? = nil,
        importViewModel: PetImportViewModel? = nil,
        petdexURLImportViewModel: PetdexURLImportViewModel? = nil,
        actionLibraryViewModel: ActionLibraryViewModel? = nil,
        languageManager: LanguageManager? = nil
    ) {
        self.viewModel = viewModel
        self.companionModel = companionModel
        self.interactiveBubbleModel = interactiveBubbleModel
        self.aiModel = aiModel
        self.aiVisualModel = aiVisualModel
        self.libraryViewModel = libraryViewModel
        self.importViewModel = importViewModel
        self.petdexURLImportViewModel = petdexURLImportViewModel
        self.actionLibraryViewModel = actionLibraryViewModel
        self.languageManager = languageManager
    }

    /// 显示设置窗口（如已存在则前置）
    public func showSettings() {
        let window = existingOrCreateWindow()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// 获取已有窗口或创建新窗口
    private func existingOrCreateWindow() -> NSWindow {
        if let window {
            return window
        }

        // 使用 NSHostingView 包装 SwiftUI 的 SettingsView
        let contentView = NSHostingView(
            rootView: SettingsView(
                model: viewModel,
                companionModel: companionModel,
                interactiveBubbleModel: interactiveBubbleModel,
                aiModel: aiModel,
                aiVisualModel: aiVisualModel,
                libraryModel: libraryViewModel,
                importModel: importViewModel,
                petdexURLImportModel: petdexURLImportViewModel,
                actionLibraryModel: actionLibraryViewModel,
                languageManager: languageManager
            )
        )
        contentView.frame = NSRect(x: 0, y: 0, width: 460, height: 680)
        let window = NSWindow(
            contentRect: contentView.frame,
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Desktop Pet Settings"
        window.center()
        window.contentView = contentView
        // 关闭后不释放，下次直接复用
        window.isReleasedWhenClosed = false
        self.window = window
        createdWindowCount += 1
        return window
    }
}
