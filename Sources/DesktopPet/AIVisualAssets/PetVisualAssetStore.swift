import Foundation

public protocol PetVisualAssetStoring: Sendable {
    func preparePendingDirectory(petId: String, actionId: String) throws -> URL
    func commitAsset(
        from imageURL: URL,
        petId: String,
        actionId: String,
        providerId: String,
        kind: AIVisualActionKind,
        renderMode: PetVisualRenderMode,
        promptDigest: String,
        expiresAt: Date?,
        lifecycleState: AssetLifecycleState,
        gateResult: GateResult?,
        referencePreviewURL: URL?,
        diagnosticsId: String?
    ) throws -> PetVisualAsset
    func loadAsset(id: String, petId: String) -> PetVisualAsset?
    func loadActiveAssets(petId: String, now: Date) -> [PetVisualAsset]
    func loadAllAssets(petId: String) -> [PetVisualAsset]
    func updateAsset(id: String, petId: String, update: (inout PetVisualAsset) -> Void) throws
    func markFavorite(assetId: String, petId: String) throws
    func unmarkFavorite(assetId: String, petId: String) throws
    func deleteAsset(id: String, petId: String) throws
    func clearNonFavoriteAssets(petId: String) throws
    func cleanupExpired(petId: String, now: Date) throws
    func cleanupPending(actionId: String, petId: String)
}

public final class PetVisualAssetStore: PetVisualAssetStoring, @unchecked Sendable {
    private let lock = NSLock()
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let baseDirectory: URL
    private let postprocessor: PetVisualImagePostprocessing
    private var cache: [String: [PetVisualAsset]] = [:]

    public init(
        baseDirectory: URL? = nil,
        postprocessor: PetVisualImagePostprocessing? = nil,
        fileManager: FileManager = .default,
        encoder: JSONEncoder = JSONEncoder(),
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.baseDirectory = baseDirectory ?? Self.defaultBaseDirectory()
        self.postprocessor = postprocessor ?? PetVisualImagePostprocessor()
        self.fileManager = fileManager
        self.encoder = encoder
        self.decoder = decoder
    }

