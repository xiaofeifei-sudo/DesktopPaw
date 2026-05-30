import AppKit
import CryptoKit
import Foundation

public struct PetDescriptor: Codable, Sendable, Equatable {
    public let petId: String

    public let speciesHint: String?
    public let nameHint: String?
    public let referenceImageTraits: ImageTraits?

    public let visualNotes: String?
    public let learnedConstraints: [String]

    public init(
        petId: String,
        speciesHint: String? = nil,
        nameHint: String? = nil,
        referenceImageTraits: ImageTraits? = nil,
        visualNotes: String? = nil,
        learnedConstraints: [String] = []
    ) {
        self.petId = petId
        self.speciesHint = speciesHint
        self.nameHint = nameHint
        self.referenceImageTraits = referenceImageTraits
        self.visualNotes = visualNotes
        self.learnedConstraints = learnedConstraints
    }
}

public struct ImageTraits: Codable, Sendable, Equatable {
    public let dominantColors: [String]
    public let hasAlpha: Bool
    public let estimatedStyle: String?
    public let width: Int
    public let height: Int

    public init(
        dominantColors: [String],
        hasAlpha: Bool,
        estimatedStyle: String? = nil,
        width: Int,
        height: Int
    ) {
        self.dominantColors = dominantColors
        self.hasAlpha = hasAlpha
        self.estimatedStyle = estimatedStyle
        self.width = width
        self.height = height
    }
}

public protocol PetIdentityDescribing: Sendable {
    func descriptor(for petId: String) async -> PetDescriptor
    func updateVisualNotes(_ notes: String, for petId: String) async throws
    func visualNotes(for petId: String) async -> String?
    func updateLearnedConstraints(_ constraints: [String], for petId: String)
}

public final class PetIdentityDescriptorStore: PetIdentityDescribing, @unchecked Sendable {
    private let baseDirectory: URL
    private let fileManager: FileManager
    private let visualPreferenceStore: PetVisualPreferenceStoring?
    private let lock = NSLock()

    public init(
        baseDirectory: URL? = nil,
        fileManager: FileManager = .default,
        visualPreferenceStore: PetVisualPreferenceStoring? = nil
    ) {
        self.baseDirectory = baseDirectory ?? PetVisualAssetStore.defaultBaseDirectory()
        self.fileManager = fileManager
        self.visualPreferenceStore = visualPreferenceStore
    }

    public func descriptor(for petId: String) async -> PetDescriptor {
        let cached = loadCachedDescriptor(petId: petId)
        let visualNotes = await visualNotes(for: petId)

        var speciesHint = cached?.speciesHint
        var nameHint = cached?.nameHint

        if speciesHint == nil || nameHint == nil {
            let manifestHints = extractManifestHints(petId: petId)
            if speciesHint == nil { speciesHint = manifestHints.speciesHint }
            if nameHint == nil { nameHint = manifestHints.nameHint }
        }

        return PetDescriptor(
            petId: petId,
            speciesHint: speciesHint,
            nameHint: nameHint,
            referenceImageTraits: cached?.referenceImageTraits,
            visualNotes: visualNotes,
            learnedConstraints: cached?.learnedConstraints ?? []
        )
    }

    public func updateVisualNotes(_ notes: String, for petId: String) async throws {
        visualPreferenceStore?.saveVisualNotes(notes, forPetId: petId)
    }

    public func visualNotes(for petId: String) async -> String? {
        visualPreferenceStore?.loadVisualNotes(forPetId: petId)
    }

    public func updateReferenceImageTraits(_ traits: ImageTraits, for petId: String) {
        lock.lock()
        defer { lock.unlock() }

        var cached = loadCachedDescriptor(petId: petId) ?? CachedDescriptor(petId: petId)
        cached.referenceImageTraits = traits
        cached.updatedAt = Date()
        saveCachedDescriptor(cached, petId: petId)
    }

    public func updateManifestHints(petId: String, displayName: String?, speciesHint: String?) {
        lock.lock()
        defer { lock.unlock() }

        var cached = loadCachedDescriptor(petId: petId) ?? CachedDescriptor(petId: petId)
        if let displayName { cached.nameHint = displayName }
        if let speciesHint { cached.speciesHint = speciesHint }
        cached.updatedAt = Date()
        saveCachedDescriptor(cached, petId: petId)
    }

    public func updateLearnedConstraints(_ constraints: [String], for petId: String) {
        lock.lock()
        defer { lock.unlock() }

        var cached = loadCachedDescriptor(petId: petId) ?? CachedDescriptor(petId: petId)
        cached.learnedConstraints = constraints
        cached.updatedAt = Date()
        saveCachedDescriptor(cached, petId: petId)
    }

    // MARK: - Cache

    private struct CachedDescriptor: Codable {
        let petId: String
        var speciesHint: String?
        var nameHint: String?
        var referenceImageTraits: ImageTraits?
        var learnedConstraints: [String]
        var updatedAt: Date

        init(petId: String) {
            self.petId = petId
            self.learnedConstraints = []
            self.updatedAt = Date()
        }
    }

    private func cacheFileURL(petId: String) -> URL {
        baseDirectory
            .appendingPathComponent(petId)
            .appendingPathComponent("visual-actions")
            .appendingPathComponent("pet-descriptor.json")
    }

    private func loadCachedDescriptor(petId: String) -> CachedDescriptor? {
        let url = cacheFileURL(petId: petId)
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(CachedDescriptor.self, from: data)
    }

    private func saveCachedDescriptor(_ descriptor: CachedDescriptor, petId: String) {
        let url = cacheFileURL(petId: petId)
        try? fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(descriptor) else { return }
        try? data.write(to: url, options: [.atomic])
    }

    // MARK: - Manifest Extraction

    private struct ManifestHints {
        let speciesHint: String?
        let nameHint: String?
    }

    private func extractManifestHints(petId: String) -> ManifestHints {
        var speciesHint: String?
        var nameHint: String?

        let petDirs = [
            baseDirectory.appendingPathComponent(petId),
            baseDirectory.appendingPathComponent("Pets").appendingPathComponent(petId),
        ]
        for dir in petDirs {
            for manifestName in ["manifest.json", "pet.json", "package.json"] {
                let url = dir.appendingPathComponent(manifestName)
                guard let data = try? Data(contentsOf: url) else { continue }
                guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }

                if nameHint == nil, let name = json["displayName"] as? String, !name.isEmpty {
                    nameHint = name
                }
                if speciesHint == nil {
                    if let species = json["species"] as? String, !species.isEmpty {
                        speciesHint = species
                    } else if let id = json["id"] as? String, !id.isEmpty {
                        speciesHint = inferSpecies(from: id)
                    }
                }
                break
            }
            if nameHint != nil || speciesHint != nil { break }
        }

        return ManifestHints(speciesHint: speciesHint, nameHint: nameHint)
    }

    private func inferSpecies(from id: String) -> String? {
        let lowered = id.lowercased()
        let knownSpecies = [
            "kitsune": "fox", "fox": "fox",
            "cat": "cat", "neko": "cat",
            "dog": "dog", "inu": "dog",
            "rabbit": "rabbit", "bunny": "rabbit",
            "bird": "bird", "penguin": "penguin",
            "bear": "bear",
        ]
        for (keyword, species) in knownSpecies {
            if lowered.contains(keyword) { return species }
        }
        return nil
    }

    // MARK: - Notes Sanitization

}
