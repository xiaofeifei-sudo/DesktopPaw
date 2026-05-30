import Foundation

public struct ProviderConfigFields: Sendable {
    public var apiKey: String = ""
    public var model: String?
    public var region: String?
    public var baseURL: String?
    public var secretId: String?
    public var secretKey: String?
}

@MainActor
public final class AIVisualSettingsViewModel: ObservableObject {
    @Published public private(set) var preferences: AIVisualPreferences
    @Published public private(set) var providerInfos: [ProviderInfo]
    @Published public private(set) var currentProviderId: String?
    @Published public private(set) var isProviderConfigured: Bool
    @Published public private(set) var usageSnapshot: AIVisualUsageSnapshot?
    @Published public private(set) var providerQuotaSnapshot: VisualProviderQuotaSnapshot?
    @Published public private(set) var hasActiveOverlay: Bool
    @Published public private(set) var consistencyPreference: ConsistencyPreference
    @Published public private(set) var petVisualNotes: String
    @Published public var showEnableNotice = false
    @Published public var showHistory = false
    @Published public var feedbackMessage: String?
    @Published public private(set) var isRefreshingProvider: Bool
    @Published public var mmxPath: String
    @Published public var showProviderConfig = false
    @Published public var apiKeyInput = ""
    @Published public var modelInput = ""
    @Published public var regionInput = ""
    @Published public var baseURLInput = ""
    @Published public var secretIdInput = ""
    @Published public var secretKeyInput = ""
    public var historyModel: AIVisualHistoryViewModel?

    public var onEnabledChanged: ((Bool) -> Void)?
    public var onAutonomousFrequencyChanged: ((AIVisualAutonomousFrequency) -> Void)?
    public var onDurationPresetChanged: ((AIVisualDurationPreset) -> Void)?
    public var onIntensityChanged: ((AIVisualIntensity) -> Void)?
    public var onProviderChanged: ((String) -> Void)?
    public var onConsistencyPreferenceChanged: ((ConsistencyPreference) -> Void)?
    public var onPetVisualNotesChanged: ((String) -> Void)?
    public var onManualGenerationRequested: (() -> Void)?
    public var onRestoreRequested: (() -> Void)?
    public var onRefreshProviderStatus: (@Sendable @MainActor () async -> Void)?
    public var onMmxPathChanged: ((String?) -> Void)?
    public var onProviderConfigSaved: ((String, ProviderConfigFields) -> Void)?
    public var onDeleteProviderConfig: ((String) -> Void)?
    public var onLoadProviderDefaults: ((String) -> ProviderConfigFields)?

    private let quotaStore: AIVisualQuotaStoring?
    private let generationService: VisualGenerationServicing?
    private let petId: String

    public init(
        preferences: AIVisualPreferences = AIVisualPreferences(),
        providerInfos: [ProviderInfo] = [],
        currentProviderId: String? = nil,
        isProviderConfigured: Bool = false,
        usageSnapshot: AIVisualUsageSnapshot? = nil,
        providerQuotaSnapshot: VisualProviderQuotaSnapshot? = nil,
        hasActiveOverlay: Bool = false,
        consistencyPreference: ConsistencyPreference = .conservative,
        petVisualNotes: String = "",
        mmxPath: String? = nil,
        petId: String = "",
        quotaStore: AIVisualQuotaStoring? = nil,
        generationService: VisualGenerationServicing? = nil
    ) {
        self.preferences = preferences
        self.providerInfos = providerInfos
        self.currentProviderId = currentProviderId
        self.isProviderConfigured = isProviderConfigured
        self.usageSnapshot = usageSnapshot
        self.providerQuotaSnapshot = providerQuotaSnapshot
        self.hasActiveOverlay = hasActiveOverlay
        self.consistencyPreference = consistencyPreference
        self.petVisualNotes = petVisualNotes
        self.isRefreshingProvider = false
        self.mmxPath = mmxPath ?? ""
        self.petId = petId
        self.quotaStore = quotaStore
        self.generationService = generationService
    }

    public var isEnabled: Bool {
        preferences.isEnabled
    }

    public var dailyUsedText: String {
        guard let snapshot = usageSnapshot else { return "0 / \(quotaDailyLimit)" }
        return "\(snapshot.dailyTotalCount) / \(quotaDailyLimit)"
    }

    public var dailyRemainingText: String {
        guard let snapshot = usageSnapshot else { return "\(quotaDailyLimit)" }
        return "\(max(quotaDailyLimit - snapshot.dailyTotalCount, 0))"
    }

    public var monthlyUsedText: String {
        guard let snapshot = usageSnapshot else { return "0 / \(quotaMonthlyLimit)" }
        return "\(snapshot.monthlyTotalCount) / \(quotaMonthlyLimit)"
    }

    public var providerQuotaText: String? {
        guard let remaining = providerQuotaSnapshot?.dailyRemaining else { return nil }
        return "Token Plan: \(remaining) remaining today"
    }

    public var selectedProviderDisplayName: String {
        guard let id = currentProviderId,
              let info = providerInfos.first(where: { $0.providerId == id }) else {
            return "Not selected"
        }
        return info.displayName
    }

    public var consistencyPreferenceDescription: String {
        consistencyPreference.userDescription
    }

    public var creativePreferenceNotice: String? {
        consistencyPreference == .creative
            ? "此模式可能带来更明显变化，但仍会保持当前桌宠身份。"
            : nil
    }

    public func requestEnable() {
        showEnableNotice = true
    }

    public func confirmEnable() {
        preferences.isEnabled = true
        showEnableNotice = false
        onEnabledChanged?(true)
    }

