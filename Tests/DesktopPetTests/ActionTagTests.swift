import Foundation
import DesktopPet

func runActionTagTests() {
    let tests = ActionTagTests()
    tests.validTagsAreAccepted()
    tests.invalidTagsAreRejected()
    tests.reservedPrefixesAreParsed()
    tests.nonReservedTagsKeepValueWithoutReservedPrefix()
    tests.codableRoundTripUsesSingleString()
}

private struct ActionTagTests {
    func validTagsAreAccepted() {
        let valid = [
            "mood:high",
            "after.click",
            "time.morning",
            "vibe:cozy",
            "season.winter"
        ]

        for rawValue in valid {
            expect(ActionTag(rawValue: rawValue)?.rawValue == rawValue, "expected \(rawValue) to be a valid ActionTag")
        }
    }

    func invalidTagsAreRejected() {
        let invalid = [
            "",
            "Mood:high",
            "has space",
            "after/click",
            String(repeating: "a", count: 65),
            "心情"
        ]

        for rawValue in invalid {
            expect(ActionTag(rawValue: rawValue) == nil, "expected \(rawValue) to be rejected as ActionTag")
        }
    }

    func reservedPrefixesAreParsed() {
        assertTag("mood:high", prefix: .mood, value: "high")
        assertTag("mood:any", prefix: .mood, value: "any")
        assertTag("after.click", prefix: .after, value: "click")
        assertTag("after.feed", prefix: .after, value: "feed")
        assertTag("time.morning", prefix: .time, value: "morning")
        assertTag("time.weekend", prefix: .time, value: "weekend")
    }

    func nonReservedTagsKeepValueWithoutReservedPrefix() {
        assertTag("vibe:cozy", prefix: nil, value: "cozy")
        assertTag("season.winter", prefix: nil, value: "winter")
        assertTag("scene.work", prefix: nil, value: "work")

        let plain = ActionTag(rawValue: "plain")!
        expect(plain.prefix == nil, "plain tag should not have a reserved prefix")
        expect(plain.value == nil, "plain tag should not have a parsed value")
    }

    func codableRoundTripUsesSingleString() {
        let tag = ActionTag(rawValue: "time.morning")!
        let encoded: Data

        do {
            encoded = try JSONEncoder().encode(tag)
        } catch {
            fail("Expected ActionTag to encode: \(error)")
        }

        expect(String(data: encoded, encoding: .utf8) == "\"time.morning\"", "ActionTag should encode as a single string")

        do {
            let decoded = try JSONDecoder().decode(ActionTag.self, from: encoded)
            expect(decoded == tag, "ActionTag should decode from its encoded string")
        } catch {
            fail("Expected ActionTag to decode: \(error)")
        }
    }

    private func assertTag(_ rawValue: String, prefix: ActionTagPrefix?, value: String?) {
        let tag = ActionTag(rawValue: rawValue)
        expect(tag != nil, "expected \(rawValue) to be a valid ActionTag")
        expect(tag?.prefix == prefix, "expected \(rawValue) prefix to be \(String(describing: prefix))")
        expect(tag?.value == value, "expected \(rawValue) value to be \(String(describing: value))")
    }
}
