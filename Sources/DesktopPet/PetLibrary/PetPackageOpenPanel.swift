import AppKit
import Foundation

@MainActor
public struct PetPackageOpenPanel: PetPackageSelecting {
    public typealias PanelRunner = @MainActor (NSOpenPanel) -> URL?

    private let panelFactory: @MainActor () -> NSOpenPanel
    private let runner: PanelRunner

    public init(
        panelFactory: @escaping @MainActor () -> NSOpenPanel = { NSOpenPanel() },
        runner: @escaping PanelRunner = PetPackageOpenPanel.runModal
    ) {
        self.panelFactory = panelFactory
        self.runner = runner
    }

    public func selectPackage() -> URL? {
        let panel = panelFactory()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = false
        panel.title = "Choose Pet Package"
        panel.prompt = "Import"

        guard let url = runner(panel) else {
            return nil
        }
        return url.pathExtension.lowercased() == PetPackageLoader.packageExtension ? url : nil
    }

    @MainActor
    public static func runModal(_ panel: NSOpenPanel) -> URL? {
        panel.runModal() == .OK ? panel.url : nil
    }
}