    public func disable() {
        preferences.isEnabled = false
        onEnabledChanged?(false)
    }

    public func setAutonomousFrequency(_ frequency: AIVisualAutonomousFrequency) {
        guard preferences.autonomousFrequency != frequency else { return }
        preferences.autonomousFrequency = frequency
        onAutonomousFrequencyChanged?(frequency)
    }

    public func setDurationPreset(_ preset: AIVisualDurationPreset) {
        guard preferences.durationPreset != preset else { return }
        preferences.durationPreset = preset
        onDurationPresetChanged?(preset)
    }

    public func setIntensity(_ intensity: AIVisualIntensity) {
        guard preferences.intensity != intensity else { return }
        preferences.intensity = intensity
        onIntensityChanged?(intensity)
    }

    public func setConsistencyPreference(_ preference: ConsistencyPreference) {
        guard consistencyPreference != preference else { return }
        consistencyPreference = preference
        onConsistencyPreferenceChanged?(preference)
    }

    public func setPetVisualNotes(_ notes: String) {
        guard petVisualNotes != notes else { return }
        petVisualNotes = notes
        onPetVisualNotesChanged?(notes)
    }

    public func selectProvider(_ providerId: String) {
        guard currentProviderId != providerId else { return }
        currentProviderId = providerId
        isProviderConfigured = providerInfos.first(where: { $0.providerId == providerId })?.isConfigured ?? false
        onProviderChanged?(providerId)
    }

    public func requestManualGeneration() {
        onManualGenerationRequested?()
    }

    public func restoreVisual() {
        onRestoreRequested?()
    }

    public func refreshUsage() {
        guard let quotaStore else { return }
        usageSnapshot = quotaStore.loadUsage(petId: petId, date: Date())
    }

    public func refreshProviderQuota() async {
        guard let service = generationService else { return }
        providerQuotaSnapshot = try? await service.quotaSnapshot()
    }

    public func updatePreferences(_ preferences: AIVisualPreferences) {
        self.preferences = preferences
    }

    public func updateProviderInfos(_ infos: [ProviderInfo]) {
        providerInfos = infos
    }

    public func updateCurrentProviderId(_ id: String?) {
        currentProviderId = id
        isProviderConfigured = id.flatMap { providerId in
            providerInfos.first(where: { $0.providerId == providerId })?.isConfigured ?? false
        } ?? false
    }

    public func updateHasActiveOverlay(_ has: Bool) {
        hasActiveOverlay = has
    }

    public func updateConsistencyControls(
        preference: ConsistencyPreference,
        petVisualNotes: String
    ) {
        consistencyPreference = preference
        self.petVisualNotes = petVisualNotes
    }

    public func showFeedback(_ message: String) {
        feedbackMessage = message
    }

    public func refreshProviderStatus() async {
        isRefreshingProvider = true
        await onRefreshProviderStatus?()
        isRefreshingProvider = false
    }

    public func commitMmxPath() {
        let trimmed = mmxPath.trimmingCharacters(in: .whitespacesAndNewlines)
        onMmxPathChanged?(trimmed.isEmpty ? nil : trimmed)
    }

    public func clearFeedback() {
        feedbackMessage = nil
    }

    // MARK: - Provider Config

    public var isCLIProvider: Bool { currentProviderId == "minimax-cli" }

    public var detectedMMXPathPlaceholder: String {
        MiniMaxCLIClient.detectedMMXPath() ?? "/usr/local/bin/mmx"
    }

    public var requiresAPIKey: Bool {
        guard let id = currentProviderId else { return false }
        return id != "minimax-cli" && id != "tencent"
    }

    public var requiresTencentCredentials: Bool { currentProviderId == "tencent" }

    public var requiresModel: Bool {
        ["aliyun", "siliconflow", "openai-compatible"].contains(currentProviderId)
    }

    public var requiresRegion: Bool {
        ["aliyun", "tencent"].contains(currentProviderId)
    }

    public var requiresBaseURL: Bool {
        currentProviderId == "openai-compatible"
    }

    public func openProviderConfig() {
        guard let id = currentProviderId else { return }
        apiKeyInput = ""
        secretIdInput = ""
        secretKeyInput = ""
        if let defaults = onLoadProviderDefaults?(id) {
            modelInput = defaults.model ?? ""
            regionInput = defaults.region ?? ""
            baseURLInput = defaults.baseURL ?? ""
        } else {
            modelInput = ""
            regionInput = ""
            baseURLInput = ""
        }
        showProviderConfig = true
    }

    public func saveProviderConfig() {
        guard let id = currentProviderId else { return }
        var fields = ProviderConfigFields()
        fields.apiKey = apiKeyInput
        fields.model = requiresModel ? modelInput : nil
        fields.region = requiresRegion ? regionInput : nil
        fields.baseURL = requiresBaseURL ? baseURLInput : nil
        fields.secretId = requiresTencentCredentials ? secretIdInput : nil
        fields.secretKey = requiresTencentCredentials ? secretKeyInput : nil
        onProviderConfigSaved?(id, fields)
        showProviderConfig = false
    }

    public func deleteProviderConfig() {
        guard let id = currentProviderId else { return }
        onDeleteProviderConfig?(id)
    }

    private var quotaDailyLimit: Int {
        quotaStore?.config.dailyTotalLimit ?? AIVisualQuotaConfig.default.dailyTotalLimit
    }

    private var quotaMonthlyLimit: Int {
        quotaStore?.config.monthlyTotalLimit ?? AIVisualQuotaConfig.default.monthlyTotalLimit
    }
}
