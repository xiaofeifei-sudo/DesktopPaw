import CoreGraphics
import Foundation
import ImageIO
import DesktopPet

func runPetPackageExporterActionPackTests() {
    let tests = PetPackageExporterActionPackTests()
    tests.exportCopiesActionPacks()
    tests.exportCopiesOverrides()
    tests.exportCreatesPetBundle()
    tests.exportValidatesPackSize()
}

func runPetPackageImporterActionPackTests() {
    let tests = PetPackageImporterActionPackTests()
    tests.importCopiesActionPacks()
    tests.importWithoutActionPacksUnchanged()
    tests.importCopiesOverrides()
}

func runPetPackageLoaderCompatibilityTests() {
    let tests = PetPackageLoaderCompatibilityTests()
    tests.oldPetPackageStillLoads()
    tests.singleImagePetStillLoads()
}

// MARK: - Exporter Tests

private struct PetPackageExporterActionPackTests {

    func exportCopiesActionPacks() {
        let fixture = makeExportFixture()
        defer { fixture.cleanUp() }

        do {
            try fixture.writePetWithActionPack()
            let exporter = PetPackageExporter()
            let result = try exporter.exportPet(
                id: "test-pet",
                from: fixture.importedPetsDir,
                to: fixture.exportDir
            )
            let exportedPacksDir = result.exportURL.appendingPathComponent("action-packs")
            expect(FileManager.default.fileExists(atPath: exportedPacksDir.path),
                   "action-packs should be copied")
            let packDir = exportedPacksDir.appendingPathComponent("wave_pack")
            expect(FileManager.default.fileExists(atPath: packDir.path),
                   "pack directory should be copied")
        } catch {
            fail("export should copy action packs; got \(error)")
        }
    }

    func exportCopiesOverrides() {
        let fixture = makeExportFixture()
        defer { fixture.cleanUp() }

        do {
            try fixture.writePetWithActionPack()
            try fixture.writeOverrides()
            let exporter = PetPackageExporter()
            let result = try exporter.exportPet(
                id: "test-pet",
                from: fixture.importedPetsDir,
                to: fixture.exportDir
            )
            let overridesFile = result.exportURL.appendingPathComponent("action-pack-overrides.json")
            expect(FileManager.default.fileExists(atPath: overridesFile.path),
                   "overrides file should be copied")
        } catch {
            fail("export should copy overrides; got \(error)")
        }
    }

    func exportCreatesPetBundle() {
        let fixture = makeExportFixture()
        defer { fixture.cleanUp() }

        do {
            try fixture.writePetWithActionPack()
            let exporter = PetPackageExporter()
            let result = try exporter.exportPet(
                id: "test-pet",
                from: fixture.importedPetsDir,
                to: fixture.exportDir
            )
            expect(result.exportURL.lastPathComponent == "test-pet.pet",
                   "bundle should have .pet extension")
            expect(result.packCount == 1, "should report 1 pack")
            expect(result.totalBytes > 0, "total bytes should be positive")
        } catch {
            fail("export should create .pet bundle; got \(error)")
        }
    }

    func exportValidatesPackSize() {
        let fixture = makeExportFixture()
        defer { fixture.cleanUp() }

        do {
            try fixture.writePetWithActionPack()
            let exporter = PetPackageExporter()
            let result = try exporter.exportPet(
                id: "test-pet",
                from: fixture.importedPetsDir,
                to: fixture.exportDir
            )
            expect(result.totalBytes <= PetPackageExporter.maximumTotalPackBytes,
                   "total bytes should be within limit")
        } catch {
            fail("export should pass size validation; got \(error)")
        }
    }
}

// MARK: - Importer Tests

private struct PetPackageImporterActionPackTests {

    func importCopiesActionPacks() {
        let fixture = makeImportFixture()
        defer { fixture.cleanUp() }

        do {
            try fixture.writePetPackageWithActionPack()
            let importer = PetPackageImporter()
            _ = try importer.importPackage(
                from: fixture.packageDir,
                to: fixture.importedPetsDir,
                builtInPetId: "starter-pet"
            )
            let importedPacksDir = fixture.importedPetsDir
                .appendingPathComponent("test-pet")
                .appendingPathComponent("action-packs")
            expect(FileManager.default.fileExists(atPath: importedPacksDir.path),
                   "action-packs should be imported")
        } catch {
            fail("import should copy action packs; got \(error)")
        }
    }

