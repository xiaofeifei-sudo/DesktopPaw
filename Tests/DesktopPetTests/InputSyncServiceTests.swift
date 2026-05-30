import Foundation
import DesktopPet

func runInputSyncServiceTests() {
    func testDefaultConfigIsDisabled() {
        let service = InputSyncService()
        expect(!service.isEnabled, "default config should have isEnabled = false")
    }

    func testConfigCodableRoundtrip() {
        let config = InputSyncConfig(
            isEnabled: true,
            syncIntensity: .expressive,
            trackKeyboard: true,
            trackMouse: false,
            respectQuietMode: true
        )
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        guard let data = try? encoder.encode(config),
              let decoded = try? decoder.decode(InputSyncConfig.self, from: data) else {
            fail("config codable roundtrip failed")
        }
        expect(decoded.isEnabled == true, "isEnabled should survive roundtrip")
        expect(decoded.syncIntensity == .expressive, "syncIntensity should survive roundtrip")
        expect(decoded.trackKeyboard == true, "trackKeyboard should survive roundtrip")
        expect(decoded.trackMouse == false, "trackMouse should survive roundtrip")
        expect(decoded.respectQuietMode == true, "respectQuietMode should survive roundtrip")
    }

    func testStartWithDisabledConfigDoesNothing() {
        let service = InputSyncService()
        let config = InputSyncConfig(isEnabled: false)
        do {
            try service.start(config: config)
            expect(!service.isEnabled, "start with isEnabled=false should not enable service")
        } catch {
            fail("start with isEnabled=false should not throw: \(error)")
        }
    }

    func testUpdateConfigDisableWhenNotRunning() {
        let service = InputSyncService()
        expect(!service.isEnabled, "should start disabled")

        service.updateConfig(InputSyncConfig(isEnabled: false))
        expect(!service.isEnabled, "disable when not running should stay disabled")
    }

    func testStopWhenNotRunningIsNoop() {
        let service = InputSyncService()
        service.stop()
    }

    func testInputSyncIntensityAllCases() {
        let allCases = InputSyncIntensity.allCases
        expect(allCases.count == 3, "should have 3 intensity levels")
        expect(allCases.contains(.subtle), "should contain subtle")
        expect(allCases.contains(.moderate), "should contain moderate")
        expect(allCases.contains(.expressive), "should contain expressive")
    }

    func testInputSyncErrorDescriptions() {
        let permError = InputSyncError.accessibilityPermissionDenied
        expect(!permError.localizedDescription.isEmpty, "accessibility error should have description")

        let tapError = InputSyncError.eventTapCreationFailed
        expect(!tapError.localizedDescription.isEmpty, "event tap error should have description")
    }

    func testConfigDefaultValues() {
        let config = InputSyncConfig()
        expect(config.isEnabled == false, "default isEnabled should be false")
        expect(config.syncIntensity == .moderate, "default syncIntensity should be moderate")
        expect(config.trackKeyboard == true, "default trackKeyboard should be true")
        expect(config.trackMouse == true, "default trackMouse should be true")
        expect(config.respectQuietMode == true, "default respectQuietMode should be true")
    }

    testDefaultConfigIsDisabled()
    testConfigCodableRoundtrip()
    testStartWithDisabledConfigDoesNothing()
    testUpdateConfigDisableWhenNotRunning()
    testStopWhenNotRunningIsNoop()
    testInputSyncIntensityAllCases()
    testInputSyncErrorDescriptions()
    testConfigDefaultValues()
}
