import Foundation

public enum PetRenderAssetKind: String, Codable, Equatable, Sendable {
    case gridImage
    case wholeImage
}

public struct PetRenderAsset: Equatable, Sendable {
    public let id: String
    public let kind: PetRenderAssetKind
    public let relativePath: String
    public let frameSize: CGSizeCodable
    public let grid: SpriteSheetLayout?
    public let previewRelativePath: String?

    public init(
        id: String,
        kind: PetRenderAssetKind,
        relativePath: String,
        frameSize: CGSizeCodable,
        grid: SpriteSheetLayout? = nil,
        previewRelativePath: String? = nil
    ) {
        self.id = id
        self.kind = kind
        self.relativePath = relativePath
        self.frameSize = frameSize
        self.grid = grid
        self.previewRelativePath = previewRelativePath
    }
}

public struct PetRenderAssetLibrary: Equatable, Sendable {
    public let defaultAssetId: String
    public let assetsById: [String: PetRenderAsset]

    public init(defaultAssetId: String, assetsById: [String: PetRenderAsset]) {
        self.defaultAssetId = defaultAssetId
        self.assetsById = assetsById
    }

    public func resolve(_ assetId: String?) -> PetRenderAsset? {
        guard let assetId else {
            return assetsById[defaultAssetId]
        }
        return assetsById[assetId] ?? assetsById[defaultAssetId]
    }
}
