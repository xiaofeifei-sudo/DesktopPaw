import Foundation

public protocol AIVisualPreferencesStoring: Sendable {
    func loadPreferences() -> AIVisualPreferences
    func savePreferences(_ preferences: AIVisualPreferences)
}

public final class AIVisualPreferencesStore: AIVisualPreferencesStoring, @unchecked Sendable {
    public static let preferencesKey = "aiVisualPreferences"

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

    public func loadPreferences() -> AIVisualPreferences {
        guard let data = userDefaults.data(forKey: Self.preferencesKey) else {
            return AIVisualPreferences()
        }

        do {
            return try decoder.decode(AIVisualPreferences.self, from: data)
        } catch {
            DesktopPetLog.aiCompanion.warning("Failed to decode AI visual preferences: \(error.localizedDescription)")
            return AIVisualPreferences()
        }
    }

    public func savePreferences(_ preferences: AIVisualPreferences) {
        guard let data = try? encoder.encode(preferences) else { return }
        userDefaults.set(data, forKey: Self.preferencesKey)
    }

    public func setEnabled(_ enabled: Bool) {
        var preferences = loadPreferences()
        preferences.isEnabled = enabled
        savePreferences(preferences)
    }

    public func setAutonomousFrequency(_ frequency: AIVisualAutonomousFrequency) {
        var preferences = loadPreferences()
        preferences.autonomousFrequency = frequency
        savePreferences(preferences)
    }

    public func setDurationPreset(_ preset: AIVisualDurationPreset) {
        var preferences = loadPreferences()
        preferences.durationPreset = preset
        savePreferences(preferences)
    }

    public func setIntensity(_ intensity: AIVisualIntensity) {
        var preferences = loadPreferences()
        preferences.intensity = intensity
        savePreferences(preferences)
    }

    public func setSelectedProviderId(_ providerId: String?) {
        var preferences = loadPreferences()
        preferences.selectedProviderId = providerId
        savePreferences(preferences)
    }

    public func setMmxPath(_ path: String?) {
        var preferences = loadPreferences()
        preferences.mmxPath = path?.isEmpty == true ? nil : path
        savePreferences(preferences)
    }
}
