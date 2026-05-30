import Foundation
import DesktopPet

func runPetLibraryStoreActionsTests() {
  let tests = PetLibraryStoreActionsTests()
  tests.corruptManifestFallsBackToBuiltInPet()
  tests.schemaVersion3ManifestFallsBackToBuiltInPet()
  tests.duplicateActionIdManifestFallsBackToBuiltInPet()
  tests.missingIdleRoleManifestLoadsAsCustomPet()
  tests.legacyPetdexRoleManifestLoadsAsGenericRows()
  tests.loadingV1ManifestRepeatedlyDoesNotMutateDisk()
}

private struct PetLibraryStoreActionsTests {
  func corruptManifestFallsBackToBuiltInPet() {
    let fixture = makeFixture()
    defer { fixture.cleanUp() }

    do {
      try fixture.writeImportedPet(id: "broken-001", manifestBody: "{ this is not valid json".utf8Data)
    } catch {
      fail("seeding broken pet failed: \(error)")
    }

    do {
      let definition = try fixture.store.loadDefinition(id: "broken-001")
      expect(
        definition.id == fixture.store.builtInPetId,
        "corrupt manifest should fall back to built-in pet, got \(definition.id)"
      )
    } catch {
      fail("loadDefinition should fall back rather than throw on corrupt manifest: \(error)")
    }
  }

  func schemaVersion3ManifestFallsBackToBuiltInPet() {
    let fixture = makeFixture()
    defer { fixture.cleanUp() }

    do {
      try fixture.writeImportedPet(id: "future-001", manifestBody: schemaV3ManifestJSON(id: "future-001").utf8Data)
    } catch {
      fail("seeding v3 pet failed: \(error)")
    }

    do {
      let definition = try fixture.store.loadDefinition(id: "future-001")
      expect(
        definition.id == fixture.store.builtInPetId,
        "schemaVersion=3 manifest should fall back to built-in pet, got \(definition.id)"
      )
    } catch {
      fail("loadDefinition should fall back rather than throw on schemaVersion=3 manifest: \(error)")
    }
  }

  func duplicateActionIdManifestFallsBackToBuiltInPet() {
    let fixture = makeFixture()
    defer { fixture.cleanUp() }

    do {
      try fixture.writeImportedPet(
        id: "dup-001",
        manifestBody: schemaV2ManifestWithDuplicateActionIdJSON(id: "dup-001").utf8Data
      )
    } catch {
      fail("seeding duplicate-id pet failed: \(error)")
    }

    do {
      let definition = try fixture.store.loadDefinition(id: "dup-001")
      expect(
        definition.id == fixture.store.builtInPetId,
        "duplicate action id should fall back to built-in pet, got \(definition.id)"
      )
    } catch {
      fail("loadDefinition should fall back rather than throw on duplicate action id: \(error)")
    }
  }

  func missingIdleRoleManifestLoadsAsCustomPet() {
    let fixture = makeFixture()
    defer { fixture.cleanUp() }

    do {
      try fixture.writeImportedPet(
        id: "miss-001",
        manifestBody: schemaV2ManifestMissingIdleRoleJSON(id: "miss-001").utf8Data
      )
    } catch {
      fail("seeding missing-idle pet failed: \(error)")
    }

    do {
      let definition = try fixture.store.loadDefinition(id: "miss-001")
      expect(
        definition.id == "miss-001",
        "missing idle role should load as a valid custom pet, got \(definition.id)"
      )
      expect(definition.animation(for: .idle)?.frames.first == SpriteFrame(column: 0, row: 1), "missing idle should resolve through the default action fallback")
    } catch {
      fail("loadDefinition should accept manifests without a fixed idle role: \(error)")
    }
  }

  func legacyPetdexRoleManifestLoadsAsGenericRows() {
    let fixture = makeFixture()
    defer { fixture.cleanUp() }

    do {
      try fixture.writeImportedPet(
        id: "petdex-old-001",
        manifestBody: schemaV2LegacyPetdexRoleManifestJSON(id: "petdex-old-001").utf8Data
      )
      try fixture.writePetdexSourceSidecar(id: "petdex-old-001")
    } catch {
      fail("seeding legacy Petdex pet failed: \(error)")
    }

    do {
      let definition = try fixture.store.loadDefinition(id: "petdex-old-001")
      expect(definition.id == "petdex-old-001", "legacy Petdex role manifest should load as imported pet")
      expect(definition.catalog.actions.count == 9, "legacy Petdex role manifest should expose one generic action per row")
      expect(definition.catalog.actions.allSatisfy { $0.role == nil }, "legacy Petdex role manifest should load role-less actions")
      expect(
        definition.catalog.actions.map(\.id.rawValue) == (1...9).map { "action_\($0)" },
        "legacy Petdex role manifest should use generic row ids"
      )
      expect(definition.catalog.resolve(actionId: ActionId(rawValue: "action_8")!)?.frames.first?.row == 7, "legacy Petdex extra row should become action_8")
      expect(definition.catalog.resolve(actionId: ActionId(rawValue: "action_9")!)?.frames.first?.row == 8, "legacy Petdex extra row should become action_9")
    } catch {
      fail("loadDefinition should normalize legacy Petdex role manifests: \(error)")
    }
  }

