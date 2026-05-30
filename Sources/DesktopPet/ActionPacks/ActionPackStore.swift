import Foundation

// MARK: - Store Protocol

public protocol ActionPackStoring: Sendable {
    func loadPacks(
        in petFolderURL: URL,
        baseFrameSize: CGSizeCodable,
        existingActionIds: Set<ActionId>
    ) throws -> ActionPackLoadResult
    func deletePack(id: String, in petFolderURL: URL) throws
}

// MARK: - Writer Protocol

public protocol ActionPackWriting: Sendable {
    func writeDraft(
        _ draft: ActionPackDraft,
        to petFolderURL: URL,
        baseFrameSize: CGSizeCodable
    ) throws -> ValidatedActionPack
}

// MARK: - File Action Pack Store

public final class FileActionPackStore: ActionPackStoring, @unchecked Sendable {
    private let validator: ActionPackValidating
    private let fileManager: FileManager

    public init(
        validator: ActionPackValidating = DefaultActionPackValidator(),
        fileManager: FileManager = .default
    ) {
        self.validator = validator
        self.fileManager = fileManager
    }

    public func loadPacks(
        in petFolderURL: URL,
        baseFrameSize: CGSizeCodable,
        existingActionIds: Set<ActionId>
    ) throws -> ActionPackLoadResult {
        let packsDir = petFolderURL.appendingPathComponent("action-packs")

        guard fileManager.fileExists(atPath: packsDir.path) else {
            return ActionPackLoadResult(packs: [], warnings: [])
        }

        let contents = try fileManager.contentsOfDirectory(
            at: packsDir,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )

        let subdirs = contents.filter { url in
            (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
        }.sorted { $0.lastPathComponent < $1.lastPathComponent }

        var packs: [ValidatedActionPack] = []
        var warnings: [ActionPackWarning] = []
        var mergedActionIds = existingActionIds

        for dir in subdirs {
            let directoryName = dir.lastPathComponent
            let manifestURL = dir.appendingPathComponent("manifest.json")

            guard fileManager.fileExists(atPath: manifestURL.path) else {
                warnings.append(ActionPackWarning(
                    kind: .packSkipped,
                    packId: directoryName,
                    detail: "Missing manifest.json"
                ))
                continue
            }

            let manifestData: Data
            do {
                manifestData = try Data(contentsOf: manifestURL)
            } catch {
                warnings.append(ActionPackWarning(
                    kind: .packSkipped,
                    packId: directoryName,
                    detail: "Cannot read manifest.json: \(error.localizedDescription)"
                ))
                continue
            }

            let manifest: ActionPackManifest
            do {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                manifest = try decoder.decode(ActionPackManifest.self, from: manifestData)
            } catch {
                warnings.append(ActionPackWarning(
                    kind: .packSkipped,
                    packId: directoryName,
                    detail: "Cannot decode manifest.json: \(error.localizedDescription)"
                ))
                continue
            }

            do {
                let validated = try validator.validate(
                    manifest: manifest,
                    packURL: dir,
                    directoryName: directoryName,
                    baseFrameSize: baseFrameSize,
                    existingActionIds: mergedActionIds
                )
                packs.append(validated)
                for action in validated.manifest.actions {
                    _ = mergedActionIds.insert(action.id)
                }
                warnings.append(contentsOf: validated.warnings)
            } catch {
                warnings.append(ActionPackWarning(
                    kind: .packSkipped,
                    packId: directoryName,
                    detail: "Validation failed: \(error.localizedDescription)"
                ))
            }
        }

        return ActionPackLoadResult(packs: packs, warnings: warnings)
    }

    public func deletePack(id: String, in petFolderURL: URL) throws {
        let packDir = petFolderURL
            .appendingPathComponent("action-packs")
            .appendingPathComponent(id)

        guard fileManager.fileExists(atPath: packDir.path) else {
            throw ActionPackError.resourceNotFound(
                packId: id, resourceId: "", path: packDir.path
            )
        }

        try fileManager.removeItem(at: packDir)
    }
}

// MARK: - File Action Pack Writer

public final class FileActionPackWriter: ActionPackWriting, @unchecked Sendable {
    private let validator: ActionPackValidating
    private let fileManager: FileManager

    public init(
        validator: ActionPackValidating = DefaultActionPackValidator(),
        fileManager: FileManager = .default
    ) {
        self.validator = validator
        self.fileManager = fileManager
    }

    public func writeDraft(
        _ draft: ActionPackDraft,
        to petFolderURL: URL,
        baseFrameSize: CGSizeCodable
    ) throws -> ValidatedActionPack {
        let packsDir = petFolderURL.appendingPathComponent("action-packs")
        try fileManager.createDirectory(at: packsDir, withIntermediateDirectories: true)

        let tmpDirName = ".tmp-\(UUID().uuidString)"
        let tmpDir = packsDir.appendingPathComponent(tmpDirName)
        try fileManager.createDirectory(at: tmpDir, withIntermediateDirectories: true)

        do {
            try writeManifest(draft.manifest, to: tmpDir)
            try writeResourceImages(draft.resourceImages, to: tmpDir)
            try writePreview(draft.previewData, to: tmpDir)
            try writeSourceMetadata(draft.sourceMetadata, to: tmpDir)

            let validated = try validator.validate(
                manifest: draft.manifest,
                packURL: tmpDir,
                directoryName: draft.manifest.id,
                baseFrameSize: baseFrameSize,
                existingActionIds: []
            )

            let finalDir = packsDir.appendingPathComponent(draft.manifest.id)
            if fileManager.fileExists(atPath: finalDir.path) {
                try fileManager.removeItem(at: finalDir)
            }
            try fileManager.moveItem(at: tmpDir, to: finalDir)

            return validated
        } catch {
            cleanupTempDir(tmpDir)
            throw error
        }
    }

    // MARK: - Write Helpers

    private func writeManifest(_ manifest: ActionPackManifest, to dir: URL) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(manifest)
        let url = dir.appendingPathComponent("manifest.json")
        try data.write(to: url, options: .atomic)
    }

    private func writeResourceImages(_ images: [String: Data], to dir: URL) throws {
        for (filename, data) in images {
            let url = dir.appendingPathComponent(filename)
            try data.write(to: url, options: .atomic)
        }
    }

    private func writePreview(_ previewData: Data?, to dir: URL) throws {
        guard let previewData else { return }
        let url = dir.appendingPathComponent("preview.png")
        try previewData.write(to: url, options: .atomic)
    }

    private func writeSourceMetadata(_ metadata: ActionPackSourceMetadata?, to dir: URL) throws {
        guard let metadata else { return }
        let sanitized = metadata.sanitized()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(sanitized)
        let url = dir.appendingPathComponent("source.json")
        try data.write(to: url, options: .atomic)
    }

    private func cleanupTempDir(_ url: URL) {
        do {
            if fileManager.fileExists(atPath: url.path) {
                try fileManager.removeItem(at: url)
            }
        } catch {
            // Best effort cleanup - can't throw from here
        }
    }
}
