import Foundation

@MainActor
public final class CompanionshipSettingsViewModel: ObservableObject {
    @Published public private(set) var relationship: RelationshipSnapshot
    @Published public private(set) var preferences: CompanionPreferences
    @Published public private(set) var quietState: QuietModeState

    public private(set) var currentPetId: String

    public var onRelationshipPromptsChanged: ((Bool) -> Void)?
    public var onPetNicknameChanged: ((String?) -> Void)?
    public var onUserNicknameChanged: ((String?) -> Void)?
    public var onQuietHoursChanged: ((QuietHours?) -> Void)?
    public var onQuietForOneHour: (() -> Void)?
    public var onClearQuietMode: (() -> Void)?
    public var onResetRelationship: (() -> Void)?

    public init(
        currentPetId: String = "default-pet",
        relationship: RelationshipSnapshot = RelationshipSnapshot(intimacyPoints: 0, currentLevel: .acquaintance),
        preferences: CompanionPreferences = CompanionPreferences(),
        quietState: QuietModeState = .inactive
    ) {
        self.currentPetId = currentPetId
        self.relationship = relationship
        self.preferences = preferences
        self.quietState = quietState
    }

    public var levelDisplayText: String {
        "Lv.\(relationship.levelNumber) \(relationship.levelName)"
    }

    public var progressText: String {
        if let nextLevelPoints = relationship.nextLevelMinimumPoints {
            let remaining = nextLevelPoints - relationship.intimacyPoints
            return "\(relationship.intimacyPoints) / \(nextLevelPoints)"
        }
        return "Max"
    }

    public var progressFraction: Double {
        guard let nextLevelPoints = relationship.nextLevelMinimumPoints else {
            return 1.0
        }
        let range = nextLevelPoints - relationship.currentLevelMinimumPoints
        guard range > 0 else { return 1.0 }
        let progress = relationship.intimacyPoints - relationship.currentLevelMinimumPoints
        return min(1.0, max(0.0, Double(progress) / Double(range)))
    }

    public var isQuietActive: Bool {
        quietState != .inactive
    }

    public var currentPetNickname: String? {
        preferences.petNicknamesByPetId[currentPetId]
    }

    public func setRelationshipPromptsEnabled(_ enabled: Bool) {
        guard preferences.showRelationshipPrompts != enabled else { return }
        preferences.showRelationshipPrompts = enabled
        onRelationshipPromptsChanged?(enabled)
    }

    public func setPetNickname(_ nickname: String?) {
        let trimmed = nickname?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let finalValue = trimmed.isEmpty ? nil : trimmed
        preferences.petNicknamesByPetId[currentPetId] = finalValue
        onPetNicknameChanged?(nickname)
    }

    public func setUserNickname(_ nickname: String?) {
        let trimmed = nickname?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let finalValue = trimmed.isEmpty ? nil : trimmed
        preferences.userNickname = finalValue
        onUserNicknameChanged?(nickname)
    }

    public func quietForOneHour() {
        onQuietForOneHour?()
    }

    public func clearQuietMode() {
        onClearQuietMode?()
    }

    public func setQuietHoursEnabled(_ enabled: Bool) {
        if enabled {
            preferences.quietHours = preferences.quietHours ?? QuietHours(startMinuteOfDay: 22 * 60, endMinuteOfDay: 8 * 60)
        } else {
            preferences.quietHours = nil
        }
        onQuietHoursChanged?(preferences.quietHours)
    }

    public func setQuietHoursStart(_ minuteOfDay: Int) {
        let current = preferences.quietHours ?? QuietHours(startMinuteOfDay: 22 * 60, endMinuteOfDay: 8 * 60)
        preferences.quietHours = QuietHours(isEnabled: current.isEnabled, startMinuteOfDay: minuteOfDay, endMinuteOfDay: current.endMinuteOfDay)
        onQuietHoursChanged?(preferences.quietHours)
    }

    public func setQuietHoursEnd(_ minuteOfDay: Int) {
        let current = preferences.quietHours ?? QuietHours(startMinuteOfDay: 22 * 60, endMinuteOfDay: 8 * 60)
        preferences.quietHours = QuietHours(isEnabled: current.isEnabled, startMinuteOfDay: current.startMinuteOfDay, endMinuteOfDay: minuteOfDay)
        onQuietHoursChanged?(preferences.quietHours)
    }

    public func resetRelationship() {
        onResetRelationship?()
    }

    public func updateRelationship(_ snapshot: RelationshipSnapshot) {
        relationship = snapshot
    }

    public func updatePreferences(_ preferences: CompanionPreferences) {
        self.preferences = preferences
    }

    public func updatePetId(_ petId: String) {
        currentPetId = petId
    }

    public func updateQuietState(_ state: QuietModeState) {
        quietState = state
    }
}
