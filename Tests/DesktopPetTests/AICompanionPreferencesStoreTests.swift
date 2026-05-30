import Foundation
import DesktopPet

@MainActor
func runAICompanionPreferencesStoreTests() {
    let tests = AICompanionPreferencesStoreTests()
    tests.testLoadDefaultPreferences()
    tests.testSaveAndLoad()
    tests.testSetAIEnabled()
    tests.testSetMemoryEnabled()
    tests.testSetSelectedProviderId()
    tests.testSetSelectedPersonalityId()
    tests.testSetAllowInitiativeBubble()
    tests.testSetInitiativeBubbleMinInterval()
    tests.testLoadReturnsDefaultOnCorruptData()
}

@MainActor
private struct AICompanionPreferencesStoreTests {
    private func makeStore() -> AICompanionPreferencesStore {
        let defaults = UserDefaults(suiteName: "test-ai-prefs-\(UUID().uuidString)")!
        return AICompanionPreferencesStore(userDefaults: defaults)
    }

    func testLoadDefaultPreferences() {
        let store = makeStore()
        let prefs = store.loadPreferences()
        expect(!prefs.isAIEnabled, "AI should be disabled by default")
        expect(prefs.isMemoryEnabled, "Memory should be enabled by default")
        expect(prefs.selectedProviderId == nil, "Provider should be nil by default")
    }

    func testSaveAndLoad() {
        let store = makeStore()
        let prefs = AICompanionPreferences(
            isAIEnabled: true,
            selectedProviderId: "test-provider",
            selectedPersonalityId: "built-in-lively"
        )
        store.savePreferences(prefs)

        let loaded = store.loadPreferences()
        expect(loaded == prefs, "Loaded preferences should match saved")
        expect(loaded.isAIEnabled, "isAIEnabled should be true")
        expect(loaded.selectedProviderId == "test-provider", "selectedProviderId should match")
        expect(loaded.selectedPersonalityId == "built-in-lively", "selectedPersonalityId should match")
    }

    func testSetAIEnabled() {
        let store = makeStore()
        store.setAIEnabled(true)
        let prefs = store.loadPreferences()
        expect(prefs.isAIEnabled, "AI should be enabled after setAIEnabled(true)")

        store.setAIEnabled(false)
        let prefs2 = store.loadPreferences()
        expect(!prefs2.isAIEnabled, "AI should be disabled after setAIEnabled(false)")
    }

    func testSetMemoryEnabled() {
        let store = makeStore()
        store.setMemoryEnabled(false)
        let prefs = store.loadPreferences()
        expect(!prefs.isMemoryEnabled, "Memory should be disabled after setMemoryEnabled(false)")

        store.setMemoryEnabled(true)
        let prefs2 = store.loadPreferences()
        expect(prefs2.isMemoryEnabled, "Memory should be enabled after setMemoryEnabled(true)")
    }

    func testSetSelectedProviderId() {
        let store = makeStore()
        store.setSelectedProviderId("http-openai")
        let prefs = store.loadPreferences()
        expect(prefs.selectedProviderId == "http-openai", "Provider should be updated")

        store.setSelectedProviderId(nil)
        let prefs2 = store.loadPreferences()
        expect(prefs2.selectedProviderId == nil, "Provider should be nil after set to nil")
    }

    func testSetSelectedPersonalityId() {
        let store = makeStore()
        store.setSelectedPersonalityId("built-in-playful")
        let prefs = store.loadPreferences()
        expect(prefs.selectedPersonalityId == "built-in-playful", "Personality should be updated")
    }

    func testSetAllowInitiativeBubble() {
        let store = makeStore()
        store.setAllowInitiativeBubble(true)
        let prefs = store.loadPreferences()
        expect(prefs.allowInitiativeBubble, "Initiative bubble should be enabled")

        store.setAllowInitiativeBubble(false)
        let prefs2 = store.loadPreferences()
        expect(!prefs2.allowInitiativeBubble, "Initiative bubble should be disabled")
    }

    func testSetInitiativeBubbleMinInterval() {
        let store = makeStore()
        store.setInitiativeBubbleMinInterval(600)
        let prefs = store.loadPreferences()
        expect(prefs.initiativeBubbleMinInterval == 600, "Interval should be 600")
    }

    func testLoadReturnsDefaultOnCorruptData() {
        let defaults = UserDefaults(suiteName: "test-ai-prefs-corrupt-\(UUID().uuidString)")!
        defaults.set(Data("not valid json".utf8), forKey: AICompanionPreferencesStore.preferencesKey)
        let store = AICompanionPreferencesStore(userDefaults: defaults)
        let prefs = store.loadPreferences()
        expect(!prefs.isAIEnabled, "Should return defaults on corrupt data")
    }
}
