import AppKit

public protocol PetVisualImagePostprocessing: Sendable {
    func convertToPNGIfNeeded(at url: URL) throws -> URL
}

public final class PetVisualImagePostprocessor: PetVisualImagePostprocessing, @unchecked Sendable {
    public init() {}

    public func convertToPNGIfNeeded(at url: URL) throws -> URL {
        let ext = url.pathExtension.lowercased()
        if ext == "png" { return url }

        guard let image = NSImage(contentsOf: url) else {
            throw PetVisualAssetError.imageLoadFailed
        }

        guard let pngData = Self.pngData(from: image) else {
            throw PetVisualAssetError.conversionFailed
        }

        let newURL = url.deletingPathExtension().appendingPathExtension("png")
        try pngData.write(to: newURL)

        if newURL != url {
            try? FileManager.default.removeItem(at: url)
        }

        return newURL
    }

    static func pngData(from image: NSImage) -> Data? {
        guard let tiffData = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiffData)
        else { return nil }
        return rep.representation(using: .png, properties: [:])
    }
}
