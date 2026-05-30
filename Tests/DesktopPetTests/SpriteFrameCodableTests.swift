import Foundation
import DesktopPet

func runSpriteFrameCodableTests() {
    let tests = SpriteFrameCodableTests()
    tests.roundTripWithAssetId()
    tests.roundTripWithoutAssetId()
    tests.oldJSONDecodesAssetIdNil()
    tests.assetIdPreservedInJSON()
}

private struct SpriteFrameCodableTests {

    func roundTripWithAssetId() {
        let frame = SpriteFrame(assetId: "wave_sheet", column: 2, row: 1, durationMs: 150)

        let data: Data
        do {
            data = try JSONEncoder().encode(frame)
        } catch {
            fail("encode frame with assetId should succeed; got \(error)")
        }

        let decoded: SpriteFrame
        do {
            decoded = try JSONDecoder().decode(SpriteFrame.self, from: data)
        } catch {
            fail("decode frame with assetId should succeed; got \(error)")
        }

        expect(decoded == frame, "round-tripped frame with assetId should equal original")
        expect(decoded.assetId == "wave_sheet", "assetId should be preserved")
    }

    func roundTripWithoutAssetId() {
        let frame = SpriteFrame(column: 0, row: 0)

        let data: Data
        do {
            data = try JSONEncoder().encode(frame)
        } catch {
            fail("encode frame without assetId should succeed; got \(error)")
        }

        let decoded: SpriteFrame
        do {
            decoded = try JSONDecoder().decode(SpriteFrame.self, from: data)
        } catch {
            fail("decode frame without assetId should succeed; got \(error)")
        }

        expect(decoded.assetId == nil, "assetId should be nil when not set")
        expect(decoded.column == 0, "column should be 0")
        expect(decoded.row == 0, "row should be 0")
    }

    func oldJSONDecodesAssetIdNil() {
        // Simulate old JSON that does not contain "assetId"
        let json = """
        { "column": 3, "row": 2 }
        """
        do {
            let frame = try JSONDecoder().decode(SpriteFrame.self, from: Data(json.utf8))
            expect(frame.assetId == nil, "old JSON without assetId should decode to nil")
            expect(frame.column == 3, "column should be 3")
            expect(frame.row == 2, "row should be 2")
            expect(frame.durationMs == nil, "durationMs should be nil")
        } catch {
            fail("old JSON without assetId should decode; got \(error)")
        }
    }

    func assetIdPreservedInJSON() {
        let json = """
        { "assetId": "custom_sheet", "column": 1, "row": 0, "durationMs": 200 }
        """
        do {
            let frame = try JSONDecoder().decode(SpriteFrame.self, from: Data(json.utf8))
            expect(frame.assetId == "custom_sheet", "assetId should decode from JSON")
            expect(frame.durationMs == 200, "durationMs should decode")
        } catch {
            fail("JSON with assetId should decode; got \(error)")
        }
    }
}
