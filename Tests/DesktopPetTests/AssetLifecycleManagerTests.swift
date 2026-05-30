import AppKit
import Foundation
import DesktopPet

@MainActor
func runAssetLifecycleManagerTests() async throws {
    let tests = AssetLifecycleManagerTests()
    try tests.backwardCompatibilityDefaultsToApplied()
    try tests.newAssetWithPendingPreviewState()
    try tests.gateResultPersistedOnAsset()
    try tests.referencePreviewURLPersistedOnAsset()
    try tests.diagnosticsIdPersistedOnAsset()
    try await tests.transitionFromPendingPreviewToApplied()
    try await tests.transitionFromPendingPreviewToDiscarded()
    try await tests.transitionFromAppliedToRestored()
    try await tests.transitionFromAppliedToExpired()
    try await tests.invalidTransitionIsNoOp()
    try await tests.pendingPreviewAssetsQuery()
    try await tests.canRestoreReturnsTrueWhenAssetApplied()
    try await tests.canRestoreReturnsFalseWhenNoAssetApplied()
    try await tests.oldMetadataDecodedAsApplied()
    try tests.commitAssetWithDefaultParamsIsApplied()
}

@MainActor
private struct AssetLifecycleManagerTests {
    private let fm = FileManager.default

    private func makeTempDir() -> URL {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("asset-lifecycle-tests-\(UUID().uuidString)", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func cleanup(_ dir: URL) {
        try? fm.removeItem(at: dir)
    }

    private func makePNG(at url: URL, width: Int = 4, height: Int = 4) throws {
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: width,
            pixelsHigh: height,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )!
        let color = NSColor(deviceRed: 1, green: 0.42, blue: 0.7, alpha: 1)
        for y in 0..<height {
            for x in 0..<width {
                rep.setColor(color, atX: x, y: y)
            }
        }
        guard let data = rep.representation(using: .png, properties: [:]) else {
            throw PetVisualAssetError.conversionFailed
        }
        try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url)
    }

    private func commitAsset(
        store: PetVisualAssetStore,
        dir: URL,
        petId: String = "pet-a",
        actionId: String = "act-1",
        lifecycleState: AssetLifecycleState = .applied,
        gateResult: GateResult? = nil,
        referencePreviewURL: URL? = nil,
        diagnosticsId: String? = nil
    ) throws -> PetVisualAsset {
        let pendingDir = dir.appendingPathComponent("pending").appendingPathComponent(actionId)
        try fm.createDirectory(at: pendingDir, withIntermediateDirectories: true)
        let imgURL = pendingDir.appendingPathComponent("\(actionId).png")
        try makePNG(at: imgURL)

        return try store.commitAsset(
            from: imgURL,
            petId: petId,
            actionId: actionId,
            providerId: "test-provider",
            kind: .ambience,
            renderMode: .replaceWholeImage,
            promptDigest: "abcd1234",
            expiresAt: Date().addingTimeInterval(3600),
            lifecycleState: lifecycleState,
            gateResult: gateResult,
            referencePreviewURL: referencePreviewURL,
            diagnosticsId: diagnosticsId
        )
    }

    // MARK: - Field Persistence

    func backwardCompatibilityDefaultsToApplied() throws {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let store = PetVisualAssetStore(baseDirectory: dir)

        let asset = try commitAsset(store: store, dir: dir)
        expect(asset.lifecycleState == .applied, "default lifecycle state should be applied")
        expect(asset.gateResult == nil, "default gate result should be nil")
        expect(asset.referencePreviewURL == nil, "default preview URL should be nil")
        expect(asset.generationDiagnosticsId == nil, "default diagnostics ID should be nil")

        let loaded = store.loadAsset(id: "act-1", petId: "pet-a")
        expect(loaded?.lifecycleState == .applied, "loaded asset should have applied state")
    }

    func newAssetWithPendingPreviewState() throws {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let store = PetVisualAssetStore(baseDirectory: dir)

        let asset = try commitAsset(store: store, dir: dir, lifecycleState: .generatedPendingPreview)
        expect(asset.lifecycleState == .generatedPendingPreview, "should be pending preview")

        let loaded = store.loadAsset(id: asset.id, petId: asset.petId)
        expect(loaded?.lifecycleState == .generatedPendingPreview, "persisted state should be pending preview")
    }

