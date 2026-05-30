import SwiftUI

@MainActor
public final class ContentPackViewModel: ObservableObject {
    @Published public private(set) var packs: [ContentPack] = []
    @Published public private(set) var selectedPreview: ContentPackPreview?
    @Published public var errorMessage: String?

    private let manager: ContentPackManaging
    private let selector: ContentPackSelecting?

    public init(manager: ContentPackManaging, selector: ContentPackSelecting? = nil) {
        self.manager = manager
        self.selector = selector
        reload()
    }

    public func reload() {
        packs = manager.getInstalledPacks()
    }

    public func requestImport() {
        guard let url = selector?.selectContentPack() else { return }
        importPack(from: url)
    }

    public func importPack(from url: URL) {
        performAndReload {
            _ = try manager.importPack(from: url)
        }
    }

    public func enablePack(_ packId: String) {
        performAndReload {
            try manager.enablePack(packId)
        }
    }

    public func disablePack(_ packId: String) {
        performAndReload {
            try manager.disablePack(packId)
        }
    }

    public func removePack(_ packId: String) {
        performAndReload {
            try manager.removePack(packId)
            if selectedPreview?.packId == packId {
                selectedPreview = nil
            }
        }
    }

    public func restoreDefaultContent() {
        performAndReload {
            try manager.restoreDefaultContent()
        }
    }

    public func previewPack(_ packId: String) {
        do {
            selectedPreview = try manager.previewPack(packId)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func performAndReload(_ operation: () throws -> Void) {
        do {
            try operation()
            errorMessage = nil
            reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

public struct ContentPackView: View {
    @ObservedObject private var model: ContentPackViewModel

    public init(model: ContentPackViewModel) {
        self.model = model
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Content Packs")
                    .font(.headline)
                Spacer()
                Button("Import") {
                    model.requestImport()
                }
                .buttonStyle(.bordered)
                Button("Restore Defaults") {
                    model.restoreDefaultContent()
                }
                .buttonStyle(.bordered)
            }

            if model.packs.isEmpty {
                Text("No content packs installed.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                packList
            }

            if let preview = model.selectedPreview {
                Divider()
                previewView(preview)
            }

            if let message = model.errorMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    private var packList: some View {
        List {
            ForEach(model.packs) { pack in
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(pack.manifest.name)
                            .font(.subheadline.weight(.medium))
                        Text("\(pack.manifest.type.rawValue) · \(pack.manifest.author)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Preview") {
                        model.previewPack(pack.id)
                    }
                    .controlSize(.small)
                    if pack.isEnabled {
                        Button("Disable") {
                            model.disablePack(pack.id)
                        }
                        .controlSize(.small)
                    } else {
                        Button("Enable") {
                            model.enablePack(pack.id)
                        }
                        .controlSize(.small)
                    }
                    Button("Remove", role: .destructive) {
                        model.removePack(pack.id)
                    }
                    .controlSize(.small)
                }
            }
        }
        .frame(minHeight: 160)
    }

    private func previewView(_ preview: ContentPackPreview) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(preview.name)
                .font(.subheadline.weight(.medium))
            ForEach(preview.previewPhrases + preview.phrases + preview.actionNames, id: \.self) { item in
                Text(item)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
