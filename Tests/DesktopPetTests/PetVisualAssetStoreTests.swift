import Foundation
import DesktopPet
import AppKit

@MainActor
func runPetVisualAssetStoreTests() {
    let tests = PetVisualAssetStoreTests()
    tests.preparePendingDirectoryCreatesDir()
    tests.commitAssetMovesPNG()
    tests.commitAssetConvertsNonPNG()
    tests.loadAssetReturnsCommittedAsset()
    tests.loadAssetReturnsNilForMissing()
    tests.loadActiveAssetsExcludesExpired()
    tests.loadAllAssetsIncludesExpired()
    tests.markFavoriteUpdatesAsset()
    tests.unmarkFavoriteUpdatesAsset()
    tests.deleteAssetRemovesFileAndMetadata()
    tests.clearNonFavoriteAssetsKeepsFavorites()
    tests.cleanupExpiredRemovesExpiredNonFavorites()
    tests.cleanupExpiredKeepsExpiredFavorites()
    tests.cleanupPendingRemovesDirectory()
    tests.digestPromptIsDeterministic()
    tests.digestPromptDiffersForDifferentPrompts()
    tests.commitAssetOverwritesExisting()
    tests.metadataPersistsAcrossInstances()
}

@MainActor
private struct PetVisualAssetStoreTests {
    private let fm = FileManager.default

