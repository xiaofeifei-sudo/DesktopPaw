import Foundation
import ImageIO
import DesktopPet

func runActionPackStoreTests() {
    let tests = ActionPackStoreTests()
    tests.loadPacksFromDirectory()
    tests.loadPacksReturnsEmptyWhenNoDirectory()
    tests.loadPacksSkipsCorruptedManifest()
    tests.loadPacksSkipsDirectoryWithoutManifest()
    tests.loadPacksSkipsValidationFailedPack()
    tests.deletePackRemovesDirectory()
    tests.deleteNonexistentPackThrows()
}

func runActionPackWriterTests() {
    let tests = ActionPackWriterTests()
    tests.writeDraftCreatesPackDirectory()
    tests.writeDraftWritesManifestAndImages()
    tests.writeDraftWritesSourceMetadata()
    tests.writeDraftCleansTmpOnValidationFailure()
    tests.writeDraftOverwritesExistingPack()
    tests.writeDraftNoTmpResidueOnSuccess()
}

// MARK: - Test Helpers

private let testFrameSize = CGSizeCodable(width: 256, height: 256)

private func makeTestManifest(
    id: String = "wave_pack",
    displayName: String = "Wave",
    resources: [ActionPackResource]? = nil,
    actions: [Action]? = nil
) -> ActionPackManifest {
    let res = resources ?? [
        ActionPackResource(
            id: "wave_sheet",
            kind: .gridImage,
            path: "spritesheet.png",
            frameSize: testFrameSize,
            grid: SpriteSheetLayout(columns: 4, rows: 1)
        )
    ]
    let acts = actions ?? [
        Action(
            id: ActionId(rawValue: "wave_pack_wave")!,
            displayName: "Wave",
            role: nil,
            assetId: "wave_sheet",
            frames: [
                SpriteFrame(column: 0, row: 0),
                SpriteFrame(column: 1, row: 0),
                SpriteFrame(column: 2, row: 0),
                SpriteFrame(column: 3, row: 0)
            ],
            frameDurationMs: 120,
            loop: false,
            nextActionId: ActionId(rawValue: "idle_default")
        )
    ]
    return ActionPackManifest(
        schemaVersion: 1,
        id: id,
        displayName: displayName,
        createdAt: Date(timeIntervalSince1970: 1_717_000_000),
        resources: res,
        actions: acts
    )
}

private func makeValidPngData(width: Int, height: Int) -> Data {
    // Minimal valid PNG: 1x1 transparent pixel
    // We use CGImage to create real PNG data for tests that need it
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ), let image = context.makeImage() else {
        // Fallback: minimal PNG header bytes (not a real image, but enough for file-exists checks)
        return Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
    }

    let data = NSMutableData()
    guard let destination = CGImageDestinationCreateWithData(data, "public.png" as CFString, 1, nil) else {
        return Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
    }
    CGImageDestinationAddImage(destination, image, nil)
    CGImageDestinationFinalize(destination)
    return data as Data
}

// MARK: - Store Tests

private struct ActionPackStoreTests {

    func loadPacksFromDirectory() {
        let tmpDir = createTempPetDir()
        defer { cleanupTempDir(tmpDir) }

        let packsDir = tmpDir.appendingPathComponent("action-packs")
        let packDir = packsDir.appendingPathComponent("wave_pack")
        try! FileManager.default.createDirectory(at: packDir, withIntermediateDirectories: true)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let manifestData = try! encoder.encode(makeTestManifest())
        try! manifestData.write(to: packDir.appendingPathComponent("manifest.json"))

        let imageData = makeValidPngData(width: 1024, height: 256)
        try! imageData.write(to: packDir.appendingPathComponent("spritesheet.png"))

        let store = FileActionPackStore()
        do {
            let result = try store.loadPacks(
                in: tmpDir,
                baseFrameSize: testFrameSize,
                existingActionIds: []
            )
            expect(result.packs.count == 1, "should load 1 pack, got \(result.packs.count)")
            expect(result.packs.first?.manifest.id == "wave_pack", "pack id should match")
        } catch {
            fail("loadPacks should succeed; got \(error)")
        }
    }

