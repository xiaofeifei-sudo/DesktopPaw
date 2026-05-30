import Foundation

public protocol AICompanionPreferencesStoring: Sendable {
    func loadPreferences() -> AICompanionPreferences
    func savePreferences(_ preferences: AICompanionPreferences)
}

public final class AICompanionPreferencesStore: AICompanionPreferencesStoring, @unchecked Sendable {
    public static let preferencesKey = "aiCompanionPreferences"

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

    public func loadPreferences() -> AICompanionPreferences {
        guard let data = userDefaults.data(forKey: Self.preferencesKey) else {
            return AICompanionPreferences()
        }

        do {
            return try decoder.decode(AICompanionPreferences.self, from: data)
        } catch {
            DesktopPetLog.aiCompanion.warning("Failed to decode AI preferences: \(error.localizedDescription)")
            return AICompanionPreferences()
        }
    }

    public func savePreferences(_ preferences: AICompanionPreferences) {
        guard let data = try? encoder.encode(preferences) else {
            return
        }
        userDefaults.set(data, forKey: Self.preferencesKey)
    }

    public func setAIEnabled(_ enabled: Bool) {
        var preferences = loadPreferences()
        preferences.isAIEnabled = enabled
        savePreferences(preferences)
    }

    public func setMemoryEnabled(_ enabled: Bool) {
        var preferences = loadPreferences()
        preferences.isMemoryEnabled = enabled
        savePreferences(preferences)
    }

    public func setSelectedProviderId(_ providerId: String?) {
        var preferences = loadPreferences()
        preferences.selectedProviderId = providerId
        savePreferences(preferences)
    }

    public func setSelectedPersonalityId(_ personalityId: String) {
        var preferences = loadPreferences()
        preferences.selectedPersonalityId = personalityId
        savePreferences(preferences)
    }

    public func setAllowInitiativeBubble(_ allowed: Bool) {
        var preferences = loadPreferences()
        preferences.allowInitiativeBubble = allowed
        savePreferences(preferences)
    }

    public func setInitiativeBubbleMinInterval(_ interval: TimeInterval) {
        var preferences = loadPreferences()
        preferences.initiativeBubbleMinInterval = interval
        savePreferences(preferences)
    }
}
