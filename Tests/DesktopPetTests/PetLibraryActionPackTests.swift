import CoreGraphics
import Foundation
import ImageIO
import DesktopPet

func runPetLibraryStoreActionPackTests() {
    let tests = PetLibraryStoreActionPackTests()
    tests.loadDefinitionWithoutActionPacksUnchanged()
    tests.loadDefinitionWithActionPacks()
    tests.loadDefinitionWithCorruptedPackStillLoadsBase()
    tests.loadDefinitionComposesRenderAssetLibrary()
}

@MainActor
func runPetLibraryCommanderActionPackTests() {
    let tests = PetLibraryCommanderActionPackTests()
    tests.disablePackOverridePersists()
    tests.disableActionOverridePersists()
    tests.displayNameOverridePersists()
}

// MARK: - PetLibraryStore Action Pack Tests

private struct PetLibraryStoreActionPackTests {

    func loadDefinitionWithoutActionPacksUnchanged() {
        let fixture = makeFixture()
        defer { fixture.cleanUp() }

        do {
            try fixture.writeFakeImportedPet(id: "test-pet", displayName: "Test Pet")
            let definition = try fixture.store.loadDefinition(id: "test-pet")
            expect(definition.id == "test-pet", "id should match")
            expect(definition.renderAssetLibrary != nil, "renderAssetLibrary should be set even without packs")
        } catch {
            fail("loadDefinition without action packs should succeed; got \(error)")
        }
    }

    func loadDefinitionWithActionPacks() {
        let fixture = makeFixture()
        defer { fixture.cleanUp() }

        do {
            try fixture.writeFakeImportedPet(id: "test-pet", displayName: "Test Pet")
            try fixture.writeActionPack(
                petId: "test-pet",
                packId: "wave_pack",
                actionId: "wave_pack_wave"
            )
            let definition = try fixture.store.loadDefinition(id: "test-pet")
            expect(definition.catalog.resolve(actionId: ActionId(rawValue: "wave_pack_wave")!) != nil,
                   "pack action should be in catalog")
            expect(definition.renderAssetLibrary != nil, "renderAssetLibrary should be set")
        } catch {
            fail("loadDefinition with action packs should succeed; got \(error)")
        }
    }

    func loadDefinitionWithCorruptedPackStillLoadsBase() {
        let fixture = makeFixture()
        defer { fixture.cleanUp() }

        do {
            try fixture.writeFakeImportedPet(id: "test-pet", displayName: "Test Pet")
            try fixture.writeCorruptedPack(petId: "test-pet", packId: "broken_pack")
            let definition = try fixture.store.loadDefinition(id: "test-pet")
            expect(definition.id == "test-pet", "should still load base pet")
        } catch {
            fail("corrupted pack should not prevent base pet loading; got \(error)")
        }
    }

    func loadDefinitionComposesRenderAssetLibrary() {
        let fixture = makeFixture()
        defer { fixture.cleanUp() }

        do {
            try fixture.writeFakeImportedPet(id: "test-pet", displayName: "Test Pet")
            let definition = try fixture.store.loadDefinition(id: "test-pet")
            let library = definition.renderAssetLibrary
            expect(library != nil, "renderAssetLibrary should be present")
            expect(library?.defaultAssetId == "base/default", "default should be base/default")
        } catch {
            fail("renderAssetLibrary composition should succeed; got \(error)")
        }
    }
}

// MARK: - PetLibraryCommander Action Pack Tests

@MainActor
private struct PetLibraryCommanderActionPackTests {

    func disablePackOverridePersists() {
        let tmpDir = createTempDir()
        defer { cleanupTempDir(tmpDir) }

        let overrideStore = FileActionPackOverrideStore(petsDirectoryURL: tmpDir)
        var overrides = ActionPackOverrideSet(petId: "test-pet")
        overrides = overrides.disablingPack("old_pack")

        do {
            try overrideStore.save(overrides, petId: "test-pet")
            let loaded = overrideStore.load(petId: "test-pet")
            expect(loaded?.isPackDisabled("old_pack") == true, "pack should be disabled after save/load")
        } catch {
            fail("disable pack override should persist; got \(error)")
        }
    }

    func disableActionOverridePersists() {
        let tmpDir = createTempDir()
        defer { cleanupTempDir(tmpDir) }

        let overrideStore = FileActionPackOverrideStore(petsDirectoryURL: tmpDir)
        let actionId = ActionId(rawValue: "wave_custom")!
        var overrides = ActionPackOverrideSet(petId: "test-pet")
        overrides = overrides.disablingAction(actionId)

        do {
            try overrideStore.save(overrides, petId: "test-pet")
            let loaded = overrideStore.load(petId: "test-pet")
            expect(loaded?.isActionDisabled(actionId) == true, "action should be disabled after save/load")
        } catch {
            fail("disable action override should persist; got \(error)")
        }
    }

