import Foundation

public protocol PetActionOverrideStoring {
    func load(petId: String) throws -> PetActionOverrideSet?
    func save(_ overrides: PetActionOverrideSet, for petId: String) throws
    func delete(petId: String) throws
}

public enum ActionOverrideError: Error, Equatable, Sendable {
    case writeFailed(petId: String, reason: String)
    case deleteFailed(petId: String, reason: String)
}

public final class PetActionOverrideStore: PetActionOverrideStoring {
    public static let fileName = "action-overrides.json"

    private let petsDirectoryURL: URL
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let manifestRewriter: ManifestRewriting

    public init(
        petsDirectoryURL: URL? = nil,
        fileManager: FileManager = .default,
        encoder: JSONEncoder = JSONEncoder(),
        decoder: JSONDecoder = JSONDecoder(),
        manifestRewriter: ManifestRewriting = ManifestRewriter()
    ) {
        self.petsDirectoryURL = petsDirectoryURL ?? Self.defaultPetsDirectoryURL(fileManager: fileManager)
        self.fileManager = fileManager
        self.encoder = encoder
        self.decoder = decoder
        self.manifestRewriter = manifestRewriter
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }

    public func load(petId: String) throws -> PetActionOverrideSet? {
        let fileURL = overrideFileURL(for: petId)
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let overrides = try decoder.decode(PetActionOverrideSet.self, from: data)
            guard overrides.overrideSchemaVersion == PetActionOverrideSet.currentSchemaVersion else {
                DesktopPetLog.petLibrary.warning("Unsupported action override schema \(overrides.overrideSchemaVersion, privacy: .public) for pet \(petId, privacy: .public); ignoring override file.")
                return nil
            }
            return overrides
        } catch {
            DesktopPetLog.petLibrary.warning("Failed to load action overrides for pet \(petId, privacy: .public): \(error.localizedDescription, privacy: .public). Ignoring override file.")
            return nil
        }
    }

    public func save(_ overrides: PetActionOverrideSet, for petId: String) throws {
        let petDirectoryURL = petDirectoryURL(for: petId)
        let destinationURL = overrideFileURL(for: petId)
        let temporaryURL = petDirectoryURL.appendingPathComponent(
            ".\(Self.fileName).\(UUID().uuidString).tmp",
            isDirectory: false
        )
        let normalizedOverrides = PetActionOverrideSet(
            overrideSchemaVersion: PetActionOverrideSet.currentSchemaVersion,
            petId: petId,
            overrides: overrides.overrides
        )

        do {
            try fileManager.createDirectory(at: petDirectoryURL, withIntermediateDirectories: true)
            try rewriteLegacyManifestIfNeeded(for: petId)
            let data = try encoder.encode(normalizedOverrides)
            try data.write(to: temporaryURL)
            if fileManager.fileExists(atPath: destinationURL.path) {
                _ = try fileManager.replaceItemAt(destinationURL, withItemAt: temporaryURL)
            } else {
                try fileManager.moveItem(at: temporaryURL, to: destinationURL)
            }
        } catch {
            try? fileManager.removeItem(at: temporaryURL)
            DesktopPetLog.petLibrary.error("Failed to save action overrides for pet \(petId, privacy: .public): \(error.localizedDescription, privacy: .public).")
            throw ActionOverrideError.writeFailed(petId: petId, reason: error.localizedDescription)
        }
    }

    public func delete(petId: String) throws {
        let fileURL = overrideFileURL(for: petId)
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return
        }

        do {
            try fileManager.removeItem(at: fileURL)
        } catch {
            DesktopPetLog.petLibrary.error("Failed to delete action overrides for pet \(petId, privacy: .public): \(error.localizedDescription, privacy: .public).")
            throw ActionOverrideError.deleteFailed(petId: petId, reason: error.localizedDescription)
        }
    }

    public func overrideFileURL(for petId: String) -> URL {
        petDirectoryURL(for: petId).appendingPathComponent(Self.fileName, isDirectory: false)
    }

    public func manifestFileURL(for petId: String) -> URL {
        petDirectoryURL(for: petId).appendingPathComponent(PetLibraryStore.manifestFileName, isDirectory: false)
    }

    private func petDirectoryURL(for petId: String) -> URL {
        petsDirectoryURL.appendingPathComponent(petId, isDirectory: true)
    }

    private func rewriteLegacyManifestIfNeeded(for petId: String) throws {
        let manifestURL = manifestFileURL(for: petId)
        guard fileManager.fileExists(atPath: manifestURL.path) else {
            return
        }

        let data = try Data(contentsOf: manifestURL)
        let manifest = try decoder.decode(PetPackageManifest.self, from: data)
        guard manifest.schemaVersion == 1 || manifest.legacyAnimations != nil else {
            return
        }

        try manifestRewriter.rewriteV1ManifestToV2(at: manifestURL)
    }

    private static func defaultPetsDirectoryURL(fileManager: FileManager) -> URL {
        if let url = try? fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        ) {
            return url
                .appendingPathComponent("DesktopPet", isDirectory: true)
                .appendingPathComponent(PetLibraryStore.petsDirectoryName, isDirectory: true)
        }

        return fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/DesktopPet", isDirectory: true)
            .appendingPathComponent(PetLibraryStore.petsDirectoryName, isDirectory: true)
    }
}
