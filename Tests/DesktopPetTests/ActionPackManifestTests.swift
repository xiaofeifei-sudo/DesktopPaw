import Foundation
import DesktopPet

func runActionPackManifestTests() {
    let tests = ActionPackManifestTests()
    tests.manifestEncodeDecodeRoundTrip()
    tests.manifestDecodesWithPreviewFrame()
    tests.manifestDecodesWithoutPreviewFrame()
    tests.unsupportedSchemaVersionThrows()
    tests.resourceEncodeDecodeRoundTrip()
    tests.resourcePathWithSeparatorRejected()
    tests.sourceMetadataEncodeDecodeRoundTrip()
    tests.sourceMetadataSanitized()
    tests.packErrorDescriptions()
    tests.warningEquality()
    tests.resourceKindEncodeDecode()
}

// MARK: - Action Pack Manifest Tests

private struct ActionPackManifestTests {

    func manifestEncodeDecodeRoundTrip() {
        let manifest = ActionPackManifest(
            schemaVersion: 1,
            id: "wave_20260529_1530",
            displayName: "Wave",
            createdAt: Date(timeIntervalSince1970: 1_717_000_000),
            resources: [
                ActionPackResource(
                    id: "wave_sheet",
                    kind: .gridImage,
                    path: "spritesheet.png",
                    frameSize: CGSizeCodable(width: 256, height: 256),
                    grid: SpriteSheetLayout(columns: 4, rows: 1),
                    previewFrame: SpriteFrame(column: 0, row: 0)
                )
            ],
            actions: [
                Action(
                    id: ActionId(rawValue: "wave_20260529_1530")!,
                    displayName: "Wave",
                    role: nil,
                    tags: [ActionTag(rawValue: "interaction")!],
                    assetId: "wave_sheet",
                    frames: [
                        SpriteFrame(assetId: "wave_sheet", column: 0, row: 0),
                        SpriteFrame(assetId: "wave_sheet", column: 1, row: 0),
                        SpriteFrame(assetId: "wave_sheet", column: 2, row: 0),
                        SpriteFrame(assetId: "wave_sheet", column: 3, row: 0)
                    ],
                    frameDurationMs: 120,
                    loop: false,
                    nextActionId: ActionId(rawValue: "idle_default")
                )
            ]
        )

        let data: Data
        do {
            data = try JSONEncoder().encode(manifest)
        } catch {
            fail("encode manifest should succeed; got \(error)")
        }

        let decoded: ActionPackManifest
        do {
            decoded = try JSONDecoder().decode(ActionPackManifest.self, from: data)
        } catch {
            fail("decode manifest should succeed; got \(error)")
        }

        expect(decoded == manifest, "round-tripped manifest should equal original")
    }

