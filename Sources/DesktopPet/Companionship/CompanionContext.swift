import Foundation

public struct CompanionContext: Equatable, Sendable {
    public let petId: String
    public let petDisplayName: String
    public let petNickname: String?
    public let userNickname: String?
    public let runtimeState: PetRuntimeState
    public let relationship: RelationshipSnapshot
    public let preferences: CompanionPreferences
    public let timeSlots: Set<CompanionTimeSlot>
    public let recentBubbleTexts: [String]
    public let lastCompanionEvent: CompanionEvent?

    public init(
        petId: String,
        petDisplayName: String,
        petNickname: String? = nil,
        userNickname: String? = nil,
        runtimeState: PetRuntimeState,
        relationship: RelationshipSnapshot,
        preferences: CompanionPreferences,
        timeSlots: Set<CompanionTimeSlot>,
        recentBubbleTexts: [String] = [],
        lastCompanionEvent: CompanionEvent? = nil
    ) {
        self.petId = petId
        self.petDisplayName = petDisplayName
        self.petNickname = petNickname
        self.userNickname = userNickname
        self.runtimeState = runtimeState
        self.relationship = relationship
        self.preferences = preferences
        self.timeSlots = timeSlots
        self.recentBubbleTexts = recentBubbleTexts
        self.lastCompanionEvent = lastCompanionEvent
    }
}