  func loadingV1ManifestRepeatedlyDoesNotMutateDisk() {
    let fixture = makeFixture()
    defer { fixture.cleanUp() }

    let petId = "v1-stable-001"
    let manifestBytes = schemaV1ManifestJSON(id: petId).utf8Data
    do {
      try fixture.writeImportedPet(id: petId, manifestBody: manifestBytes)
    } catch {
      fail("seeding v1 pet failed: \(error)")
    }

    let manifestURL = fixture.store.importedPetsDirectoryURL
      .appendingPathComponent(petId, isDirectory: true)
      .appendingPathComponent(PetLibraryStore.manifestFileName)
    let initialBytes: Data
    do {
      initialBytes = try Data(contentsOf: manifestURL)
    } catch {
      fail("could not read seeded v1 manifest bytes: \(error)")
    }
    expect(initialBytes == manifestBytes, "seeded manifest bytes should match input fixture")

    for iteration in 0..<10 {
      do {
        _ = try fixture.store.loadDefinition(id: petId)
      } catch {
        fail("loadDefinition iteration \(iteration) should succeed for v1 manifest: \(error)")
      }
      let nextBytes: Data
      do {
        nextBytes = try Data(contentsOf: manifestURL)
      } catch {
        fail("could not re-read v1 manifest at iteration \(iteration): \(error)")
      }
      expect(
        nextBytes == initialBytes,
        "v1 manifest must not be rewritten on load (iteration \(iteration))"
      )
    }
  }

  private func makeFixture() -> Fixture {
    let temporaryRoot = FileManager.default.temporaryDirectory
      .appendingPathComponent("DesktopPetActionsTests-\(UUID().uuidString)", isDirectory: true)
    try? FileManager.default.createDirectory(at: temporaryRoot, withIntermediateDirectories: true)
    let store = PetLibraryStore(rootDirectory: temporaryRoot)
    return Fixture(rootDirectory: temporaryRoot, store: store)
  }

  private func schemaV1ManifestJSON(id: String) -> String {
    """
    {
      "schemaVersion": 1,
      "id": "\(id)",
      "displayName": "V1 Stable",
      "description": "v1 manifest used for read-only assertion",
      "asset": "spritesheet.png",
      "preview": "preview.png",
      "frameSize": { "width": 128, "height": 128 },
      "spritesheet": { "columns": 1, "rows": 7 },
      "defaultScale": 1.0,
      "animations": {
        "idle": { "frames": [{ "column": 0, "row": 0 }], "frameDurationMs": 160, "loop": true },
        "walking": { "frames": [{ "column": 0, "row": 1 }], "frameDurationMs": 160, "loop": true },
        "sleeping": { "frames": [{ "column": 0, "row": 2 }], "frameDurationMs": 160, "loop": true },
        "happy": { "frames": [{ "column": 0, "row": 3 }], "frameDurationMs": 120, "loop": false, "nextState": "idle" },
        "eating": { "frames": [{ "column": 0, "row": 4 }], "frameDurationMs": 120, "loop": false, "nextState": "idle" },
        "jumping": { "frames": [{ "column": 0, "row": 5 }], "frameDurationMs": 120, "loop": false, "nextState": "idle" },
        "dragging": { "frames": [{ "column": 0, "row": 6 }], "frameDurationMs": 160, "loop": true }
      }
    }
    """
  }

  private func schemaV3ManifestJSON(id: String) -> String {
    """
    {
      "schemaVersion": 3,
      "id": "\(id)",
      "displayName": "V3 Future",
      "description": "Future schema; should fall back",
      "asset": "spritesheet.png",
      "frameSize": { "width": 128, "height": 128 },
      "spritesheet": { "columns": 1, "rows": 7 },
      "defaultScale": 1.0,
      "actions": []
    }
    """
  }

  private func schemaV2ManifestWithDuplicateActionIdJSON(id: String) -> String {
    """
    {
      "schemaVersion": 2,
      "id": "\(id)",
      "displayName": "Dup Pet",
      "description": "manifest with duplicate action ids",
      "asset": "spritesheet.png",
      "frameSize": { "width": 128, "height": 128 },
      "spritesheet": { "columns": 1, "rows": 7 },
      "defaultScale": 1.0,
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
          "id": "idle_default",
          "displayName": "Idle Duplicate",
          "role": "idle",
          "tags": [],
          "frames": [{ "column": 0, "row": 1 }],
          "frameDurationMs": 160,
          "loop": true
        },
        {
          "id": "dragging_default",
          "displayName": "Drag",
          "role": "dragging",
          "tags": [],
          "frames": [{ "column": 0, "row": 6 }],
          "frameDurationMs": 160,
          "loop": true
        }
      ]
    }
    """
  }