    func loadPacksReturnsEmptyWhenNoDirectory() {
        let tmpDir = createTempPetDir()
        defer { cleanupTempDir(tmpDir) }

        let store = FileActionPackStore()
        do {
            let result = try store.loadPacks(
                in: tmpDir,
                baseFrameSize: testFrameSize,
                existingActionIds: []
            )
            expect(result.packs.isEmpty, "should return empty packs when no action-packs dir")
            expect(result.warnings.isEmpty, "should have no warnings")
        } catch {
            fail("loadPacks without action-packs dir should succeed; got \(error)")
        }
    }

    func loadPacksSkipsCorruptedManifest() {
        let tmpDir = createTempPetDir()
        defer { cleanupTempDir(tmpDir) }

        let packsDir = tmpDir.appendingPathComponent("action-packs")
        let packDir = packsDir.appendingPathComponent("broken_pack")
        try! FileManager.default.createDirectory(at: packDir, withIntermediateDirectories: true)

        // Write invalid JSON
        try! Data("{ invalid".utf8).write(to: packDir.appendingPathComponent("manifest.json"))

        let store = FileActionPackStore()
        do {
            let result = try store.loadPacks(
                in: tmpDir,
                baseFrameSize: testFrameSize,
                existingActionIds: []
            )
            expect(result.packs.isEmpty, "corrupted pack should be skipped")
            expect(result.warnings.contains { $0.kind == .packSkipped }, "should have packSkipped warning")
        } catch {
            fail("corrupted pack should not throw; got \(error)")
        }
    }

    func loadPacksSkipsDirectoryWithoutManifest() {
        let tmpDir = createTempPetDir()
        defer { cleanupTempDir(tmpDir) }

        let packsDir = tmpDir.appendingPathComponent("action-packs")
        let emptyDir = packsDir.appendingPathComponent("no_manifest")
        try! FileManager.default.createDirectory(at: emptyDir, withIntermediateDirectories: true)

        let store = FileActionPackStore()
        do {
            let result = try store.loadPacks(
                in: tmpDir,
                baseFrameSize: testFrameSize,
                existingActionIds: []
            )
            expect(result.packs.isEmpty, "dir without manifest should be skipped")
            expect(result.warnings.contains { $0.kind == .packSkipped }, "should have packSkipped warning")
        } catch {
            fail("dir without manifest should not throw; got \(error)")
        }
    }

    func loadPacksSkipsValidationFailedPack() {
        let tmpDir = createTempPetDir()
        defer { cleanupTempDir(tmpDir) }

        let packsDir = tmpDir.appendingPathComponent("action-packs")
        let packDir = packsDir.appendingPathComponent("bad_id_pack")
        try! FileManager.default.createDirectory(at: packDir, withIntermediateDirectories: true)

        // Manifest id doesn't match directory name
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let manifest = makeTestManifest(id: "different_id")
        let manifestData = try! encoder.encode(manifest)
        try! manifestData.write(to: packDir.appendingPathComponent("manifest.json"))

        let imageData = makeValidPngData(width: 1024, height: 256)
        try! imageData.write(to: packDir.appendingPathComponent("spritesheet.png"))

        let store = FileActionPackStore()
        do {
            let result = try store.loadPacks(
                in: tmpDir,
                baseFrameSize: testFrameSize,
                existingActionIds: []
            )
            expect(result.packs.isEmpty, "validation-failed pack should be skipped")
            expect(result.warnings.contains { $0.kind == .packSkipped }, "should have packSkipped warning")
        } catch {
            fail("validation-failed pack should not throw; got \(error)")
        }
    }

    func deletePackRemovesDirectory() {
        let tmpDir = createTempPetDir()
        defer { cleanupTempDir(tmpDir) }

        let packsDir = tmpDir.appendingPathComponent("action-packs")
        let packDir = packsDir.appendingPathComponent("del_pack")
        try! FileManager.default.createDirectory(at: packDir, withIntermediateDirectories: true)
        try! Data("{}".utf8).write(to: packDir.appendingPathComponent("manifest.json"))

        let store = FileActionPackStore()
        do {
            try store.deletePack(id: "del_pack", in: tmpDir)
            expect(!FileManager.default.fileExists(atPath: packDir.path), "pack dir should be removed")
        } catch {
            fail("deletePack should succeed; got \(error)")
        }
    }

