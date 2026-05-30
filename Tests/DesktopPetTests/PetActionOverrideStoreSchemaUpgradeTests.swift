import Foundation
import DesktopPet

func runPetActionOverrideStoreSchemaUpgradeTests() {
    let tests = PetActionOverrideStoreSchemaUpgradeTests()
    tests.loadingV1PackageOneThousandTimesDoesNotRewriteManifest()
    tests.savingOverrideForV1PackageUpgradesManifestThenWritesOverride()
    tests.rewriterWriteFailureKeepsV1ManifestAndDoesNotWriteOverride()
    tests.savingOverrideForV2PackageWritesOverrideWithoutChangingManifestBytes()
}

private struct PetActionOverrideStoreSchemaUpgradeTests {
    func loadingV1PackageOneThousandTimesDoesNotRewriteManifest() {
        let fixture = makeFixture()
        defer { fixture.cleanUp() }

        let petId = "schema-load-v1"
        let originalData = schemaUpgradeV1ManifestJSON(id: petId).utf8Data
        do {
            try fixture.writeManifest(petId: petId, data: originalData)
        } catch {
            fail("failed to seed v1 manifest: \(error)")
        }

        let manifestURL = fixture.manifestURL(for: petId)
        for iteration in 0..<1_000 {
            do {
                _ = try fixture.libraryStore.loadDefinition(id: petId)
            } catch {
                fail("loadDefinition iteration \(iteration) should not throw: \(error)")
            }

            do {
                let currentData = try Data(contentsOf: manifestURL)
                expect(currentData == originalData, "v1 manifest should not change on load iteration \(iteration)")
            } catch {
                fail("failed to read manifest on iteration \(iteration): \(error)")
            }
        }
    }

    func savingOverrideForV1PackageUpgradesManifestThenWritesOverride() {
        let fixture = makeFixture()
        defer { fixture.cleanUp() }

        let petId = "schema-save-v1"
        do {
            try fixture.writeManifest(petId: petId, data: schemaUpgradeV1ManifestJSON(id: petId).utf8Data)
            try fixture.overrideStore.save(makeOverrides(petId: petId), for: petId)
        } catch {
            fail("saving override for v1 package should succeed: \(error)")
        }

        do {
            let manifest = try JSONDecoder().decode(PetPackageManifest.self, from: Data(contentsOf: fixture.manifestURL(for: petId)))
            expect(manifest.schemaVersion == 2, "v1 manifest should be upgraded to schemaVersion=2")
            expect(manifest.legacyAnimations == nil, "upgraded manifest should not contain legacy animations")
            expect(manifest.actions.count == PetState.allCases.count, "upgraded manifest should include generated actions")
            expect(
                manifest.actions.contains(where: { $0.id == ActionId(rawValue: "idle_default") && $0.role == .idle }),
                "upgraded manifest should include idle_default action"
            )
            expect(
                manifest.actions.contains(where: { $0.id == ActionId(rawValue: "dragging_default") && $0.role == .dragging }),
                "upgraded manifest should include dragging_default action"
            )
        } catch {
            fail("upgraded manifest should be decodable: \(error)")
        }

        let overrideURL = fixture.overrideStore.overrideFileURL(for: petId)
        expect(FileManager.default.fileExists(atPath: overrideURL.path), "override file should be written after manifest upgrade")
        do {
            let loaded = try fixture.overrideStore.load(petId: petId)
            expect(loaded == makeOverrides(petId: petId), "saved override should load after manifest upgrade")
        } catch {
            fail("override should load after manifest upgrade: \(error)")
        }
    }

    func rewriterWriteFailureKeepsV1ManifestAndDoesNotWriteOverride() {
        let fixture = makeFixture()
        defer { fixture.cleanUp() }

        let petId = "schema-save-failure"
        let originalData = schemaUpgradeV1ManifestJSON(id: petId).utf8Data
        let petDirectoryURL = fixture.petDirectoryURL(for: petId)

        do {
            try fixture.writeManifest(petId: petId, data: originalData)
            try FileManager.default.setAttributes([.posixPermissions: 0o500], ofItemAtPath: petDirectoryURL.path)
        } catch {
            fail("failed to seed non-writable v1 package: \(error)")
        }
        defer {
            try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: petDirectoryURL.path)
        }

