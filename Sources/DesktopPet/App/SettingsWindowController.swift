import AppKit
import SwiftUI

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
    private var window: NSWindow?
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
        actionLibraryViewModel: ActionLibraryViewModel? = nil
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
    }

    public func showSettings() {
        let window = existingOrCreateWindow()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func existingOrCreateWindow() -> NSWindow {
        if let window {
            return window
        }

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
                actionLibraryModel: actionLibraryViewModel
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
        window.isReleasedWhenClosed = false
        self.window = window
        createdWindowCount += 1
        return window
    }
}
