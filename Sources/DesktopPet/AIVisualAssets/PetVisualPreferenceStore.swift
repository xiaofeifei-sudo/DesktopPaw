import Foundation

public enum AIVisualThemePreference: String, Codable, Sendable, CaseIterable {
    case cute
    case quiet
    case festival
    case warm
    case funny

    public var displayName: String {
        switch self {
        case .cute: "Cute"
        case .quiet: "Quiet"
        case .festival: "Festival"
        case .warm: "Warm"
        case .funny: "Funny"
        }
    }
}

public enum AIVisualDislikedContent: String, Codable, Sendable, CaseIterable {
    case exaggeratedDeformation
    case strongScenes
    case tooManyAccessories

    public var displayName: String {
        switch self {
        case .exaggeratedDeformation: "Exaggerated Deformation"
        case .strongScenes: "Strong Scenes"
        case .tooManyAccessories: "Too Many Accessories"
        }
    }
}

public struct PetVisualPreferences: Codable, Equatable, Sendable {
    public var preferredThemes: Set<AIVisualThemePreference>
    public var dislikedContent: Set<AIVisualDislikedContent>
    public var activeFavoriteId: String?
    public var favoriteNames: [String: String]
    public var petVisualNotes: [String: String]?
    public var consistencyPreference: ConsistencyPreference
    public var consistencyPreferences: [String: ConsistencyPreference]

    public init(
        preferredThemes: Set<AIVisualThemePreference> = [],
        dislikedContent: Set<AIVisualDislikedContent> = [],
        activeFavoriteId: String? = nil,
        favoriteNames: [String: String] = [:],
        petVisualNotes: [String: String]? = nil,
        consistencyPreference: ConsistencyPreference = .conservative,
        consistencyPreferences: [String: ConsistencyPreference] = [:]
    ) {
        self.preferredThemes = preferredThemes
        self.dislikedContent = dislikedContent
        self.activeFavoriteId = activeFavoriteId
        self.favoriteNames = favoriteNames
        self.petVisualNotes = petVisualNotes
        self.consistencyPreference = consistencyPreference
        self.consistencyPreferences = consistencyPreferences
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        preferredThemes = try container.decodeIfPresent(Set<AIVisualThemePreference>.self, forKey: .preferredThemes) ?? []
        dislikedContent = try container.decodeIfPresent(Set<AIVisualDislikedContent>.self, forKey: .dislikedContent) ?? []
        activeFavoriteId = try container.decodeIfPresent(String.self, forKey: .activeFavoriteId)
        favoriteNames = try container.decodeIfPresent([String: String].self, forKey: .favoriteNames) ?? [:]
        petVisualNotes = try container.decodeIfPresent([String: String].self, forKey: .petVisualNotes)
        consistencyPreference = try container.decodeIfPresent(ConsistencyPreference.self, forKey: .consistencyPreference) ?? .conservative
        consistencyPreferences = try container.decodeIfPresent([String: ConsistencyPreference].self, forKey: .consistencyPreferences) ?? [:]
    }

    public func consistencyPreference(forPetId petId: String) -> ConsistencyPreference {
        guard !petId.isEmpty else { return consistencyPreference }
        return consistencyPreferences[petId] ?? consistencyPreference
    }
}

public protocol ConsistencyPreferenceStoring: Sendable {
    func preference(for petId: String) async -> ConsistencyPreference
    func setPreference(_ preference: ConsistencyPreference, for petId: String) async throws
    func visualNotes(for petId: String) async -> String?
    func setVisualNotes(_ notes: String, for petId: String) async throws
}

public protocol PetVisualPreferenceStoring: ConsistencyPreferenceStoring {
    func loadPreferences() -> PetVisualPreferences
    func savePreferences(_ preferences: PetVisualPreferences)
    func setPreferredThemes(_ themes: Set<AIVisualThemePreference>)
    func setDislikedContent(_ content: Set<AIVisualDislikedContent>)
    func setActiveFavoriteId(_ id: String?)
    func setFavoriteName(_ name: String?, forAssetId assetId: String)
}

