import Foundation
import DesktopPet

func runAdvancedPreferencesStoreTests() {
    func testLoadDefaultWhenNoData() {
        let defaults = UserDefaults(suiteName: "test.advanced.store1")!
        defaults.removePersistentDomain(forName: "test.advanced.store1")

        let store = AdvancedPreferencesStore(userDefaults: defaults)
        let prefs = store.loadPreferences()

        expect(prefs.inputSyncConfig.isEnabled == false, "should load default disabled input sync")
        expect(prefs.desktopSpaceEnabled == false, "should load default desktop space disabled")
        expect(prefs.externalStateEnabled == false, "should load default external state disabled")
    }

    func testSaveAndLoadPreferences() {
        let defaults = UserDefaults(suiteName: "test.advanced.store2")!
        defaults.removePersistentDomain(forName: "test.advanced.store2")

        let store = AdvancedPreferencesStore(userDefaults: defaults)
        var prefs = AdvancedPreferences()
        prefs.inputSyncConfig.isEnabled = true
        prefs.desktopSpaceEnabled = true
        prefs.desktopSpaceEdgeThreshold = 80
        store.savePreferences(prefs)

        let loaded = store.loadPreferences()
        expect(loaded.inputSyncConfig.isEnabled == true, "inputSync enabled should persist")
        expect(loaded.desktopSpaceEnabled == true, "desktopSpace enabled should persist")
        expect(loaded.desktopSpaceEdgeThreshold == 80, "edge threshold should persist")
    }

    func testSetInputSyncEnabled() {
        let defaults = UserDefaults(suiteName: "test.advanced.store3")!
        defaults.removePersistentDomain(forName: "test.advanced.store3")

        let store = AdvancedPreferencesStore(userDefaults: defaults)
        store.setInputSyncEnabled(true)
        expect(store.loadPreferences().inputSyncConfig.isEnabled == true, "setInputSyncEnabled should work")

        store.setInputSyncEnabled(false)
        expect(store.loadPreferences().inputSyncConfig.isEnabled == false, "setInputSyncEnabled false should work")
    }

    func testSetInputSyncIntensity() {
        let defaults = UserDefaults(suiteName: "test.advanced.store4")!
        defaults.removePersistentDomain(forName: "test.advanced.store4")

        let store = AdvancedPreferencesStore(userDefaults: defaults)
        store.setInputSyncIntensity(.expressive)
        expect(store.loadPreferences().inputSyncConfig.syncIntensity == .expressive, "intensity should persist")
    }

    func testSetDesktopSpaceEnabled() {
        let defaults = UserDefaults(suiteName: "test.advanced.store5")!
        defaults.removePersistentDomain(forName: "test.advanced.store5")

        let store = AdvancedPreferencesStore(userDefaults: defaults)
        store.setDesktopSpaceEnabled(true)
        expect(store.loadPreferences().desktopSpaceEnabled == true, "desktopSpace enabled should persist")
    }

    func testSetExternalStateEnabled() {
        let defaults = UserDefaults(suiteName: "test.advanced.store6")!
        defaults.removePersistentDomain(forName: "test.advanced.store6")

        let store = AdvancedPreferencesStore(userDefaults: defaults)
        store.setExternalStateEnabled(true)
        expect(store.loadPreferences().externalStateEnabled == true, "externalState enabled should persist")
    }

    func testSetMovementConstrained() {
        let defaults = UserDefaults(suiteName: "test.advanced.store7")!
        defaults.removePersistentDomain(forName: "test.advanced.store7")

        let store = AdvancedPreferencesStore(userDefaults: defaults)
        store.setMovementConstrained(true)
        expect(store.loadPreferences().isMovementConstrained == true, "movement constrained should persist")
    }

    func testSetDesktopSpaceEdgeThreshold() {
        let defaults = UserDefaults(suiteName: "test.advanced.store8")!
        defaults.removePersistentDomain(forName: "test.advanced.store8")

        let store = AdvancedPreferencesStore(userDefaults: defaults)
        store.setDesktopSpaceEdgeThreshold(60)
        expect(store.loadPreferences().desktopSpaceEdgeThreshold == 60, "edge threshold should persist")
    }

    testLoadDefaultWhenNoData()
    testSaveAndLoadPreferences()
    testSetInputSyncEnabled()
    testSetInputSyncIntensity()
    testSetDesktopSpaceEnabled()
    testSetExternalStateEnabled()
    testSetMovementConstrained()
    testSetDesktopSpaceEdgeThreshold()
}