  private func schemaV2ManifestMissingIdleRoleJSON(id: String) -> String {
    """
    {
      "schemaVersion": 2,
      "id": "\(id)",
      "displayName": "Missing Idle",
      "description": "v2 manifest without idle role",
      "asset": "spritesheet.png",
      "frameSize": { "width": 128, "height": 128 },
      "spritesheet": { "columns": 1, "rows": 7 },
      "defaultScale": 1.0,
      "actions": [
        {
          "id": "walking_default",
          "displayName": "Walking",
          "role": "walking",
          "tags": [],
          "frames": [{ "column": 0, "row": 1 }],
          "frameDurationMs": 160,
          "loop": true
        },
        {
          "id": "dragging_default",
          "displayName": "Drag",
          "role": "dragging",
          "tags": [],
          "frames": [{ "column": 0, "row": 6 }],
          "frameDurationMs": 160,
          "loop": true
        }
      ]
    }
    """
  }

  private func schemaV2LegacyPetdexRoleManifestJSON(id: String) -> String {
    """
    {
      "schemaVersion": 2,
      "id": "\(id)",
      "displayName": "Legacy Petdex",
      "description": "old Petdex role-mapped manifest",
      "asset": "spritesheet.png",
      "preview": "preview.png",
      "frameSize": { "width": 128, "height": 128 },
      "spritesheet": { "columns": 8, "rows": 9 },
      "defaultScale": 1.0,
      "actions": [
        { "id": "idle_default", "displayName": "Idle", "role": "idle", "tags": [], "frames": [{ "column": 0, "row": 0 }], "frameDurationMs": 160, "loop": true },
        { "id": "walking_default", "displayName": "Walking", "role": "walking", "tags": [], "frames": [{ "column": 0, "row": 1 }], "frameDurationMs": 160, "loop": true },
        { "id": "sleeping_default", "displayName": "Sleeping", "role": "sleeping", "tags": [], "frames": [{ "column": 0, "row": 2 }], "frameDurationMs": 300, "loop": true },
        { "id": "happy_default", "displayName": "Happy", "role": "happy", "tags": [], "frames": [{ "column": 0, "row": 3 }], "frameDurationMs": 120, "loop": false, "nextActionId": "idle_default" },
        { "id": "eating_default", "displayName": "Eating", "role": "eating", "tags": [], "frames": [{ "column": 0, "row": 4 }], "frameDurationMs": 120, "loop": false, "nextActionId": "idle_default" },
        { "id": "jumping_default", "displayName": "Jumping", "role": "jumping", "tags": [], "frames": [{ "column": 0, "row": 5 }], "frameDurationMs": 120, "loop": false, "nextActionId": "idle_default" },
        { "id": "dragging_default", "displayName": "Dragging", "role": "dragging", "tags": [], "frames": [{ "column": 0, "row": 6 }], "frameDurationMs": 160, "loop": true },
        { "id": "extra_1", "displayName": "Extra 1", "role": null, "tags": [], "frames": [{ "column": 0, "row": 7 }], "frameDurationMs": 120, "loop": false, "nextActionId": "idle_default" },
        { "id": "extra_2", "displayName": "Extra 2", "role": null, "tags": [], "frames": [{ "column": 0, "row": 8 }], "frameDurationMs": 120, "loop": false, "nextActionId": "idle_default" }
      ]
    }
    """
  }
}

private struct Fixture {
  let rootDirectory: URL
  let store: PetLibraryStore

  func cleanUp() {
    try? FileManager.default.removeItem(at: rootDirectory)
  }

  func writeImportedPet(id: String, manifestBody: Data) throws {
    let folder = store.importedPetsDirectoryURL.appendingPathComponent(id, isDirectory: true)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    let manifestURL = folder.appendingPathComponent(PetLibraryStore.manifestFileName)
    try manifestBody.write(to: manifestURL)
  }

  func writePetdexSourceSidecar(id: String) throws {
    let folder = store.importedPetsDirectoryURL.appendingPathComponent(id, isDirectory: true)
    let sidecarURL = folder.appendingPathComponent(PetdexSourceMetadata.fileName)
    let body = """
    {
      "source": "petdex",
      "petdexId": "\(id)",
      "originalDisplayName": "Legacy Petdex",
      "importedAt": "2026-05-15T00:00:00Z"
    }
    """
    try body.utf8Data.write(to: sidecarURL)
  }
}

private extension String {
  var utf8Data: Data {
    Data(self.utf8)
  }
}
