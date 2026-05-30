import Foundation

public final class ContentPackManager: ContentPackManaging, @unchecked Sendable {
    private struct PackState: Codable, Equatable {
        var isEnabled: Bool
    }

    private let installedRootURL: URL
    private let validator: ContentPackValidator
    private let fileManager: FileManager

    public init(
        installedRootURL: URL? = nil,
        validator: ContentPackValidator = ContentPackValidator(),
        fileManager: FileManager = .default
    ) {
        self.fileManager = fileManager
        self.installedRootURL = installedRootURL ?? Self.defaultInstalledRootURL(fileManager: fileManager)
        self.validator = validator
    }

    public func importPack(from url: URL) throws -> ContentPack {
        let validation = validatePack(at: url)
        guard validation.isValid else {
            throw ContentPackError.validationFailed(validation)
        }

        let manifest = try ContentPackManifest.load(from: url)
        let destination = installedURL(for: manifest.id)
        do {
            try ensureInstalledRootExists()
            if fileManager.fileExists(atPath: destination.path) {
                try fileManager.removeItem(at: destination)
            }
            try fileManager.copyItem(at: url, to: destination)
            try writeState(PackState(isEnabled: false), packURL: destination)
            return ContentPack(manifest: manifest, installedURL: destination, isEnabled: false)
        } catch let error as ContentPackError {
            throw error
        } catch {
            throw ContentPackError.storageError(error.localizedDescription)
        }
    }

    public func validatePack(at url: URL) -> ContentPackValidationResult {
        validator.validatePack(at: url)
    }

    public func getInstalledPacks() -> [ContentPack] {
        guard let urls = try? fileManager.contentsOfDirectory(
            at: installedRootURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return urls
            .filter { $0.pathExtension == "dpcp" }
            .compactMap(loadInstalledPack)
            .sorted { $0.id < $1.id }
    }

    public func enablePack(_ packId: String) throws {
        try updateEnabled(true, packId: packId)
    }

    public func disablePack(_ packId: String) throws {
        try updateEnabled(false, packId: packId)
    }

    public func removePack(_ packId: String) throws {
        let url = installedURL(for: packId)
        guard fileManager.fileExists(atPath: url.path) else {
            throw ContentPackError.packNotFound(packId)
        }
        try fileManager.removeItem(at: url)
    }

    public func previewPack(_ packId: String) throws -> ContentPackPreview {
        let packURL = installedURL(for: packId)
        guard let pack = loadInstalledPack(packURL) else {
            throw ContentPackError.packNotFound(packId)
        }

        switch pack.manifest.type {
        case .dialogue:
            let dialogue = try DialoguePack.load(from: packURL, manifest: pack.manifest)
            return ContentPackPreview(
                packId: pack.id,
                type: .dialogue,
                name: pack.manifest.name,
                previewPhrases: pack.manifest.previewPhrases,
                phrases: dialogue.entries.map(\.text)
            )
        case .personality:
            let personality = try PersonalityPack.load(from: packURL, manifest: pack.manifest)
            return ContentPackPreview(
                packId: pack.id,
                type: .personality,
                name: pack.manifest.name,
                previewPhrases: personality.payload.previewPhrases,
                personalityName: pack.manifest.name
            )
        case .action:
            let action = try ActionPack.load(from: packURL, manifest: pack.manifest)
            return ContentPackPreview(
                packId: pack.id,
                type: .action,
                name: pack.manifest.name,
                previewPhrases: pack.manifest.previewPhrases,
                actionNames: action.actions.map(\.displayName)
            )
        }
    }

    public func restoreDefaultContent() throws {
        for pack in getInstalledPacks() {
            try disablePack(pack.id)
        }
    }

    public func enabledDialogueCatalog(merging base: BubblePhraseCatalog) -> BubblePhraseCatalog {
        enabledPacks(ofType: .dialogue).reduce(base) { catalog, pack in
            guard let dialogue = try? DialoguePack.load(from: pack.installedURL, manifest: pack.manifest) else {
                return catalog
            }
            return catalog.merging(with: dialogue.bubbleCatalog())
        }
    }

    public func enabledBubbleCatalog(merging base: BubblePhraseCatalog) -> BubblePhraseCatalog {
        let withDialogue = enabledDialogueCatalog(merging: base)
        return enabledPacks(ofType: .personality).reduce(withDialogue) { catalog, pack in
            guard let personality = try? PersonalityPack.load(from: pack.installedURL, manifest: pack.manifest) else {
                return catalog
            }
            return catalog.merging(with: personality.bubbleCatalog())
        }
    }

    public func availablePersonalityProfiles(base: [AIPersonalityProfile]) -> [AIPersonalityProfile] {
        let existingIds = Set(base.map(\.id))
        let packProfiles = enabledPacks(ofType: .personality).compactMap { pack -> AIPersonalityProfile? in
            guard let personality = try? PersonalityPack.load(from: pack.installedURL, manifest: pack.manifest) else {
                return nil
            }
            let profile = personality.profile()
            return existingIds.contains(profile.id) ? nil : profile
        }
        return base + packProfiles
    }

    public func enabledActionCatalog(merging base: PetActionCatalog) -> PetActionCatalog {
        var existingIds = Set(base.actions.map(\.id))
        var actions = base.actions
        for pack in enabledPacks(ofType: .action) {
            guard let actionPack = try? ActionPack.load(from: pack.installedURL, manifest: pack.manifest) else {
                continue
            }
            for action in actionPack.actions where !existingIds.contains(action.id) {
                existingIds.insert(action.id)
                actions.append(action)
            }
        }
        return PetActionCatalog(petId: base.petId, actions: actions, warnings: base.warnings)
    }

    private func enabledPacks(ofType type: ContentPackType) -> [ContentPack] {
        getInstalledPacks().filter { $0.isEnabled && $0.manifest.type == type }
    }

    private func updateEnabled(_ enabled: Bool, packId: String) throws {
        let url = installedURL(for: packId)
        guard fileManager.fileExists(atPath: url.path) else {
            throw ContentPackError.packNotFound(packId)
        }
        try writeState(PackState(isEnabled: enabled), packURL: url)
    }

    private func loadInstalledPack(_ url: URL) -> ContentPack? {
        guard let manifest = try? ContentPackManifest.load(from: url) else {
            return nil
        }
        let state = loadState(packURL: url)
        return ContentPack(manifest: manifest, installedURL: url, isEnabled: state.isEnabled)
    }

    private func loadState(packURL: URL) -> PackState {
        let url = stateURL(for: packURL)
        guard let data = try? Data(contentsOf: url),
              let state = try? JSONDecoder().decode(PackState.self, from: data) else {
            return PackState(isEnabled: false)
        }
        return state
    }

    private func writeState(_ state: PackState, packURL: URL) throws {
        let data = try JSONEncoder().encode(state)
        try data.write(to: stateURL(for: packURL), options: .atomic)
    }

    private func installedURL(for packId: String) -> URL {
        installedRootURL.appendingPathComponent("\(packId).dpcp", isDirectory: true)
    }

    private func stateURL(for packURL: URL) -> URL {
        packURL.appendingPathComponent(".content-pack-state.json")
    }

    private func ensureInstalledRootExists() throws {
        if !fileManager.fileExists(atPath: installedRootURL.path) {
            try fileManager.createDirectory(at: installedRootURL, withIntermediateDirectories: true)
        }
    }

    private static func defaultInstalledRootURL(fileManager: FileManager) -> URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport
            .appendingPathComponent("DesktopPet", isDirectory: true)
            .appendingPathComponent("content-packs", isDirectory: true)
    }
}
