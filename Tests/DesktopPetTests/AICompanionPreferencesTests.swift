import Foundation
import DesktopPet

func runAICompanionPreferencesTests() {
    let tests = AICompanionPreferencesTests()
    tests.testDefaultValues()
    tests.testCustomValues()
    tests.testCodableRoundTrip()
    tests.testEquality()
    tests.testMutation()
}

private struct AICompanionPreferencesTests {
    func testDefaultValues() {
        let prefs = AICompanionPreferences()
        expect(!prefs.isAIEnabled, "AI should be disabled by default")
        expect(prefs.isMemoryEnabled, "Memory should be enabled by default")
        expect(prefs.selectedProviderId == nil, "Provider should be nil by default")
        expect(prefs.selectedPersonalityId == AIPersonalityProfile.defaultProfileId, "Personality should default to gentle")
        expect(!prefs.allowInitiativeBubble, "Initiative bubble should be off by default")
        expect(prefs.initiativeBubbleMinInterval == 1800, "Initiative bubble interval should be 1800")
        expect(prefs.showAIReminderOnStartup, "Startup reminder should be on by default")
    }

    func testCustomValues() {
        let prefs = AICompanionPreferences(
            isAIEnabled: true,
            isMemoryEnabled: false,
            selectedProviderId: "http-openai",
            selectedPersonalityId: "built-in-lively",
            allowInitiativeBubble: true,
            initiativeBubbleMinInterval: 600,
            showAIReminderOnStartup: false
        )
        expect(prefs.isAIEnabled, "AI should be enabled")
        expect(!prefs.isMemoryEnabled, "Memory should be disabled")
        expect(prefs.selectedProviderId == "http-openai", "Provider should match")
        expect(prefs.selectedPersonalityId == "built-in-lively", "Personality should match")
        expect(prefs.allowInitiativeBubble, "Initiative bubble should be on")
        expect(prefs.initiativeBubbleMinInterval == 600, "Interval should be 600")
        expect(!prefs.showAIReminderOnStartup, "Startup reminder should be off")
    }

    func testCodableRoundTrip() {
        let prefs = AICompanionPreferences(
            isAIEnabled: true,
            isMemoryEnabled: true,
            selectedProviderId: "test-provider",
            selectedPersonalityId: "built-in-playful",
            allowInitiativeBubble: true,
            initiativeBubbleMinInterval: 900,
            showAIReminderOnStartup: false
        )

        let encoder = JSONEncoder()
        let data = try! encoder.encode(prefs)
        let decoder = JSONDecoder()
        let decoded = try! decoder.decode(AICompanionPreferences.self, from: data)

        expect(decoded == prefs, "Decoded preferences should equal original")
        expect(decoded.isAIEnabled == prefs.isAIEnabled, "isAIEnabled should match")
        expect(decoded.selectedProviderId == prefs.selectedProviderId, "selectedProviderId should match")
        expect(decoded.selectedPersonalityId == prefs.selectedPersonalityId, "selectedPersonalityId should match")
    }

    func testEquality() {
        let a = AICompanionPreferences()
        let b = AICompanionPreferences()
        expect(a == b, "Two default preferences should be equal")

        let c = AICompanionPreferences(isAIEnabled: true)
        expect(a != c, "Modified preferences should not be equal to default")
    }

    func testMutation() {
        var prefs = AICompanionPreferences()
        expect(!prefs.isAIEnabled, "Should start disabled")

        prefs.isAIEnabled = true
        expect(prefs.isAIEnabled, "Should be enabled after mutation")

        prefs.selectedPersonalityId = "built-in-quiet"
        expect(prefs.selectedPersonalityId == "built-in-quiet", "Personality should be updated")
    }
}
