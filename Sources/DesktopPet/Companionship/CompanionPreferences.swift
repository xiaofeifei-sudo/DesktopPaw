import Foundation

public struct CompanionPreferences: Codable, Equatable, Sendable {
    public var showRelationshipPrompts: Bool
    public var petNicknamesByPetId: [String: String]
    public var userNickname: String?
    public var quietUntil: Date?
    public var quietHours: QuietHours?
    public var microDialogsEnabled: Bool

    public init(
        showRelationshipPrompts: Bool = true,
        petNicknamesByPetId: [String: String] = [:],
        userNickname: String? = nil,
        quietUntil: Date? = nil,
        quietHours: QuietHours? = nil,
        microDialogsEnabled: Bool = true
    ) {
        self.showRelationshipPrompts = showRelationshipPrompts
        self.petNicknamesByPetId = petNicknamesByPetId
        self.userNickname = userNickname
        self.quietUntil = quietUntil
        self.quietHours = quietHours
        self.microDialogsEnabled = microDialogsEnabled
    }
}

public struct QuietHours: Codable, Equatable, Sendable {
    public var isEnabled: Bool
    public var startMinuteOfDay: Int
    public var endMinuteOfDay: Int

    public init(
        isEnabled: Bool = true,
        startMinuteOfDay: Int,
        endMinuteOfDay: Int
    ) {
        self.isEnabled = isEnabled
        self.startMinuteOfDay = Self.normalizedMinute(startMinuteOfDay)
        self.endMinuteOfDay = Self.normalizedMinute(endMinuteOfDay)
    }

    public var crossesMidnight: Bool {
        startMinuteOfDay > endMinuteOfDay
    }

    public var isEmpty: Bool {
        startMinuteOfDay == endMinuteOfDay
    }

    private static func normalizedMinute(_ value: Int) -> Int {
        min(max(value, 0), 23 * 60 + 59)
    }
}
