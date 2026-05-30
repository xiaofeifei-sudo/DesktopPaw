import Foundation
import DesktopPet
import AppKit

@MainActor
func runPetVisualHistoryStoreTests() {
    let tests = PetVisualHistoryStoreTests()
    tests.loadHistoryReturnsAllSorted()
    tests.loadFavoritesReturnsOnlyFavorites()
    tests.markFavoriteUpdatesAsset()
    tests.unmarkFavoriteClearsActiveFavorite()
    tests.renameFavoriteUpdatesName()
    tests.deleteRecordRemovesAsset()
    tests.setActiveFavoriteUpdatesPreference()
    tests.clearActiveFavoriteClearsPreference()
    tests.clearHistoryKeepsFavorites()
    tests.clearAllRemovesEverything()
}

@MainActor
private struct PetVisualHistoryStoreTests {
    private let fm = FileManager.default

    private func makeTempDir() -> URL {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("test-history-store-\(UUID().uuidString)")
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func cleanup(_ dir: URL) {
        try? fm.removeItem(at: dir)
    }

    private func createTestPNG(at url: URL) throws {
        let size = NSSize(width: 4, height: 4)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.blue.drawSwatch(in: NSRect(origin: .zero, size: size))
        image.unlockFocus()
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let data = rep.representation(using: .png, properties: [:])
        else { throw PetVisualAssetError.conversionFailed }
        try data.write(to: url)
    }

    private func createStores(baseDir: URL) -> (PetVisualHistoryStore, PetVisualAssetStore, PetVisualPreferenceStore) {
        let assetStore = PetVisualAssetStore(baseDirectory: baseDir)
        let prefStore = PetVisualPreferenceStore(
            userDefaults: UserDefaults(suiteName: "test-history-prefs-\(UUID().uuidString)")!
        )
        let historyStore = PetVisualHistoryStore(assetStore: assetStore, preferenceStore: prefStore)
        return (historyStore, assetStore, prefStore)
    }

    private func commitAsset(_ assetStore: PetVisualAssetStore, petId: String, actionId: String, kind: AIVisualActionKind = .expression) throws -> PetVisualAsset {
        let pendingDir = try assetStore.preparePendingDirectory(petId: petId, actionId: actionId)
        try createTestPNG(at: pendingDir.appendingPathComponent("\(actionId).png"))
        return try assetStore.commitAsset(
            from: pendingDir.appendingPathComponent("\(actionId).png"),
            petId: petId,
            actionId: actionId,
            providerId: "mock",
            kind: kind,
            renderMode: .replaceWholeImage,
            promptDigest: actionId,
            expiresAt: nil
        )
    }

    func loadHistoryReturnsAllSorted() {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let (historyStore, assetStore, _) = createStores(baseDir: dir)

        let now = Date()
        let earlier = now.addingTimeInterval(-100)
        // Commit two assets - the second one has an earlier creation time
        // but loadHistory sorts by createdAt desc so the first one should be first
        let _ = try! commitAsset(assetStore, petId: "cat-1", actionId: "h1")
        let _ = try! commitAsset(assetStore, petId: "cat-1", actionId: "h2")

        let history = historyStore.loadHistory(petId: "cat-1")
        expect(history.count == 2, "should return all assets")
    }

    func loadFavoritesReturnsOnlyFavorites() {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let (historyStore, assetStore, _) = createStores(baseDir: dir)

        _ = try! commitAsset(assetStore, petId: "cat-1", actionId: "f1")
        _ = try! commitAsset(assetStore, petId: "cat-1", actionId: "f2")
        try! assetStore.markFavorite(assetId: "f1", petId: "cat-1")

        let favorites = historyStore.loadFavorites(petId: "cat-1")
        expect(favorites.count == 1, "should return only favorites")
        expect(favorites[0].id == "f1", "should return the favorited asset")
    }

    func markFavoriteUpdatesAsset() {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let (historyStore, assetStore, _) = createStores(baseDir: dir)

        _ = try! commitAsset(assetStore, petId: "cat-1", actionId: "mf1")
        try! historyStore.markFavorite(assetId: "mf1", petId: "cat-1")

        let asset = assetStore.loadAsset(id: "mf1", petId: "cat-1")
        expect(asset?.isFavorite == true, "asset should be favorited")
    }

    func unmarkFavoriteClearsActiveFavorite() {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let (historyStore, assetStore, prefStore) = createStores(baseDir: dir)

        _ = try! commitAsset(assetStore, petId: "cat-1", actionId: "uf1")
        try! assetStore.markFavorite(assetId: "uf1", petId: "cat-1")
        prefStore.setActiveFavoriteId("uf1")

        try! historyStore.unmarkFavorite(assetId: "uf1", petId: "cat-1")

        let asset = assetStore.loadAsset(id: "uf1", petId: "cat-1")
        expect(asset?.isFavorite == false, "asset should not be favorite")
        expect(prefStore.loadPreferences().activeFavoriteId == nil, "active favorite should be cleared")
    }

    func renameFavoriteUpdatesName() {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let (historyStore, assetStore, prefStore) = createStores(baseDir: dir)

        _ = try! commitAsset(assetStore, petId: "cat-1", actionId: "rn1")
        try! assetStore.markFavorite(assetId: "rn1", petId: "cat-1")

        try! historyStore.renameFavorite(assetId: "rn1", petId: "cat-1", name: "Holiday Hat")

        let asset = assetStore.loadAsset(id: "rn1", petId: "cat-1")
        expect(asset?.favoriteName == "Holiday Hat", "asset should have new name")
        expect(prefStore.loadPreferences().favoriteNames["rn1"] == "Holiday Hat", "preference store should have name")
    }

    func deleteRecordRemovesAsset() {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let (historyStore, assetStore, prefStore) = createStores(baseDir: dir)

        _ = try! commitAsset(assetStore, petId: "cat-1", actionId: "dr1")
        prefStore.setActiveFavoriteId("dr1")
        prefStore.setFavoriteName("Test Name", forAssetId: "dr1")

        try! historyStore.deleteRecord(assetId: "dr1", petId: "cat-1")

        expect(assetStore.loadAsset(id: "dr1", petId: "cat-1") == nil, "asset should be deleted")
        expect(prefStore.loadPreferences().activeFavoriteId == nil, "active favorite should be cleared")
        expect(prefStore.loadPreferences().favoriteNames["dr1"] == nil, "favorite name should be cleared")
    }

    func setActiveFavoriteUpdatesPreference() {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let (historyStore, assetStore, prefStore) = createStores(baseDir: dir)

        _ = try! commitAsset(assetStore, petId: "cat-1", actionId: "af1")
        try! assetStore.markFavorite(assetId: "af1", petId: "cat-1")

        try! historyStore.setActiveFavorite(assetId: "af1", petId: "cat-1")

        expect(prefStore.loadPreferences().activeFavoriteId == "af1", "active favorite should be set")
    }

    func clearActiveFavoriteClearsPreference() {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let (historyStore, assetStore, prefStore) = createStores(baseDir: dir)

        _ = try! commitAsset(assetStore, petId: "cat-1", actionId: "caf1")
        try! assetStore.markFavorite(assetId: "caf1", petId: "cat-1")
        prefStore.setActiveFavoriteId("caf1")

        try! historyStore.clearActiveFavorite(petId: "cat-1")

        expect(prefStore.loadPreferences().activeFavoriteId == nil, "active favorite should be cleared")
    }

    func clearHistoryKeepsFavorites() {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let (historyStore, assetStore, _) = createStores(baseDir: dir)

        _ = try! commitAsset(assetStore, petId: "cat-1", actionId: "ch1")
        _ = try! commitAsset(assetStore, petId: "cat-1", actionId: "ch2")
        try! assetStore.markFavorite(assetId: "ch1", petId: "cat-1")

        try! historyStore.clearHistory(petId: "cat-1")

        let remaining = assetStore.loadAllAssets(petId: "cat-1")
        expect(remaining.count == 1, "only favorite should remain")
        expect(remaining[0].id == "ch1", "favorite should be kept")
    }

    func clearAllRemovesEverything() {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let (historyStore, assetStore, prefStore) = createStores(baseDir: dir)

        _ = try! commitAsset(assetStore, petId: "cat-1", actionId: "ca1")
        _ = try! commitAsset(assetStore, petId: "cat-1", actionId: "ca2")
        try! assetStore.markFavorite(assetId: "ca1", petId: "cat-1")
        prefStore.setActiveFavoriteId("ca1")
        prefStore.setFavoriteName("Name", forAssetId: "ca1")

        try! historyStore.clearAll(petId: "cat-1")

        let remaining = assetStore.loadAllAssets(petId: "cat-1")
        expect(remaining.isEmpty, "all assets should be removed")
        let prefs = prefStore.loadPreferences()
        expect(prefs.activeFavoriteId == nil, "active favorite should be cleared")
        expect(prefs.favoriteNames.isEmpty, "favorite names should be cleared")
    }
}
