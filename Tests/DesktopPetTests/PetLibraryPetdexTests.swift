import Foundation
import DesktopPet

func runPetLibraryPetdexTests() {
    let tests = PetLibraryPetdexTests()
    tests.petdexSidecarMarksLibraryItemAsPetdex()
    tests.loadDefinitionUsesInternalManifestWhenPetdexSidecarExists()
    tests.deleteImportedPetRemovesPetdexFolder()
    tests.corruptPetdexSidecarFallsBackToPackageSource()
    tests.petdexAndPackagePetsCoexist()
}

private struct PetLibraryPetdexTests {
    func petdexSidecarMarksLibraryItemAsPetdex() {
        let fixture = makeFixture()
        defer { fixture.cleanUp() }

        do {
            try fixture.writeSpriteSheetPet(id: "my-cat-v3-large", displayName: "Beibei")
            try fixture.writePetdexSidecar(id: "my-cat-v3-large", originalDisplayName: "Beibei")
        } catch {
            fail("failed to seed Petdex pet: \(error)")
        }

        let item = listItem(id: "my-cat-v3-large", fixture: fixture)
        expect(item.source == .petdex, "valid petdex-source.json should mark item as petdex")
        expect(item.displayName == "Beibei", "library item should still use internal manifest displayName")
        expect(item.previewURL?.lastPathComponent == "preview.png", "preview should come from internal manifest")
    }

    func loadDefinitionUsesInternalManifestWhenPetdexSidecarExists() {
        let fixture = makeFixture()
        defer { fixture.cleanUp() }

        do {
            try fixture.writeSpriteSheetPet(id: "petdex-load", displayName: "Manifest Name")
            try fixture.writePetdexSidecar(id: "petdex-load", originalDisplayName: "Sidecar Name")
        } catch {
            fail("failed to seed Petdex pet: \(error)")
        }

        do {
            let definition = try fixture.store.loadDefinition(id: "petdex-load")
            expect(definition.id == "petdex-load", "loadDefinition should load the internal manifest id")
            expect(definition.displayName == "Manifest Name", "loadDefinition should not read displayName from Petdex sidecar")
            expect(definition.assetKind == .spriteSheet, "Petdex package should load as internal spriteSheet definition")
        } catch {
            fail("loadDefinition should ignore Petdex sidecar and load manifest.json: \(error)")
        }
    }

    func deleteImportedPetRemovesPetdexFolder() {
        let fixture = makeFixture()
        defer { fixture.cleanUp() }

        do {
            try fixture.writeSpriteSheetPet(id: "petdex-delete", displayName: "Delete Me")
            try fixture.writePetdexSidecar(id: "petdex-delete", originalDisplayName: "Delete Me")
        } catch {
            fail("failed to seed Petdex pet: \(error)")
        }

        let folder = fixture.petFolder(id: "petdex-delete")
        expect(FileManager.default.fileExists(atPath: folder.path), "Petdex pet folder should exist before delete")

        do {
            try fixture.store.deleteImportedPet(id: "petdex-delete")
        } catch {
            fail("deleteImportedPet should allow Petdex pets: \(error)")
        }

        expect(!FileManager.default.fileExists(atPath: folder.path), "deleteImportedPet should remove the App-owned Petdex folder")
    }

    func corruptPetdexSidecarFallsBackToPackageSource() {
        let fixture = makeFixture()
        defer { fixture.cleanUp() }

        do {
            try fixture.writeSpriteSheetPet(id: "corrupt-sidecar", displayName: "Corrupt Sidecar")
            try fixture.writeCorruptPetdexSidecar(id: "corrupt-sidecar")
        } catch {
            fail("failed to seed corrupt sidecar pet: \(error)")
        }

        let item = listItem(id: "corrupt-sidecar", fixture: fixture)
        expect(item.source == .package, "corrupt petdex-source.json should not block listing and should fall back to package")

        do {
            let definition = try fixture.store.loadDefinition(id: "corrupt-sidecar")
            expect(definition.id == "corrupt-sidecar", "corrupt sidecar should not affect manifest loading")
        } catch {
            fail("corrupt sidecar should not affect loadDefinition: \(error)")
        }
    }

