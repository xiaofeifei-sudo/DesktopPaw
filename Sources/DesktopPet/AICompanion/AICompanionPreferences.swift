import Foundation

public enum AIProviderProtocol: String, Codable, Sendable, CaseIterable {
    case openai
    case anthropic
}

public struct AICompanionPreferences: Codable, Equatable, Sendable {
    public var isAIEnabled: Bool
    public var isMemoryEnabled: Bool
    public var selectedProviderId: String?
    public var selectedPersonalityId: String
    public var allowInitiativeBubble: Bool
    public var initiativeBubbleMinInterval: TimeInterval
    public var showAIReminderOnStartup: Bool
    public var providerEndpoint: String?
    public var providerModel: String?
    public var providerProtocol: AIProviderProtocol

    public init(
        isAIEnabled: Bool = false,
        isMemoryEnabled: Bool = true,
        selectedProviderId: String? = nil,
        selectedPersonalityId: String = AIPersonalityProfile.defaultProfileId,
        allowInitiativeBubble: Bool = false,
        initiativeBubbleMinInterval: TimeInterval = 1800,
        showAIReminderOnStartup: Bool = true,
        providerEndpoint: String? = nil,
        providerModel: String? = nil,
        providerProtocol: AIProviderProtocol = .openai
    ) {
        self.isAIEnabled = isAIEnabled
        self.isMemoryEnabled = isMemoryEnabled
        self.selectedProviderId = selectedProviderId
        self.selectedPersonalityId = selectedPersonalityId
        self.allowInitiativeBubble = allowInitiativeBubble
        self.initiativeBubbleMinInterval = initiativeBubbleMinInterval
        self.showAIReminderOnStartup = showAIReminderOnStartup
        self.providerEndpoint = providerEndpoint
        self.providerModel = providerModel
        self.providerProtocol = providerProtocol
    }
}
