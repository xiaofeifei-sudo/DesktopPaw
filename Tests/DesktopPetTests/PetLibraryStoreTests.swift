import Foundation
import DesktopPet

func runPetLibraryStoreTests() {
    let tests = PetLibraryStoreTests()
    tests.emptyDirectoryReturnsOnlyBuiltIn()
    tests.directoryIsAutoCreatedOnFirstAccess()
    tests.listMergesImportedPets()
    tests.unknownIdFallsBackToBuiltIn()
    tests.corruptManifestIsSkipped()
    tests.deleteImportedPetRemovesFolder()
    tests.deleteBuiltInPetThrows()
    tests.deleteUnknownPetThrows()
    tests.loadDefinitionFromImportedManifest()
}

private struct PetLibraryStoreTests {
    func emptyDirectoryReturnsOnlyBuiltIn() {
        let fixture = makeFixture()
        defer { fixture.cleanUp() }

        let items: [PetLibraryItem]
        do {
            items = try fixture.store.listPets()
        } catch {
            fail("listPets should not fail on empty directory: \(error)")
        }

        expect(items.count == 1, "empty directory should yield only the built-in pet, got \(items.count)")
        expect(items.first?.id == fixture.store.builtInPetId, "built-in pet should be present")
        expect(items.first?.source == .builtIn, "built-in pet should be tagged builtIn")
    }

    func directoryIsAutoCreatedOnFirstAccess() {
        let fixture = makeFixture()
        defer { fixture.cleanUp() }

        let petsURL = fixture.store.importedPetsDirectoryURL
        expect(!FileManager.default.fileExists(atPath: petsURL.path), "Pets directory should not exist before listing")

        do {
            _ = try fixture.store.listPets()
        } catch {
            fail("listPets should auto-create directory: \(error)")
        }

        var isDir: ObjCBool = false
        expect(
            FileManager.default.fileExists(atPath: petsURL.path, isDirectory: &isDir) && isDir.boolValue,
            "Pets directory should be auto-created on first access"
        )
    }

    func listMergesImportedPets() {
        let fixture = makeFixture()
        defer { fixture.cleanUp() }

        do {
            try fixture.writeFakeImportedPet(id: "alpha-001", displayName: "Alpha")
            try fixture.writeFakeImportedPet(id: "beta-002", displayName: "Beta")
        } catch {
            fail("failed to seed fake pets: \(error)")
        }

        let items: [PetLibraryItem]
        do {
            items = try fixture.store.listPets()
        } catch {
            fail("listPets should succeed with imported pets: \(error)")
        }

        let ids = Set(items.map { $0.id })
        expect(ids.contains(fixture.store.builtInPetId), "built-in pet should still be present")
        expect(ids.contains("alpha-001"), "alpha imported pet should be listed")
        expect(ids.contains("beta-002"), "beta imported pet should be listed")

        let imported = items.filter { $0.source == .importedImage }
        expect(imported.count == 2, "should have two imported pets, got \(imported.count)")
    }

    func unknownIdFallsBackToBuiltIn() {
        let fixture = makeFixture()
        defer { fixture.cleanUp() }

        do {
            let definition = try fixture.store.loadDefinition(id: "totally-missing")
            expect(definition.id == fixture.store.builtInPetId, "unknown id should fall back to built-in pet")
        } catch {
            fail("unknown id should fallback rather than throw: \(error)")
        }
    }

    func corruptManifestIsSkipped() {
        let fixture = makeFixture()
        defer { fixture.cleanUp() }

        do {
            try fixture.writeFakeImportedPet(id: "good-001", displayName: "Good")
            try fixture.writeBrokenImportedPet(id: "broken-001")
        } catch {
            fail("seeding pets failed: \(error)")
        }

        let items: [PetLibraryItem]
        do {
            items = try fixture.store.listPets()
        } catch {
            fail("listPets should not fail when one pet has corrupt manifest: \(error)")
        }

        let ids = items.map { $0.id }
        expect(ids.contains("good-001"), "valid imported pet should still be listed")
        expect(!ids.contains("broken-001"), "corrupt imported pet should be skipped")
    }

