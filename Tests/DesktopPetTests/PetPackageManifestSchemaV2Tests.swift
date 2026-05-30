import Foundation
import DesktopPet

func runPetPackageManifestSchemaV2Tests() {
    let tests = PetPackageManifestSchemaV2Tests()
    tests.v1FixtureDecodesIntoLegacyAnimations()
    tests.v2FixtureDecodesIntoActions()
    tests.v3FixtureDecodeThrowsUnsupportedSchemaVersion()
    tests.encodeAlwaysProducesSchemaV2WithActions()
    tests.encodeOmitsAnimationsField()
    tests.encodeV1LoadedManifestProducesV2JSON()
    tests.roundTripV2EncodeThenDecodeIsEquivalent()
    tests.unknownTopLevelFieldIsTolerated()
    tests.v2DecodeThenPetDefinitionSucceeds()
}

private struct PetPackageManifestSchemaV2Tests {
    func v1FixtureDecodesIntoLegacyAnimations() {
        let manifest: PetPackageManifest
        do {
            manifest = try JSONDecoder().decode(PetPackageManifest.self, from: v1FixtureJSON)
        } catch {
            fail("v1 fixture should decode; got \(error)")
        }
        expect(manifest.schemaVersion == 1, "v1 manifest should keep schemaVersion=1 after decode")
        expect(manifest.legacyAnimations != nil, "v1 manifest should populate legacyAnimations")
        expect(manifest.legacyAnimations?[.idle]?.frames.first == SpriteFrame(column: 0, row: 0), "v1 legacy animations idle frames should decode")
        expect(manifest.actions.isEmpty, "v1 manifest decode should leave actions empty")
    }

    func v2FixtureDecodesIntoActions() {
        let manifest: PetPackageManifest
        do {
            manifest = try JSONDecoder().decode(PetPackageManifest.self, from: v2FixtureJSON)
        } catch {
            fail("v2 fixture should decode; got \(error)")
        }
        expect(manifest.schemaVersion == 2, "v2 manifest should keep schemaVersion=2 after decode")
        expect(manifest.legacyAnimations == nil, "v2 manifest should not populate legacyAnimations")
        expect(manifest.actions.isEmpty == false, "v2 manifest should have non-empty actions")
        let ids = manifest.actions.map(\.id.rawValue).sorted()
        expect(ids.contains("idle_default"), "v2 manifest should decode idle_default")
        expect(ids.contains("dragging_default"), "v2 manifest should decode dragging_default")
        expect(ids.contains("extra_1"), "v2 manifest should decode extra_1")
    }

    func v3FixtureDecodeThrowsUnsupportedSchemaVersion() {
        do {
            _ = try JSONDecoder().decode(PetPackageManifest.self, from: v3FixtureJSON)
            fail("v3 manifest should fail to decode")
        } catch let ActionCatalogError.unsupportedSchemaVersion(version) {
            expect(version == 3, "should report version 3")
        } catch {
            fail("expected ActionCatalogError.unsupportedSchemaVersion(3); got \(error)")
        }
    }

    func encodeAlwaysProducesSchemaV2WithActions() {
        let manifest: PetPackageManifest
        do {
            manifest = try JSONDecoder().decode(PetPackageManifest.self, from: v2FixtureJSON)
        } catch {
            fail("v2 fixture should decode; got \(error)")
        }
        let encoded: Data
        do {
            encoded = try JSONEncoder().encode(manifest)
        } catch {
            fail("encode should succeed; got \(error)")
        }
        let json = jsonObject(from: encoded)
        expect(json["schemaVersion"] as? Int == 2, "encoded schemaVersion must be 2")
        expect(json["actions"] != nil, "encoded JSON must contain actions field")
    }

    func encodeOmitsAnimationsField() {
        let manifest: PetPackageManifest
        do {
            manifest = try JSONDecoder().decode(PetPackageManifest.self, from: v1FixtureJSON)
        } catch {
            fail("v1 fixture should decode; got \(error)")
        }
        let encoded: Data
        do {
            encoded = try JSONEncoder().encode(manifest)
        } catch {
            fail("encode should succeed; got \(error)")
        }
        let json = jsonObject(from: encoded)
        expect(json["animations"] == nil, "encoded JSON must NOT contain animations field")
    }

