import AppKit
import Foundation
import UniformTypeIdentifiers

@MainActor
public struct ActionPackImageOpenPanel {
    public typealias PanelRunner = @MainActor (NSOpenPanel) -> [URL]

    public static let defaultAllowedFileExtensions: [String] = ["png", "jpg", "jpeg"]

    private let allowedFileExtensions: [String]
    private let panelFactory: @MainActor () -> NSOpenPanel
    private let runner: PanelRunner

    public init(
        allowedFileExtensions: [String] = ActionPackImageOpenPanel.defaultAllowedFileExtensions,
        panelFactory: @escaping @MainActor () -> NSOpenPanel = { NSOpenPanel() },
        runner: @escaping PanelRunner = ActionPackImageOpenPanel.runModal
    ) {
        self.allowedFileExtensions = allowedFileExtensions
        self.panelFactory = panelFactory
        self.runner = runner
    }

    public func selectImages() -> [URL] {
        let panel = panelFactory()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.canCreateDirectories = false
        panel.title = "选择动作图片"
        panel.prompt = "选择"

        applyAllowedTypes(to: panel)

        let urls = runner(panel)
        return urls.filter { isAllowedExtension(url: $0) }
    }

    private func applyAllowedTypes(to panel: NSOpenPanel) {
        let types = allowedFileExtensions.compactMap { UTType(filenameExtension: $0) }
        guard !types.isEmpty else { return }
        panel.allowedContentTypes = types
    }

    private func isAllowedExtension(url: URL) -> Bool {
        let normalized = allowedFileExtensions.map { $0.lowercased() }
        return normalized.contains(url.pathExtension.lowercased())
    }

    @MainActor
    public static func runModal(_ panel: NSOpenPanel) -> [URL] {
        panel.runModal() == .OK ? panel.urls : []
    }
}