    func petdexAndPackagePetsCoexist() {
        let fixture = makeFixture()
        defer { fixture.cleanUp() }

        do {
            try fixture.writeSpriteSheetPet(id: "plain-package", displayName: "Plain Package")
            try fixture.writeSpriteSheetPet(id: "petdex-package", displayName: "Petdex Package")
            try fixture.writePetdexSidecar(id: "petdex-package", originalDisplayName: "Petdex Package")
        } catch {
            fail("failed to seed mixed package pets: \(error)")
        }

        let items = listItems(fixture: fixture)
        let sourcesById = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0.source) })

        expect(sourcesById["plain-package"] == .package, "plain sprite-sheet package should remain package")
        expect(sourcesById["petdex-package"] == .petdex, "Petdex sidecar package should be petdex")
        expect(sourcesById[fixture.store.builtInPetId] == .builtIn, "built-in pet should continue to coexist")
    }

    private func makeFixture() -> Fixture {
        let temporaryRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("PetLibraryPetdexTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: temporaryRoot, withIntermediateDirectories: true)
        return Fixture(rootDirectory: temporaryRoot, store: PetLibraryStore(rootDirectory: temporaryRoot))
    }

    private func listItem(id: String, fixture: Fixture) -> PetLibraryItem {
        let items = listItems(fixture: fixture)
        guard let item = items.first(where: { $0.id == id }) else {
            fail("expected library item \(id), got \(items.map(\.id))")
        }
        return item
    }

    private func listItems(fixture: Fixture) -> [PetLibraryItem] {
        do {
            return try fixture.store.listPets()
        } catch {
            fail("listPets should succeed: \(error)")
        }
    }
}

private struct Fixture {
    let rootDirectory: URL
    let store: PetLibraryStore

    func cleanUp() {
        try? FileManager.default.removeItem(at: rootDirectory)
    }

    func petFolder(id: String) -> URL {
        store.importedPetsDirectoryURL.appendingPathComponent(id, isDirectory: true)
    }

    func writeSpriteSheetPet(id: String, displayName: String) throws {
        let folder = petFolder(id: id)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try Data(spriteSheetManifest(id: id, displayName: displayName).utf8)
            .write(to: folder.appendingPathComponent(PetLibraryStore.manifestFileName))
    }

    func writePetdexSidecar(id: String, originalDisplayName: String) throws {
        let metadata = PetdexSourceMetadata(
            petdexId: id,
            originalDisplayName: originalDisplayName,
            importedAt: Date(timeIntervalSince1970: 1_778_544_000)
        )
        let data = try JSONEncoder().encode(metadata)
        try data.write(to: petFolder(id: id).appendingPathComponent(PetdexSourceMetadata.fileName))
    }

    func writeCorruptPetdexSidecar(id: String) throws {
        try Data("{ not valid petdex metadata".utf8)
            .write(to: petFolder(id: id).appendingPathComponent(PetdexSourceMetadata.fileName))
    }

    private func spriteSheetManifest(id: String, displayName: String) -> String {
        """
        {
          "schemaVersion": 2,
          "id": "\(id)",
          "displayName": "\(displayName)",
          "description": "imported Petdex-compatible package",
          "asset": "spritesheet.png",
          "preview": "preview.png",
          "assetKind": "spriteSheet",
          "frameSize": { "width": 192, "height": 208 },
          "spritesheet": { "columns": 8, "rows": 9 },
          "defaultScale": 1.0,
          "animations": {
            "idle": { "frames": [{ "column": 0, "row": 0 }], "frameDurationMs": 160, "loop": true },
            "walking": { "frames": [{ "column": 0, "row": 1 }], "frameDurationMs": 120, "loop": true },
            "sleeping": { "frames": [{ "column": 0, "row": 2 }], "frameDurationMs": 240, "loop": true },
            "happy": { "frames": [{ "column": 0, "row": 3 }], "frameDurationMs": 140, "loop": false, "nextState": "idle" },
            "eating": { "frames": [{ "column": 0, "row": 4 }], "frameDurationMs": 140, "loop": false, "nextState": "idle" },
            "jumping": { "frames": [{ "column": 0, "row": 5 }], "frameDurationMs": 120, "loop": false, "nextState": "idle" },
            "dragging": { "frames": [{ "column": 0, "row": 6 }], "frameDurationMs": 120, "loop": true }
          }
        }
        """
    }
}