    private func makeTempDir() -> URL {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("test-asset-store-\(UUID().uuidString)")
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

    private func createStore(baseDir: URL) -> PetVisualAssetStore {
        PetVisualAssetStore(baseDirectory: baseDir)
    }

    func preparePendingDirectoryCreatesDir() {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let store = createStore(baseDir: dir)

        let pending = try! store.preparePendingDirectory(petId: "cat-1", actionId: "act-1")
        expect(fm.fileExists(atPath: pending.path), "pending directory should exist")
        expect(pending.lastPathComponent == "act-1", "pending dir should be named by actionId")
    }

    func commitAssetMovesPNG() {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let store = createStore(baseDir: dir)

        let pendingDir = try! store.preparePendingDirectory(petId: "cat-1", actionId: "act-1")
        let pngURL = pendingDir.appendingPathComponent("act-1.png")
        try! createTestPNG(at: pngURL)

        let asset = try! store.commitAsset(
            from: pngURL,
            petId: "cat-1",
            actionId: "act-1",
            providerId: "mock",
            kind: .expression,
            renderMode: .replaceWholeImage,
            promptDigest: "abc123",
            expiresAt: nil
        )

        expect(asset.id == "act-1", "asset id should match actionId")
        expect(asset.petId == "cat-1", "petId should match")
        expect(asset.providerId == "mock", "providerId should match")
        expect(asset.kind == .expression, "kind should match")
        expect(asset.renderMode == .replaceWholeImage, "renderMode should match")
        expect(asset.promptDigest == "abc123", "promptDigest should match")
        expect(asset.isFavorite == false, "should not be favorite by default")
        expect(fm.fileExists(atPath: asset.localURL.path), "asset file should exist")
        expect(asset.localURL.lastPathComponent == "act-1.png", "asset file should be named by actionId")
        expect(!fm.fileExists(atPath: pendingDir.path), "pending directory should be cleaned up")
    }

    func commitAssetConvertsNonPNG() {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let store = createStore(baseDir: dir)

        let pendingDir = try! store.preparePendingDirectory(petId: "cat-1", actionId: "act-2")
        let jpgURL = pendingDir.appendingPathComponent("act-2.jpg")

        let size = NSSize(width: 4, height: 4)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.red.drawSwatch(in: NSRect(origin: .zero, size: size))
        image.unlockFocus()
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let data = rep.representation(using: .jpeg, properties: [:])
        else { fail("failed to create test JPEG"); return }
        try! data.write(to: jpgURL)

        let asset = try! store.commitAsset(
            from: jpgURL,
            petId: "cat-1",
            actionId: "act-2",
            providerId: "mock",
            kind: .accessory,
            renderMode: .overlayImage,
            promptDigest: "def456",
            expiresAt: nil
        )

        expect(asset.localURL.pathExtension == "png", "converted asset should be PNG")
        expect(fm.fileExists(atPath: asset.localURL.path), "converted asset file should exist")
    }

    func loadAssetReturnsCommittedAsset() {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let store = createStore(baseDir: dir)

        let pendingDir = try! store.preparePendingDirectory(petId: "cat-1", actionId: "act-3")
        try! createTestPNG(at: pendingDir.appendingPathComponent("act-3.png"))

        _ = try! store.commitAsset(
            from: pendingDir.appendingPathComponent("act-3.png"),
            petId: "cat-1",
            actionId: "act-3",
            providerId: "mock",
            kind: .pose,
            renderMode: .replaceWholeImage,
            promptDigest: "ghi",
            expiresAt: nil
        )

        let loaded = store.loadAsset(id: "act-3", petId: "cat-1")
        expect(loaded != nil, "should load committed asset")
        expect(loaded?.kind == .pose, "kind should match")
    }

    func loadAssetReturnsNilForMissing() {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let store = createStore(baseDir: dir)

        let loaded = store.loadAsset(id: "nonexistent", petId: "cat-1")
        expect(loaded == nil, "should return nil for missing asset")
    }

    func loadActiveAssetsExcludesExpired() {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let store = createStore(baseDir: dir)

        let now = Date()
        let past = now.addingTimeInterval(-100)

        let pendingDir = try! store.preparePendingDirectory(petId: "cat-1", actionId: "act-exp")
        try! createTestPNG(at: pendingDir.appendingPathComponent("act-exp.png"))

        _ = try! store.commitAsset(
            from: pendingDir.appendingPathComponent("act-exp.png"),
            petId: "cat-1",
            actionId: "act-exp",
            providerId: "mock",
            kind: .expression,
            renderMode: .replaceWholeImage,
            promptDigest: "exp",
            expiresAt: past
        )

        let active = store.loadActiveAssets(petId: "cat-1", now: now)
        expect(active.isEmpty, "expired assets should not be active")
    }

    func loadAllAssetsIncludesExpired() {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let store = createStore(baseDir: dir)

        let now = Date()
        let past = now.addingTimeInterval(-100)

        let pendingDir = try! store.preparePendingDirectory(petId: "cat-1", actionId: "act-exp2")
        try! createTestPNG(at: pendingDir.appendingPathComponent("act-exp2.png"))

        _ = try! store.commitAsset(
            from: pendingDir.appendingPathComponent("act-exp2.png"),
            petId: "cat-1",
            actionId: "act-exp2",
            providerId: "mock",
            kind: .expression,
            renderMode: .replaceWholeImage,
            promptDigest: "exp2",
            expiresAt: past
        )

        let all = store.loadAllAssets(petId: "cat-1")
        expect(all.count == 1, "loadAll should include expired assets")
    }

    func markFavoriteUpdatesAsset() {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let store = createStore(baseDir: dir)

        let pendingDir = try! store.preparePendingDirectory(petId: "cat-1", actionId: "act-fav")
        try! createTestPNG(at: pendingDir.appendingPathComponent("act-fav.png"))

        _ = try! store.commitAsset(
            from: pendingDir.appendingPathComponent("act-fav.png"),
            petId: "cat-1",
            actionId: "act-fav",
            providerId: "mock",
            kind: .accessory,
            renderMode: .replaceWholeImage,
            promptDigest: "fav",
            expiresAt: nil
        )

        try! store.markFavorite(assetId: "act-fav", petId: "cat-1")
        let loaded = store.loadAsset(id: "act-fav", petId: "cat-1")
        expect(loaded?.isFavorite == true, "asset should be marked favorite")
    }

    func unmarkFavoriteUpdatesAsset() {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let store = createStore(baseDir: dir)

        let pendingDir = try! store.preparePendingDirectory(petId: "cat-1", actionId: "act-uf")
        try! createTestPNG(at: pendingDir.appendingPathComponent("act-uf.png"))

        _ = try! store.commitAsset(
            from: pendingDir.appendingPathComponent("act-uf.png"),
            petId: "cat-1",
            actionId: "act-uf",
            providerId: "mock",
            kind: .accessory,
            renderMode: .replaceWholeImage,
            promptDigest: "uf",
            expiresAt: nil
        )

        try! store.markFavorite(assetId: "act-uf", petId: "cat-1")
        try! store.unmarkFavorite(assetId: "act-uf", petId: "cat-1")
        let loaded = store.loadAsset(id: "act-uf", petId: "cat-1")
        expect(loaded?.isFavorite == false, "asset should not be favorite after unmark")
    }

    func deleteAssetRemovesFileAndMetadata() {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let store = createStore(baseDir: dir)

        let pendingDir = try! store.preparePendingDirectory(petId: "cat-1", actionId: "act-del")
        try! createTestPNG(at: pendingDir.appendingPathComponent("act-del.png"))

        let asset = try! store.commitAsset(
            from: pendingDir.appendingPathComponent("act-del.png"),
            petId: "cat-1",
            actionId: "act-del",
            providerId: "mock",
            kind: .expression,
            renderMode: .replaceWholeImage,
            promptDigest: "del",
            expiresAt: nil
        )

        let filePath = asset.localURL.path
        try! store.deleteAsset(id: "act-del", petId: "cat-1")

        expect(!fm.fileExists(atPath: filePath), "asset file should be deleted")
        expect(store.loadAsset(id: "act-del", petId: "cat-1") == nil, "asset should be removed from metadata")
    }

    func clearNonFavoriteAssetsKeepsFavorites() {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let store = createStore(baseDir: dir)

        for id in ["a1", "a2"] {
            let pendingDir = try! store.preparePendingDirectory(petId: "cat-1", actionId: id)
            try! createTestPNG(at: pendingDir.appendingPathComponent("\(id).png"))
            _ = try! store.commitAsset(
                from: pendingDir.appendingPathComponent("\(id).png"),
                petId: "cat-1",
                actionId: id,
                providerId: "mock",
                kind: .expression,
                renderMode: .replaceWholeImage,
                promptDigest: id,
                expiresAt: nil
            )
        }

        try! store.markFavorite(assetId: "a1", petId: "cat-1")
        try! store.clearNonFavoriteAssets(petId: "cat-1")

        let remaining = store.loadAllAssets(petId: "cat-1")
        expect(remaining.count == 1, "only favorite asset should remain")
        expect(remaining[0].id == "a1", "favorite asset should be kept")
    }

    func cleanupExpiredRemovesExpiredNonFavorites() {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let store = createStore(baseDir: dir)

        let now = Date()
        let past = now.addingTimeInterval(-100)

        let pendingDir = try! store.preparePendingDirectory(petId: "cat-1", actionId: "act-exp3")
        try! createTestPNG(at: pendingDir.appendingPathComponent("act-exp3.png"))
        _ = try! store.commitAsset(
            from: pendingDir.appendingPathComponent("act-exp3.png"),
            petId: "cat-1",
            actionId: "act-exp3",
            providerId: "mock",
            kind: .expression,
            renderMode: .replaceWholeImage,
            promptDigest: "exp3",
            expiresAt: past
        )

        try! store.cleanupExpired(petId: "cat-1", now: now)
        let remaining = store.loadAllAssets(petId: "cat-1")
        expect(remaining.isEmpty, "expired non-favorite should be removed")
    }

    func cleanupExpiredKeepsExpiredFavorites() {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let store = createStore(baseDir: dir)

        let now = Date()
        let past = now.addingTimeInterval(-100)

        let pendingDir = try! store.preparePendingDirectory(petId: "cat-1", actionId: "act-favexp")
        try! createTestPNG(at: pendingDir.appendingPathComponent("act-favexp.png"))
        _ = try! store.commitAsset(
            from: pendingDir.appendingPathComponent("act-favexp.png"),
            petId: "cat-1",
            actionId: "act-favexp",
            providerId: "mock",
            kind: .expression,
            renderMode: .replaceWholeImage,
            promptDigest: "favexp",
            expiresAt: past
        )

        try! store.markFavorite(assetId: "act-favexp", petId: "cat-1")
        try! store.cleanupExpired(petId: "cat-1", now: now)

        let remaining = store.loadAllAssets(petId: "cat-1")
        expect(remaining.count == 1, "expired favorite should be kept")
        expect(remaining[0].id == "act-favexp", "favorite should be preserved")
    }

    func cleanupPendingRemovesDirectory() {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let store = createStore(baseDir: dir)

        let pending = try! store.preparePendingDirectory(petId: "cat-1", actionId: "act-cl")
        expect(fm.fileExists(atPath: pending.path), "pending dir should exist before cleanup")

        store.cleanupPending(actionId: "act-cl", petId: "cat-1")
        expect(!fm.fileExists(atPath: pending.path), "pending dir should be removed after cleanup")
    }

    func digestPromptIsDeterministic() {
        let digest1 = PetVisualAssetStore.digestPrompt("a happy cat wearing a hat")
        let digest2 = PetVisualAssetStore.digestPrompt("a happy cat wearing a hat")
        expect(digest1 == digest2, "same prompt should produce same digest")
    }

    func digestPromptDiffersForDifferentPrompts() {
        let digest1 = PetVisualAssetStore.digestPrompt("a happy cat")
        let digest2 = PetVisualAssetStore.digestPrompt("a sad cat")
        expect(digest1 != digest2, "different prompts should produce different digests")
    }

    func commitAssetOverwritesExisting() {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let store = createStore(baseDir: dir)

        let pendingDir = try! store.preparePendingDirectory(petId: "cat-1", actionId: "act-ow")
        try! createTestPNG(at: pendingDir.appendingPathComponent("act-ow.png"))
        _ = try! store.commitAsset(
            from: pendingDir.appendingPathComponent("act-ow.png"),
            petId: "cat-1",
            actionId: "act-ow",
            providerId: "mock",
            kind: .expression,
            renderMode: .replaceWholeImage,
            promptDigest: "v1",
            expiresAt: nil
        )

        let pendingDir2 = try! store.preparePendingDirectory(petId: "cat-1", actionId: "act-ow")
        try! createTestPNG(at: pendingDir2.appendingPathComponent("act-ow.png"))
        let asset2 = try! store.commitAsset(
            from: pendingDir2.appendingPathComponent("act-ow.png"),
            petId: "cat-1",
            actionId: "act-ow",
            providerId: "mock",
            kind: .pose,
            renderMode: .replaceWholeImage,
            promptDigest: "v2",
            expiresAt: nil
        )

        expect(asset2.promptDigest == "v2", "should use new digest")
        let all = store.loadAllAssets(petId: "cat-1")
        expect(all.count == 1, "should not duplicate assets with same actionId")
    }

    func metadataPersistsAcrossInstances() {
        let dir = makeTempDir()
        defer { cleanup(dir) }

        let store1 = createStore(baseDir: dir)
        let pendingDir = try! store1.preparePendingDirectory(petId: "cat-1", actionId: "act-p")
        try! createTestPNG(at: pendingDir.appendingPathComponent("act-p.png"))
        _ = try! store1.commitAsset(
            from: pendingDir.appendingPathComponent("act-p.png"),
            petId: "cat-1",
            actionId: "act-p",
            providerId: "mock",
            kind: .expression,
            renderMode: .replaceWholeImage,
            promptDigest: "persist",
            expiresAt: nil
        )

        let store2 = createStore(baseDir: dir)
        let loaded = store2.loadAsset(id: "act-p", petId: "cat-1")
        expect(loaded != nil, "asset should persist across store instances")
        expect(loaded?.promptDigest == "persist", "digest should persist")
    }
}
