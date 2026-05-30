@preconcurrency import AppKit
import Foundation

@MainActor
public final class MultiAssetSpriteSheetRenderer: PetRenderable {
    public typealias ImageLoader = @MainActor (String) -> NSImage?

    public let definition: PetDefinition

    private let assetLibrary: PetRenderAssetLibrary
    private var loadedImages: [String: CGImage] = [:]
    private var loadedWholeImages: [String: NSImage] = [:]
    private var assetPreviewImages: [String: NSImage] = [:]
    private var previewImage: NSImage?
    private var placeholderImage: NSImage?
    private var cache: [String: [SpriteFrame: NSImage]] = [:]

    public init(
        definition: PetDefinition,
        assetLibrary: PetRenderAssetLibrary,
        imageLoader: ImageLoader = SpriteSheetRenderer.loadBundledImage(named:)
    ) {
        self.definition = definition
        self.assetLibrary = assetLibrary
        loadAssets(imageLoader: imageLoader)
        if let previewName = definition.previewAssetName {
            previewImage = imageLoader(previewName)
        }
        placeholderImage = imageLoader(PetDefinition.placeholderAssetName)
    }

    private func loadAssets(imageLoader: ImageLoader) {
        for (id, asset) in assetLibrary.assetsById {
            if let previewPath = asset.previewRelativePath,
               let preview = imageLoader(previewPath) {
                assetPreviewImages[id] = preview
            }

            switch asset.kind {
            case .gridImage:
                if let nsImage = imageLoader(asset.relativePath),
                   let cgImage = nsImage.desktopPetCGImage {
                    loadedImages[id] = cgImage
                }
            case .wholeImage:
                if let nsImage = imageLoader(asset.relativePath) {
                    loadedWholeImages[id] = nsImage
                }
            }
        }
    }

    public func image(for state: PetState) -> NSImage? {
        guard let frame = definition.animation(for: state)?.frames.first else {
            return fallbackImage()
        }
        return image(for: frame)
    }

    public func image(for state: PetState, frame: SpriteFrame?) -> NSImage? {
        if let frame {
            return image(for: frame)
        }
        return image(for: state)
    }

    public func image(for frame: SpriteFrame) -> NSImage? {
        let actionAssetId: String? = findActionForFrame(frame).flatMap {
            definition.catalog.resolve(actionId: $0)?.assetId
        }
        let resolvedAssetId = frame.assetId ?? actionAssetId ?? assetLibrary.defaultAssetId

        guard let asset = assetLibrary.resolve(resolvedAssetId) else {
            return fallbackImage()
        }

        switch asset.kind {
        case .gridImage:
            return gridImage(for: frame, assetId: asset.id, asset: asset)
        case .wholeImage:
            return loadedWholeImages[asset.id]
        }
    }

    private func gridImage(for frame: SpriteFrame, assetId: String, asset: PetRenderAsset) -> NSImage? {
        if let assetCache = cache[assetId], let cached = assetCache[frame] {
            return cached
        }

        guard let cgImage = loadedImages[assetId] else {
            return fallbackForAsset(asset)
        }

        let frameSize = asset.frameSize
        let cropRect = CGRect(
            x: Double(frame.column) * frameSize.width,
            y: Double(frame.row) * frameSize.height,
            width: frameSize.width,
            height: frameSize.height
        )

        guard cgImage.width >= Int(cropRect.maxX),
              cgImage.height >= Int(cropRect.maxY),
              let cropped = cgImage.cropping(to: cropRect) else {
            return fallbackForAsset(asset)
        }

        let size = CGSize(width: definition.frameSize.width, height: definition.frameSize.height)
        let nsImage = NSImage(cgImage: cropped, size: size)

        if cache[assetId] == nil {
            cache[assetId] = [:]
        }
        cache[assetId]?[frame] = nsImage
        return nsImage
    }

    private func fallbackForAsset(_ asset: PetRenderAsset) -> NSImage? {
        if let preview = assetPreviewImages[asset.id] {
            return preview
        }

        if let preview = previewImage {
            return preview
        }

        return placeholderImage
    }

    public func fallbackImage() -> NSImage? {
        let defaultAsset = assetLibrary.resolve(nil)
        if let asset = defaultAsset {
            return fallbackForAsset(asset)
        }

        return previewImage ?? placeholderImage
    }

    private func findActionForFrame(_ frame: SpriteFrame) -> ActionId? {
        for action in definition.catalog.actions {
            if action.frames.contains(frame) {
                return action.id
            }
        }
        return nil
    }
}

private extension NSImage {
    var desktopPetCGImage: CGImage? {
        var rect = CGRect(origin: .zero, size: size)
        return cgImage(forProposedRect: &rect, context: nil, hints: nil)
    }
}
