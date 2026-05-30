import AppKit
import UniformTypeIdentifiers

@MainActor
public protocol ContentPackSelecting: AnyObject {
    func selectContentPack() -> URL?
}

@MainActor
public final class ContentPackOpenPanel: ContentPackSelecting {
    public init() {}

    public func selectContentPack() -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        if let type = UTType(filenameExtension: "dpcp") {
            panel.allowedContentTypes = [type]
        }
        return panel.runModal() == .OK ? panel.url : nil
    }
}
