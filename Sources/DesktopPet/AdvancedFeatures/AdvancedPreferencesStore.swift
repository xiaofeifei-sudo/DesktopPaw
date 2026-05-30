import Foundation

public protocol AdvancedPreferencesStoring: Sendable {
    func loadPreferences() -> AdvancedPreferences
    func savePreferences(_ preferences: AdvancedPreferences)
}

public final class AdvancedPreferencesStore: AdvancedPreferencesStoring, @unchecked Sendable {
    public static let preferencesKey = "advancedPreferences"

    private let userDefaults: UserDefaults
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(
        userDefaults: UserDefaults = .standard,
        encoder: JSONEncoder = JSONEncoder(),
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.userDefaults = userDefaults
        self.encoder = encoder
        self.decoder = decoder
    }

    public func loadPreferences() -> AdvancedPreferences {
        guard let data = userDefaults.data(forKey: Self.preferencesKey) else {
            return AdvancedPreferences()
        }
        do {
            return try decoder.decode(AdvancedPreferences.self, from: data)
        } catch {
            return AdvancedPreferences()
        }
    }

    public func savePreferences(_ preferences: AdvancedPreferences) {
        guard let data = try? encoder.encode(preferences) else { return }
        userDefaults.set(data, forKey: Self.preferencesKey)
    }

    public func setInputSyncEnabled(_ enabled: Bool) {
        var preferences = loadPreferences()
        preferences.inputSyncConfig.isEnabled = enabled
        savePreferences(preferences)
    }

    public func setInputSyncIntensity(_ intensity: InputSyncIntensity) {
        var preferences = loadPreferences()
        preferences.inputSyncConfig.syncIntensity = intensity
        savePreferences(preferences)
    }

    public func setInputSyncTrackKeyboard(_ track: Bool) {
        var preferences = loadPreferences()
        preferences.inputSyncConfig.trackKeyboard = track
        savePreferences(preferences)
    }

    public func setInputSyncTrackMouse(_ track: Bool) {
        var preferences = loadPreferences()
        preferences.inputSyncConfig.trackMouse = track
        savePreferences(preferences)
    }

    public func setInputSyncRespectQuietMode(_ respect: Bool) {
        var preferences = loadPreferences()
        preferences.inputSyncConfig.respectQuietMode = respect
        savePreferences(preferences)
    }

    public func setDesktopSpaceEnabled(_ enabled: Bool) {
        var preferences = loadPreferences()
        preferences.desktopSpaceEnabled = enabled
        savePreferences(preferences)
    }

    public func setDesktopSpaceEdgeThreshold(_ threshold: Double) {
        var preferences = loadPreferences()
        preferences.desktopSpaceEdgeThreshold = threshold
        savePreferences(preferences)
    }

    public func setMovementConstrained(_ constrained: Bool) {
        var preferences = loadPreferences()
        preferences.isMovementConstrained = constrained
        savePreferences(preferences)
    }

    public func setExternalStateEnabled(_ enabled: Bool) {
        var preferences = loadPreferences()
        preferences.externalStateEnabled = enabled
        savePreferences(preferences)
    }

    public func setExternalStateSocketPath(_ path: String) {
        var preferences = loadPreferences()
        preferences.externalStateSocketPath = path
        savePreferences(preferences)
    }
}
