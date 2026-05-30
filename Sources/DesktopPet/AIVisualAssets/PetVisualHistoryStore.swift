import Foundation

public protocol PetVisualHistoryStoring: Sendable {
    func loadHistory(petId: String) -> [PetVisualAsset]
    func loadFavorites(petId: String) -> [PetVisualAsset]
    func markFavorite(assetId: String, petId: String) throws
    func unmarkFavorite(assetId: String, petId: String) throws
    func renameFavorite(assetId: String, petId: String, name: String?) throws
    func deleteRecord(assetId: String, petId: String) throws
    func setActiveFavorite(assetId: String, petId: String) throws
    func clearActiveFavorite(petId: String) throws
    func clearHistory(petId: String) throws
    func clearAll(petId: String) throws
    func favoriteDisplayName(assetId: String) -> String?
    func activeFavoriteId() -> String?
}

public final class PetVisualHistoryStore: PetVisualHistoryStoring, @unchecked Sendable {
    private let assetStore: PetVisualAssetStoring
    private let preferenceStore: PetVisualPreferenceStoring

    public init(
        assetStore: PetVisualAssetStoring,
        preferenceStore: PetVisualPreferenceStoring
    ) {
        self.assetStore = assetStore
        self.preferenceStore = preferenceStore
    }

    public func loadHistory(petId: String) -> [PetVisualAsset] {
        assetStore.loadAllAssets(petId: petId)
            .sorted { $0.createdAt > $1.createdAt }
    }

    public func loadFavorites(petId: String) -> [PetVisualAsset] {
        assetStore.loadAllAssets(petId: petId)
            .filter { $0.isFavorite }
            .sorted { $0.createdAt > $1.createdAt }
    }

    public func markFavorite(assetId: String, petId: String) throws {
        try assetStore.markFavorite(assetId: assetId, petId: petId)
    }

    public func unmarkFavorite(assetId: String, petId: String) throws {
        try assetStore.unmarkFavorite(assetId: assetId, petId: petId)
        let prefs = preferenceStore.loadPreferences()
        if prefs.activeFavoriteId == assetId {
            preferenceStore.setActiveFavoriteId(nil)
        }
    }

    public func renameFavorite(assetId: String, petId: String, name: String?) throws {
        let prefs = preferenceStore.loadPreferences()
        let isCurrentlyFavorite = assetStore.loadAsset(id: assetId, petId: petId)?.isFavorite ?? false
        guard isCurrentlyFavorite else { return }
        preferenceStore.setFavoriteName(name, forAssetId: assetId)
        try assetStore.updateAsset(id: assetId, petId: petId) { asset in
            asset.favoriteName = name
        }
    }

    public func deleteRecord(assetId: String, petId: String) throws {
        let prefs = preferenceStore.loadPreferences()
        if prefs.activeFavoriteId == assetId {
            preferenceStore.setActiveFavoriteId(nil)
        }
        preferenceStore.setFavoriteName(nil, forAssetId: assetId)
        try assetStore.deleteAsset(id: assetId, petId: petId)
    }

    public func setActiveFavorite(assetId: String, petId: String) throws {
        let asset = assetStore.loadAsset(id: assetId, petId: petId)
        guard let asset, asset.isFavorite else { return }
        preferenceStore.setActiveFavoriteId(assetId)
    }

    public func clearActiveFavorite(petId: String) throws {
        preferenceStore.setActiveFavoriteId(nil)
    }

    public func clearHistory(petId: String) throws {
        try assetStore.clearNonFavoriteAssets(petId: petId)
    }

    public func clearAll(petId: String) throws {
        let allAssets = assetStore.loadAllAssets(petId: petId)
        for asset in allAssets {
            try? assetStore.deleteAsset(id: asset.id, petId: petId)
        }
        preferenceStore.savePreferences(PetVisualPreferences())
    }

    public func favoriteDisplayName(assetId: String) -> String? {
        preferenceStore.loadPreferences().favoriteNames[assetId]
    }

    public func activeFavoriteId() -> String? {
        preferenceStore.loadPreferences().activeFavoriteId
    }
}
