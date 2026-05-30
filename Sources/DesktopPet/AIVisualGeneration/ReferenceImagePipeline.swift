import AppKit
import CryptoKit
import Foundation

public struct ImageSnapshot: Codable, Sendable, Equatable {
    public let width: Int
    public let height: Int
    public let hasAlpha: Bool
    public let boundingBox: CGRect?
    public let visibleAreaRatio: Double
    public let dominantColors: [String]

    public init(
        width: Int,
        height: Int,
        hasAlpha: Bool,
        boundingBox: CGRect? = nil,
        visibleAreaRatio: Double = 0,
        dominantColors: [String] = []
    ) {
        self.width = width
        self.height = height
        self.hasAlpha = hasAlpha
        self.boundingBox = boundingBox
        self.visibleAreaRatio = visibleAreaRatio
        self.dominantColors = dominantColors
    }
}

public struct ProcessedReference: Sendable, Equatable {
    public let transparentPNG: URL
    public let providerFriendly: URL
    public let originalInfo: ImageSnapshot
    public let processedInfo: ImageSnapshot

    public init(
        transparentPNG: URL,
        providerFriendly: URL,
        originalInfo: ImageSnapshot,
        processedInfo: ImageSnapshot
    ) {
        self.transparentPNG = transparentPNG
        self.providerFriendly = providerFriendly
        self.originalInfo = originalInfo
        self.processedInfo = processedInfo
    }
}

public protocol ReferenceImageProcessing: Sendable {
    func process(petId: String, sourceURL: URL) async throws -> ProcessedReference
}

public final class ReferenceImagePipeline: ReferenceImageProcessing, @unchecked Sendable {
    private let baseDirectory: URL
    private let fileManager: FileManager

    public init(baseDirectory: URL? = nil) {
        self.baseDirectory = baseDirectory ?? PetVisualAssetStore.defaultBaseDirectory()
        self.fileManager = .default
    }

    public func process(petId: String, sourceURL: URL) async throws -> ProcessedReference {
        let refDir = referenceDirectory(petId: petId)
        try fileManager.createDirectory(at: refDir, withIntermediateDirectories: true)

        let transparentURL = refDir.appendingPathComponent("reference-processed.png")
        let providerURL = refDir.appendingPathComponent("reference-provider.png")
        let cacheURL = refDir.appendingPathComponent("reference-cache.json")

        if let cached = try? loadCached(cacheURL: cacheURL, transparentURL: transparentURL, providerURL: providerURL, sourceURL: sourceURL) {
            return cached
        }

        let sourceData = try Data(contentsOf: sourceURL)
        guard let sourceRep = NSBitmapImageRep(data: sourceData) else {
            throw ReferenceImagePipelineError.imageLoadFailed
        }

        let originalInfo = analyzeSnapshot(rep: sourceRep)

        let croppedRep = try cropToVisibleBounds(sourceRep)

        let targetSize = calculateTargetSize(width: croppedRep.pixelsWide, height: croppedRep.pixelsHigh)
        let useNearestNeighbor = estimatedStyle(width: originalInfo.width, height: originalInfo.height, hasAlpha: originalInfo.hasAlpha) == "pixel-art"
        let scaledRep = scaleToCanvas(croppedRep, targetWidth: targetSize.width, targetHeight: targetSize.height, nearestNeighbor: useNearestNeighbor)

        guard let transparentPNGData = scaledRep.representation(using: .png, properties: [:]) else {
            throw ReferenceImagePipelineError.encodingFailed
        }
        try transparentPNGData.write(to: transparentURL, options: [.atomic])

        let matteRep = applyMatteBackground(scaledRep)
        guard let providerPNGData = matteRep.representation(using: .png, properties: [:]) else {
            throw ReferenceImagePipelineError.encodingFailed
        }
        try providerPNGData.write(to: providerURL, options: [.atomic])

        let processedInfo = analyzeSnapshot(rep: scaledRep)

        let result = ProcessedReference(
            transparentPNG: transparentURL,
            providerFriendly: providerURL,
            originalInfo: originalInfo,
            processedInfo: processedInfo
        )

        try? saveCache(cacheURL: cacheURL, sourceURL: sourceURL, result: result)

        return result
    }

    // MARK: - Private

    private func referenceDirectory(petId: String) -> URL {
        baseDirectory
            .appendingPathComponent(petId)
            .appendingPathComponent("visual-actions")
            .appendingPathComponent("ref")
    }

