@preconcurrency import AppKit
import Foundation

@MainActor
public protocol PetRenderableFactory {
    func makeRenderer(for definition: PetDefinition, folderURL: URL?) -> PetRenderable
}

@MainActor
public final class DefaultPetRenderableFactory: PetRenderableFactory {
    public init() {}

    public func makeRenderer(for definition: PetDefinition, folderURL: URL? = nil) -> PetRenderable {
        let loader = Self.makeImageLoader(folderURL: folderURL)
        if let assetLibrary = definition.renderAssetLibrary {
            return MultiAssetSpriteSheetRenderer(
                definition: definition,
                assetLibrary: assetLibrary,
                imageLoader: loader
            )
        }
        switch definition.assetKind {
        case .spriteSheet:
            return SpriteSheetRenderer(definition: definition, imageLoader: loader)
        case .singleImage:
            return SingleImageRenderer(definition: definition, imageLoader: loader)
        }
    }

    public static func makeImageLoader(folderURL: URL?) -> @MainActor (String) -> NSImage? {
        guard let folderURL else {
            return SpriteSheetRenderer.loadBundledImage(named:)
        }

        return { name in
            let fileURL = folderURL.appendingPathComponent(name)
            if FileManager.default.fileExists(atPath: fileURL.path),
               let image = NSImage(contentsOf: fileURL) {
                return image
            }
            return SpriteSheetRenderer.loadBundledImage(named: name)
        }
    }
}