    func gateResultPersistedOnAsset() throws {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let store = PetVisualAssetStore(baseDirectory: dir)

        let gate = GateResult(
            overall: .warn,
            checks: [GateCheckResult(checkType: .dominantColor, passed: false, score: 0.3, detail: "color mismatch")],
            riskLevel: .medium,
            userFacingMessage: "这次变化较大，请确认。",
            autoAction: .requirePreview
        )

        let asset = try commitAsset(store: store, dir: dir, gateResult: gate)
        expect(asset.gateResult != nil, "gate result should be set")
        expect(asset.gateResult?.overall == .warn, "gate verdict should be warn")
        expect(asset.gateResult?.autoAction == .requirePreview, "auto action should be requirePreview")
        expect(asset.gateResult?.checks.count == 1, "should have 1 check")

        let loaded = store.loadAsset(id: asset.id, petId: asset.petId)
        expect(loaded?.gateResult?.overall == .warn, "loaded gate verdict should persist")
    }

    func referencePreviewURLPersistedOnAsset() throws {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let store = PetVisualAssetStore(baseDirectory: dir)

        let previewURL = dir.appendingPathComponent("ref-preview.png")
        let asset = try commitAsset(store: store, dir: dir, referencePreviewURL: previewURL)
        expect(asset.referencePreviewURL == previewURL, "preview URL should be set")

        let loaded = store.loadAsset(id: asset.id, petId: asset.petId)
        expect(loaded?.referencePreviewURL == previewURL, "loaded preview URL should persist")
    }

    func diagnosticsIdPersistedOnAsset() throws {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let store = PetVisualAssetStore(baseDirectory: dir)

        let asset = try commitAsset(store: store, dir: dir, diagnosticsId: "req-12345")
        expect(asset.generationDiagnosticsId == "req-12345", "diagnostics ID should be set")

        let loaded = store.loadAsset(id: asset.id, petId: asset.petId)
        expect(loaded?.generationDiagnosticsId == "req-12345", "loaded diagnostics ID should persist")
    }

    // MARK: - State Transitions

    func transitionFromPendingPreviewToApplied() async throws {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let store = PetVisualAssetStore(baseDirectory: dir)
        let manager = AssetLifecycleManager(assetStore: store)

        let asset = try commitAsset(store: store, dir: dir, lifecycleState: .generatedPendingPreview)
        expect(asset.lifecycleState == .generatedPendingPreview, "initial state should be pending")

        try await manager.transition(asset: asset, to: .applied)
        let loaded = store.loadAsset(id: asset.id, petId: asset.petId)
        expect(loaded?.lifecycleState == .applied, "should transition to applied")
    }

    func transitionFromPendingPreviewToDiscarded() async throws {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let store = PetVisualAssetStore(baseDirectory: dir)
        let manager = AssetLifecycleManager(assetStore: store)

        let asset = try commitAsset(store: store, dir: dir, lifecycleState: .generatedPendingPreview)
        try await manager.transition(asset: asset, to: .discardedByUser)
        let loaded = store.loadAsset(id: asset.id, petId: asset.petId)
        expect(loaded?.lifecycleState == .discardedByUser, "should transition to discarded")
    }

    func transitionFromAppliedToRestored() async throws {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let store = PetVisualAssetStore(baseDirectory: dir)
        let manager = AssetLifecycleManager(assetStore: store)

        let asset = try commitAsset(store: store, dir: dir, lifecycleState: .applied)
        try await manager.transition(asset: asset, to: .restored)
        let loaded = store.loadAsset(id: asset.id, petId: asset.petId)
        expect(loaded?.lifecycleState == .restored, "should transition to restored")
    }

    func transitionFromAppliedToExpired() async throws {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let store = PetVisualAssetStore(baseDirectory: dir)
        let manager = AssetLifecycleManager(assetStore: store)

        let asset = try commitAsset(store: store, dir: dir, lifecycleState: .applied)
        try await manager.transition(asset: asset, to: .expired)
        let loaded = store.loadAsset(id: asset.id, petId: asset.petId)
        expect(loaded?.lifecycleState == .expired, "should transition to expired")
    }

    func invalidTransitionIsNoOp() async throws {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let store = PetVisualAssetStore(baseDirectory: dir)
        let manager = AssetLifecycleManager(assetStore: store)

        let asset = try commitAsset(store: store, dir: dir, lifecycleState: .discardedByUser)
        try await manager.transition(asset: asset, to: .applied)
        let loaded = store.loadAsset(id: asset.id, petId: asset.petId)
        expect(loaded?.lifecycleState == .discardedByUser, "invalid transition should be no-op")
    }