    func importWithoutActionPacksUnchanged() {
        let fixture = makeImportFixture()
        defer { fixture.cleanUp() }

        do {
            try fixture.writeBasicPetPackage()
            let importer = PetPackageImporter()
            let definition = try importer.importPackage(
                from: fixture.packageDir,
                to: fixture.importedPetsDir,
                builtInPetId: "starter-pet"
            )
            expect(definition.id == "test-pet", "should import successfully")
            let importedDir = fixture.importedPetsDir.appendingPathComponent("test-pet")
            let packsDir = importedDir.appendingPathComponent("action-packs")
            expect(!FileManager.default.fileExists(atPath: packsDir.path),
                   "no action-packs dir when source has none")
        } catch {
            fail("import without action packs should work; got \(error)")
        }
    }

    func importCopiesOverrides() {
        let fixture = makeImportFixture()
        defer { fixture.cleanUp() }

        do {
            try fixture.writePetPackageWithActionPack()
            try fixture.writeOverridesInPackage()
            let importer = PetPackageImporter()
            _ = try importer.importPackage(
                from: fixture.packageDir,
                to: fixture.importedPetsDir,
                builtInPetId: "starter-pet"
            )
            let overridesFile = fixture.importedPetsDir
                .appendingPathComponent("test-pet")
                .appendingPathComponent("action-pack-overrides.json")
            expect(FileManager.default.fileExists(atPath: overridesFile.path),
                   "overrides should be imported")
        } catch {
            fail("import should copy overrides; got \(error)")
        }
    }
}

// MARK: - Loader Compatibility Tests

private struct PetPackageLoaderCompatibilityTests {

    func oldPetPackageStillLoads() {
        let fixture = makeImportFixture()
        defer { fixture.cleanUp() }

        do {
            try fixture.writeBasicPetPackage()
            let loader = PetPackageLoader()
            let definition = try loader.loadPackage(at: fixture.packageDir)
            expect(definition.id == "test-pet", "old package should load")
            expect(definition.assetKind == .spriteSheet, "should be spriteSheet")
        } catch {
            fail("old .pet package should still load; got \(error)")
        }
    }

    func singleImagePetStillLoads() {
        let fixture = makeImportFixture()
        defer { fixture.cleanUp() }

        do {
            try fixture.writeSingleImagePackage()
            let importer = PetPackageImporter()
            _ = try importer.importPackage(
                from: fixture.packageDir,
                to: fixture.importedPetsDir,
                builtInPetId: "starter-pet"
            )
            fail("single image .pet package should be rejected by PetPackageLoader")
        } catch let error as PetLibraryError {
            expect(error == .unsupportedPackage || error == .invalidPackage,
                   "single image should be rejected, got \(error)")
        } catch {
            fail("expected PetLibraryError, got \(error)")
        }
    }
}

// MARK: - Fixtures

private struct ExportFixture {
    let rootDir: URL
    let importedPetsDir: URL
    let exportDir: URL

    func cleanUp() {
        try? FileManager.default.removeItem(at: rootDir)
    }

