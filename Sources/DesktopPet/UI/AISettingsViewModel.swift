import Foundation

@MainActor
public final class AISettingsViewModel: ObservableObject {
    @Published public private(set) var preferences: AICompanionPreferences
    @Published public private(set) var isConfigured: Bool
    @Published public var showPrivacyNotice = false
    @Published public var showProviderConfig = false
    @Published public var showMemoryManager = false
    @Published public var apiKeyInput = ""
    @Published public var endpointInput = ""
    @Published public var modelInput = ""
    @Published public var selectedProtocol: AIProviderProtocol

    public var onAIEnabledChanged: ((Bool) -> Void)?
    public var onMemoryEnabledChanged: ((Bool) -> Void)?
    public var onProviderChanged: ((String?) -> Void)?
    public var onPersonalityChanged: ((String) -> Void)?
    public var onInitiativeBubbleChanged: ((Bool) -> Void)?
    public var onClearMemory: (() -> Void)?
    public var onExportMemory: (() -> Void)?
    public var onAPIKeySaved: ((String) -> Void)?

    @Published private var availableProfiles: [AIPersonalityProfile]
    public let memoryViewModel: AIMemoryViewModel?
    public let memoryManagementViewModel: MemoryManagementViewModel?

    public init(
        preferences: AICompanionPreferences = AICompanionPreferences(),
        isConfigured: Bool = false,
        profiles: [AIPersonalityProfile] = AIPersonalityProfile.defaultProfiles,
        memoryViewModel: AIMemoryViewModel? = nil,
        memoryManagementViewModel: MemoryManagementViewModel? = nil
    ) {
        self.preferences = preferences
        self.isConfigured = isConfigured
        self.availableProfiles = profiles
        self.memoryViewModel = memoryViewModel
        self.memoryManagementViewModel = memoryManagementViewModel
        self.selectedProtocol = preferences.providerProtocol
    }

    public var isAIEnabled: Bool {
        preferences.isAIEnabled
    }

    public var personalityProfiles: [AIPersonalityProfile] {
        availableProfiles
    }

    public var selectedProfile: AIPersonalityProfile? {
        availableProfiles.first { $0.id == preferences.selectedPersonalityId }
    }

    public var selectedProfilePreviewPhrases: [String] {
        selectedProfile?.previewPhrases ?? []
    }

    public func requestEnableAI() {
        showPrivacyNotice = true
    }

    public func confirmEnableAI() {
        preferences.isAIEnabled = true
        showPrivacyNotice = false
        onAIEnabledChanged?(true)
    }

    public func disableAI() {
        preferences.isAIEnabled = false
        onAIEnabledChanged?(false)
    }

    public func setMemoryEnabled(_ enabled: Bool) {
        guard preferences.isMemoryEnabled != enabled else { return }
        preferences.isMemoryEnabled = enabled
        onMemoryEnabledChanged?(enabled)
    }

    public func setPersonality(_ profileId: String) {
        guard preferences.selectedPersonalityId != profileId else { return }
        preferences.selectedPersonalityId = profileId
        onPersonalityChanged?(profileId)
    }

    public func setAllowInitiativeBubble(_ allowed: Bool) {
        guard preferences.allowInitiativeBubble != allowed else { return }
        preferences.allowInitiativeBubble = allowed
        onInitiativeBubbleChanged?(allowed)
    }

    public func openProviderConfig() {
        endpointInput = ""
        modelInput = selectedProtocol == .anthropic ? "claude-sonnet-4-20250514" : "gpt-4o-mini"
        apiKeyInput = ""
        showProviderConfig = true
    }

    public func saveProviderConfig() {
        guard !apiKeyInput.isEmpty else { return }
        onAPIKeySaved?(apiKeyInput)
        onProviderChanged?(selectedProtocol == .anthropic ? "anthropic" : "http-openai")
        isConfigured = true
        showProviderConfig = false
    }

    public func clearMemory() {
        onClearMemory?()
    }

    public func openMemoryManager() {
        memoryManagementViewModel?.loadData()
        memoryViewModel?.loadMemories()
        showMemoryManager = true
    }

    public func exportMemory() {
        onExportMemory?()
    }

    public func updatePreferences(_ preferences: AICompanionPreferences) {
        self.preferences = preferences
    }

    public func updateProfiles(_ profiles: [AIPersonalityProfile]) {
        availableProfiles = profiles
    }

    public func updateIsConfigured(_ configured: Bool) {
        isConfigured = configured
    }
}
