import Foundation

public protocol CompanionPreferencesStoring: Sendable {
    func loadPreferences() -> CompanionPreferences
    func savePreferences(_ preferences: CompanionPreferences)
}

public final class CompanionPreferencesStore: CompanionPreferencesStoring, @unchecked Sendable {
    public static let preferencesKey = "companionPreferences"

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

    public func loadPreferences() -> CompanionPreferences {
        guard let data = userDefaults.data(forKey: Self.preferencesKey) else {
            return CompanionPreferences()
        }

        do {
            return try decoder.decode(CompanionPreferences.self, from: data)
        } catch {
            return CompanionPreferences()
        }
    }

    public func savePreferences(_ preferences: CompanionPreferences) {
        guard let data = try? encoder.encode(preferences) else {
            return
        }
        userDefaults.set(data, forKey: Self.preferencesKey)
    }

    public func setPetNickname(_ nickname: String?, for petId: String) {
        var preferences = loadPreferences()
        let trimmedNickname = nickname?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if trimmedNickname.isEmpty {
            preferences.petNicknamesByPetId.removeValue(forKey: petId)
        } else {
            preferences.petNicknamesByPetId[petId] = trimmedNickname
        }

        savePreferences(preferences)
    }

    public func setUserNickname(_ nickname: String?) {
        var preferences = loadPreferences()
        let trimmedNickname = nickname?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        preferences.userNickname = trimmedNickname.isEmpty ? nil : trimmedNickname
        savePreferences(preferences)
    }

    public func quietForOneHour(from date: Date = Date()) {
        var preferences = loadPreferences()
        preferences.quietUntil = date.addingTimeInterval(3_600)
        savePreferences(preferences)
    }

    public func clearQuietMode() {
        var preferences = loadPreferences()
        preferences.quietUntil = nil
        savePreferences(preferences)
    }
}
