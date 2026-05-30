import Foundation
import DesktopPet

func runPetPackageManifestTests() {
    let tests = PetPackageManifestTests()
    tests.manifestJSONCanBeDecoded()
    tests.missingRequiredFieldThrows()
    tests.unknownAnimationStateThrows()
}

private struct PetPackageManifestTests {
    func manifestJSONCanBeDecoded() {
        let manifest: PetPackageManifest
        do {
            manifest = try JSONDecoder().decode(PetPackageManifest.self, from: validManifestData)
        } catch {
            fail("Expected valid manifest to decode: \(error)")
        }

        expect(manifest.schemaVersion == 1, "manifest schema version should decode")
        expect(manifest.id == "test-pet", "manifest id should decode")
        expect(manifest.animations[.idle]?.frames.first == SpriteFrame(column: 0, row: 0), "idle frames should decode")
        expect(manifest.animations[.jumping]?.nextState == .idle, "next state should decode")
    }

    func missingRequiredFieldThrows() {
        let json = """
        {
          "schemaVersion": 1,
          "id": "test-pet"
        }
        """

        expectDecodeFailure(json)
    }

    func unknownAnimationStateThrows() {
        let json = """
        {
          "schemaVersion": 1,
          "id": "test-pet",
          "displayName": "Test Pet",
          "description": "A test pet.",
          "asset": "spritesheet.png",
          "preview": "preview.png",
          "frameSize": { "width": 128, "height": 128 },
          "spritesheet": { "columns": 2, "rows": 2 },
          "defaultScale": 1.0,
          "animations": {
            "unknown": {
              "frames": [{ "column": 0, "row": 0 }],
              "frameDurationMs": 100,
              "loop": true
            }
          }
        }
        """

        expectDecodeFailure(json)
    }

    private func expectDecodeFailure(_ json: String) {
        do {
            _ = try JSONDecoder().decode(PetPackageManifest.self, from: Data(json.utf8))
            fail("Expected manifest decoding to fail.")
        } catch {
        }
    }

    private var validManifestData: Data {
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
}
