import Foundation

public protocol RelationshipStoring: Sendable {
    func loadState(petId: String) throws -> RelationshipState
    func saveState(_ state: RelationshipState, petId: String) throws
    func resetState(petId: String) throws
}

public enum RelationshipStoreError: Error, Equatable, Sendable {
    case writeFailed(petId: String, reason: String)
    case deleteFailed(petId: String, reason: String)
}

public final class RelationshipStore: RelationshipStoring, @unchecked Sendable {
    public static let relationshipsDirectoryName = "Relationships"
    public static let fileName = "relationship.json"

    private let rootDirectoryURL: URL
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public var relationshipsDirectoryURL: URL {
        rootDirectoryURL.appendingPathComponent(Self.relationshipsDirectoryName, isDirectory: true)
    }

    public init(
        rootDirectoryURL: URL? = nil,
        fileManager: FileManager = .default,
        encoder: JSONEncoder = JSONEncoder(),
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.rootDirectoryURL = rootDirectoryURL ?? Self.defaultRootDirectoryURL(fileManager: fileManager)
        self.fileManager = fileManager
        self.encoder = encoder
        self.decoder = decoder
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }

    public func loadState(petId: String) throws -> RelationshipState {
        let fileURL = relationshipFileURL(for: petId)
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return RelationshipState()
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let state = try decoder.decode(RelationshipState.self, from: data)
            guard state.schemaVersion == RelationshipState.currentSchemaVersion else {
                return RelationshipState()
            }
            return state
        } catch {
            return RelationshipState()
        }
    }

    public func saveState(_ state: RelationshipState, petId: String) throws {
        let petDirectoryURL = petDirectoryURL(for: petId)
        let destinationURL = relationshipFileURL(for: petId)
        let temporaryURL = petDirectoryURL.appendingPathComponent(
            ".\(Self.fileName).\(UUID().uuidString).tmp",
            isDirectory: false
        )

        var normalizedState = state
        normalizedState.schemaVersion = RelationshipState.currentSchemaVersion

        do {
            try fileManager.createDirectory(at: petDirectoryURL, withIntermediateDirectories: true)
            let data = try encoder.encode(normalizedState)
            try data.write(to: temporaryURL)
            if fileManager.fileExists(atPath: destinationURL.path) {
                _ = try fileManager.replaceItemAt(destinationURL, withItemAt: temporaryURL)
            } else {
                try fileManager.moveItem(at: temporaryURL, to: destinationURL)
            }
        } catch {
            try? fileManager.removeItem(at: temporaryURL)
            throw RelationshipStoreError.writeFailed(petId: petId, reason: error.localizedDescription)
        }
    }

    public func resetState(petId: String) throws {
        try saveState(RelationshipState(), petId: petId)
    }

    public func deleteState(petId: String) throws {
        let fileURL = relationshipFileURL(for: petId)
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return
        }

        do {
            try fileManager.removeItem(at: fileURL)
            try removePetDirectoryIfEmpty(for: petId)
        } catch {
            throw RelationshipStoreError.deleteFailed(petId: petId, reason: error.localizedDescription)
        }
    }

    public func relationshipFileURL(for petId: String) -> URL {
        petDirectoryURL(for: petId).appendingPathComponent(Self.fileName, isDirectory: false)
    }

    private func petDirectoryURL(for petId: String) -> URL {
        relationshipsDirectoryURL.appendingPathComponent(petId, isDirectory: true)
    }

    private func removePetDirectoryIfEmpty(for petId: String) throws {
        let directoryURL = petDirectoryURL(for: petId)
        guard fileManager.fileExists(atPath: directoryURL.path) else {
            return
        }

        let contents = try fileManager.contentsOfDirectory(atPath: directoryURL.path)
        if contents.isEmpty {
            try fileManager.removeItem(at: directoryURL)
        }
    }

    private static func defaultRootDirectoryURL(fileManager: FileManager) -> URL {
        if let url = try? fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        ) {
            return url.appendingPathComponent("DesktopPet", isDirectory: true)
        }

        return fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/DesktopPet", isDirectory: true)
    }
}
