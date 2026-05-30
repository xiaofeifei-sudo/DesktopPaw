import Foundation
import DesktopPet

func runCompanionPreferencesStoreTests() {
    let tests = CompanionPreferencesStoreTests()
    tests.defaultsUseLowPressureCompanionshipSettings()
    tests.preferencesPersistAcrossStoreInstances()
    tests.petNicknamesAreStoredPerPet()
    tests.quietForOneHourAndClearQuietModePersist()
    tests.corruptStoredPreferencesFallbackToDefaults()
}

private struct CompanionPreferencesStoreTests {
    func defaultsUseLowPressureCompanionshipSettings() {
        let harness = CompanionPreferencesHarness()

        let preferences = harness.store.loadPreferences()

        expect(preferences.showRelationshipPrompts, "relationship prompts should default to enabled")
        expect(preferences.petNicknamesByPetId.isEmpty, "pet nicknames should default to empty")
        expect(preferences.userNickname == nil, "user nickname should default to nil")
        expect(preferences.quietUntil == nil, "temporary quiet mode should default to nil")
        expect(preferences.quietHours == nil, "quiet hours should default to nil")
        expect(preferences.microDialogsEnabled, "micro dialogs should default to enabled as an opt-out preference")
    }

    func preferencesPersistAcrossStoreInstances() {
        let harness = CompanionPreferencesHarness()
        let quietUntil = Date(timeIntervalSince1970: 1_779_094_800)
        let quietHours = QuietHours(startMinuteOfDay: 22 * 60, endMinuteOfDay: 8 * 60)
        let preferences = CompanionPreferences(
            showRelationshipPrompts: false,
            petNicknamesByPetId: ["pet-a": "Mochi"],
            userNickname: "Alex",
            quietUntil: quietUntil,
            quietHours: quietHours,
            microDialogsEnabled: false
        )

        harness.store.savePreferences(preferences)
        let nextStore = harness.makeStore()

        expect(nextStore.loadPreferences() == preferences, "companion preferences should persist across store instances")
    }

    func petNicknamesAreStoredPerPet() {
        let harness = CompanionPreferencesHarness()

        harness.store.setPetNickname("Mochi", for: "pet-a")
        harness.store.setPetNickname("Nori", for: "pet-b")
        harness.store.setPetNickname("   ", for: "pet-a")

        let preferences = harness.store.loadPreferences()
        expect(preferences.petNicknamesByPetId["pet-a"] == nil, "blank nickname should remove only that pet nickname")
        expect(preferences.petNicknamesByPetId["pet-b"] == "Nori", "pet-b nickname should remain isolated")
    }

    func quietForOneHourAndClearQuietModePersist() {
        let harness = CompanionPreferencesHarness()
        let now = Date(timeIntervalSince1970: 1_779_091_200)

        harness.store.quietForOneHour(from: now)
        expect(
            harness.store.loadPreferences().quietUntil == now.addingTimeInterval(3_600),
            "quietForOneHour should set quietUntil one hour from now"
        )

        harness.store.clearQuietMode()
        expect(harness.store.loadPreferences().quietUntil == nil, "clearQuietMode should remove temporary quietUntil")
    }

    func corruptStoredPreferencesFallbackToDefaults() {
        let harness = CompanionPreferencesHarness()
        harness.defaults.set(Data("{ not valid json".utf8), forKey: CompanionPreferencesStore.preferencesKey)

        expect(harness.store.loadPreferences() == CompanionPreferences(), "corrupt companion preferences should fall back to defaults")
    }
}

private final class CompanionPreferencesHarness {
    let suiteName: String
    let defaults: UserDefaults
    let store: CompanionPreferencesStore

    init() {
        suiteName = "DesktopPetTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        store = CompanionPreferencesStore(userDefaults: defaults)
    }

    func makeStore() -> CompanionPreferencesStore {
        CompanionPreferencesStore(userDefaults: defaults)
    }
}
