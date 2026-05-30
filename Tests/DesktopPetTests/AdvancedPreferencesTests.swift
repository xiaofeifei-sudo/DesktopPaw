import Foundation
import DesktopPet

func runAdvancedPreferencesTests() {
    func testDefaultPreferences() {
        let prefs = AdvancedPreferences()
        expect(prefs.inputSyncConfig.isEnabled == false, "input sync should be disabled by default")
        expect(prefs.desktopSpaceEnabled == false, "desktop space should be disabled by default")
        expect(prefs.externalStateEnabled == false, "external state should be disabled by default")
        expect(prefs.desktopSpaceEdgeThreshold == 40, "default edge threshold should be 40")
        expect(!prefs.isMovementConstrained, "movement should not be constrained by default")
    }

    func testDefaultSocketPath() {
        let path = AdvancedPreferences.defaultSocketPath()
        expect(path.hasSuffix("external-state.sock"), "socket path should end with external-state.sock")
        expect(path.contains("DesktopPet"), "socket path should contain DesktopPet")
    }

    func testCodableRoundtrip() {
        var prefs = AdvancedPreferences()
        prefs.inputSyncConfig.isEnabled = true
        prefs.inputSyncConfig.syncIntensity = .expressive
        prefs.desktopSpaceEnabled = true
        prefs.desktopSpaceEdgeThreshold = 60
        prefs.externalStateEnabled = true

        guard let data = try? JSONEncoder().encode(prefs),
              let decoded = try? JSONDecoder().decode(AdvancedPreferences.self, from: data) else {
            fail("advanced preferences codable roundtrip failed")
        }
        expect(decoded.inputSyncConfig.isEnabled == true, "inputSync enabled should survive")
        expect(decoded.inputSyncConfig.syncIntensity == .expressive, "intensity should survive")
        expect(decoded.desktopSpaceEnabled == true, "desktopSpace enabled should survive")
        expect(decoded.desktopSpaceEdgeThreshold == 60, "edge threshold should survive")
        expect(decoded.externalStateEnabled == true, "externalState enabled should survive")
    }

    func testFeatureInfoModels() {
        let info = AdvancedSettingsViewModel.inputSyncInfo
        expect(!info.title.isEmpty, "info should have title")
        expect(!info.whyNeeded.isEmpty, "info should have whyNeeded")
        expect(!info.whatItAccesses.isEmpty, "info should have whatItAccesses")
        expect(!info.whatItDoesNotAccess.isEmpty, "info should have whatItDoesNotAccess")
        expect(!info.dataSaved.isEmpty, "info should have dataSaved")
        expect(!info.howToClose.isEmpty, "info should have howToClose")
        expect(!info.whatYouLose.isEmpty, "info should have whatYouLose")
    }

    func testAllFeatureInfosPresent() {
        let inputSyncInfo = AdvancedSettingsViewModel.inputSyncInfo
        let desktopSpaceInfo = AdvancedSettingsViewModel.desktopSpaceInfo
        let externalStateInfo = AdvancedSettingsViewModel.externalStateInfo

        expect(inputSyncInfo.id == "inputSync", "should have inputSync info")
        expect(desktopSpaceInfo.id == "desktopSpace", "should have desktopSpace info")
        expect(externalStateInfo.id == "externalState", "should have externalState info")
    }

    func testPreferencesInitialization() {
        var prefs = AdvancedPreferences()
        prefs.desktopSpaceEnabled = true
        prefs.inputSyncConfig.isEnabled = true
        prefs.externalStateEnabled = true
        expect(prefs.desktopSpaceEnabled, "should be able to set desktop space enabled")
        expect(prefs.inputSyncConfig.isEnabled, "should be able to set input sync enabled")
        expect(prefs.externalStateEnabled, "should be able to set external state enabled")
    }

    testDefaultPreferences()
    testDefaultSocketPath()
    testCodableRoundtrip()
    testFeatureInfoModels()
    testAllFeatureInfosPresent()
    testPreferencesInitialization()
}
