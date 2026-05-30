import Foundation

public protocol PetPackageImporting {
    func importPackage(
        from sourceURL: URL,
        to importedPetsDirectoryURL: URL,
        builtInPetId: String
    ) throws -> PetDefinition
}

public final class PetPackageImporter: PetPackageImporting {
    private let loader: PetPackageLoading
    private let fileManager: FileManager

    public init(
        loader: PetPackageLoading = PetPackageLoader(),
        fileManager: FileManager = .default
    ) {
        self.loader = loader
        self.fileManager = fileManager
    }

    public func importPackage(
        from sourceURL: URL,
        to importedPetsDirectoryURL: URL,
        builtInPetId: String
    ) throws -> PetDefinition {
        let definition: PetDefinition
        do {
            definition = try loader.loadPackage(at: sourceURL)
        } catch {
            throw mapPackageError(error)
        }

        guard definition.id != builtInPetId else {
            throw PetLibraryError.petAlreadyExists
        }

        do {
            try fileManager.createDirectory(at: importedPetsDirectoryURL, withIntermediateDirectories: true)
        } catch {
            DesktopPetLog.petLibrary.error(
                "Failed to create package import directory \(importedPetsDirectoryURL.path, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
            throw PetLibraryError.cannotCreatePetDirectory
        }

        let destinationFolder = importedPetsDirectoryURL.appendingPathComponent(definition.id, isDirectory: true)
        guard !fileManager.fileExists(atPath: destinationFolder.path) else {
            throw PetLibraryError.petAlreadyExists
        }

        do {
            try fileManager.createDirectory(at: destinationFolder, withIntermediateDirectories: true)
            try copyPackageFile(
                PetPackageLoader.manifestFileName,
                from: sourceURL,
                to: destinationFolder
            )
            try copyPackageFile(definition.assetName, from: sourceURL, to: destinationFolder)
            if let preview = definition.previewAssetName {
                try copyPackageFile(preview, from: sourceURL, to: destinationFolder)
            }
            try copyActionPacksIfPresent(from: sourceURL, to: destinationFolder)
            try copyPackageFileIfPresent("action-pack-overrides.json", from: sourceURL, to: destinationFolder)
        } catch let error as PetLibraryError {
            cleanUp(destinationFolder)
            throw error
        } catch {
            DesktopPetLog.petLibrary.error(
                "Failed to copy package \(definition.id, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
            cleanUp(destinationFolder)
            throw PetLibraryError.invalidPackage
        }

        return definition
    }

    private func copyPackageFile(_ fileName: String, from sourceFolder: URL, to destinationFolder: URL) throws {
        let source = sourceFolder.appendingPathComponent(fileName)
        let destination = destinationFolder.appendingPathComponent(fileName)
        do {
            try fileManager.copyItem(at: source, to: destination)
        } catch {
            DesktopPetLog.petLibrary.error(
                "Failed to copy package file \(fileName, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
            throw PetLibraryError.invalidPackage
        }
    }

    private func copyPackageFileIfPresent(_ fileName: String, from sourceFolder: URL, to destinationFolder: URL) throws {
        let source = sourceFolder.appendingPathComponent(fileName)
        guard fileManager.fileExists(atPath: source.path) else { return }
        let destination = destinationFolder.appendingPathComponent(fileName)
        try fileManager.copyItem(at: source, to: destination)
    }

    private func copyActionPacksIfPresent(from sourceFolder: URL, to destinationFolder: URL) throws {
        let sourcePacksDir = sourceFolder.appendingPathComponent("action-packs")
        guard fileManager.fileExists(atPath: sourcePacksDir.path) else { return }
        let destinationPacksDir = destinationFolder.appendingPathComponent("action-packs")
        try fileManager.copyItem(at: sourcePacksDir, to: destinationPacksDir)
    }

    private func mapPackageError(_ error: Error) -> PetLibraryError {
        if let libraryError = error as? PetLibraryError {
            return libraryError
        }

        guard let assetError = error as? PetAssetError else {
            return .invalidPackage
        }

        switch assetError {
        case .invalidPackageExtension:
            return .unsupportedPackage
        case .manifestNotFound:
            return .missingManifest
        case .missingPackageResource:
            return .missingPackageResource
        case .invalidPackageStructure,
             .singleImagePackageUnsupported,
             .unsafePackageResourceName,
             .unreadablePackageResource,
             .invalidSpriteSheetLayout,
             .emptyAnimation,
             .frameOutOfBounds,
             .missingRequiredAnimation,
             .packageLoadingReservedForFutureVersion:
            return .invalidPackage
        }
    }

    private func cleanUp(_ folderURL: URL) {
        guard fileManager.fileExists(atPath: folderURL.path) else {
            return
        }

        do {
            try fileManager.removeItem(at: folderURL)
        } catch {
            DesktopPetLog.petLibrary.warning(
                "Failed to remove partially imported package at \(folderURL.path, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
        }
    }
}