    func deleteImportedPetRemovesFolder() {
        let fixture = makeFixture()
        defer { fixture.cleanUp() }

        do {
            try fixture.writeFakeImportedPet(id: "to-delete", displayName: "Bye")
        } catch {
            fail("seeding pets failed: \(error)")
        }

        let folder = fixture.store.importedPetsDirectoryURL.appendingPathComponent("to-delete")
        expect(FileManager.default.fileExists(atPath: folder.path), "folder should exist before delete")

        do {
            try fixture.store.deleteImportedPet(id: "to-delete")
        } catch {
            fail("deleteImportedPet should succeed: \(error)")
        }

        expect(!FileManager.default.fileExists(atPath: folder.path), "folder should be gone after delete")
    }

    func deleteBuiltInPetThrows() {
        let fixture = makeFixture()
        defer { fixture.cleanUp() }

        do {
            try fixture.store.deleteImportedPet(id: fixture.store.builtInPetId)
            fail("deleting built-in pet should throw")
        } catch let error as PetLibraryError {
            expect(error == .cannotDeleteBuiltInPet, "expected cannotDeleteBuiltInPet, got \(error)")
        } catch {
            fail("expected PetLibraryError, got \(error)")
        }
    }

    func deleteUnknownPetThrows() {
        let fixture = makeFixture()
        defer { fixture.cleanUp() }

        do {
            try fixture.store.deleteImportedPet(id: "no-such-pet")
            fail("deleting unknown pet should throw petNotFound")
        } catch let error as PetLibraryError {
            expect(error == .petNotFound, "expected petNotFound, got \(error)")
        } catch {
            fail("expected PetLibraryError, got \(error)")
        }
    }

    func loadDefinitionFromImportedManifest() {
        let fixture = makeFixture()
        defer { fixture.cleanUp() }

        do {
            try fixture.writeFakeImportedPet(id: "loaded-001", displayName: "Loaded")
        } catch {
            fail("seeding pets failed: \(error)")
        }

        do {
            let definition = try fixture.store.loadDefinition(id: "loaded-001")
            expect(definition.id == "loaded-001", "loaded definition should match id")
            expect(definition.assetKind == .singleImage, "imported pet should be single image")
            expect(definition.animations.count == PetState.allCases.count, "loaded definition should have all states")
        } catch {
            fail("loadDefinition should succeed for imported pet: \(error)")
        }
    }

    private func makeFixture() -> Fixture {
        let temporaryRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("DesktopPetTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: temporaryRoot, withIntermediateDirectories: true)
        let store = PetLibraryStore(rootDirectory: temporaryRoot)
        return Fixture(rootDirectory: temporaryRoot, store: store)
    }
}

private struct Fixture {
    let rootDirectory: URL
    let store: PetLibraryStore

    func cleanUp() {
        try? FileManager.default.removeItem(at: rootDirectory)
    }

    func writeFakeImportedPet(id: String, displayName: String) throws {
        let folder = store.importedPetsDirectoryURL.appendingPathComponent(id, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let manifestURL = folder.appendingPathComponent("manifest.json")
        try Data(singleImageManifest(id: id, displayName: displayName).utf8).write(to: manifestURL)
    }

    func writeBrokenImportedPet(id: String) throws {
        let folder = store.importedPetsDirectoryURL.appendingPathComponent(id, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let manifestURL = folder.appendingPathComponent("manifest.json")
        try Data("{ this is not valid json".utf8).write(to: manifestURL)
    }

    private func singleImageManifest(id: String, displayName: String) -> String {
        """
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
            "idle": { "frames": [{ "column": 0, "row": 0 }], "frameDurationMs": 1000, "loop": true },
            "walking": { "frames": [{ "column": 0, "row": 0 }], "frameDurationMs": 1000, "loop": true },
            "sleeping": { "frames": [{ "column": 0, "row": 0 }], "frameDurationMs": 1000, "loop": true },
            "happy": { "frames": [{ "column": 0, "row": 0 }], "frameDurationMs": 1000, "loop": false, "nextState": "idle" },
            "eating": { "frames": [{ "column": 0, "row": 0 }], "frameDurationMs": 1000, "loop": false, "nextState": "idle" },
            "jumping": { "frames": [{ "column": 0, "row": 0 }], "frameDurationMs": 1000, "loop": false, "nextState": "idle" },
            "dragging": { "frames": [{ "column": 0, "row": 0 }], "frameDurationMs": 1000, "loop": true }
          }
        }
        """
    }
}