        do {
            try fixture.overrideStore.save(makeOverrides(petId: petId), for: petId)
            fail("saving override should fail when manifest rewrite cannot write")
        } catch let error as ActionOverrideError {
            switch error {
            case .writeFailed(let failedPetId, _):
                expect(failedPetId == petId, "writeFailed should include pet id")
            case .deleteFailed:
                fail("save failure should throw writeFailed, got \(error)")
            }
        } catch {
            fail("save failure should throw ActionOverrideError.writeFailed, got \(error)")
        }

        do {
            let currentData = try Data(contentsOf: fixture.manifestURL(for: petId))
            expect(currentData == originalData, "manifest should remain original v1 bytes after rewrite failure")
            let manifest = try JSONDecoder().decode(PetPackageManifest.self, from: currentData)
            expect(manifest.schemaVersion == 1, "manifest should still decode as schemaVersion=1")
            expect(manifest.legacyAnimations != nil, "manifest should still contain legacy animations")
        } catch {
            fail("v1 manifest should remain readable after rewrite failure: \(error)")
        }

        expect(
            !FileManager.default.fileExists(atPath: fixture.overrideStore.overrideFileURL(for: petId).path),
            "override file must not be written when manifest rewrite fails"
        )
    }

    func savingOverrideForV2PackageWritesOverrideWithoutChangingManifestBytes() {
        let fixture = makeFixture()
        defer { fixture.cleanUp() }

        let petId = "schema-save-v2"
        let originalData = schemaUpgradeV2ManifestJSON(id: petId).utf8Data
        let rewriter = RecordingManifestRewriter()
        let overrideStore = PetActionOverrideStore(
            petsDirectoryURL: fixture.libraryStore.importedPetsDirectoryURL,
            manifestRewriter: rewriter
        )

        do {
            try fixture.writeManifest(petId: petId, data: originalData)
            try overrideStore.save(makeOverrides(petId: petId), for: petId)
        } catch {
            fail("saving override for v2 package should succeed: \(error)")
        }

        expect(rewriter.calls == 0, "v2 save should not call manifest rewriter")
        do {
            let currentData = try Data(contentsOf: fixture.manifestURL(for: petId))
            expect(currentData == originalData, "v2 manifest bytes should remain unchanged when saving override")
        } catch {
            fail("v2 manifest should remain readable after save: \(error)")
        }

        expect(
            FileManager.default.fileExists(atPath: overrideStore.overrideFileURL(for: petId).path),
            "v2 save should still write override"
        )
    }

    private func makeFixture() -> SchemaUpgradeFixture {
        let temporaryRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("PetActionOverrideStoreSchemaUpgradeTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: temporaryRoot, withIntermediateDirectories: true)
        let libraryStore = PetLibraryStore(rootDirectory: temporaryRoot)
        let overrideStore = PetActionOverrideStore(petsDirectoryURL: libraryStore.importedPetsDirectoryURL)
        return SchemaUpgradeFixture(rootDirectory: temporaryRoot, libraryStore: libraryStore, overrideStore: overrideStore)
    }

    private func makeOverrides(petId: String) -> PetActionOverrideSet {
        PetActionOverrideSet(
            petId: petId,
            overrides: [
                PetActionOverride(
                    actionId: ActionId(rawValue: "idle_default")!,
                    displayName: "Calm Idle",
                    tags: [ActionTag(rawValue: "mood:high")!],
                    role: .idle
                )
            ]
        )
    }
}

private final class RecordingManifestRewriter: ManifestRewriting {
    private(set) var calls = 0

    func rewriteV1ManifestToV2(at manifestURL: URL) throws -> Bool {
        calls += 1
        return false
    }
}

