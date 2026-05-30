import Foundation
import DesktopPet

func runBubbleProfileTests() {
    let tests = BubbleProfileTests()
    tests.defaultProfileCoversInteractionTriggers()
    tests.defaultProfileCoversStateTriggers()
    tests.defaultProfileHasReasonableTimings()
    tests.profileEncodesAndDecodes()
    tests.unknownTriggerInDecodingThrows()
    tests.phraseLookupReturnsEmptyForMissingTrigger()
}

private struct BubbleProfileTests {
    func defaultProfileCoversInteractionTriggers() {
        let profile = BubbleProfileDefaults.defaultProfile()
        for trigger in [BubbleTrigger.clicked, .pet, .feed] {
            let phrases = profile.phrases(for: trigger)
            expect(!phrases.isEmpty, "default profile must provide phrases for \(trigger.rawValue)")
        }
    }

    func defaultProfileCoversStateTriggers() {
        let profile = BubbleProfileDefaults.defaultProfile()
        for trigger in [BubbleTrigger.hungry, .tired, .happy, .idle, .walking, .sleeping] {
            let phrases = profile.phrases(for: trigger)
            expect(!phrases.isEmpty, "default profile must provide phrases for \(trigger.rawValue)")
        }
    }

    func defaultProfileHasReasonableTimings() {
        let profile = BubbleProfileDefaults.defaultProfile()
        expect(profile.minimumIntervalSeconds >= 30, "default minimum interval should not flood the user")
        expect(profile.displayDurationSeconds >= 2 && profile.displayDurationSeconds <= 6, "default display duration should remain in user-friendly range")
    }

    func profileEncodesAndDecodes() {
        let original = BubbleProfileDefaults.defaultProfile()
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        do {
            let data = try encoder.encode(original)
            let decoded = try decoder.decode(BubbleProfile.self, from: data)
            expect(decoded == original, "bubble profile round-trip should preserve data")
        } catch {
            fail("bubble profile round-trip failed: \(error)")
        }
    }

    func unknownTriggerInDecodingThrows() {
        let json = """
        {
          "minimumIntervalSeconds": 60,
          "displayDurationSeconds": 3,
          "phrases": {
            "totally_invalid": ["nope"]
          }
        }
        """
        do {
            _ = try JSONDecoder().decode(BubbleProfile.self, from: Data(json.utf8))
            fail("decoding should fail for unknown bubble trigger")
        } catch {
        }
    }

    func phraseLookupReturnsEmptyForMissingTrigger() {
        let profile = BubbleProfile(
            phrases: [.clicked: ["hi"]],
            minimumIntervalSeconds: 60,
            displayDurationSeconds: 3
        )
        expect(profile.phrases(for: .hungry).isEmpty, "missing trigger should return empty phrase list")
        expect(profile.phrases(for: .clicked) == ["hi"], "existing trigger should return its phrases")
    }
}
