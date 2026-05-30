import AppKit
import Foundation
import UniformTypeIdentifiers

@MainActor
public struct PetImageOpenPanel: PetImageSelecting {
    public typealias PanelRunner = @MainActor (NSOpenPanel) -> URL?

    public static let defaultAllowedFileExtensions: [String] = ["png", "jpg", "jpeg"]

    private let allowedFileExtensions: [String]
    private let panelFactory: @MainActor () -> NSOpenPanel
    private let runner: PanelRunner

    public init(
        allowedFileExtensions: [String] = PetImageOpenPanel.defaultAllowedFileExtensions,
        panelFactory: @escaping @MainActor () -> NSOpenPanel = { NSOpenPanel() },
        runner: @escaping PanelRunner = PetImageOpenPanel.runModal
    ) {
        self.allowedFileExtensions = allowedFileExtensions
        self.panelFactory = panelFactory
        self.runner = runner
    }

    public func selectImage() -> URL? {
        let panel = panelFactory()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.canCreateDirectories = false
        panel.title = "Choose Pet Image"
        panel.prompt = "Use"

        applyAllowedTypes(to: panel)

        guard let url = runner(panel) else {
            return nil
        }
        return isAllowedExtension(url: url) ? url : nil
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
    public static func runModal(_ panel: NSOpenPanel) -> URL? {
        panel.runModal() == .OK ? panel.url : nil
    }
}