    func encodeV1LoadedManifestProducesV2JSON() {
        let manifest: PetPackageManifest
        do {
            manifest = try JSONDecoder().decode(PetPackageManifest.self, from: v1FixtureJSON)
        } catch {
            fail("v1 fixture should decode; got \(error)")
        }
        let encoded: Data
        do {
            encoded = try JSONEncoder().encode(manifest)
        } catch {
            fail("encode should succeed; got \(error)")
        }
        let json = jsonObject(from: encoded)
        expect(json["schemaVersion"] as? Int == 2, "v1-loaded manifest must encode schemaVersion=2")
        guard let actions = json["actions"] as? [[String: Any]] else {
            fail("encoded actions must be a JSON array")
        }
        expect(actions.count == 7, "v1 conversion should yield 7 role actions, got \(actions.count)")
        let ids = actions.compactMap { $0["id"] as? String }.sorted()
        expect(ids.contains("idle_default"), "encoded actions should include idle_default")
        expect(ids.contains("dragging_default"), "encoded actions should include dragging_default")
    }

    func roundTripV2EncodeThenDecodeIsEquivalent() {
        let firstDecode: PetPackageManifest
        do {
            firstDecode = try JSONDecoder().decode(PetPackageManifest.self, from: v2FixtureJSON)
        } catch {
            fail("v2 fixture should decode; got \(error)")
        }
        let encoded: Data
        do {
            encoded = try JSONEncoder().encode(firstDecode)
        } catch {
            fail("encode v2-loaded manifest should succeed; got \(error)")
        }
        let secondDecode: PetPackageManifest
        do {
            secondDecode = try JSONDecoder().decode(PetPackageManifest.self, from: encoded)
        } catch {
            fail("re-decode of encoded v2 manifest should succeed; got \(error)")
        }
        expect(secondDecode.schemaVersion == 2, "re-decoded schemaVersion should be 2")
        expect(secondDecode.actions == firstDecode.actions, "actions should round-trip")
        expect(secondDecode.id == firstDecode.id, "id should round-trip")
    }

    func unknownTopLevelFieldIsTolerated() {
        let json = """
        {
          "schemaVersion": 2,
          "id": "test-pet",
          "displayName": "Test Pet",
          "description": "A test pet.",
          "asset": "spritesheet.png",
          "frameSize": { "width": 128, "height": 128 },
          "spritesheet": { "columns": 2, "rows": 7 },
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
              "id": "dragging_default",
              "displayName": "Drag",
              "role": "dragging",
              "tags": [],
              "frames": [{ "column": 0, "row": 6 }],
              "frameDurationMs": 120,
              "loop": true
            }
          ],
          "futureField": { "key": "value" }
        }
        """
        do {
            let manifest = try JSONDecoder().decode(PetPackageManifest.self, from: Data(json.utf8))
            expect(manifest.schemaVersion == 2, "manifest with unknown field should still decode v2")
            expect(manifest.actions.count == 2, "manifest with unknown field should retain actions")
        } catch {
            fail("unknown top-level fields should be tolerated; got \(error)")
        }
    }

    func v2DecodeThenPetDefinitionSucceeds() {
        let manifest: PetPackageManifest
        do {
            manifest = try JSONDecoder().decode(PetPackageManifest.self, from: v2FixtureJSON)
        } catch {
            fail("v2 fixture should decode; got \(error)")
        }
        do {
            let definition = try manifest.petDefinition()
            expect(definition.id == manifest.id, "definition id should match manifest id")
            expect(definition.animations.count == PetState.allCases.count, "definition should have animations for all required states (\(definition.animations.count))")
            expect(definition.animations[.idle] != nil, "definition should expose idle clip")
            expect(definition.animations[.dragging] != nil, "definition should expose dragging clip")
        } catch {
            fail("petDefinition() should succeed for valid v2 manifest; got \(error)")
        }
    }

