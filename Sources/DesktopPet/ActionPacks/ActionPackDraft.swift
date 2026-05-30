import Foundation

public struct ActionPackDraft: Equatable, Sendable {
    public let manifest: ActionPackManifest
    public let resourceImages: [String: Data]
    public let previewData: Data?
    public let sourceMetadata: ActionPackSourceMetadata?

    public init(
        manifest: ActionPackManifest,
        resourceImages: [String: Data],
        previewData: Data? = nil,
        sourceMetadata: ActionPackSourceMetadata? = nil
    ) {
        self.manifest = manifest
        self.resourceImages = resourceImages
        self.previewData = previewData
        self.sourceMetadata = sourceMetadata
    }
}

public struct ActionPackLoadResult: Equatable, Sendable {
    public let packs: [ValidatedActionPack]
    public let warnings: [ActionPackWarning]

    public init(packs: [ValidatedActionPack], warnings: [ActionPackWarning]) {
        self.packs = packs
        self.warnings = warnings
    }
}