    func writePetWithActionPack() throws {
        let petDir = importedPetsDir.appendingPathComponent("test-pet", isDirectory: true)
        try FileManager.default.createDirectory(at: petDir, withIntermediateDirectories: true)

        let manifest = """
        {
          "schemaVersion": 2,
          "id": "test-pet",
          "displayName": "Test Pet",
          "description": "test",
          "asset": "spritesheet.png",
          "preview": "preview.png",
          "assetKind": "spriteSheet",
          "frameSize": { "width": 256, "height": 256 },
          "spritesheet": { "columns": 4, "rows": 1 },
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
        try Data(manifest.utf8).write(to: petDir.appendingPathComponent("manifest.json"))
        try makeTestPNG(width: 1024, height: 256).write(to: petDir.appendingPathComponent("spritesheet.png"))
        try makeTestPNG(width: 256, height: 256).write(to: petDir.appendingPathComponent("preview.png"))

        let packsDir = petDir.appendingPathComponent("action-packs/wave_pack")
        try FileManager.default.createDirectory(at: packsDir, withIntermediateDirectories: true)
        let packManifest = """
        {
          "schemaVersion": 1,
          "id": "wave_pack",
          "displayName": "Wave",
          "createdAt": "2026-05-29T15:30:00Z",
          "resources": [{ "id": "sheet", "kind": "gridImage", "path": "spritesheet.png", "frameSize": { "width": 256, "height": 256 }, "grid": { "columns": 1, "rows": 1 } }],
          "actions": [{ "id": "wave_pack_wave", "displayName": "Wave", "role": null, "tags": [], "assetId": "sheet", "frames": [{ "column": 0, "row": 0 }], "frameDurationMs": 120, "loop": false, "nextActionId": "idle_default" }]
        }
        """
        try Data(packManifest.utf8).write(to: packsDir.appendingPathComponent("manifest.json"))
        try makeTestPNG(width: 256, height: 256).write(to: packsDir.appendingPathComponent("spritesheet.png"))
    }

    func writeOverrides() throws {
        let petDir = importedPetsDirectoryURL.appendingPathComponent("test-pet")
        let overrides = """
        { "schemaVersion": 1, "petId": "test-pet", "disabledPackIds": [], "actionOverrides": [] }
        """
        try Data(overrides.utf8).write(to: petDir.appendingPathComponent("action-pack-overrides.json"))
    }

    private var importedPetsDirectoryURL: URL { importedPetsDir }
}

private struct ImportFixture {
    let rootDir: URL
    let packageDir: URL
    let importedPetsDir: URL

    func cleanUp() {
        try? FileManager.default.removeItem(at: rootDir)
    }

    func writeBasicPetPackage() throws {
        try FileManager.default.createDirectory(at: packageDir, withIntermediateDirectories: true)
        let manifest = """
        {
          "schemaVersion": 2,
          "id": "test-pet",
          "displayName": "Test",
          "description": "test",
          "asset": "spritesheet.png",
          "preview": "preview.png",
          "assetKind": "spriteSheet",
          "frameSize": { "width": 256, "height": 256 },
          "spritesheet": { "columns": 4, "rows": 1 },
          "defaultScale": 1.0,
          "animations": {
            "idle": { "frames": [{ "column": 0, "row": 0 }], "frameDurationMs": 160, "loop": true }
          }
        }
        """
        try Data(manifest.utf8).write(to: packageDir.appendingPathComponent("manifest.json"))
        try makeTestPNG(width: 1024, height: 256).write(to: packageDir.appendingPathComponent("spritesheet.png"))
        try makeTestPNG(width: 256, height: 256).write(to: packageDir.appendingPathComponent("preview.png"))
    }

    func writePetPackageWithActionPack() throws {
        try writeBasicPetPackage()
        let packsDir = packageDir.appendingPathComponent("action-packs/wave_pack")
        try FileManager.default.createDirectory(at: packsDir, withIntermediateDirectories: true)
        let packManifest = """
        {
          "schemaVersion": 1,
          "id": "wave_pack",
          "displayName": "Wave",
          "createdAt": "2026-05-29T15:30:00Z",
          "resources": [{ "id": "sheet", "kind": "gridImage", "path": "spritesheet.png", "frameSize": { "width": 256, "height": 256 }, "grid": { "columns": 1, "rows": 1 } }],
          "actions": [{ "id": "wave_pack_wave", "displayName": "Wave", "role": null, "tags": [], "assetId": "sheet", "frames": [{ "column": 0, "row": 0 }], "frameDurationMs": 120, "loop": false, "nextActionId": "idle_default" }]
        }
        """
        try Data(packManifest.utf8).write(to: packsDir.appendingPathComponent("manifest.json"))
        try makeTestPNG(width: 256, height: 256).write(to: packsDir.appendingPathComponent("spritesheet.png"))
    }

    func writeOverridesInPackage() throws {
        let overrides = """
        { "schemaVersion": 1, "petId": "test-pet", "disabledPackIds": [], "actionOverrides": [] }
        """
        try Data(overrides.utf8).write(to: packageDir.appendingPathComponent("action-pack-overrides.json"))
    }

    func writeSingleImagePackage() throws {
        try FileManager.default.createDirectory(at: packageDir, withIntermediateDirectories: true)
        let manifest = """
        {
          "schemaVersion": 2,
          "id": "single-pet",
          "displayName": "Single",
          "description": "single image pet",
          "asset": "image.png",
          "assetKind": "singleImage",
          "frameSize": { "width": 256, "height": 256 },
          "defaultScale": 1.0,
          "animations": {
            "idle": { "frames": [{ "column": 0, "row": 0 }], "frameDurationMs": 160, "loop": true }
          }
        }
        """
        try Data(manifest.utf8).write(to: packageDir.appendingPathComponent("manifest.json"))
        try makeTestPNG(width: 256, height: 256).write(to: packageDir.appendingPathComponent("image.png"))
    }
}

// MARK: - Helpers

private func makeExportFixture() -> ExportFixture {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("PetExportTests-\(UUID().uuidString)")
    let imported = root.appendingPathComponent("Pets", isDirectory: true)
    let export = root.appendingPathComponent("Export", isDirectory: true)
    try! FileManager.default.createDirectory(at: imported, withIntermediateDirectories: true)
    try! FileManager.default.createDirectory(at: export, withIntermediateDirectories: true)
    return ExportFixture(rootDir: root, importedPetsDir: imported, exportDir: export)
}

private func makeImportFixture() -> ImportFixture {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("PetImportTests-\(UUID().uuidString)")
    let package = root.appendingPathComponent("test-pet.pet", isDirectory: true)
    let imported = root.appendingPathComponent("Pets", isDirectory: true)
    return ImportFixture(rootDir: root, packageDir: package, importedPetsDir: imported)
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
