import Foundation

public protocol ActionPackOverrideStoring: Sendable {
    func load(petId: String) -> ActionPackOverrideSet?
    func save(_ overrides: ActionPackOverrideSet, petId: String) throws
    func delete(petId: String)
}

public final class FileActionPackOverrideStore: ActionPackOverrideStoring, @unchecked Sendable {
    public static let fileName = "action-pack-overrides.json"

    private let petsDirectoryURL: URL
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(
        petsDirectoryURL: URL,
        fileManager: FileManager = .default
    ) {
        self.petsDirectoryURL = petsDirectoryURL
        self.fileManager = fileManager

        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder = enc

        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        self.decoder = dec
    }

    public func load(petId: String) -> ActionPackOverrideSet? {
        let url = overrideFileURL(for: petId)
        guard fileManager.fileExists(atPath: url.path) else {
            return nil
        }

        guard let data = try? Data(contentsOf: url) else {
            return nil
        }

        guard let overrides = try? decoder.decode(ActionPackOverrideSet.self, from: data) else {
            return nil
        }

        guard overrides.schemaVersion == ActionPackOverrideSet.currentSchemaVersion else {
            return nil
        }

        return overrides
    }

    public func save(_ overrides: ActionPackOverrideSet, petId: String) throws {
        let url = overrideFileURL(for: petId)
        let petDir = url.deletingLastPathComponent()
        try fileManager.createDirectory(at: petDir, withIntermediateDirectories: true)

        let normalized = ActionPackOverrideSet(
            schemaVersion: ActionPackOverrideSet.currentSchemaVersion,
            petId: overrides.petId,
            disabledPackIds: overrides.disabledPackIds,
            actionOverrides: overrides.actionOverrides
        )

        let data: Data
        do {
            data = try encoder.encode(normalized)
        } catch {
            throw ActionPackError.overrideDecodingFailed(underlying: error.localizedDescription)
        }

        let tmpURL = url.deletingLastPathComponent()
            .appendingPathComponent(".tmp-\(UUID().uuidString)-\(Self.fileName)")

        do {
            try data.write(to: tmpURL, options: .atomic)
            if fileManager.fileExists(atPath: url.path) {
                _ = try fileManager.replaceItemAt(url, withItemAt: tmpURL)
            } else {
                try fileManager.moveItem(at: tmpURL, to: url)
            }
        } catch {
            try? fileManager.removeItem(at: tmpURL)
            throw ActionPackError.writeFailed(packId: petId, underlying: error.localizedDescription)
        }
    }

    public func delete(petId: String) {
        let url = overrideFileURL(for: petId)
        try? fileManager.removeItem(at: url)
    }

    private func overrideFileURL(for petId: String) -> URL {
        petsDirectoryURL
            .appendingPathComponent(petId)
            .appendingPathComponent(Self.fileName)
    }
}