    // MARK: - Queries

    func pendingPreviewAssetsQuery() async throws {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let store = PetVisualAssetStore(baseDirectory: dir)
        let manager = AssetLifecycleManager(assetStore: store)

        _ = try commitAsset(store: store, dir: dir, actionId: "act-1", lifecycleState: .generatedPendingPreview)
        _ = try commitAsset(store: store, dir: dir, actionId: "act-2", lifecycleState: .applied)
        _ = try commitAsset(store: store, dir: dir, actionId: "act-3", lifecycleState: .generatedPendingPreview)

        let pending = await manager.pendingPreviewAssets(for: "pet-a")
        expect(pending.count == 2, "should find 2 pending preview assets")
        expect(pending.allSatisfy { $0.lifecycleState == .generatedPendingPreview }, "all should be pending")
    }

    func canRestoreReturnsTrueWhenAssetApplied() async throws {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let store = PetVisualAssetStore(baseDirectory: dir)
        let manager = AssetLifecycleManager(assetStore: store)

        _ = try commitAsset(store: store, dir: dir, actionId: "act-1", lifecycleState: .generatedPendingPreview)
        let canRestore1 = await manager.canRestore(for: "pet-a")
        expect(!canRestore1, "no applied asset yet")

        _ = try commitAsset(store: store, dir: dir, actionId: "act-2", lifecycleState: .applied)
        let canRestore2 = await manager.canRestore(for: "pet-a")
        expect(canRestore2, "should be restorable when asset is applied")
    }

    func canRestoreReturnsFalseWhenNoAssetApplied() async throws {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let store = PetVisualAssetStore(baseDirectory: dir)
        let manager = AssetLifecycleManager(assetStore: store)

        _ = try commitAsset(store: store, dir: dir, lifecycleState: .generatedPendingPreview)
        let canRestore = await manager.canRestore(for: "pet-a")
        expect(!canRestore, "no applied asset, should not be restorable")
    }

    // MARK: - Backward Compatibility (old metadata without lifecycle fields)

    func oldMetadataDecodedAsApplied() async throws {
        let dir = makeTempDir()
        defer { cleanup(dir) }

        let metadataDir = dir.appendingPathComponent("pet-old").appendingPathComponent("visual-actions")
        try fm.createDirectory(at: metadataDir, withIntermediateDirectories: true)

        // Write old-format metadata without lifecycle fields
        let oldJSON = """
        [{
            "id": "old-1",
            "petId": "pet-old",
            "actionId": "old-1",
            "providerId": "test",
            "localURL": "file:///tmp/fake.png",
            "promptDigest": "abc",
            "kind": "ambience",
            "renderMode": "replaceWholeImage",
            "createdAt": 700000000.0,
            "expiresAt": null,
            "isFavorite": false,
            "favoriteName": null
        }]
        """
        let metadataURL = metadataDir.appendingPathComponent("metadata.json")
        try oldJSON.write(to: metadataURL, atomically: true, encoding: .utf8)

        let store = PetVisualAssetStore(baseDirectory: dir)
        let loaded = store.loadAsset(id: "old-1", petId: "pet-old")
        expect(loaded != nil, "old metadata should be loadable")
        expect(loaded?.lifecycleState == .applied, "old asset should default to applied")
    }

    // MARK: - Default Parameters

    func commitAssetWithDefaultParamsIsApplied() throws {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let store = PetVisualAssetStore(baseDirectory: dir)

        let pendingDir = dir.appendingPathComponent("pending").appendingPathComponent("def-1")
        try fm.createDirectory(at: pendingDir, withIntermediateDirectories: true)
        let imgURL = pendingDir.appendingPathComponent("def-1.png")
        try makePNG(at: imgURL)

        // Use only old parameters (default lifecycle params)
        let asset = try store.commitAsset(
            from: imgURL,
            petId: "pet-a",
            actionId: "def-1",
            providerId: "test",
            kind: .ambience,
            renderMode: .overlayImage,
            promptDigest: "xyz",
            expiresAt: nil
        )
        expect(asset.lifecycleState == .applied, "commit with defaults should be applied")
        expect(asset.gateResult == nil, "default gate result should be nil")
    }
}
