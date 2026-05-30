import Foundation
import DesktopPet

func runManifestRewriterTests() {
    let tests = ManifestRewriterTests()
    tests.rewritesV1ManifestToV2PreservingFieldsAndGeneratingActions()
    tests.v2ManifestIsLeftUnchanged()
}

private struct ManifestRewriterTests {
    func rewritesV1ManifestToV2PreservingFieldsAndGeneratingActions() {
        let fixture = makeFixture()
        defer { fixture.cleanUp() }

        let manifestURL = fixture.manifestURL
        let originalData = schemaV1ManifestJSON(id: "rewrite-v1").utf8Data
        do {
            try fixture.writeManifest(originalData)
        } catch {
            fail("failed to seed v1 manifest: \(error)")
        }

        let originalManifest: PetPackageManifest
        do {
            originalManifest = try JSONDecoder().decode(PetPackageManifest.self, from: originalData)
        } catch {
            fail("seeded v1 manifest should decode: \(error)")
        }

        do {
            let didRewrite = try ManifestRewriter().rewriteV1ManifestToV2(at: manifestURL)
            expect(didRewrite, "rewriter should report rewriting a v1 manifest")
        } catch {
            fail("rewriter should upgrade v1 manifest: \(error)")
        }

        let rewrittenData: Data
        do {
            rewrittenData = try Data(contentsOf: manifestURL)
        } catch {
            fail("rewritten manifest should be readable: \(error)")
        }

        let rewrittenManifest: PetPackageManifest
        do {
            rewrittenManifest = try JSONDecoder().decode(PetPackageManifest.self, from: rewrittenData)
        } catch {
            fail("rewritten manifest should decode as v2: \(error)")
        }

        expect(rewrittenManifest.schemaVersion == 2, "rewritten manifest should have schemaVersion=2")
        expect(rewrittenManifest.legacyAnimations == nil, "rewritten manifest should not keep legacy animations")
        expect(rewrittenManifest.actions.count == PetState.allCases.count, "rewritten manifest should generate one action per legacy state")
        expect(rewrittenManifest.id == originalManifest.id, "rewriter should preserve id")
        expect(rewrittenManifest.displayName == originalManifest.displayName, "rewriter should preserve displayName")
        expect(rewrittenManifest.description == originalManifest.description, "rewriter should preserve description")
        expect(rewrittenManifest.asset == originalManifest.asset, "rewriter should preserve asset")
        expect(rewrittenManifest.preview == originalManifest.preview, "rewriter should preserve preview")
        expect(rewrittenManifest.assetKind == originalManifest.assetKind, "rewriter should preserve assetKind")
        expect(rewrittenManifest.frameSize == originalManifest.frameSize, "rewriter should preserve frameSize")
        expect(rewrittenManifest.spritesheet == originalManifest.spritesheet, "rewriter should preserve spritesheet")
        expect(rewrittenManifest.defaultScale == originalManifest.defaultScale, "rewriter should preserve defaultScale")
        expect(rewrittenManifest.motionProfile == originalManifest.motionProfile, "rewriter should preserve motionProfile")
        expect(rewrittenManifest.bubbleProfile == originalManifest.bubbleProfile, "rewriter should preserve bubbleProfile")

        let actionsByRole = Dictionary(uniqueKeysWithValues: rewrittenManifest.actions.compactMap { action in
            action.role.map { ($0, action) }
        })
        expect(actionsByRole[.idle]?.id == ActionId(rawValue: "idle_default"), "idle action should use legacy default id")
        expect(actionsByRole[.walking]?.id == ActionId(rawValue: "walking_default"), "walking action should use legacy default id")
        expect(actionsByRole[.happy]?.nextActionId == ActionId(rawValue: "idle_default"), "nextState should become nextActionId")
        expect(actionsByRole[.idle]?.frames == originalManifest.legacyAnimations?[.idle]?.frames, "idle frames should be preserved")
        expect(actionsByRole[.dragging]?.loop == originalManifest.legacyAnimations?[.dragging]?.loop, "dragging loop should be preserved")

        let json = jsonObject(from: rewrittenData)
        expect(json["schemaVersion"] as? Int == 2, "rewritten JSON should encode schemaVersion=2")
        expect(json.keys.contains("actions"), "rewritten JSON should include actions")
        expect(!json.keys.contains("animations"), "rewritten JSON should omit legacy animations")
    }

    func v2ManifestIsLeftUnchanged() {
        let fixture = makeFixture()
        defer { fixture.cleanUp() }

        let originalData = schemaV2ManifestJSON(id: "rewrite-v2").utf8Data
        do {
            try fixture.writeManifest(originalData)
        } catch {
            fail("failed to seed v2 manifest: \(error)")
        }

        do {
            let didRewrite = try ManifestRewriter().rewriteV1ManifestToV2(at: fixture.manifestURL)
            expect(!didRewrite, "rewriter should no-op for v2 manifest")
        } catch {
            fail("rewriter should not fail for v2 manifest: \(error)")
        }

        do {
            let afterData = try Data(contentsOf: fixture.manifestURL)
            expect(afterData == originalData, "v2 manifest bytes should remain unchanged")
        } catch {
            fail("v2 manifest should remain readable: \(error)")
        }
    }

    private func makeFixture() -> ManifestRewriterFixture {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("ManifestRewriterTests-\(UUID().uuidString)", isDirectory: true)
        let manifestURL = root.appendingPathComponent(PetLibraryStore.manifestFileName, isDirectory: false)
        return ManifestRewriterFixture(rootDirectory: root, manifestURL: manifestURL)
    }

    private func jsonObject(from data: Data) -> [String: Any] {
        do {
            guard let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                fail("manifest JSON should be a dictionary")
            }
            return dict
        } catch {
            fail("manifest JSON should parse: \(error)")
        }
    }
}

private struct ManifestRewriterFixture {
    let rootDirectory: URL
    let manifestURL: URL

    func writeManifest(_ data: Data) throws {
        try FileManager.default.createDirectory(at: rootDirectory, withIntermediateDirectories: true)
        try data.write(to: manifestURL)
    }

    func cleanUp() {
        try? FileManager.default.removeItem(at: rootDirectory)
    }
}

private func schemaV1ManifestJSON(id: String) -> String {
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

private func schemaV2ManifestJSON(id: String) -> String {
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
