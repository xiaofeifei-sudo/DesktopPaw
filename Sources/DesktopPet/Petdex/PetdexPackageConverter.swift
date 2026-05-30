import Foundation

public protocol PetdexPackageConverting {
    func convert(
        manifest: PetdexManifest,
        spritesheet: ProcessedPetdexSpriteSheet,
        actions: [Action],
        warnings: [ActionImportWarning]
    ) throws -> ConvertedPetPackage
}

public struct ConvertedPetPackage: Equatable {
    public static let manifestFileName = "manifest.json"
    public static let importWarningsFileName = "import-warnings.json"

    public let petId: String
    public let manifest: PetPackageManifest
    public let files: [String: Data]
    public let sourceMetadata: PetdexSourceMetadata

    public init(
        petId: String,
        manifest: PetPackageManifest,
        files: [String: Data],
        sourceMetadata: PetdexSourceMetadata
    ) {
        self.petId = petId
        self.manifest = manifest
        self.files = files
        self.sourceMetadata = sourceMetadata
    }
}

public final class PetdexPackageConverter: PetdexPackageConverting {
    public static let manifestSchemaVersion = 2
    public static let defaultScale = 1.0

    private let importedAtProvider: @Sendable () -> Date
    private let encoder: JSONEncoder

    public init(
        importedAtProvider: @escaping @Sendable () -> Date = { Date() },
        encoder: JSONEncoder = PetdexPackageConverter.makeDefaultEncoder()
    ) {
        self.importedAtProvider = importedAtProvider
        self.encoder = encoder
    }

    public func convert(
        manifest: PetdexManifest,
        spritesheet: ProcessedPetdexSpriteSheet,
        actions: [Action],
        warnings: [ActionImportWarning]
    ) throws -> ConvertedPetPackage {
        let packageManifest = PetPackageManifest(
            schemaVersion: Self.manifestSchemaVersion,
            id: manifest.id,
            displayName: manifest.displayName,
            description: manifest.description,
            asset: ProcessedPetdexSpriteSheet.spritesheetFileName,
            preview: ProcessedPetdexSpriteSheet.previewFileName,
            frameSize: spritesheet.frameSize,
            spritesheet: SpriteSheetLayout(columns: spritesheet.columns, rows: spritesheet.rows),
            defaultScale: Self.defaultScale,
            actions: actions,
            assetKind: .spriteSheet
        )

        do {
            _ = try packageManifest.petDefinition()
        } catch {
            throw PetdexImportError.invalidSpritesheetLayout("converted manifest is not a valid pet definition")
        }

        let sourceMetadata = PetdexSourceMetadata(
            petdexId: manifest.id,
            originalDisplayName: manifest.displayName,
            importedAt: importedAtProvider()
        )

        let manifestData: Data
        let sourceMetadataData: Data
        let importWarningsData: Data?
        do {
            manifestData = try encoder.encode(packageManifest)
            sourceMetadataData = try encoder.encode(sourceMetadata)
            importWarningsData = warnings.isEmpty ? nil : try encoder.encode(warnings.map(ImportWarningSidecarEntry.init))
        } catch {
            throw PetdexImportError.writeFailed("converted Petdex package metadata")
        }

        var files = [
            ConvertedPetPackage.manifestFileName: manifestData,
            ProcessedPetdexSpriteSheet.spritesheetFileName: spritesheet.spritesheetPNGData,
            ProcessedPetdexSpriteSheet.previewFileName: spritesheet.previewPNGData,
            PetdexSourceMetadata.fileName: sourceMetadataData
        ]
        if let importWarningsData {
            files[ConvertedPetPackage.importWarningsFileName] = importWarningsData
        }

        return ConvertedPetPackage(
            petId: manifest.id,
            manifest: packageManifest,
            files: files,
            sourceMetadata: sourceMetadata
        )
    }

    public static func makeDefaultEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}

private struct ImportWarningSidecarEntry: Encodable {
    let kind: String
    let detail: String
    let role: ActionRole?
    let actionId: ActionId?

    init(warning: ActionImportWarning) {
        kind = warning.kind.rawValue
        detail = warning.detail
        role = warning.role
        actionId = warning.actionId
    }
}

public extension PetdexPackageConverting {
    func convert(
        manifest: PetdexManifest,
        spritesheet: ProcessedPetdexSpriteSheet,
        animations: [PetState: ManifestAnimationClip]
    ) throws -> ConvertedPetPackage {
        try convert(
            manifest: manifest,
            spritesheet: spritesheet,
            actions: LegacyAnimationsAdapter().actions(from: animations),
            warnings: []
        )
    }
}
