import CoreGraphics
import Foundation
import ImageIO

// MARK: - Types

public enum ActionImageInput: Equatable, Sendable {
    case singleImage(Data)
    case multipleImages([Data])
}

public struct NormalizedActionImage: Equatable, Sendable {
    public let imageData: Data
    public let width: Int
    public let height: Int

    public init(imageData: Data, width: Int, height: Int) {
        self.imageData = imageData
        self.width = width
        self.height = height
    }
}

public struct GridPreset: Equatable, Sendable {
    public let columns: Int
    public let rows: Int

    public init(columns: Int, rows: Int) {
        self.columns = columns
        self.rows = rows
    }
}

public struct ActionGridAnalysis: Equatable, Sendable {
    public let columns: Int
    public let rows: Int
    public let suggestedPresets: [GridPreset]

    public init(columns: Int, rows: Int, suggestedPresets: [GridPreset] = []) {
        self.columns = columns
        self.rows = rows
        self.suggestedPresets = suggestedPresets
    }
}

public struct ActionFrameSelection: Equatable, Sendable {
    public let column: Int
    public let row: Int
    public let durationMs: Int?

    public init(column: Int, row: Int, durationMs: Int? = nil) {
        self.column = column
        self.row = row
        self.durationMs = durationMs
    }
}

// MARK: - Protocols

public protocol ActionImageNormalizing: Sendable {
    func normalize(
        _ input: ActionImageInput,
        targetFrameSize: CGSizeCodable
    ) throws -> NormalizedActionImage
}

public protocol ActionGridAnalyzing: Sendable {
    func analyze(
        _ image: NormalizedActionImage,
        targetFrameSize: CGSizeCodable
    ) -> ActionGridAnalysis
}

// MARK: - Grid Presets

public let actionGridPresets: [GridPreset] = [
    GridPreset(columns: 1, rows: 1),
    GridPreset(columns: 2, rows: 1),
    GridPreset(columns: 4, rows: 1),
    GridPreset(columns: 4, rows: 2),
    GridPreset(columns: 8, rows: 1),
    GridPreset(columns: 8, rows: 2)
]

// MARK: - Default Image Normalizer

public struct DefaultActionImageNormalizer: ActionImageNormalizing {
    public init() {}

    public func normalize(
        _ input: ActionImageInput,
        targetFrameSize: CGSizeCodable
    ) throws -> NormalizedActionImage {
        switch input {
        case .singleImage(let data):
            return try normalizeSingleImage(data, targetFrameSize: targetFrameSize)
        case .multipleImages(let images):
            return try normalizeMultipleImages(images, targetFrameSize: targetFrameSize)
        }
    }

    private func normalizeSingleImage(
        _ data: Data,
        targetFrameSize: CGSizeCodable
    ) throws -> NormalizedActionImage {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else {
            throw ActionPackError.resourceUnreadable(packId: "", resourceId: "", path: "input image")
        }

        let width = cgImage.width
        let height = cgImage.height
        let targetW = Int(targetFrameSize.width)
        let targetH = Int(targetFrameSize.height)

        // If image is already exactly target size or a multiple, use as-is
        if width >= targetW && height >= targetH,
           width % targetW == 0, height % targetH == 0 {
            return NormalizedActionImage(imageData: data, width: width, height: height)
        }

        // Otherwise, scale to fit target frame size (center crop to exact frame)
        let resized = try resizeImage(cgImage, to: CGSize(width: targetW, height: targetH))
        let pngData = try encodeToPNG(resized)
        return NormalizedActionImage(imageData: pngData, width: targetW, height: targetH)
    }

    private func normalizeMultipleImages(
        _ images: [Data],
        targetFrameSize: CGSizeCodable
    ) throws -> NormalizedActionImage {
        guard !images.isEmpty else {
            throw ActionPackError.invalidResourcePath("No images provided")
        }

        let targetW = Int(targetFrameSize.width)
        let targetH = Int(targetFrameSize.height)

        var cgImages: [CGImage] = []
        for data in images {
            guard let source = CGImageSourceCreateWithData(data as CFData, nil),
                  let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil)
            else {
                throw ActionPackError.resourceUnreadable(packId: "", resourceId: "", path: "input image")
            }
            let resized = try resizeImage(cgImage, to: CGSize(width: targetW, height: targetH))
            cgImages.append(resized)
        }

        let totalWidth = targetW * cgImages.count
        let synthesized = try synthesizeHorizontal(images: cgImages, frameWidth: targetW, frameHeight: targetH)
        let pngData = try encodeToPNG(synthesized)
        return NormalizedActionImage(imageData: pngData, width: totalWidth, height: targetH)
    }

    private func resizeImage(_ image: CGImage, to size: CGSize) throws -> CGImage {
        let width = Int(size.width)
        let height = Int(size.height)
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw ActionPackError.writeFailed(packId: "", underlying: "Failed to create CGContext")
        }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(origin: .zero, size: size))
        guard let result = context.makeImage() else {
            throw ActionPackError.writeFailed(packId: "", underlying: "Failed to create resized image")
        }
        return result
    }

    private func synthesizeHorizontal(images: [CGImage], frameWidth: Int, frameHeight: Int) throws -> CGImage {
        let totalWidth = frameWidth * images.count
        guard let context = CGContext(
            data: nil,
            width: totalWidth,
            height: frameHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw ActionPackError.writeFailed(packId: "", underlying: "Failed to create synthesis context")
        }

        for (index, image) in images.enumerated() {
            let rect = CGRect(x: index * frameWidth, y: 0, width: frameWidth, height: frameHeight)
            context.draw(image, in: rect)
        }

        guard let result = context.makeImage() else {
            throw ActionPackError.writeFailed(packId: "", underlying: "Failed to synthesize images")
        }
        return result
    }

    private func encodeToPNG(_ image: CGImage) throws -> Data {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, "public.png" as CFString, 1, nil) else {
            throw ActionPackError.writeFailed(packId: "", underlying: "Failed to create PNG destination")
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw ActionPackError.writeFailed(packId: "", underlying: "Failed to encode PNG")
        }
        return data as Data
    }
}

// MARK: - Default Grid Analyzer

public struct DefaultActionGridAnalyzer: ActionGridAnalyzing {
    public init() {}

    public func analyze(
        _ image: NormalizedActionImage,
        targetFrameSize: CGSizeCodable
    ) -> ActionGridAnalysis {
        let targetW = Int(targetFrameSize.width)
        let targetH = Int(targetFrameSize.height)

        guard targetW > 0, targetH > 0 else {
            return ActionGridAnalysis(columns: 1, rows: 1, suggestedPresets: actionGridPresets)
        }

        let columns = image.width / targetW
        let rows = image.height / targetH

        let safeColumns = max(1, columns)
        let safeRows = max(1, rows)

        let matchingPresets = actionGridPresets.filter { preset in
            preset.columns <= safeColumns && preset.rows <= safeRows
        }

        return ActionGridAnalysis(
            columns: safeColumns,
            rows: safeRows,
            suggestedPresets: matchingPresets.isEmpty ? [GridPreset(columns: safeColumns, rows: safeRows)] : matchingPresets
        )
    }
}