    func displayNameOverridePersists() {
        let tmpDir = createTempDir()
        defer { cleanupTempDir(tmpDir) }

        let overrideStore = FileActionPackOverrideStore(petsDirectoryURL: tmpDir)
        let actionId = ActionId(rawValue: "wave_custom")!
        var overrides = ActionPackOverrideSet(petId: "test-pet")
        overrides = overrides.settingDisplayName("My Wave", for: actionId)

        do {
            try overrideStore.save(overrides, petId: "test-pet")
            let loaded = overrideStore.load(petId: "test-pet")
            expect(loaded?.displayNameOverride(for: actionId) == "My Wave",
                   "displayName override should persist")
        } catch {
            fail("displayName override should persist; got \(error)")
        }
    }
}

// MARK: - Fixtures

private struct StoreFixture {
    let rootDirectory: URL
    let store: PetLibraryStore

    func cleanUp() {
        try? FileManager.default.removeItem(at: rootDirectory)
    }

    func writeFakeImportedPet(id: String, displayName: String) throws {
        let folder = store.importedPetsDirectoryURL.appendingPathComponent(id, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let manifest = """
        {
          "schemaVersion": 2,
          "id": "\(id)",
          "displayName": "\(displayName)",
          "description": "imported pet",
          "asset": "image.png",
          "preview": "preview.png",
          "assetKind": "singleImage",
          "frameSize": { "width": 256, "height": 256 },
          "defaultScale": 1.0,
          "animations": {
            "idle": {
              "frames": [{ "column": 0, "row": 0 }],
              "frameDurationMs": 160,
              "loop": true
            }
          }
        }
        """
        try Data(manifest.utf8).write(to: folder.appendingPathComponent("manifest.json"))
        try Data().write(to: folder.appendingPathComponent("image.png"))
    }

    func writeActionPack(petId: String, packId: String, actionId: String) throws {
        let packsDir = store.importedPetsDirectoryURL
            .appendingPathComponent(petId)
            .appendingPathComponent("action-packs")
        let packDir = packsDir.appendingPathComponent(packId)
        try FileManager.default.createDirectory(at: packDir, withIntermediateDirectories: true)

        let manifest = """
        {
          "schemaVersion": 1,
          "id": "\(packId)",
          "displayName": "Wave",
          "createdAt": "2026-05-29T15:30:00Z",
          "resources": [
            {
              "id": "wave_sheet",
              "kind": "gridImage",
              "path": "spritesheet.png",
              "frameSize": { "width": 256, "height": 256 },
              "grid": { "columns": 1, "rows": 1 }
            }
          ],
          "actions": [
            {
              "id": "\(actionId)",
              "displayName": "Wave",
              "role": null,
              "tags": [],
              "assetId": "wave_sheet",
              "frames": [{ "column": 0, "row": 0 }],
              "frameDurationMs": 120,
              "loop": false,
              "nextActionId": "idle_default"
            }
          ]
        }
        """
        try Data(manifest.utf8).write(to: packDir.appendingPathComponent("manifest.json"))

        let pngData = makeTestPNG(width: 256, height: 256)
        try pngData.write(to: packDir.appendingPathComponent("spritesheet.png"))
    }

    func writeCorruptedPack(petId: String, packId: String) throws {
        let packsDir = store.importedPetsDirectoryURL
            .appendingPathComponent(petId)
            .appendingPathComponent("action-packs")
        let packDir = packsDir.appendingPathComponent(packId)
        try FileManager.default.createDirectory(at: packDir, withIntermediateDirectories: true)
        try Data("{ invalid".utf8).write(to: packDir.appendingPathComponent("manifest.json"))
    }
}

private func makeFixture() -> StoreFixture {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("DesktopPetAPTests-\(UUID().uuidString)", isDirectory: true)
    try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let store = PetLibraryStore(rootDirectory: root)
    return StoreFixture(rootDirectory: root, store: store)
}

private func createTempDir() -> URL {
    let tmpDir = FileManager.default.temporaryDirectory
        .appendingPathComponent("DesktopPetOverrideTest-\(UUID().uuidString)")
    try! FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
    return tmpDir
}

private func cleanupTempDir(_ url: URL) {
    try? FileManager.default.removeItem(at: url)
}

private func makeTestPNG(width: Int, height: Int) -> Data {
    guard let context = CGContext(
        data: nil, width: width, height: height,
        bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ), let image = context.makeImage() else {
        return Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
    }
    let data = NSMutableData()
    guard let dest = CGImageDestinationCreateWithData(data, "public.png" as CFString, 1, nil) else {
        return Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
    }
    CGImageDestinationAddImage(dest, image, nil)
    CGImageDestinationFinalize(dest)
    return data as Data
}
