import Foundation
import DesktopPet

@MainActor
func runPreferencesStoreTests() {
    let tests = PreferencesStoreTests()
    tests.defaultsAreUsedOnFirstLaunch()
    tests.invalidScaleIsClampedAndWrittenBack()
    tests.runtimeNumbersAreClampedAndWrittenBack()
    tests.unknownPetIdFallsBackToStarterPet()
    tests.offscreenFrameFallsBackToDefaultFrame()
    tests.valuesPersistAcrossStoreInstances()
}

@MainActor
private struct PreferencesStoreTests {
    func defaultsAreUsedOnFirstLaunch() {
        let harness = PreferencesHarness()

        expect(harness.store.isPetVisible, "pet should be visible by default")
        expect(harness.store.petScale == 1, "scale should default to 1")
        expect(harness.store.isRandomWalkingEnabled, "random walking should default to on")
        expect(harness.store.isSoundEnabled, "sound should default to on")
        expect(harness.store.selectedPetId == "starter-pet", "selected pet should default to starter pet")
        expect(harness.store.mood == 0.8, "mood should use default")
        expect(harness.store.hunger == 0.2, "hunger should use default")
        expect(harness.store.energy == 0.8, "energy should use default")
    }

    func invalidScaleIsClampedAndWrittenBack() {
        let harness = PreferencesHarness()
        harness.defaults.set(3.5, forKey: PreferenceKeys.petScale)

        expect(harness.store.petScale == 2, "scale should clamp to upper bound")
        expect(harness.defaults.double(forKey: PreferenceKeys.petScale) == 2, "clamped scale should be written back")
    }

    func runtimeNumbersAreClampedAndWrittenBack() {
        let harness = PreferencesHarness()
        harness.defaults.set(-1, forKey: PreferenceKeys.mood)
        harness.defaults.set(2, forKey: PreferenceKeys.hunger)
        harness.defaults.set(3, forKey: PreferenceKeys.energy)

        expect(harness.store.mood == 0, "mood should clamp to lower bound")
        expect(harness.store.hunger == 1, "hunger should clamp to upper bound")
        expect(harness.store.energy == 1, "energy should clamp to upper bound")
    }

    func unknownPetIdFallsBackToStarterPet() {
        let harness = PreferencesHarness()
        harness.defaults.set("future-pet", forKey: PreferenceKeys.selectedPetId)

        expect(harness.store.selectedPetId == "starter-pet", "unknown pet id should fall back")
        expect(harness.defaults.string(forKey: PreferenceKeys.selectedPetId) == "starter-pet", "fallback pet id should be written back")
    }

    func offscreenFrameFallsBackToDefaultFrame() {
        let harness = PreferencesHarness()
        harness.store.savePetWindowFrame(CGRect(x: 2_500, y: 1_600, width: 128, height: 128))

        let frame = harness.store.resolvedPetWindowFrame()

        expect(frame == CGRect(x: 1_288, y: 24, width: 128, height: 128), "offscreen frame should fall back to default")
    }

    func valuesPersistAcrossStoreInstances() {
        let harness = PreferencesHarness()
        harness.store.petScale = 1.25
        harness.store.isRandomWalkingEnabled = false
        harness.store.isSoundEnabled = false
        harness.store.mood = 0.3

        let nextStore = harness.makeStore()

        expect(nextStore.petScale == 1.25, "scale should persist")
        expect(!nextStore.isRandomWalkingEnabled, "random walking should persist")
        expect(!nextStore.isSoundEnabled, "sound preference should persist")
        expect(nextStore.mood == 0.3, "runtime value should persist")
    }
}

@MainActor
private final class PreferencesHarness {
    let suiteName: String
    let defaults: UserDefaults
    let store: PreferencesStore

    init() {
        suiteName = "DesktopPetTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        store = PreferencesHarness.makeStore(defaults: defaults)
    }

    func makeStore() -> PreferencesStore {
        Self.makeStore(defaults: defaults)
    }

    private static func makeStore(defaults: UserDefaults) -> PreferencesStore {
        PreferencesStore(
            userDefaults: defaults,
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
