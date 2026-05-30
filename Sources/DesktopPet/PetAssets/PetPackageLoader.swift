import Foundation
import ImageIO

public protocol PetPackageLoading {
    func loadBuiltInPet() throws -> PetDefinition
    func loadPackage(at url: URL) throws -> PetDefinition
}

public final class PetPackageLoader: PetPackageLoading {
    public static let packageExtension = "pet"
    public static let manifestFileName = "manifest.json"

    private let builtInProvider: BuiltInPetDefinitionProvider
    private let fileManager: FileManager
    private let decoder: JSONDecoder

    public init(
        builtInProvider: BuiltInPetDefinitionProvider = BuiltInPetDefinitionProvider(),
        fileManager: FileManager = .default,
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.builtInProvider = builtInProvider
        self.fileManager = fileManager
        self.decoder = decoder
    }

    public func loadBuiltInPet() throws -> PetDefinition {
        try builtInProvider.loadBuiltInPet()
    }

    public func loadPackage(at url: URL) throws -> PetDefinition {
        guard url.pathExtension.lowercased() == Self.packageExtension else {
            throw PetAssetError.invalidPackageExtension
        }

        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw PetAssetError.invalidPackageStructure("package must be a folder")
        }

        let manifestURL = url.appendingPathComponent(Self.manifestFileName)
        guard fileManager.fileExists(atPath: manifestURL.path) else {
            throw PetAssetError.manifestNotFound(manifestURL)
        }

        let data = try Data(contentsOf: manifestURL)
        let manifest = try decoder.decode(PetPackageManifest.self, from: data)
        let definition = try manifest.petDefinition()

        guard definition.assetKind == .spriteSheet else {
            throw PetAssetError.singleImagePackageUnsupported
        }

        try validatePackageResourceName(definition.assetName)
        if let preview = definition.previewAssetName {
            try validatePackageResourceName(preview)
        }

        try validateImageResource(named: definition.assetName, in: url)
        if let preview = definition.previewAssetName {
            try validateImageResource(named: preview, in: url)
        }

        return definition
    }

    public func decodeManifest(data: Data) throws -> PetDefinition {
        let manifest = try decoder.decode(PetPackageManifest.self, from: data)
        return try manifest.petDefinition()
    }

    private func validatePackageResourceName(_ name: String) throws {
        guard !name.isEmpty,
              name != ".",
              name != "..",
              !name.contains("/"),
              !name.contains("\\") else {
            throw PetAssetError.unsafePackageResourceName(name)
        }
    }

    private func validateImageResource(named name: String, in packageURL: URL) throws {
        let url = packageURL.appendingPathComponent(name)
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory),
              !isDirectory.boolValue else {
            throw PetAssetError.missingPackageResource(name)
        }

        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int,
              width > 0,
              height > 0 else {
            throw PetAssetError.unreadablePackageResource(name)
        }
    }
}
