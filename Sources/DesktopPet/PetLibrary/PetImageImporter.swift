@preconcurrency import AppKit
import Foundation

public struct ImportedPetImage: Equatable, Sendable {
    public let imageFileName: String
    public let previewFileName: String
    public let pixelSize: CGSizeCodable
    public let hasAlpha: Bool

    public init(
        imageFileName: String,
        previewFileName: String,
        pixelSize: CGSizeCodable,
        hasAlpha: Bool
    ) {
        self.imageFileName = imageFileName
        self.previewFileName = previewFileName
        self.pixelSize = pixelSize
        self.hasAlpha = hasAlpha
    }
}

public protocol PetImageImporting {
    func importImage(
        from sourceURL: URL,
        to destinationFolder: URL,
        displayName: String
    ) throws -> ImportedPetImage
}

public final class PetImageImporter: PetImageImporting {
    public static let imageFileName = "image.png"
    public static let previewFileName = "preview.png"
    public static let defaultMainImageMaxLongestSide = 1024
    public static let defaultPreviewMaxLongestSide = 256
    public static let defaultMaxFileBytes = 20 * 1024 * 1024
    public static let supportedExtensions: Set<String> = ["png", "jpg", "jpeg"]

    private let fileManager: FileManager
    private let maxFileBytes: Int
    private let mainImageMaxLongestSide: Int
    private let previewMaxLongestSide: Int

    public init(
        fileManager: FileManager = .default,
        maxFileBytes: Int = PetImageImporter.defaultMaxFileBytes,
        mainImageMaxLongestSide: Int = PetImageImporter.defaultMainImageMaxLongestSide,
        previewMaxLongestSide: Int = PetImageImporter.defaultPreviewMaxLongestSide
    ) {
        self.fileManager = fileManager
        self.maxFileBytes = maxFileBytes
        self.mainImageMaxLongestSide = mainImageMaxLongestSide
        self.previewMaxLongestSide = previewMaxLongestSide
    }

    public func importImage(
        from sourceURL: URL,
        to destinationFolder: URL,
        displayName: String
    ) throws -> ImportedPetImage {
        let lowerExt = sourceURL.pathExtension.lowercased()
        guard Self.supportedExtensions.contains(lowerExt) else {
            DesktopPetLog.petLibrary.warning(
                "Rejecting import for unsupported extension \(lowerExt, privacy: .public) (display=\(displayName, privacy: .public))"
            )
            throw PetLibraryError.unsupportedImageType
        }

        if let attributes = try? fileManager.attributesOfItem(atPath: sourceURL.path),
           let size = attributes[.size] as? NSNumber,
           size.intValue > maxFileBytes {
            DesktopPetLog.petLibrary.warning(
                "Rejecting oversized image (\(size.intValue, privacy: .public) bytes) for display=\(displayName, privacy: .public)"
            )
            throw PetLibraryError.imageTooLarge
        }

        guard let image = NSImage(contentsOf: sourceURL),
              let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              bitmap.pixelsWide > 0,
              bitmap.pixelsHigh > 0,
              let cgImage = bitmap.cgImage else {
            DesktopPetLog.petLibrary.warning(
                "Rejecting unreadable image at \(sourceURL.lastPathComponent, privacy: .public)"
            )
            throw PetLibraryError.unreadableImage
        }

        let hasAlpha = bitmap.hasAlpha

        do {
            try fileManager.createDirectory(at: destinationFolder, withIntermediateDirectories: true, attributes: nil)
        } catch {
            DesktopPetLog.petLibrary.error(
                "Failed to create destination folder \(destinationFolder.path, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
            throw PetLibraryError.cannotCreatePetDirectory
        }

        let mainImage = try resizedImage(cgImage, maxLongestSide: mainImageMaxLongestSide, hasAlpha: hasAlpha)
        let previewImage = try resizedImage(cgImage, maxLongestSide: previewMaxLongestSide, hasAlpha: hasAlpha)

        let mainURL = destinationFolder.appendingPathComponent(Self.imageFileName)
        let previewURL = destinationFolder.appendingPathComponent(Self.previewFileName)

        try writePNG(cgImage: mainImage, to: mainURL)
        try writePNG(cgImage: previewImage, to: previewURL)

        return ImportedPetImage(
            imageFileName: Self.imageFileName,
            previewFileName: Self.previewFileName,
            pixelSize: CGSizeCodable(
                width: Double(mainImage.width),
                height: Double(mainImage.height)
            ),
            hasAlpha: hasAlpha
        )
    }

    private func resizedImage(
        _ source: CGImage,
        maxLongestSide: Int,
        hasAlpha: Bool
    ) throws -> CGImage {
        let originalWidth = source.width
        let originalHeight = source.height
        let longest = max(originalWidth, originalHeight)

        if longest <= maxLongestSide {
            return source
        }

        let ratio = Double(maxLongestSide) / Double(longest)
        let targetWidth = max(1, Int(Double(originalWidth) * ratio))
        let targetHeight = max(1, Int(Double(originalHeight) * ratio))

        let bitmapInfo: UInt32 = hasAlpha
            ? CGImageAlphaInfo.premultipliedLast.rawValue
            : CGImageAlphaInfo.noneSkipLast.rawValue

        guard let context = CGContext(
            data: nil,
            width: targetWidth,
            height: targetHeight,
            bitsPerComponent: 8,
            bytesPerRow: targetWidth * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: bitmapInfo
        ) else {
            throw PetLibraryError.unreadableImage
        }

        context.interpolationQuality = .high
        context.draw(source, in: CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight))

        guard let resized = context.makeImage() else {
            throw PetLibraryError.unreadableImage
        }
        return resized
    }

    private func writePNG(cgImage: CGImage, to url: URL) throws {
        let rep = NSBitmapImageRep(cgImage: cgImage)
        guard let data = rep.representation(using: .png, properties: [:]) else {
            DesktopPetLog.petLibrary.error("Failed to encode PNG image for imported pet.")
            throw PetLibraryError.cannotWriteImage
        }
        do {
            try data.write(to: url, options: [.atomic])
        } catch {
            DesktopPetLog.petLibrary.error(
                "Failed to write PNG to \(url.path, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
            throw PetLibraryError.cannotWriteImage
        }
    }
}