    public static func defaultBaseDirectory() -> URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("DesktopPet")
    }

    public static func digestPrompt(_ prompt: String) -> String {
        let utf8 = prompt.utf8
        var hash: UInt64 = 5381
        for byte in utf8 {
            hash = ((hash << 5) &+ hash) &+ UInt64(byte)
        }
        return String(format: "%016llx", hash)
    }

    // MARK: - Pending Directory

    public func preparePendingDirectory(petId: String, actionId: String) throws -> URL {
        let dir = pendingDirectory(petId: petId, actionId: actionId)
        do {
            try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
            return dir
        } catch {
            throw PetVisualAssetError.pendingDirectoryCreationFailed(error.localizedDescription)
        }
    }

    public func cleanupPending(actionId: String, petId: String) {
        let dir = pendingDirectory(petId: petId, actionId: actionId)
        try? fileManager.removeItem(at: dir)
    }

    // MARK: - Commit Asset

    public func commitAsset(
        from imageURL: URL,
        petId: String,
        actionId: String,
        providerId: String,
        kind: AIVisualActionKind,
        renderMode: PetVisualRenderMode,
        promptDigest: String,
        expiresAt: Date?,
        lifecycleState: AssetLifecycleState = .applied,
        gateResult: GateResult? = nil,
        referencePreviewURL: URL? = nil,
        diagnosticsId: String? = nil
    ) throws -> PetVisualAsset {
        lock.lock()
        defer { lock.unlock() }

        let assetId = actionId
        let pngURL = try postprocessor.convertToPNGIfNeeded(at: imageURL)

        let assetsDir = self.assetsDirectory(petId: petId)
        try fileManager.createDirectory(at: assetsDir, withIntermediateDirectories: true)

        let destURL = assetsDir.appendingPathComponent("\(assetId).png")
        if pngURL != destURL {
            if fileManager.fileExists(atPath: destURL.path) {
                try fileManager.removeItem(at: destURL)
            }
            try fileManager.moveItem(at: pngURL, to: destURL)
        } else {
            if fileManager.fileExists(atPath: destURL.path) {
                try fileManager.removeItem(at: destURL)
            }
            try fileManager.copyItem(at: pngURL, to: destURL)
        }

        let pendingDir = pendingDirectory(petId: petId, actionId: actionId)
        try? fileManager.removeItem(at: pendingDir)

        let asset = PetVisualAsset(
            id: assetId,
            petId: petId,
            actionId: actionId,
            providerId: providerId,
            localURL: destURL,
            promptDigest: promptDigest,
            kind: kind,
            renderMode: renderMode,
            expiresAt: expiresAt,
            lifecycleState: lifecycleState,
            gateResult: gateResult,
            referencePreviewURL: referencePreviewURL,
            generationDiagnosticsId: diagnosticsId
        )

        var assets = loadAssetsLocked(petId: petId)
        assets.removeAll { $0.id == assetId }
        assets.append(asset)
        try saveAssetsLocked(assets, petId: petId)

        return asset
    }

    // MARK: - Load

    public func loadAsset(id: String, petId: String) -> PetVisualAsset? {
        lock.lock()
        defer { lock.unlock() }
        return loadAssetsLocked(petId: petId).first { $0.id == id }
    }

    public func loadActiveAssets(petId: String, now: Date = Date()) -> [PetVisualAsset] {
        lock.lock()
        defer { lock.unlock() }
        return loadAssetsLocked(petId: petId).filter { !$0.isExpired(now: now) }
    }

    public func loadAllAssets(petId: String) -> [PetVisualAsset] {
        lock.lock()
        defer { lock.unlock() }
        return loadAssetsLocked(petId: petId)
    }

    // MARK: - Update

    public func updateAsset(id: String, petId: String, update: (inout PetVisualAsset) -> Void) throws {
        lock.lock()
        defer { lock.unlock() }
        try updateAssetLocked(assetId: id, petId: petId, update: update)
    }

    // MARK: - Favorite

    public func markFavorite(assetId: String, petId: String) throws {
        lock.lock()
        defer { lock.unlock() }
        try updateAssetLocked(assetId: assetId, petId: petId) { $0.isFavorite = true }
    }

    public func unmarkFavorite(assetId: String, petId: String) throws {
        lock.lock()
        defer { lock.unlock() }
        try updateAssetLocked(assetId: assetId, petId: petId) { $0.isFavorite = false }
    }

    // MARK: - Delete

    public func deleteAsset(id: String, petId: String) throws {
        lock.lock()
        defer { lock.unlock() }

        var assets = loadAssetsLocked(petId: petId)
        guard let index = assets.firstIndex(where: { $0.id == id }) else {
            throw PetVisualAssetError.assetNotFound(assetId: id)
        }

        let asset = assets.remove(at: index)
        try? fileManager.removeItem(at: asset.localURL)
        try saveAssetsLocked(assets, petId: petId)
    }

    public func clearNonFavoriteAssets(petId: String) throws {
        lock.lock()
        defer { lock.unlock() }

        let assets = loadAssetsLocked(petId: petId)
        let toDelete = assets.filter { !$0.isFavorite }
        let toKeep = assets.filter { $0.isFavorite }

        for asset in toDelete {
            try? fileManager.removeItem(at: asset.localURL)
        }

        try saveAssetsLocked(toKeep, petId: petId)
    }

    public func cleanupExpired(petId: String, now: Date = Date()) throws {
        lock.lock()
        defer { lock.unlock() }

        let assets = loadAssetsLocked(petId: petId)
        var toKeep: [PetVisualAsset] = []

        for asset in assets {
            if asset.isFavorite {
                toKeep.append(asset)
            } else if asset.isExpired(now: now) {
                try? fileManager.removeItem(at: asset.localURL)
            } else {
                toKeep.append(asset)
            }
        }

        try saveAssetsLocked(toKeep, petId: petId)
    }

    // MARK: - Private

    private func visualActionsDirectory(petId: String) -> URL {
        baseDirectory.appendingPathComponent(petId).appendingPathComponent("visual-actions")
    }

    private func assetsDirectory(petId: String) -> URL {
        visualActionsDirectory(petId: petId).appendingPathComponent("assets")
    }

    private func pendingDirectory(petId: String, actionId: String) -> URL {
        visualActionsDirectory(petId: petId).appendingPathComponent("pending").appendingPathComponent(actionId)
    }

    private func metadataURL(petId: String) -> URL {
        visualActionsDirectory(petId: petId).appendingPathComponent("metadata.json")
    }

    private func loadAssetsLocked(petId: String) -> [PetVisualAsset] {
        if let cached = cache[petId] { return cached }

        let url = metadataURL(petId: petId)
        guard fileManager.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let assets = try? decoder.decode([PetVisualAsset].self, from: data)
        else { return [] }

        cache[petId] = assets
        return assets
    }

    private func saveAssetsLocked(_ assets: [PetVisualAsset], petId: String) throws {
        cache[petId] = assets

        let url = metadataURL(petId: petId)
        let dir = url.deletingLastPathComponent()
        try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)

        guard let data = try? encoder.encode(assets) else {
            throw PetVisualAssetError.metadataWriteFailed
        }

        let tempURL = dir.appendingPathComponent(".metadata.json.tmp")
        try data.write(to: tempURL)

        try? fileManager.removeItem(at: url)
        try fileManager.moveItem(at: tempURL, to: url)
    }

    private func updateAssetLocked(
        assetId: String,
        petId: String,
        update: (inout PetVisualAsset) -> Void
    ) throws {
        var assets = loadAssetsLocked(petId: petId)
        guard let index = assets.firstIndex(where: { $0.id == assetId }) else {
            throw PetVisualAssetError.assetNotFound(assetId: assetId)
        }
        update(&assets[index])
        try saveAssetsLocked(assets, petId: petId)
    }
}
