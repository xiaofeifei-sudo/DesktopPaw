import Foundation

public protocol PetdexPackageImporting {
    func importPackage(
        at archiveURL: URL,
        to importedPetsDirectoryURL: URL,
        builtInPetId: String
    ) throws -> PetDefinition
}

public final class PetdexPackageImporter: PetdexPackageImporting {
    public typealias FileWriter = (Data, URL) throws -> Void

    private let archiveReader: PetdexArchiveReading
    private let manifestParser: PetdexManifestParsing
    private let spriteSheetProcessor: PetdexSpriteSheetProcessing
    private let mappingProvider: PetdexAnimationMappingProviding
    private let converter: PetdexPackageConverting
    private let fileManager: FileManager
    private let imageConvention: PetdexSpriteSheetConvention
    private let fileWriter: FileWriter

    public init(
        archiveReader: PetdexArchiveReading = PetdexArchiveReader(),
        manifestParser: PetdexManifestParsing = PetdexManifestParser(),
        spriteSheetProcessor: PetdexSpriteSheetProcessing = PetdexSpriteSheetProcessor(),
        mappingProvider: PetdexAnimationMappingProviding = DefaultPetdexAnimationMappingProvider(),
        converter: PetdexPackageConverting = PetdexPackageConverter(),
        fileManager: FileManager = .default,
        imageConvention: PetdexSpriteSheetConvention = PetdexSpriteSheetConvention(
            columns: DefaultPetdexAnimationMappingProvider.defaultColumns,
            rows: DefaultPetdexAnimationMappingProvider.defaultRows
        ),
        fileWriter: @escaping FileWriter = { data, url in
            try data.write(to: url, options: [.atomic])
        }
    ) {
        self.archiveReader = archiveReader
        self.manifestParser = manifestParser
        self.spriteSheetProcessor = spriteSheetProcessor
        self.mappingProvider = mappingProvider
        self.converter = converter
        self.fileManager = fileManager
        self.imageConvention = imageConvention
        self.fileWriter = fileWriter
    }

    public func importPackage(
        at archiveURL: URL,
        to importedPetsDirectoryURL: URL,
        builtInPetId: String
    ) throws -> PetDefinition {
        let archive = try archiveReader.readPackage(at: archiveURL)
        let manifest = try manifestParser.parse(archive.manifestData)
        try validatePetId(manifest.id)

        guard manifest.id != builtInPetId else {
            throw PetdexImportError.petAlreadyExists(manifest.id)
        }

        try validateSupportedRows(imageConvention.rows)

        let processedSpritesheet = try spriteSheetProcessor.process(
            data: archive.spritesheetData,
            sourceFileName: archive.spritesheetFileName,
            convention: imageConvention
        )
        let convention = try mappingProvider.convention(
            for: manifest,
            imageSize: processedSpritesheet.pixelSize
        )
        try validateSupportedRows(convention.rows)
        let mappingResult = try mappingProvider.actions(for: convention)
        let actions = trimTrailingTransparentFrames(
            in: mappingResult.actions,
            nonEmptyFrameCountsByRow: processedSpritesheet.nonEmptyFrameCountsByRow
        )
        let convertedPackage = try converter.convert(
            manifest: manifest,
            spritesheet: processedSpritesheet,
            actions: actions,
            warnings: mappingResult.warnings
        )
        let definition = try convertedPackage.manifest.petDefinition()

        try createDirectoryIfNeeded(importedPetsDirectoryURL)

        let destinationFolder = importedPetsDirectoryURL.appendingPathComponent(convertedPackage.petId, isDirectory: true)
        guard !fileManager.fileExists(atPath: destinationFolder.path) else {
            throw PetdexImportError.petAlreadyExists(convertedPackage.petId)
        }

        do {
            try fileManager.createDirectory(at: destinationFolder, withIntermediateDirectories: true)
            try write(convertedPackage.files, to: destinationFolder)
        } catch let error as PetdexImportError {
            cleanUp(destinationFolder)
            throw error
        } catch {
            cleanUp(destinationFolder)
            throw PetdexImportError.writeFailed(destinationFolder.path)
        }

        return definition
    }

    private func createDirectoryIfNeeded(_ url: URL) throws {
        do {
            try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        } catch {
            throw PetdexImportError.writeFailed(url.path)
        }
    }

    private func validateSupportedRows(_ rows: Int) throws {
        guard rows > 0 else {
            throw PetdexImportError.invalidSpritesheetLayout("spritesheet rows must be greater than zero")
        }
    }

    private func write(_ files: [String: Data], to folderURL: URL) throws {
        for (fileName, data) in files {
            try validateOutputFileName(fileName)
            let fileURL = folderURL.appendingPathComponent(fileName, isDirectory: false)
            do {
                try fileWriter(data, fileURL)
            } catch {
                throw PetdexImportError.writeFailed(fileURL.path)
            }
        }
    }

    private func trimTrailingTransparentFrames(
        in actions: [Action],
        nonEmptyFrameCountsByRow: [Int: Int]
    ) -> [Action] {
        guard !nonEmptyFrameCountsByRow.isEmpty else {
            return actions
        }

        return actions.map { action in
            guard let row = action.frames.map(\.row).min(),
                  let frameCount = nonEmptyFrameCountsByRow[row],
                  frameCount > 0 else {
                return action
            }

            let frames = action.frames.filter { frame in
                frame.row != row || frame.column < frameCount
            }
            guard !frames.isEmpty, frames.count != action.frames.count else {
                return action
            }

            return Action(
                id: action.id,
                displayName: action.displayName,
                role: action.role,
                tags: action.tags,
                frames: frames,
                frameDurationMs: action.frameDurationMs,
                loop: action.loop,
                nextActionId: action.nextActionId
            )
        }
    }

    private func validatePetId(_ id: String) throws {
        guard !id.isEmpty,
              id != ".",
              id != "..",
              !id.contains("/"),
              !id.contains("\\") else {
            throw PetdexImportError.invalidManifestField(field: "id", reason: "must be a safe folder name")
        }
    }

    private func validateOutputFileName(_ fileName: String) throws {
        guard !fileName.isEmpty,
              fileName != ".",
              fileName != "..",
              !fileName.contains("/"),
              !fileName.contains("\\") else {
            throw PetdexImportError.writeFailed(fileName)
        }
    }

    private func cleanUp(_ folderURL: URL) {
        guard fileManager.fileExists(atPath: folderURL.path) else {
            return
        }

        try? fileManager.removeItem(at: folderURL)
    }
}
