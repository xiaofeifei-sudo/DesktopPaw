import Foundation
import DesktopPet

func runActionCodableTests() {
    let tests = ActionCodableTests()
    tests.encodeDecodeRoundTripWithRoleAndTags()
    tests.encodeDecodeRoundTripWithoutRoleAndTags()
    tests.roleNullDecodes()
    tests.invalidActionIdInJSONThrows()
    tests.invalidTagInJSONThrows()
    tests.oldJSONDecodesAssetIdNil()
    tests.encodeDecodeRoundTripWithAssetId()
    tests.assetIdNullDecodesAsNil()
}

private struct ActionCodableTests {
    func encodeDecodeRoundTripWithRoleAndTags() {
        let action = Action(
            id: ActionId(rawValue: "happy_default")!,
            displayName: "Happy",
            role: .happy,
            tags: [ActionTag(rawValue: "mood:high")!, ActionTag(rawValue: "after.pet")!],
            frames: [SpriteFrame(column: 0, row: 3), SpriteFrame(column: 1, row: 3)],
            frameDurationMs: 120,
            loop: false,
            nextActionId: ActionId(rawValue: "idle_default")!
        )

        let data: Data
        do {
            data = try JSONEncoder().encode(action)
        } catch {
            fail("encode should succeed; got \(error)")
        }

        let decoded: Action
        do {
            decoded = try JSONDecoder().decode(Action.self, from: data)
        } catch {
            fail("decode should succeed; got \(error)")
        }

        expect(decoded == action, "round-tripped action should equal original")
    }

    func encodeDecodeRoundTripWithoutRoleAndTags() {
        let action = Action(
            id: ActionId(rawValue: "extra_1")!,
            displayName: "Extra 1",
            role: nil,
            tags: [],
            frames: [SpriteFrame(column: 0, row: 7)],
            frameDurationMs: 160,
            loop: true,
            nextActionId: nil
        )

        let data: Data
        do {
            data = try JSONEncoder().encode(action)
        } catch {
            fail("encode without role should succeed; got \(error)")
        }

        let decoded: Action
        do {
            decoded = try JSONDecoder().decode(Action.self, from: data)
        } catch {
            fail("decode without role should succeed; got \(error)")
        }

        expect(decoded == action, "round-trip with nil role and empty tags should equal original")
    }

    func roleNullDecodes() {
        let json = """
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
        """
        do {
            let action = try JSONDecoder().decode(Action.self, from: Data(json.utf8))
            expect(action.role == nil, "role: null should decode to nil")
            expect(action.id.rawValue == "extra_1", "id should decode")
            expect(action.nextActionId?.rawValue == "idle_default", "nextActionId should decode")
        } catch {
            fail("role:null JSON should decode; got \(error)")
        }
    }

    func invalidActionIdInJSONThrows() {
        let json = """
        {
          "id": "INVALID UPPERCASE",
          "displayName": "Bad",
          "role": "idle",
          "tags": [],
          "frames": [{ "column": 0, "row": 0 }],
          "frameDurationMs": 100,
          "loop": true
        }
        """
        do {
            _ = try JSONDecoder().decode(Action.self, from: Data(json.utf8))
            fail("invalid action id should fail to decode")
        } catch {
            // expected
        }
    }

    func invalidTagInJSONThrows() {
        let json = """
        {
          "id": "extra_1",
          "displayName": "Extra",
          "role": null,
          "tags": ["BAD TAG"],
          "frames": [{ "column": 0, "row": 0 }],
          "frameDurationMs": 100,
          "loop": true
        }
        """
        do {
            _ = try JSONDecoder().decode(Action.self, from: Data(json.utf8))
            fail("invalid action tag should fail to decode")
        } catch {
            // expected
        }
    }

    func oldJSONDecodesAssetIdNil() {
        // Simulate old JSON without assetId field
        let json = """
        {
          "id": "idle_default",
          "displayName": "Idle",
          "role": "idle",
          "tags": [],
          "frames": [{ "column": 0, "row": 0 }],
          "frameDurationMs": 160,
          "loop": true
        }
        """
        do {
            let action = try JSONDecoder().decode(Action.self, from: Data(json.utf8))
            expect(action.assetId == nil, "old JSON without assetId should decode to nil")
            expect(action.id.rawValue == "idle_default", "id should decode")
            expect(action.frames.first?.assetId == nil, "frame assetId should be nil")
        } catch {
            fail("old JSON without assetId should decode; got \(error)")
        }
    }

    func encodeDecodeRoundTripWithAssetId() {
        let action = Action(
            id: ActionId(rawValue: "wave_custom")!,
            displayName: "Wave Custom",
            role: nil,
            tags: [],
            assetId: "wave_sheet",
            frames: [
                SpriteFrame(assetId: "wave_sheet", column: 0, row: 0),
                SpriteFrame(assetId: "wave_sheet", column: 1, row: 0)
            ],
            frameDurationMs: 120,
            loop: false,
            nextActionId: ActionId(rawValue: "idle_default")
        )

        let data: Data
        do {
            data = try JSONEncoder().encode(action)
        } catch {
            fail("encode action with assetId should succeed; got \(error)")
        }

        let decoded: Action
        do {
            decoded = try JSONDecoder().decode(Action.self, from: data)
        } catch {
            fail("decode action with assetId should succeed; got \(error)")
        }

        expect(decoded == action, "round-tripped action with assetId should equal original")
        expect(decoded.assetId == "wave_sheet", "assetId should be preserved")
    }

    func assetIdNullDecodesAsNil() {
        let json = """
        {
          "id": "extra_1",
          "displayName": "Extra",
          "role": null,
          "tags": [],
          "assetId": null,
          "frames": [{ "column": 0, "row": 0 }],
          "frameDurationMs": 100,
          "loop": true
        }
        """
        do {
            let action = try JSONDecoder().decode(Action.self, from: Data(json.utf8))
            expect(action.assetId == nil, "null assetId should decode to nil")
        } catch {
            fail("null assetId should decode; got \(error)")
        }
    }
}
