import Foundation
import DesktopPet

@MainActor
func runPreferencesStoreCustomPetTests() {
    let tests = PreferencesStoreCustomPetTests()
    tests.bubbleSettingsUseDefaultsOnFirstLaunch()
    tests.bubbleSettingsPersistAcrossInstances()
    tests.invalidBubbleFrequencyFallsBackToNormal()
    tests.bubbleFrequencyAcceptsAllKnownValues()
    tests.dynamicKnownPetIdsAcceptImportedPet()
    tests.removingCurrentPetFallsBackToBuiltIn()
    tests.unknownAssignedImportedPetFallsBack()
}

@MainActor
private struct PreferencesStoreCustomPetTests {
    func bubbleSettingsUseDefaultsOnFirstLaunch() {
        let harness = CustomPetPreferencesHarness()

        expect(harness.store.isSpeechBubbleEnabled, "speech bubble should default to enabled")
        expect(harness.store.bubbleFrequency == .normal, "bubble frequency should default to normal")
    }

    func bubbleSettingsPersistAcrossInstances() {
        let harness = CustomPetPreferencesHarness()
        harness.store.isSpeechBubbleEnabled = false
        harness.store.bubbleFrequency = .expressive

        let next = harness.makeStore()
        expect(!next.isSpeechBubbleEnabled, "isSpeechBubbleEnabled should persist")
        expect(next.bubbleFrequency == .expressive, "bubbleFrequency should persist")
    }

    func invalidBubbleFrequencyFallsBackToNormal() {
        let harness = CustomPetPreferencesHarness()
        harness.defaults.set("ultra", forKey: PreferenceKeys.bubbleFrequency)

        expect(harness.store.bubbleFrequency == .normal, "invalid bubble frequency should fall back to normal")
        expect(
            harness.defaults.string(forKey: PreferenceKeys.bubbleFrequency) == BubbleFrequency.normal.rawValue,
            "fallback bubble frequency should be written back"
        )
    }

    func bubbleFrequencyAcceptsAllKnownValues() {
        let harness = CustomPetPreferencesHarness()
        for value in BubbleFrequency.allCases {
            harness.store.bubbleFrequency = value
            expect(harness.store.bubbleFrequency == value, "bubble frequency \(value.rawValue) should round-trip")
        }
    }

    func dynamicKnownPetIdsAcceptImportedPet() {
        let library = MutableLibrary(initialIds: ["starter-pet"])
        let harness = CustomPetPreferencesHarness(library: library)

        harness.store.selectedPetId = "imported-1"
        expect(harness.store.selectedPetId == "starter-pet", "unknown imported pet should fall back before registration")

        library.add("imported-1")
        harness.store.selectedPetId = "imported-1"
        expect(harness.store.selectedPetId == "imported-1", "imported pet should be selectable after registration")
    }

    func removingCurrentPetFallsBackToBuiltIn() {
        let library = MutableLibrary(initialIds: ["starter-pet", "imported-1"])
        let harness = CustomPetPreferencesHarness(library: library)
        harness.store.selectedPetId = "imported-1"
        expect(harness.store.selectedPetId == "imported-1", "imported pet should be selected before deletion")

        library.remove("imported-1")
        expect(harness.store.selectedPetId == "starter-pet", "deleted pet should fall back to built-in pet")
        expect(
            harness.defaults.string(forKey: PreferenceKeys.selectedPetId) == "starter-pet",
            "fallback should be written back to defaults"
        )
    }

    func unknownAssignedImportedPetFallsBack() {
        let library = MutableLibrary(initialIds: ["starter-pet", "imported-1"])
        let harness = CustomPetPreferencesHarness(library: library)

        harness.store.selectedPetId = "ghost"
        expect(harness.store.selectedPetId == "starter-pet", "unknown assigned id should fall back at write time")
        expect(
            harness.defaults.string(forKey: PreferenceKeys.selectedPetId) == "starter-pet",
            "unknown assigned id fallback should be persisted"
        )
    }
}

@MainActor
private final class MutableLibrary {
    private var ids: Set<String>

    init(initialIds: Set<String>) {
        self.ids = initialIds
    }

    func snapshot() -> Set<String> {
        ids
    }

    func add(_ id: String) {
        ids.insert(id)
    }

    func remove(_ id: String) {
        ids.remove(id)
    }
}

@MainActor
private final class CustomPetPreferencesHarness {
    let suiteName: String
    let defaults: UserDefaults
    let store: PreferencesStore
    private let library: MutableLibrary

    init(library: MutableLibrary = MutableLibrary(initialIds: ["starter-pet"])) {
        suiteName = "DesktopPetTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        self.library = library
        self.store = Self.makeStore(defaults: defaults, library: library)
    }

    func makeStore() -> PreferencesStore {
        Self.makeStore(defaults: defaults, library: library)
    }

    private static func makeStore(defaults: UserDefaults, library: MutableLibrary) -> PreferencesStore {
        PreferencesStore(
            userDefaults: defaults,
            knownPetIdsProvider: { library.snapshot() },
            screenGeometryProvider: {
                ScreenGeometry(visibleFrames: [CGRect(x: 0, y: 0, width: 1_440, height: 900)])
            },
            frameSizeProvider: {
                CGSize(width: 128, height: 128)
            },
            now: {
                Date(timeIntervalSince1970: 1_700_000_000)
            }
        )
    }
}