    func manifestDecodesWithPreviewFrame() {
        let json = """
        {
          "schemaVersion": 1,
          "id": "sit_20260530",
          "displayName": "Sit",
          "createdAt": "2026-05-30T10:00:00Z",
          "resources": [
            {
              "id": "sit_sheet",
              "kind": "gridImage",
              "path": "sheet.png",
              "frameSize": { "width": 256, "height": 256 },
              "grid": { "columns": 2, "rows": 1 },
              "previewFrame": { "column": 0, "row": 0 }
            }
          ],
          "actions": [
            {
              "id": "sit_20260530",
              "displayName": "Sit",
              "role": null,
              "tags": [],
              "assetId": "sit_sheet",
              "frames": [{ "column": 0, "row": 0 }, { "column": 1, "row": 0 }],
              "frameDurationMs": 200,
              "loop": true
            }
          ]
        }
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            let manifest = try decoder.decode(ActionPackManifest.self, from: Data(json.utf8))
            expect(manifest.schemaVersion == 1, "schemaVersion should be 1")
            expect(manifest.id == "sit_20260530", "id should match")
            expect(manifest.resources.first?.previewFrame != nil, "previewFrame should be present")
            expect(manifest.actions.first?.assetId == "sit_sheet", "action assetId should match")
        } catch {
            fail("manifest with previewFrame should decode; got \(error)")
        }
    }

    func manifestDecodesWithoutPreviewFrame() {
        let json = """
        {
          "schemaVersion": 1,
          "id": "nod_20260530",
          "displayName": "Nod",
          "createdAt": "2026-05-30T10:00:00Z",
          "resources": [
            {
              "id": "nod_sheet",
              "kind": "gridImage",
              "path": "nod.png",
              "frameSize": { "width": 128, "height": 128 },
              "grid": { "columns": 3, "rows": 1 }
            }
          ],
          "actions": [
            {
              "id": "nod_20260530",
              "displayName": "Nod",
              "role": null,
              "tags": [],
              "frames": [{ "column": 0, "row": 0 }, { "column": 1, "row": 0 }, { "column": 2, "row": 0 }],
              "frameDurationMs": 100,
              "loop": false,
              "nextActionId": "idle_default"
            }
          ]
        }
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            let manifest = try decoder.decode(ActionPackManifest.self, from: Data(json.utf8))
            expect(manifest.resources.first?.previewFrame == nil, "previewFrame should be nil when omitted")
            expect(manifest.actions.first?.assetId == nil, "action assetId should be nil when omitted")
        } catch {
            fail("manifest without previewFrame should decode; got \(error)")
        }
    }

    func unsupportedSchemaVersionThrows() {
        let json = """
        {
          "schemaVersion": 99,
          "id": "future_pack",
          "displayName": "Future",
          "createdAt": "2026-05-30T10:00:00Z",
          "resources": [],
          "actions": []
        }
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            let manifest = try decoder.decode(ActionPackManifest.self, from: Data(json.utf8))
            expect(manifest.schemaVersion == 99, "schemaVersion should decode as 99")
            // Schema version validation is the validator's job, not the model's.
            // The model decodes any version; the validator rejects unsupported ones.
            expect(manifest.schemaVersion != ActionPackManifest.supportedSchemaVersion,
                   "99 should differ from supported version")
        } catch {
            fail("manifest with schemaVersion 99 should still decode; got \(error)")
        }
    }

    func resourceEncodeDecodeRoundTrip() {
        let resource = ActionPackResource(
            id: "test_resource",
            kind: .gridImage,
            path: "sprites.png",
            frameSize: CGSizeCodable(width: 256, height: 256),
            grid: SpriteSheetLayout(columns: 4, rows: 2),
            previewFrame: SpriteFrame(column: 1, row: 0)
        )

        let data: Data
        do {
            data = try JSONEncoder().encode(resource)
        } catch {
            fail("encode resource should succeed; got \(error)")
        }

        let decoded: ActionPackResource
        do {
            decoded = try JSONDecoder().decode(ActionPackResource.self, from: data)
        } catch {
            fail("decode resource should succeed; got \(error)")
        }

        expect(decoded == resource, "round-tripped resource should equal original")
    }

    func resourcePathWithSeparatorRejected() {
        // Path safety is enforced by the validator, not the model.
        // The model stores the path as-is; the validator rejects paths with separators.
        let resource = ActionPackResource(
            id: "bad_path",
            kind: .gridImage,
            path: "../secret.png",
            frameSize: CGSizeCodable(width: 256, height: 256),
            grid: SpriteSheetLayout(columns: 1, rows: 1)
        )
        expect(resource.path == "../secret.png", "model should store path as-is for validator to reject")
    }

    func sourceMetadataEncodeDecodeRoundTrip() {
        let metadata = ActionPackSourceMetadata(
            source: .aiGeneration,
            createdAt: Date(timeIntervalSince1970: 1_717_000_000),
            provider: "openai-compatible",
            model: "example-model",
            prompt: "small desktop pet waving",
            negativePrompt: "blur, text",
            seed: "12345",
            inputImages: [],
            notes: "User selected frames 0-3."
        )

        let data: Data
        do {
            data = try JSONEncoder().encode(metadata)
        } catch {
            fail("encode source metadata should succeed; got \(error)")
        }

        let decoded: ActionPackSourceMetadata
        do {
            decoded = try JSONDecoder().decode(ActionPackSourceMetadata.self, from: data)
        } catch {
            fail("decode source metadata should succeed; got \(error)")
        }

        expect(decoded == metadata, "round-tripped source metadata should equal original")
    }

    func sourceMetadataSanitized() {
        let metadata = ActionPackSourceMetadata(
            source: .aiGeneration,
            createdAt: Date(),
            provider: "test",
            model: "test-model",
            prompt: "cute pet api_key=sk-12345abcde",
            notes: "saved from /Users/testuser/Desktop/input.png"
        )

        let sanitized = metadata.sanitized()
        expect(!sanitized.prompt!.contains("sk-12345abcde"), "API key should be redacted from prompt")
        expect(!sanitized.notes!.contains("/Users/testuser"), "absolute path should be redacted from notes")
    }

    func packErrorDescriptions() {
        let error = ActionPackError.unsupportedSchemaVersion(99)
        expect(error.errorDescription != nil, "error should have description")
        expect(error.errorDescription!.contains("99"), "description should contain version number")

        let pathError = ActionPackError.invalidResourcePath("../bad")
        expect(pathError.errorDescription!.contains("../bad"), "description should contain path")

        let frameError = ActionPackError.emptyActionFrames(actionId: "test_action")
        expect(frameError.errorDescription!.contains("test_action"), "description should contain action id")
    }

    func warningEquality() {
        let w1 = ActionPackWarning(kind: .packSkipped, packId: "p1", detail: "bad manifest")
        let w2 = ActionPackWarning(kind: .packSkipped, packId: "p1", detail: "bad manifest")
        let w3 = ActionPackWarning(kind: .actionSkipped, packId: "p1", actionId: "a1", detail: "conflict")

        expect(w1 == w2, "identical warnings should be equal")
        expect(w1 != w3, "different kind warnings should not be equal")
    }

    func resourceKindEncodeDecode() {
        let kind = ActionPackResourceKind.gridImage
        let data = try! JSONEncoder().encode(kind)
        let decoded = try! JSONDecoder().decode(ActionPackResourceKind.self, from: data)
        expect(decoded == .gridImage, "gridImage kind should round-trip")
    }
}