    private func analyzeSnapshot(rep: NSBitmapImageRep) -> ImageSnapshot {
        let w = rep.pixelsWide
        let h = rep.pixelsHigh
        let hasAlpha = rep.hasAlpha

        var visiblePixels = 0
        var colorCounts: [String: Int] = [:]
        let totalPixels = w * h

        for y in 0..<h {
            for x in 0..<w {
                let alpha = alphaValue(in: rep, x: x, y: y)
                guard alpha >= 0.05 else { continue }
                visiblePixels += 1

                if let hex = colorHex(in: rep, x: x, y: y) {
                    colorCounts[hex, default: 0] += 1
                }
            }
        }

        let dominantColors = colorCounts
            .sorted { $0.value > $1.value }
            .prefix(5)
            .map(\.key)

        let visibleRatio = totalPixels == 0 ? 0 : Double(visiblePixels) / Double(totalPixels)
        let bbox = boundingBox(rep: rep, width: w, height: h)

        return ImageSnapshot(
            width: w,
            height: h,
            hasAlpha: hasAlpha,
            boundingBox: bbox,
            visibleAreaRatio: roundRatio(visibleRatio),
            dominantColors: dominantColors
        )
    }

    private func boundingBox(rep: NSBitmapImageRep, width: Int, height: Int) -> CGRect? {
        var minX = width, minY = height, maxX = 0, maxY = 0
        var found = false

        for y in 0..<height {
            for x in 0..<width {
                guard alphaValue(in: rep, x: x, y: y) >= 0.05 else { continue }
                found = true
                if x < minX { minX = x }
                if x > maxX { maxX = x }
                if y < minY { minY = y }
                if y > maxY { maxY = y }
            }
        }

        guard found else { return nil }
        return CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
    }

    private func cropToVisibleBounds(_ rep: NSBitmapImageRep) throws -> NSBitmapImageRep {
        guard let bbox = boundingBox(rep: rep, width: rep.pixelsWide, height: rep.pixelsHigh) else {
            return rep
        }

        let croppedWidth = Int(bbox.width)
        let croppedHeight = Int(bbox.height)
        guard croppedWidth > 0, croppedHeight > 0 else { return rep }

        guard let cgImage = rep.cgImage else { return rep }
        let croppingRect = CGRect(
            x: CGFloat(bbox.origin.x),
            y: CGFloat(rep.pixelsHigh) - CGFloat(bbox.origin.y) - CGFloat(bbox.height),
            width: CGFloat(bbox.width),
            height: CGFloat(bbox.height)
        )
        guard let croppedCG = cgImage.cropping(to: croppingRect) else { return rep }

        let croppedRep = NSBitmapImageRep(cgImage: croppedCG)
        return croppedRep
    }

    private func calculateTargetSize(width: Int, height: Int) -> (width: Int, height: Int) {
        let minSize = 512
        let maxSize = 1024

        guard width > 0, height > 0 else { return (minSize, minSize) }

        if width >= minSize && height >= minSize && width <= maxSize && height <= maxSize {
            return (width, height)
        }

        let longestSide = max(width, height)
        let scale = Double(minSize) / Double(longestSide)
        let scaledW = Int((Double(width) * scale).rounded(.up))
        let scaledH = Int((Double(height) * scale).rounded(.up))

        let finalW = min(max(scaledW, minSize), maxSize)
        let finalH = min(max(scaledH, minSize), maxSize)
        return (finalW, finalH)
    }

    private func scaleToCanvas(_ rep: NSBitmapImageRep, targetWidth: Int, targetHeight: Int, nearestNeighbor: Bool) -> NSBitmapImageRep {
        let srcW = rep.pixelsWide
        let srcH = rep.pixelsHigh

        let scale = min(Double(targetWidth) / Double(srcW), Double(targetHeight) / Double(srcH))
        let scaledW = max(1, Int(Double(srcW) * scale))
        let scaledH = max(1, Int(Double(srcH) * scale))

        let canvasW = max(scaledW, targetWidth)
        let canvasH = max(scaledH, targetHeight)

        guard let cgImage = rep.cgImage else { return rep }

        let interpolation = nearestNeighbor || isPixelArtLike(width: srcW, height: srcH, hasAlpha: rep.hasAlpha)
            ? CGInterpolationQuality.none
            : CGInterpolationQuality.high

        guard let context = CGContext(
            data: nil,
            width: canvasW,
            height: canvasH,
            bitsPerComponent: 8,
            bytesPerRow: 4 * canvasW,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ) else { return rep }

        context.interpolationQuality = interpolation

        let offsetX = (canvasW - scaledW) / 2
        let offsetY = (canvasH - scaledH) / 2
        let drawRect = CGRect(x: offsetX, y: offsetY, width: scaledW, height: scaledH)

        context.draw(cgImage, in: drawRect)

        guard let resultCG = context.makeImage() else { return rep }
        let resultRep = NSBitmapImageRep(cgImage: resultCG)
        return resultRep
    }

