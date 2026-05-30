import AppKit
import Foundation
import UniformTypeIdentifiers

@MainActor
public protocol PetdexPackageSelecting {
    func selectPetdexPackage() -> URL?
}

@MainActor
public struct PetdexPackageOpenPanel: PetdexPackageSelecting {
    public typealias PanelRunner = @MainActor (NSOpenPanel) -> URL?

    public static let allowedFileExtension = "zip"

    private let panelFactory: @MainActor () -> NSOpenPanel
    private let runner: PanelRunner

    public init(
        panelFactory: @escaping @MainActor () -> NSOpenPanel = { NSOpenPanel() },
        runner: @escaping PanelRunner = PetdexPackageOpenPanel.runModal
    ) {
        self.panelFactory = panelFactory
        self.runner = runner
    }

    public func selectPetdexPackage() -> URL? {
        let panel = panelFactory()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.canCreateDirectories = false
        panel.title = "Choose Petdex Zip"
        panel.prompt = "Import"

        if let zipType = UTType(filenameExtension: Self.allowedFileExtension) {
            panel.allowedContentTypes = [zipType]
        }

        guard let url = runner(panel) else {
            return nil
        }
        return url.pathExtension.lowercased() == Self.allowedFileExtension ? url : nil
    }

    @MainActor
    public static func runModal(_ panel: NSOpenPanel) -> URL? {
        panel.runModal() == .OK ? panel.url : nil
    }
}