    private func jsonObject(from data: Data) -> [String: Any] {
        do {
            guard let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                fail("encoded payload should be a JSON object")
            }
            return dict
        } catch {
            fail("JSON deserialization failed: \(error)")
        }
    }

    private var v1FixtureJSON: Data {
        Data(
            """
            {
              "schemaVersion": 1,
              "id": "test-pet",
              "displayName": "Test Pet",
              "description": "A test pet.",
              "asset": "spritesheet.png",
              "preview": "preview.png",
              "frameSize": { "width": 128, "height": 128 },
              "spritesheet": { "columns": 2, "rows": 7 },
              "defaultScale": 1.0,
              "animations": {
                "idle": {
                  "frames": [{ "column": 0, "row": 0 }, { "column": 1, "row": 0 }],
                  "frameDurationMs": 160,
                  "loop": true
                },
                "walking": {
                  "frames": [{ "column": 0, "row": 1 }],
                  "frameDurationMs": 160,
                  "loop": true
                },
                "sleeping": {
                  "frames": [{ "column": 0, "row": 2 }],
                  "frameDurationMs": 160,
                  "loop": true
                },
                "happy": {
                  "frames": [{ "column": 0, "row": 3 }],
                  "frameDurationMs": 120,
                  "loop": false,
                  "nextState": "idle"
                },
                "eating": {
                  "frames": [{ "column": 0, "row": 4 }],
                  "frameDurationMs": 120,
                  "loop": false,
                  "nextState": "idle"
                },
                "jumping": {
                  "frames": [{ "column": 0, "row": 5 }],
                  "frameDurationMs": 120,
                  "loop": false,
                  "nextState": "idle"
                },
                "dragging": {
                  "frames": [{ "column": 0, "row": 6 }],
                  "frameDurationMs": 120,
                  "loop": true
                }
              }
            }
            """.utf8
        )
    }

    private var v2FixtureJSON: Data {
        Data(
            """
            {
              "schemaVersion": 2,
              "id": "test-pet",
              "displayName": "Test Pet",
              "description": "A test pet.",
              "asset": "spritesheet.png",
              "preview": "preview.png",
              "frameSize": { "width": 128, "height": 128 },
              "spritesheet": { "columns": 2, "rows": 8 },
              "defaultScale": 1.0,
              "actions": [
                {
                  "id": "idle_default",
                  "displayName": "Idle",
                  "role": "idle",
                  "tags": [],
                  "frames": [{ "column": 0, "row": 0 }, { "column": 1, "row": 0 }],
                  "frameDurationMs": 160,
                  "loop": true
                },
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
                  "id": "sleeping_default",
                  "displayName": "Sleeping",
                  "role": "sleeping",
                  "tags": [],
                  "frames": [{ "column": 0, "row": 2 }],
                  "frameDurationMs": 160,
                  "loop": true
                },
                {
                  "id": "happy_default",
                  "displayName": "Happy",
                  "role": "happy",
                  "tags": [],
                  "frames": [{ "column": 0, "row": 3 }],
                  "frameDurationMs": 120,
                  "loop": false,
                  "nextActionId": "idle_default"
                },
                {
                  "id": "eating_default",
                  "displayName": "Eating",
                  "role": "eating",
                  "tags": [],
                  "frames": [{ "column": 0, "row": 4 }],
                  "frameDurationMs": 120,
                  "loop": false,
                  "nextActionId": "idle_default"
                },
                {
                  "id": "jumping_default",
                  "displayName": "Jumping",
                  "role": "jumping",
                  "tags": [],
                  "frames": [{ "column": 0, "row": 5 }],
                  "frameDurationMs": 120,
                  "loop": false,
                  "nextActionId": "idle_default"
                },
                {
                  "id": "dragging_default",
                  "displayName": "Dragging",
                  "role": "dragging",
                  "tags": [],
                  "frames": [{ "column": 0, "row": 6 }],
                  "frameDurationMs": 120,
                  "loop": true
                },
                {
                  "id": "extra_1",
                  "displayName": "Extra 1",
                  "role": null,
                  "tags": [],
                  "frames": [{ "column": 0, "row": 7 }],
                  "frameDurationMs": 120,
                  "loop": false,
                  "nextActionId": "idle_default"
                }
              ]
            }
            """.utf8
        )
    }

    private var v3FixtureJSON: Data {
        Data(
            """
            {
              "schemaVersion": 3,
              "id": "test-pet",
              "displayName": "Test Pet",
              "description": "A test pet.",
              "asset": "spritesheet.png",
              "frameSize": { "width": 128, "height": 128 },
              "spritesheet": { "columns": 2, "rows": 7 },
              "defaultScale": 1.0,
              "actions": []
            }
            """.utf8
        )
    }
}