    func deleteNonexistentPackThrows() {
        let tmpDir = createTempPetDir()
        defer { cleanupTempDir(tmpDir) }

        let packsDir = tmpDir.appendingPathComponent("action-packs")
        try! FileManager.default.createDirectory(at: packsDir, withIntermediateDirectories: true)

        let store = FileActionPackStore()
        do {
            try store.deletePack(id: "nonexistent", in: tmpDir)
            fail("delete nonexistent pack should throw")
        } catch is ActionPackError {
            // expected
        } catch {
            fail("expected ActionPackError, got \(error)")
        }
    }
}

// MARK: - Writer Tests

private struct ActionPackWriterTests {

    func writeDraftCreatesPackDirectory() {
        let tmpDir = createTempPetDir()
        defer { cleanupTempDir(tmpDir) }

        let imageData = makeValidPngData(width: 1024, height: 256)
        let manifest = makeTestManifest()
        let draft = ActionPackDraft(
            manifest: manifest,
            resourceImages: ["spritesheet.png": imageData]
        )

        let writer = FileActionPackWriter()
        do {
            let result = try writer.writeDraft(draft, to: tmpDir, baseFrameSize: testFrameSize)
            let packDir = tmpDir.appendingPathComponent("action-packs/wave_pack")
            expect(FileManager.default.fileExists(atPath: packDir.path), "pack dir should exist")
            expect(result.manifest.id == "wave_pack", "validated manifest id should match")
        } catch {
            fail("writeDraft should succeed; got \(error)")
        }
    }

