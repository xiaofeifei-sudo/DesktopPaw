import Foundation

public enum AppCommand: Equatable {
    case showPet
    case hidePet
    case clicked
    case pet
    case feed
    case sleepOrWake
    case playAction(ActionId)
    case resetPosition
    case openSettings
    case setLaunchAtLogin(Bool)
    case quit
    case importPetImage(URL, displayName: String)
    case importPetPackage(URL)
    case importPetdexPackage(URL)
    case importPetdexURL(String)
    case cancelPetdexURLImport
    case selectPet(String)
    case deletePet(String)
    case setSpeechBubbleEnabled(Bool)
    case setBubbleFrequency(BubbleFrequency)
    case setRelationshipPromptsEnabled(Bool)
    case quietForOneHour
    case clearQuietMode
    case selectMicroDialogOption(MicroDialogOptionId)
    case openChatPanel(petId: String)
    case closeChatPanel
    case sendChatMessage(text: String, petId: String)
    case toggleAI(enabled: Bool)
    case clearAIMemory(petId: String)
    case exportAIMemory(petId: String)
    case deleteAIMemory(memoryId: String, petId: String)
    case updateAIPreferences(AICompanionPreferences)
    case selectPersonality(profileId: String)
    case importContentPack(from: URL)
    case removeContentPack(packId: String)
    case enableContentPack(packId: String)
    case disableContentPack(packId: String)
    case restoreDefaultContent
}

public struct AppMenuState: Equatable {
    public var isPetVisible: Bool
    public var isSleeping: Bool
    public var isLaunchAtLoginEnabled: Bool
    public var isSpeechBubbleEnabled: Bool
    public var isQuietModeActive: Bool
    public var actionNotice: String?

    public init(
        isPetVisible: Bool,
        isSleeping: Bool,
        isLaunchAtLoginEnabled: Bool,
        isSpeechBubbleEnabled: Bool = true,
        isQuietModeActive: Bool = false,
        actionNotice: String? = nil
    ) {
        self.isPetVisible = isPetVisible
        self.isSleeping = isSleeping
        self.isLaunchAtLoginEnabled = isLaunchAtLoginEnabled
        self.isSpeechBubbleEnabled = isSpeechBubbleEnabled
        self.isQuietModeActive = isQuietModeActive
        self.actionNotice = actionNotice
    }
}