public final class PetVisualPreferenceStore: PetVisualPreferenceStoring, @unchecked Sendable {
    public static let preferencesKey = "petVisualPreferences"

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

    public func loadPreferences() -> PetVisualPreferences {
        guard let data = userDefaults.data(forKey: Self.preferencesKey) else {
            return PetVisualPreferences()
        }
        do {
            return try decoder.decode(PetVisualPreferences.self, from: data)
        } catch {
            DesktopPetLog.aiCompanion.warning("Failed to decode pet visual preferences: \(error.localizedDescription)")
            return PetVisualPreferences()
        }
    }

    public func savePreferences(_ preferences: PetVisualPreferences) {
        guard let data = try? encoder.encode(preferences) else { return }
        userDefaults.set(data, forKey: Self.preferencesKey)
    }

    public func setPreferredThemes(_ themes: Set<AIVisualThemePreference>) {
        var prefs = loadPreferences()
        prefs.preferredThemes = themes
        savePreferences(prefs)
    }

    public func setDislikedContent(_ content: Set<AIVisualDislikedContent>) {
        var prefs = loadPreferences()
        prefs.dislikedContent = content
        savePreferences(prefs)
    }

    public func setActiveFavoriteId(_ id: String?) {
        var prefs = loadPreferences()
        prefs.activeFavoriteId = id
        savePreferences(prefs)
    }

    public func setFavoriteName(_ name: String?, forAssetId assetId: String) {
        var prefs = loadPreferences()
        if let name, !name.isEmpty {
            prefs.favoriteNames[assetId] = name
        } else {
            prefs.favoriteNames.removeValue(forKey: assetId)
        }
        savePreferences(prefs)
    }
}

extension PetVisualPreferenceStoring {
    public func preference(for petId: String) async -> ConsistencyPreference {
        preferenceValue(forPetId: petId)
    }

    public func setPreference(_ preference: ConsistencyPreference, for petId: String) async throws {
        savePreference(preference, forPetId: petId)
    }

    public func visualNotes(for petId: String) async -> String? {
        loadVisualNotes(forPetId: petId)
    }

    public func setVisualNotes(_ notes: String, for petId: String) async throws {
        saveVisualNotes(notes, forPetId: petId)
    }

    public func preferenceValue(forPetId petId: String) -> ConsistencyPreference {
        loadPreferences().consistencyPreference(forPetId: petId)
    }

    public func savePreference(_ preference: ConsistencyPreference, forPetId petId: String) {
        var prefs = loadPreferences()
        if petId.isEmpty {
            prefs.consistencyPreference = preference
        } else {
            prefs.consistencyPreferences[petId] = preference
        }
        savePreferences(prefs)
    }

    public func saveVisualNotes(_ notes: String, forPetId petId: String) {
        let cleaned = PetVisualNotesSanitizer.sanitize(notes)
        var prefs = loadPreferences()
        if prefs.petVisualNotes == nil {
            prefs.petVisualNotes = [:]
        }
        if cleaned.isEmpty {
            prefs.petVisualNotes?.removeValue(forKey: petId)
        } else {
            prefs.petVisualNotes?[petId] = cleaned
        }
        savePreferences(prefs)
    }

    public func loadVisualNotes(forPetId petId: String) -> String? {
        loadPreferences().petVisualNotes?[petId]
    }
}

enum PetVisualNotesSanitizer {
    static func sanitize(_ notes: String) -> String {
        var cleaned = notes
        let dangerousPatterns = [
            "ignore previous", "ignore all", "disregard",
            "忘记之前", "忽略之前", "忽略以上",
            "新指令：", "new instruction:",
            "system:", "系统提示：", "override:",
            "forget everything", "reset instructions",
        ]
        for pattern in dangerousPatterns {
            cleaned = cleaned.replacingOccurrences(
                of: pattern,
                with: "",
                options: [.caseInsensitive]
            )
        }
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.count > 500 {
            cleaned = String(cleaned.prefix(500))
        }
        return cleaned
    }
}