    private func applyMatteBackground(_ rep: NSBitmapImageRep) -> NSBitmapImageRep {
        let w = rep.pixelsWide
        let h = rep.pixelsHigh

        guard let matteRep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: w,
            pixelsHigh: h,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: false,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else { return rep }

        matteRep.colorAt(x: 0, y: 0)

        for y in 0..<h {
            for x in 0..<w {
                let alpha = alphaValue(in: rep, x: x, y: y)
                if alpha >= 0.95 {
                    if let color = rep.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) {
                        matteRep.setColor(color, atX: x, y: y)
                    }
                } else {
                    matteRep.setColor(NSColor(white: 0.97, alpha: 1.0), atX: x, y: y)
                }
            }
        }

        return matteRep
    }

    private func alphaValue(in rep: NSBitmapImageRep, x: Int, y: Int) -> Double {
        if let data = rep.bitmapData, !rep.isPlanar, rep.bitsPerSample == 8 {
            let bytesPerPixel = max(rep.bitsPerPixel / 8, rep.samplesPerPixel)
            let offset = y * rep.bytesPerRow + x * bytesPerPixel
            let alphaFirst = rep.hasAlpha && rep.bitmapFormat.contains(.alphaFirst)
            if rep.hasAlpha {
                let alphaIndex = alphaFirst ? 0 : rep.samplesPerPixel - 1
                guard offset + alphaIndex < (y + 1) * rep.bytesPerRow else {
                    return Double(rep.colorAt(x: x, y: y)?.alphaComponent ?? 0)
                }
                return Double(data[offset + alphaIndex]) / 255.0
            }
            return 1.0
        }
        return Double(rep.colorAt(x: x, y: y)?.alphaComponent ?? 0)
    }

    private func colorHex(in rep: NSBitmapImageRep, x: Int, y: Int) -> String? {
        guard let color = rep.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else { return nil }
        let r = max(0, min(255, Int((color.redComponent * 255).rounded())))
        let g = max(0, min(255, Int((color.greenComponent * 255).rounded())))
        let b = max(0, min(255, Int((color.blueComponent * 255).rounded())))
        return String(format: "#%02X%02X%02X", r, g, b)
    }

    private func estimatedStyle(width: Int, height: Int, hasAlpha: Bool) -> String? {
        if hasAlpha && width <= 256 && height <= 256 {
            return width <= 64 || height <= 64 ? "pixel-art" : "2d-sprite"
        }
        return "illustration"
    }

    private func isPixelArtLike(width: Int, height: Int, hasAlpha: Bool) -> Bool {
        hasAlpha && (width <= 64 || height <= 64)
    }

    private func roundRatio(_ value: Double) -> Double {
        (value * 10_000).rounded() / 10_000
    }

    // MARK: - Cache

    private struct CacheEntry: Codable {
        let sourceDigest: String
        let originalInfo: ImageSnapshot
        let processedInfo: ImageSnapshot
    }

    private func digest(at url: URL) throws -> String {
        let data = try Data(contentsOf: url)
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func loadCached(cacheURL: URL, transparentURL: URL, providerURL: URL, sourceURL: URL) throws -> ProcessedReference? {
        guard fileManager.fileExists(atPath: cacheURL.path),
              fileManager.fileExists(atPath: transparentURL.path),
              fileManager.fileExists(atPath: providerURL.path)
        else { return nil }

        let data = try Data(contentsOf: cacheURL)
        let entry = try JSONDecoder().decode(CacheEntry.self, from: data)

        let currentDigest = try digest(at: sourceURL)
        guard currentDigest == entry.sourceDigest else { return nil }

        return ProcessedReference(
            transparentPNG: transparentURL,
            providerFriendly: providerURL,
            originalInfo: entry.originalInfo,
            processedInfo: entry.processedInfo
        )
    }

    private func saveCache(cacheURL: URL, sourceURL: URL, result: ProcessedReference) throws {
        let sourceDigest = try digest(at: sourceURL)
        let entry = CacheEntry(
            sourceDigest: sourceDigest,
            originalInfo: result.originalInfo,
            processedInfo: result.processedInfo
        )
        let data = try JSONEncoder().encode(entry)
        try data.write(to: cacheURL, options: [.atomic])
    }
}

public enum ReferenceImagePipelineError: Error, Equatable, LocalizedError {
    case imageLoadFailed
    case encodingFailed

    public var errorDescription: String? {
        switch self {
        case .imageLoadFailed: return "Failed to load reference image"
        case .encodingFailed: return "Failed to encode processed image"
        }
    }
}
