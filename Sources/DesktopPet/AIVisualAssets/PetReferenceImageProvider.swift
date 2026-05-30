import AppKit

public protocol PetReferenceImageProviding: Sendable {
    func exportReferenceImage(petId: String, image: NSImage) throws -> URL
}

public final class PetReferenceImageProvider: PetReferenceImageProviding, @unchecked Sendable {
    private let baseDirectory: URL

    public init(baseDirectory: URL? = nil) {
        self.baseDirectory = baseDirectory ?? Self.defaultBaseDirectory()
    }

    public func exportReferenceImage(petId: String, image: NSImage) throws -> URL {
        let dir = baseDirectory
            .appendingPathComponent(petId)
            .appendingPathComponent("visual-actions")
            .appendingPathComponent("ref")

        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let url = dir.appendingPathComponent("reference.png")

        guard let pngData = PetVisualImagePostprocessor.pngData(from: image) else {
            throw PetVisualAssetError.conversionFailed
        }

        try pngData.write(to: url)
        return url
    }

    private static func defaultBaseDirectory() -> URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("DesktopPet")
    }
}