    func writeDraftWritesManifestAndImages() {
        let tmpDir = createTempPetDir()
        defer { cleanupTempDir(tmpDir) }

        let imageData = makeValidPngData(width: 1024, height: 256)
        let manifest = makeTestManifest()
        let draft = ActionPackDraft(
            manifest: manifest,
            resourceImages: ["spritesheet.png": imageData]
        )

        let writer = FileActionPackWriter()
        do {
            _ = try writer.writeDraft(draft, to: tmpDir, baseFrameSize: testFrameSize)

            let manifestURL = tmpDir.appendingPathComponent("action-packs/wave_pack/manifest.json")
            expect(FileManager.default.fileExists(atPath: manifestURL.path), "manifest.json should exist")

            let imageURL = tmpDir.appendingPathComponent("action-packs/wave_pack/spritesheet.png")
            expect(FileManager.default.fileExists(atPath: imageURL.path), "spritesheet.png should exist")

            // Verify manifest content
            let data = try Data(contentsOf: manifestURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let decoded = try decoder.decode(ActionPackManifest.self, from: data)
            expect(decoded.id == "wave_pack", "manifest id should match")
        } catch {
            fail("writeDraft should write manifest and images; got \(error)")
        }
    }

    func writeDraftWritesSourceMetadata() {
        let tmpDir = createTempPetDir()
        defer { cleanupTempDir(tmpDir) }

        let imageData = makeValidPngData(width: 1024, height: 256)
        let manifest = makeTestManifest()
        let sourceMeta = ActionPackSourceMetadata(
            source: .localImage,
            createdAt: Date(),
            notes: "Test note"
        )
        let draft = ActionPackDraft(
            manifest: manifest,
            resourceImages: ["spritesheet.png": imageData],
            sourceMetadata: sourceMeta
        )

        let writer = FileActionPackWriter()
        do {
            _ = try writer.writeDraft(draft, to: tmpDir, baseFrameSize: testFrameSize)

            let sourceURL = tmpDir.appendingPathComponent("action-packs/wave_pack/source.json")
            expect(FileManager.default.fileExists(atPath: sourceURL.path), "source.json should exist")

            let data = try Data(contentsOf: sourceURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let decoded = try decoder.decode(ActionPackSourceMetadata.self, from: data)
            expect(decoded.source == .localImage, "source should match")
        } catch {
            fail("writeDraft should write source.json; got \(error)")
        }
    }

    func writeDraftCleansTmpOnValidationFailure() {
        let tmpDir = createTempPetDir()
        defer { cleanupTempDir(tmpDir) }

        // Create a manifest with id that won't match the directory name after move
        // Actually, the writer uses manifest.id as the directory name, so validation should pass.
        // Let's create an invalid manifest that will fail validation.
        let manifest = makeTestManifest(actions: [
            Action(
                id: ActionId(rawValue: "wave_pack_empty")!,
                displayName: "Empty",
                role: nil,
                assetId: "wave_sheet",
                frames: [],
                frameDurationMs: 120,
                loop: false
            )
        ])

        let imageData = makeValidPngData(width: 1024, height: 256)
        let draft = ActionPackDraft(
            manifest: manifest,
            resourceImages: ["spritesheet.png": imageData]
        )

        let writer = FileActionPackWriter()
        do {
            _ = try writer.writeDraft(draft, to: tmpDir, baseFrameSize: testFrameSize)
            fail("writeDraft with empty frames should fail")
        } catch {
            // expected - validation should fail due to empty frames
        }

        // Check no .tmp-* directories remain
        let packsDir = tmpDir.appendingPathComponent("action-packs")
        if FileManager.default.fileExists(atPath: packsDir.path) {
            let contents = try! FileManager.default.contentsOfDirectory(at: packsDir, includingPropertiesForKeys: nil)
            let tmpDirs = contents.filter { $0.lastPathComponent.hasPrefix(".tmp-") }
            expect(tmpDirs.isEmpty, "no .tmp-* directories should remain after failure")
        }
    }

    func writeDraftOverwritesExistingPack() {
        let tmpDir = createTempPetDir()
        defer { cleanupTempDir(tmpDir) }

        let imageData = makeValidPngData(width: 1024, height: 256)
        let manifest = makeTestManifest(displayName: "Wave V1")
        let draft1 = ActionPackDraft(manifest: manifest, resourceImages: ["spritesheet.png": imageData])

        let writer = FileActionPackWriter()
        do {
            _ = try writer.writeDraft(draft1, to: tmpDir, baseFrameSize: testFrameSize)
        } catch {
            fail("first write should succeed; got \(error)")
        }

        let manifest2 = makeTestManifest(displayName: "Wave V2")
        let draft2 = ActionPackDraft(manifest: manifest2, resourceImages: ["spritesheet.png": imageData])

        do {
            let result = try writer.writeDraft(draft2, to: tmpDir, baseFrameSize: testFrameSize)
            expect(result.manifest.displayName == "Wave V2", "should have updated display name")
        } catch {
            fail("overwrite should succeed; got \(error)")
        }
    }

    func writeDraftNoTmpResidueOnSuccess() {
        let tmpDir = createTempPetDir()
        defer { cleanupTempDir(tmpDir) }

        let imageData = makeValidPngData(width: 1024, height: 256)
        let manifest = makeTestManifest()
        let draft = ActionPackDraft(manifest: manifest, resourceImages: ["spritesheet.png": imageData])

        let writer = FileActionPackWriter()
        do {
            _ = try writer.writeDraft(draft, to: tmpDir, baseFrameSize: testFrameSize)
        } catch {
            fail("writeDraft should succeed; got \(error)")
        }

        let packsDir = tmpDir.appendingPathComponent("action-packs")
        let contents = try! FileManager.default.contentsOfDirectory(at: packsDir, includingPropertiesForKeys: nil)
        let tmpDirs = contents.filter { $0.lastPathComponent.hasPrefix(".tmp-") }
        expect(tmpDirs.isEmpty, "no .tmp-* directories should remain after success")
    }
}

// MARK: - Temp Directory Helpers

private func createTempPetDir() -> URL {
    let tmpDir = FileManager.default.temporaryDirectory
        .appendingPathComponent("action-pack-store-test-\(UUID().uuidString)")
    try! FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
    return tmpDir
}

private func cleanupTempDir(_ url: URL) {
    try? FileManager.default.removeItem(at: url)
}
