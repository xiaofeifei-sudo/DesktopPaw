import Foundation
import DesktopPet

func runActionIdTests() {
    let tests = ActionIdTests()
    tests.validIdsAreAccepted()
    tests.invalidIdsAreRejected()
    tests.codableRoundTripUsesSingleString()
}

private struct ActionIdTests {
    func validIdsAreAccepted() {
        let valid = [
            "idle_default",
            "extra_1",
            "walk.fast",
            "after:click",
            "a-b.c_d:0"
        ]

        for rawValue in valid {
            expect(ActionId(rawValue: rawValue)?.rawValue == rawValue, "expected \(rawValue) to be a valid ActionId")
        }

        expect(ActionId.idle.rawValue == "idle_default", "idle ActionId should use schema v2 default id")
    }

    func invalidIdsAreRejected() {
        let invalid = [
            "",
            "Hello",
            "has space",
            "a/b",
            String(repeating: "a", count: 65),
            "猫"
        ]

        for rawValue in invalid {
            expect(ActionId(rawValue: rawValue) == nil, "expected \(rawValue) to be rejected as ActionId")
        }
    }

    func codableRoundTripUsesSingleString() {
        let id = ActionId(rawValue: "extra_1")!
        let encoded: Data

        do {
            encoded = try JSONEncoder().encode(id)
        } catch {
            fail("Expected ActionId to encode: \(error)")
        }

        expect(String(data: encoded, encoding: .utf8) == "\"extra_1\"", "ActionId should encode as a single string")

        do {
            let decoded = try JSONDecoder().decode(ActionId.self, from: encoded)
            expect(decoded == id, "ActionId should decode from its encoded string")
        } catch {
            fail("Expected ActionId to decode: \(error)")
        }
    }
}
