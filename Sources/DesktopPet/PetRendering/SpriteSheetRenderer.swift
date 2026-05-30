@preconcurrency import AppKit
import Foundation

@MainActor
public final class SpriteSheetRenderer: PetRenderable {
    public typealias ImageLoader = @MainActor (String) -> NSImage?

    private enum Source {
        case spriteSheet(CGImage)
        case wholeImage(NSImage)
        case missing
    }

    public let definition: PetDefinition

    private let source: Source
    private var cache: [SpriteFrame: NSImage] = [:]
    private var transparentFrameCache: [SpriteFrame: Bool] = [:]

    public init(
        definition: PetDefinition,
        imageLoader: ImageLoader = SpriteSheetRenderer.loadBundledImage(named:)
    ) {
        self.definition = definition

        if let spriteSheet = imageLoader(definition.assetName)?.desktopPetCGImage,
           Self.canCrop(spriteSheet, for: definition) {
            self.source = .spriteSheet(spriteSheet)
        } else if let previewAssetName = definition.previewAssetName,
                  let preview = imageLoader(previewAssetName) {
            DesktopPetLog.assets.warning("Spritesheet resource unavailable for \(definition.id, privacy: .public); using preview fallback.")
            self.source = .wholeImage(preview)
        } else if let placeholder = imageLoader(PetDefinition.placeholderAssetName) {
            DesktopPetLog.assets.warning("Pet resources unavailable for \(definition.id, privacy: .public); using placeholder fallback.")
            self.source = .wholeImage(placeholder)
        } else {
            DesktopPetLog.assets.error("Pet resources unavailable for \(definition.id, privacy: .public), including placeholder.")
            self.source = .missing
        }
    }

    public static func loadBundledImage(named name: String) -> NSImage? {
        guard let url = bundledResourceURL(named: name) else {
            return nil
        }

        return NSImage(contentsOf: url)
    }

    public static func bundledResourceURL(named name: String) -> URL? {
        let url = URL(fileURLWithPath: name)
        let resourceName = url.deletingPathExtension().lastPathComponent
        let fileExtension = url.pathExtension.isEmpty ? "png" : url.pathExtension
        return DesktopPetResources.url(named: resourceName, extension: fileExtension)
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
        switch source {
        case .spriteSheet(let spriteSheet):
            let resolvedFrame = visibleFrame(for: frame, in: spriteSheet)
            if let cached = cache[resolvedFrame] {
                return cached
            }

            guard let cropped = spriteSheet.cropping(to: cropRect(for: resolvedFrame)) else {
                DesktopPetLog.assets.warning("Frame crop failed for \(self.definition.id, privacy: .public); using fallback image.")
                return fallbackImage()
            }

            let image = NSImage(cgImage: cropped, size: CGSize(width: definition.frameSize.width, height: definition.frameSize.height))
            cache[resolvedFrame] = image
            return image
        case .wholeImage(let image):
            return image
        case .missing:
            return nil
        }
    }

    private func visibleFrame(for frame: SpriteFrame, in spriteSheet: CGImage) -> SpriteFrame {
        guard isTransparentFrame(frame, in: spriteSheet),
              let columns = definition.spritesheet?.columns,
              columns > 0 else {
            return frame
        }

        let startingColumn = min(max(frame.column, 0), columns - 1)
        for column in stride(from: startingColumn, through: 0, by: -1) {
            let candidate = SpriteFrame(column: column, row: frame.row)
            if !isTransparentFrame(candidate, in: spriteSheet) {
                return candidate
            }
        }

        if startingColumn + 1 < columns {
            for column in (startingColumn + 1)..<columns {
                let candidate = SpriteFrame(column: column, row: frame.row)
                if !isTransparentFrame(candidate, in: spriteSheet) {
                    return candidate
                }
            }
        }

        return frame
    }

    private func isTransparentFrame(_ frame: SpriteFrame, in spriteSheet: CGImage) -> Bool {
        if let cached = transparentFrameCache[frame] {
            return cached
        }

        let isTransparent = spriteSheet.desktopPetFrameIsFullyTransparent(cropRect(for: frame))
        transparentFrameCache[frame] = isTransparent
        return isTransparent
    }

    public func fallbackImage() -> NSImage? {
        switch source {
        case .wholeImage(let image):
            return image
        case .spriteSheet:
            guard let idleFrame = definition.animation(for: .idle)?.frames.first else {
                return nil
            }

            return image(for: idleFrame)
        case .missing:
            return nil
        }
    }

    public func cropRect(for frame: SpriteFrame) -> CGRect {
        CGRect(
            x: Double(frame.column) * definition.frameSize.width,
            y: Double(frame.row) * definition.frameSize.height,
            width: definition.frameSize.width,
            height: definition.frameSize.height
        )
    }

    public static func canCrop(_ image: CGImage, for definition: PetDefinition) -> Bool {
        guard let spritesheet = definition.spritesheet else {
            return false
        }
        let requiredWidth = Int(definition.frameSize.width) * spritesheet.columns
        let requiredHeight = Int(definition.frameSize.height) * spritesheet.rows
        return image.width >= requiredWidth && image.height >= requiredHeight
    }
}

private extension NSImage {
    var desktopPetCGImage: CGImage? {
        var rect = CGRect(origin: .zero, size: size)
        return cgImage(forProposedRect: &rect, context: nil, hints: nil)
    }
}