private struct SchemaUpgradeFixture {
    let rootDirectory: URL
    let libraryStore: PetLibraryStore
    let overrideStore: PetActionOverrideStore

    func petDirectoryURL(for petId: String) -> URL {
        libraryStore.importedPetsDirectoryURL.appendingPathComponent(petId, isDirectory: true)
    }

    func manifestURL(for petId: String) -> URL {
        petDirectoryURL(for: petId).appendingPathComponent(PetLibraryStore.manifestFileName, isDirectory: false)
    }

    func writeManifest(petId: String, data: Data) throws {
        let petDirectoryURL = petDirectoryURL(for: petId)
        try FileManager.default.createDirectory(at: petDirectoryURL, withIntermediateDirectories: true)
        try data.write(to: manifestURL(for: petId))
    }

    func cleanUp() {
        try? FileManager.default.removeItem(at: rootDirectory)
    }
}

private func schemaUpgradeV1ManifestJSON(id: String) -> String {
    """
    {
      "schemaVersion": 1,
      "id": "\(id)",
      "displayName": "Schema Upgrade Pet",
      "description": "v1 manifest used for schema upgrade",
      "asset": "spritesheet.png",
      "preview": "preview.png",
      "assetKind": "spriteSheet",
      "frameSize": { "width": 128, "height": 96 },
      "spritesheet": { "columns": 2, "rows": 7 },
      "defaultScale": 1.5,
      "animations": {
        "idle": { "frames": [{ "column": 0, "row": 0 }, { "column": 1, "row": 0 }], "frameDurationMs": 160, "loop": true },
        "walking": { "frames": [{ "column": 0, "row": 1 }], "frameDurationMs": 160, "loop": true },
        "sleeping": { "frames": [{ "column": 0, "row": 2 }], "frameDurationMs": 220, "loop": true },
        "happy": { "frames": [{ "column": 0, "row": 3 }], "frameDurationMs": 120, "loop": false, "nextState": "idle" },
        "eating": { "frames": [{ "column": 0, "row": 4 }], "frameDurationMs": 130, "loop": false, "nextState": "idle" },
        "jumping": { "frames": [{ "column": 0, "row": 5 }], "frameDurationMs": 110, "loop": false, "nextState": "idle" },
        "dragging": { "frames": [{ "column": 0, "row": 6 }], "frameDurationMs": 140, "loop": true }
      },
      "motionProfile": {
        "stateMotions": {
          "idle": { "kind": "bob", "amplitude": 4, "durationMs": 1800, "loop": true },
          "dragging": { "kind": "tilt", "amplitude": 6, "durationMs": 240, "loop": false }
        }
      },
      "bubbleProfile": {
        "minimumIntervalSeconds": 30,
        "displayDurationSeconds": 2.5,
        "phrases": {
          "clicked": ["hello"],
          "idle": ["idle"]
        }
      }
    }
    """
}

private func schemaUpgradeV2ManifestJSON(id: String) -> String {
    """
    {
      "schemaVersion": 2,
      "id": "\(id)",
      "displayName": "Schema V2 Pet",
      "description": "v2 manifest should not be rewritten",
      "asset": "spritesheet.png",
      "preview": "preview.png",
      "assetKind": "spriteSheet",
      "frameSize": { "width": 128, "height": 96 },
      "spritesheet": { "columns": 2, "rows": 7 },
      "defaultScale": 1.5,
      "actions": [
        {
          "id": "idle_default",
          "displayName": "Idle",
          "role": "idle",
          "tags": [],
          "frames": [{ "column": 0, "row": 0 }],
          "frameDurationMs": 160,
          "loop": true
        },
        {
          "id": "dragging_default",
          "displayName": "Dragging",
          "role": "dragging",
          "tags": [],
          "frames": [{ "column": 0, "row": 6 }],
          "frameDurationMs": 140,
          "loop": true
        }
      ]
    }
    """
}

private extension String {
    var utf8Data: Data {
        Data(utf8)
    }
}
