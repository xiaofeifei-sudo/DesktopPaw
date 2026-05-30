import Foundation
import DesktopPet

func runPetActionOverrideStoreTests() {
    let tests = PetActionOverrideStoreTests()
    tests.saveLoadRoundTripsActionsMapping()
    tests.loadMissingFileReturnsNil()
    tests.loadCorruptJSONReturnsNil()
    tests.deleteRemovesOverrideFileAndIgnoresMissingFile()
    tests.deleteImportedPetRemovesOverrideFileWithPetFolder()
    tests.saveFailureThrowsWriteFailed()
}

private struct PetActionOverrideStoreTests {
    func saveLoadRoundTripsActionsMapping() {
        let fixture = makeFixture()
        defer { fixture.cleanUp() }

        let overrides = makeOverrides(petId: "override-roundtrip")

        do {
            try fixture.overrideStore.save(overrides, for: "override-roundtrip")
        } catch {
            fail("save should succeed: \(error)")
        }

        let fileURL = fixture.overrideStore.overrideFileURL(for: "override-roundtrip")
        expect(FileManager.default.fileExists(atPath: fileURL.path), "save should create action-overrides.json")

        do {
            let raw = try String(contentsOf: fileURL, encoding: .utf8)
            expect(raw.contains("\"overrideSchemaVersion\""), "override file should include overrideSchemaVersion")
            expect(raw.contains("\"actions\""), "override file should use the actions mapping")
            expect(!raw.contains("\"manifest\""), "override save should not write or reference manifest data")
        } catch {
            fail("saved override file should be readable: \(error)")
        }

        do {
            let loaded = try fixture.overrideStore.load(petId: "override-roundtrip")
            expect(loaded == overrides, "loaded overrides should equal saved overrides, got \(String(describing: loaded))")
            expect(
                loaded?.override(for: ActionId(rawValue: "extra_1")!)?.displayName == "Lick Paw",
                "loaded overrides should preserve displayName"
            )
            expect(
                loaded?.override(for: ActionId(rawValue: "extra_2")!)?.role == .happy,
                "loaded overrides should preserve role override"
            )
            expect(
                loaded?.override(for: ActionId(rawValue: "extra_1")!)?.frameDurationsMs == [90, 240],
                "loaded overrides should preserve frame duration overrides"
            )
        } catch {
            fail("load should not throw after save: \(error)")
        }
    }

    func loadMissingFileReturnsNil() {
        let fixture = makeFixture()
        defer { fixture.cleanUp() }

        do {
            let loaded = try fixture.overrideStore.load(petId: "missing")
            expect(loaded == nil, "missing override file should load as nil")
        } catch {
            fail("missing override file should not throw: \(error)")
        }
    }

    func loadCorruptJSONReturnsNil() {
        let fixture = makeFixture()
        defer { fixture.cleanUp() }

        let fileURL = fixture.overrideStore.overrideFileURL(for: "corrupt")
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try Data("{ not valid json".utf8).write(to: fileURL)
        } catch {
            fail("failed to seed corrupt override file: \(error)")
        }

        do {
            let loaded = try fixture.overrideStore.load(petId: "corrupt")
            expect(loaded == nil, "corrupt override JSON should load as nil")
        } catch {
            fail("corrupt override JSON should not throw: \(error)")
        }
    }

    func deleteRemovesOverrideFileAndIgnoresMissingFile() {
        let fixture = makeFixture()
        defer { fixture.cleanUp() }

        do {
            try fixture.overrideStore.save(makeOverrides(petId: "delete-me"), for: "delete-me")
        } catch {
            fail("save before delete should succeed: \(error)")
        }

        let fileURL = fixture.overrideStore.overrideFileURL(for: "delete-me")
        expect(FileManager.default.fileExists(atPath: fileURL.path), "override file should exist before delete")

        do {
            try fixture.overrideStore.delete(petId: "delete-me")
            try fixture.overrideStore.delete(petId: "delete-me")
        } catch {
            fail("delete should remove existing file and ignore missing file: \(error)")
        }

        expect(!FileManager.default.fileExists(atPath: fileURL.path), "override file should be removed after delete")
    }

    func deleteImportedPetRemovesOverrideFileWithPetFolder() {
        let fixture = makeFixture()
        defer { fixture.cleanUp() }

        do {
            try fixture.overrideStore.save(makeOverrides(petId: "pet-delete"), for: "pet-delete")
        } catch {
            fail("save before pet delete should succeed: \(error)")
        }

        let folderURL = fixture.libraryStore.importedPetsDirectoryURL.appendingPathComponent("pet-delete", isDirectory: true)
        let fileURL = fixture.overrideStore.overrideFileURL(for: "pet-delete")
        expect(FileManager.default.fileExists(atPath: fileURL.path), "override file should exist before pet delete")

        do {
            try fixture.libraryStore.deleteImportedPet(id: "pet-delete")
        } catch {
            fail("deleteImportedPet should delete the pet folder: \(error)")
        }

        expect(!FileManager.default.fileExists(atPath: fileURL.path), "override file should be removed with pet folder")
        expect(!FileManager.default.fileExists(atPath: folderURL.path), "pet folder should be removed")
    }

    func saveFailureThrowsWriteFailed() {
        let temporaryRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("PetActionOverrideStoreFailureTests-\(UUID().uuidString)", isDirectory: false)
        defer { try? FileManager.default.removeItem(at: temporaryRoot) }

        do {
            try Data("not a directory".utf8).write(to: temporaryRoot)
        } catch {
            fail("failed to seed file conflict: \(error)")
        }

        let store = PetActionOverrideStore(petsDirectoryURL: temporaryRoot)

        do {
            try store.save(makeOverrides(petId: "cannot-save"), for: "cannot-save")
            fail("save should throw writeFailed when PetsDir is a file")
        } catch let error as ActionOverrideError {
            switch error {
            case .writeFailed(let petId, _):
                expect(petId == "cannot-save", "writeFailed should include target pet id")
            case .deleteFailed:
                fail("save should throw writeFailed, got \(error)")
            }
        } catch {
            fail("save should throw ActionOverrideError.writeFailed, got \(error)")
        }
    }

    private func makeFixture() -> Fixture {
        let temporaryRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("PetActionOverrideStoreTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: temporaryRoot, withIntermediateDirectories: true)
        let libraryStore = PetLibraryStore(rootDirectory: temporaryRoot)
        let overrideStore = PetActionOverrideStore(petsDirectoryURL: libraryStore.importedPetsDirectoryURL)
        return Fixture(rootDirectory: temporaryRoot, libraryStore: libraryStore, overrideStore: overrideStore)
    }

    private func makeOverrides(petId: String) -> PetActionOverrideSet {
        PetActionOverrideSet(
            petId: petId,
            overrides: [
                PetActionOverride(
                    actionId: ActionId(rawValue: "extra_1")!,
                    displayName: "Lick Paw",
                    tags: [
                        ActionTag(rawValue: "after.pet")!,
                        ActionTag(rawValue: "mood:high")!
                    ],
                    role: nil,
                    frameDurationsMs: [90, 240]
                ),
                PetActionOverride(
                    actionId: ActionId(rawValue: "extra_2")!,
                    displayName: "Big Jump",
                    tags: [],
                    role: .happy
                )
            ]
        )
    }
}

private struct Fixture {
    let rootDirectory: URL
    let libraryStore: PetLibraryStore
    let overrideStore: PetActionOverrideStore

    func cleanUp() {
        try? FileManager.default.removeItem(at: rootDirectory)
    }
}
