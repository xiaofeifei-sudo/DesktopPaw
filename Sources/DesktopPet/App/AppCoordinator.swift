import AppKit
import SwiftUI

@MainActor
public protocol PetWindowControlling: AnyObject {
    var isPetVisible: Bool { get }

    func showPet()
    func hidePet()
    func resetPosition()
    func saveStateBeforeQuit()
}

@MainActor
public protocol PetCommandHandling: AnyObject {
    var isSleeping: Bool { get }
    var runtimeState: PetRuntimeState { get }
    var catalog: PetActionCatalog { get }

    func clicked()
    func pet()
    func feed()
    func sleep()
    func wake()
    func dragStarted()
    func dragEnded()
    func playAction(_ id: ActionId)
    func setScale(_ scale: Double)
    func setRandomWalkingEnabled(_ enabled: Bool)
    func tick(at date: Date)
}

@MainActor
public protocol PetLibraryCommanding: AnyObject {
    func importPetImage(at url: URL, displayName: String)
    func importPetPackage(at url: URL)
    func importPetdexPackage(at url: URL)
    func importPetdexURL(_ input: String)
    func cancelPetdexURLImport()
    func selectPet(id: String)
    func deletePet(id: String)
}

@MainActor
public protocol BubbleCommanding: AnyObject {
    func setSpeechBubbleEnabled(_ enabled: Bool)
    func setBubbleFrequency(_ frequency: BubbleFrequency)
    func handleInteraction(_ event: PetEvent, state: PetRuntimeState, at date: Date)
    func handleTick(state: PetRuntimeState, at date: Date)
    func handleCompanionInteraction(_ trigger: BubbleTrigger, context: CompanionContext, at date: Date)
    func handleCompanionTick(context: CompanionContext, at date: Date)
    var currentBubble: PetBubble? { get }
}

@MainActor
public protocol SettingsWindowControlling: AnyObject {
    func showSettings()
}

@MainActor
public protocol LaunchAtLoginControlling: AnyObject {
    var isLaunchAtLoginEnabled: Bool { get }

    func setLaunchAtLoginEnabled(_ enabled: Bool)
}

@MainActor
public protocol ApplicationTerminating: AnyObject {
    func terminate()
}

@MainActor
public final class AppCoordinator {
    private let petWindow: PetWindowControlling
    private let petCommands: PetCommandHandling
    private let settingsWindow: SettingsWindowControlling
    private let launchAtLogin: LaunchAtLoginControlling
    private let soundPlayer: PetSoundPlaying
    private let application: ApplicationTerminating
    private let actionTriggerService: ActionTriggerServicing
    private let actionCatalogProvider: () -> PetActionCatalog
    private let library: PetLibraryCommanding?
    private let bubble: BubbleCommanding?
    private let companionRouter: CompanionEventRouting?
    private let microDialogService: (any MicroDialogServicing)?
    private let chatPanel: ChatPanelControlling?
    private let aiPreferencesStore: AICompanionPreferencesStore?
    private let aiMemoryStore: AIMemoryStoring?
    private let contentPackManager: ContentPackManaging?
    private let onContentPacksChanged: (() -> Void)?
    private let now: () -> Date
    private var actionNotice: String?
    private var isSpeechBubbleEnabled: Bool = true
    private var isQuietModeActive: Bool = false

    public var onQuietModeStateChanged: ((Bool) -> Void)?

    public init(
        petWindow: PetWindowControlling,
        petCommands: PetCommandHandling,
        settingsWindow: SettingsWindowControlling,
        launchAtLogin: LaunchAtLoginControlling,
        soundPlayer: PetSoundPlaying = SilentPetSoundPlayer(),
        application: ApplicationTerminating,
        actionTriggerService: ActionTriggerServicing? = nil,
        actionCatalogProvider: (() -> PetActionCatalog)? = nil,
        library: PetLibraryCommanding? = nil,
        bubble: BubbleCommanding? = nil,
        companionRouter: CompanionEventRouting? = nil,
        microDialogService: (any MicroDialogServicing)? = nil,
        chatPanel: ChatPanelControlling? = nil,
        aiPreferencesStore: AICompanionPreferencesStore? = nil,
        aiMemoryStore: AIMemoryStoring? = nil,
        contentPackManager: ContentPackManaging? = nil,
        onContentPacksChanged: (() -> Void)? = nil,
        speechBubbleEnabled: Bool = true,
        now: @escaping () -> Date = { Date() }
    ) {
        self.petWindow = petWindow
        self.petCommands = petCommands
        self.settingsWindow = settingsWindow
        self.launchAtLogin = launchAtLogin
        self.soundPlayer = soundPlayer
        self.application = application
        self.actionTriggerService = actionTriggerService ?? ActionTriggerService(commandHandler: petCommands)
        self.actionCatalogProvider = actionCatalogProvider ?? { [petCommands] in petCommands.catalog }
        self.library = library
        self.bubble = bubble
        self.companionRouter = companionRouter
        self.microDialogService = microDialogService
        self.chatPanel = chatPanel
        self.aiPreferencesStore = aiPreferencesStore
        self.aiMemoryStore = aiMemoryStore
        self.contentPackManager = contentPackManager
        self.onContentPacksChanged = onContentPacksChanged
        self.isSpeechBubbleEnabled = speechBubbleEnabled
        self.now = now

        let previousRejectionHandler = self.actionTriggerService.onTriggerRejected
        self.actionTriggerService.onTriggerRejected = { [weak self] actionId, eligibility in
            previousRejectionHandler?(actionId, eligibility)
            self?.recordActionTriggerResult(eligibility)
        }
    }

    public var menuState: AppMenuState {
        AppMenuState(
            isPetVisible: petWindow.isPetVisible,
            isSleeping: petCommands.isSleeping,
            isLaunchAtLoginEnabled: launchAtLogin.isLaunchAtLoginEnabled,
            isSpeechBubbleEnabled: isSpeechBubbleEnabled,
            isQuietModeActive: isQuietModeActive,
            actionNotice: actionNotice
        )
    }

    public var actionCatalog: PetActionCatalog {
        actionCatalogProvider()
    }

    public func eligibility(for actionId: ActionId) -> ActionTriggerEligibility {
        actionTriggerService.eligibility(for: actionId)
    }

    public func start() {
        if petWindow.isPetVisible {
            petWindow.showPet()
        }
    }

    public func handle(_ command: AppCommand) {
        switch command {
        case .showPet:
            petWindow.showPet()
        case .hidePet:
            petWindow.hidePet()
        case .clicked:
            petCommands.clicked()
            soundPlayer.play(.click)
            companionRouter?.handle(.directInteraction(.click, now()), runtimeState: petCommands.runtimeState)
            emitBubble(trigger: .clicked, event: .clicked)
        case .pet:
            petCommands.pet()
            soundPlayer.play(.pet)
            companionRouter?.handle(.directInteraction(.pet, now()), runtimeState: petCommands.runtimeState)
            emitBubble(trigger: .pet, event: .pet)
        case .feed:
            petCommands.feed()
            soundPlayer.play(.feed)
            companionRouter?.handle(.directInteraction(.feed, now()), runtimeState: petCommands.runtimeState)
            emitBubble(trigger: .feed, event: .feed)
        case .sleepOrWake:
            if petCommands.isSleeping {
                petCommands.wake()
                companionRouter?.handle(.wakeRequested(now()), runtimeState: petCommands.runtimeState)
            } else {
                petCommands.sleep()
                companionRouter?.handle(.sleepRequested(now()), runtimeState: petCommands.runtimeState)
            }
            actionNotice = nil
        case .playAction(let actionId):
            let result = actionTriggerService.trigger(actionId: actionId)
            if case .allowed = result {
                companionRouter?.handle(.actionPlayed(actionId, now()), runtimeState: petCommands.runtimeState)
            }
            recordActionTriggerResult(result)
        case .resetPosition:
            petWindow.resetPosition()
        case .openSettings:
            settingsWindow.showSettings()
        case .setLaunchAtLogin(let enabled):
            launchAtLogin.setLaunchAtLoginEnabled(enabled)
        case .quit:
            prepareForTermination()
            application.terminate()
        case .importPetImage(let url, let displayName):
            library?.importPetImage(at: url, displayName: displayName)
        case .importPetPackage(let url):
            library?.importPetPackage(at: url)
        case .importPetdexPackage(let url):
            library?.importPetdexPackage(at: url)
        case .importPetdexURL(let input):
            library?.importPetdexURL(input)
        case .cancelPetdexURLImport:
            library?.cancelPetdexURLImport()
        case .selectPet(let id):
            library?.selectPet(id: id)
        case .deletePet(let id):
            library?.deletePet(id: id)
        case .setBubbleFrequency(let frequency):
            bubble?.setBubbleFrequency(frequency)
        case .setSpeechBubbleEnabled(let enabled):
            isSpeechBubbleEnabled = enabled
            bubble?.setSpeechBubbleEnabled(enabled)
        case .setRelationshipPromptsEnabled:
            break
        case .quietForOneHour:
            handleQuietForOneHour()
        case .clearQuietMode:
            handleClearQuietMode()
        case .selectMicroDialogOption(let optionId):
            handleMicroDialogOption(optionId)
        case .openChatPanel(let petId):
            chatPanel?.showChatPanel(petId: petId)
        case .closeChatPanel:
            chatPanel?.closeChatPanel()
        case .sendChatMessage(let text, let petId):
            if let preferences = aiPreferencesStore?.loadPreferences(), !preferences.isAIEnabled {
                return
            }
            chatPanel?.sendMessage(text, petId: petId)
        case .toggleAI(let enabled):
            aiPreferencesStore?.setAIEnabled(enabled)
            if !enabled {
                chatPanel?.closeChatPanel()
            }
        case .clearAIMemory(let petId):
            try? aiMemoryStore?.clearAll(petId: petId)
        case .exportAIMemory(let petId):
            _ = try? aiMemoryStore?.exportMemories(petId: petId)
        case .deleteAIMemory(let memoryId, let petId):
            try? aiMemoryStore?.delete(memoryId: memoryId, petId: petId)
        case .updateAIPreferences(let preferences):
            aiPreferencesStore?.savePreferences(preferences)
        case .selectPersonality(let profileId):
            aiPreferencesStore?.setSelectedPersonalityId(profileId)
        case .importContentPack(let url):
            mutateContentPacks {
                _ = try $0.importPack(from: url)
            }
        case .removeContentPack(let packId):
            mutateContentPacks {
                try $0.removePack(packId)
            }
        case .enableContentPack(let packId):
            mutateContentPacks {
                try $0.enablePack(packId)
            }
        case .disableContentPack(let packId):
            mutateContentPacks {
                try $0.disablePack(packId)
            }
        case .restoreDefaultContent:
            mutateContentPacks {
                try $0.restoreDefaultContent()
            }
        }
    }

    public func tick(at date: Date) {
        petCommands.tick(at: date)
        bubble?.handleTick(state: petCommands.runtimeState, at: date)
    }

    public func prepareForTermination() {
        petWindow.saveStateBeforeQuit()
    }

    private func handleQuietForOneHour() {
        isQuietModeActive = true
        onQuietModeStateChanged?(true)
    }

    private func handleClearQuietMode() {
        isQuietModeActive = false
        onQuietModeStateChanged?(false)
    }

    private func recordActionTriggerResult(_ result: ActionTriggerEligibility) {
        switch result {
        case .allowed:
            actionNotice = nil
        case .rejectedBusy(let reason):
            actionNotice = reason
        case .rejectedThrottled:
            actionNotice = "动作触发太快，稍后再试"
        case .rejectedUnknownActionId:
            actionNotice = "动作不可用"
        }
    }

    private func mutateContentPacks(_ mutation: (ContentPackManaging) throws -> Void) {
        guard let contentPackManager else { return }
        do {
            try mutation(contentPackManager)
            onContentPacksChanged?()
        } catch {
            DesktopPetLog.petLibrary.warning("Content pack command failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func emitBubble(trigger: BubbleTrigger, event: PetEvent) {
        let state = petCommands.runtimeState
        let date = now()
        if let context = companionRouter?.context(runtimeState: state) {
            bubble?.handleCompanionInteraction(trigger, context: context, at: date)
        } else {
            bubble?.handleInteraction(event, state: state, at: date)
        }
    }

    private func handleMicroDialogOption(_ optionId: MicroDialogOptionId) {
        guard let service = microDialogService else { return }
        let command = service.command(for: optionId, now: now())
        service.dismissActiveDialog()

        if let router = companionRouter {
            _ = router.handle(.microDialogCompleted(optionId, now()), runtimeState: petCommands.runtimeState)
        }

        guard let command else { return }

        switch command {
        case .pet:
            handle(.pet)
        case .feed:
            handle(.feed)
        case .sleep:
            petCommands.sleep()
        case .dismiss(let replyTrigger):
            if let trigger = replyTrigger {
                emitBubble(trigger: trigger, event: .clicked)
            }
        case .showBubble(let trigger):
            emitBubble(trigger: trigger, event: .clicked)
        }
    }
}

@MainActor
final class SwitchablePetCommandHandler: PetCommandHandling {
    private var current: PetEngineCommandHandler {
        didSet {
            bindStateChanged()
        }
    }

    var onStateChanged: ((PetRuntimeState) -> Void)? {
        didSet {
            bindStateChanged()
        }
    }

    init(current: PetEngineCommandHandler) {
        self.current = current
    }

    var isSleeping: Bool {
        current.isSleeping
    }

    var runtimeState: PetRuntimeState {
        current.runtimeState
    }

    var catalog: PetActionCatalog {
        current.catalog
    }

    func replaceCurrent(
        catalog: PetActionCatalog,
        initialState: PetRuntimeState,
        isRandomWalkingEnabled: Bool
    ) {
        let randomNumberGenerator = SystemRandomNumberGenerator()
        current = PetEngineCommandHandler(
            engine: PetEngine(
                catalog: catalog,
                initialState: initialState,
                isRandomWalkingEnabled: isRandomWalkingEnabled,
                randomNumberGenerator: randomNumberGenerator
            ),
            catalog: catalog
        )
    }

    func clicked() {
        current.clicked()
    }

    func pet() {
        current.pet()
    }

    func feed() {
        current.feed()
    }

    func sleep() {
        current.sleep()
    }

    func wake() {
        current.wake()
    }

    func dragStarted() {
        current.dragStarted()
    }

    func dragEnded() {
        current.dragEnded()
    }

    func playAction(_ id: ActionId) {
        current.playAction(id)
    }

    func setScale(_ scale: Double) {
        current.setScale(scale)
    }

    func setRandomWalkingEnabled(_ enabled: Bool) {
        current.setRandomWalkingEnabled(enabled)
    }

    func tick(at date: Date) {
        current.tick(at: date)
    }

    func applyInteractiveBubbleEffect(changes: StateChanges, animation: PetState?) {
        current.applyInteractiveBubbleEffect(changes: changes, animation: animation)
    }

    private func bindStateChanged() {
        current.onStateChanged = { [weak self] state in
            self?.onStateChanged?(state)
        }
    }
}

@MainActor
final class NSApplicationTerminator: ApplicationTerminating {
    func terminate() {
        NSApp.terminate(nil)
    }
}

@MainActor
final class AppDependencyContainer {
    let petWindow: PetWindowController
    let petCommands: SwitchablePetCommandHandler
    let launchAtLogin: LaunchAtLoginController
    let settingsViewModel: SettingsViewModel
    let soundPlayer: PetSoundPlayer
    let library: PetLibraryCommander
    let bubble: BubbleCommander
    let libraryViewModel: PetLibraryViewModel
    let importViewModel: PetImportViewModel
    let petdexURLImportViewModel: PetdexURLImportViewModel
    let actionLibraryViewModel: ActionLibraryViewModel
    let actionTriggerService: ActionTriggerService
    let companionSettingsViewModel: CompanionshipSettingsViewModel
    let aiSettingsViewModel: AISettingsViewModel
    let aiVisualSettingsViewModel: AIVisualSettingsViewModel
    let interactiveBubbleSettingsViewModel: InteractiveBubbleSettingsViewModel
    private let preferencesStore: PreferencesStore
    let companionPreferencesStore: CompanionPreferencesStore
    let companionEventRouter: CompanionEventRouter
    private let petViewModel: PetViewModel
    private let petEngineTimer: PetEngineTimer
    private let store: PetLibraryStore
    private let bubbleEngine: BubbleEngine
    let microDialogService: MicroDialogService
    private let quietModePolicy: QuietModePolicy
    private let rendererFactory: PetRenderableFactory
    private(set) var currentDefinition: PetDefinition
    let chatPanelController: ChatPanelController
    let aiPreferencesStore: AICompanionPreferencesStore
    let aiMemoryStore: AIMemoryStore
    let emotionalModelStore: EmotionalModelStore
    let emotionalTrackingService: EmotionalTrackingService
    let proactiveMemoryEngine: ProactiveMemoryEngine
    let contentPackManager: ContentPackManager
    let aiChatEngine: AIChatEngine
    private let aiBubbleBridge: AIBubbleBridge
    private let interactiveBubbleScheduler: InteractiveBubbleScheduler
    private let interactiveBubblePresenter: InteractiveBubblePresenter
    private let interactiveBubbleContentGenerator: InteractiveBubbleContentGenerator
    private let interactiveBubbleOptionHandler: InteractiveBubbleOptionHandler
    private let interactiveBubbleSettingsStore: InteractiveBubbleSettingsStore
    private let aiVisualPreferencesStore: AIVisualPreferencesStore
    private let visualGenerationService: VisualGenerationServicing
    private let visualProviderRegistry: VisualGenerationProviderRegistry
    private let petVisualStateController: PetVisualStateController
    private let petVisualPreferenceStore: PetVisualPreferenceStore
    private let visualActionMediator: AIVisualActionMediator
    private var mmxGenerator: MiniMaxCLIImageGenerator
    private let minimaxApiGenerator: MiniMaxAPIImageGenerator
    private let aliyunGenerator: AliyunImageGenerator
    private let siliconFlowGenerator: SiliconFlowImageGenerator
    private let openaiCompatibleGenerator: OpenAICompatibleImageGenerator
    private let tencentGenerator: TencentImageGenerator
    private let apiProviderConfigStore: APIProviderConfigStore
    private var interactiveBubbleRecentTexts: [String] = []

    init() {
        let store = PetLibraryStore()
        let importer = PetImageImporter()
        let packageImporter = PetPackageImporter()
        let petdexPackageImporter = PetdexPackageImporter()
        let manifestWriter = PetLibraryManifestWriter()
        let rendererFactory = DefaultPetRenderableFactory()
        let actionOverrideStore = PetActionOverrideStore(petsDirectoryURL: store.importedPetsDirectoryURL)
        let actionPackOverrideStore = FileActionPackOverrideStore(petsDirectoryURL: store.importedPetsDirectoryURL)

        let preferencesStore = PreferencesStore(
            knownPetIdsProvider: {
                let items = (try? store.listPets()) ?? []
                return Set(items.map(\.id))
            },
            frameSizeProvider: { CGSize(width: 128, height: 128) }
        )

        let definition: PetDefinition
        do {
            definition = try store.loadDefinition(id: preferencesStore.selectedPetId)
        } catch {
            DesktopPetLog.petLibrary.error("Failed to load selected pet definition; falling back to built-in: \(error.localizedDescription, privacy: .public)")
            definition = (try? BuiltInPetDefinitionProvider().loadBuiltInPet()) ?? Self.fallbackDefinition()
        }

        let contentPackManager = ContentPackManager()
        let initialActionCatalog = contentPackManager.enabledActionCatalog(merging: definition.catalog)
        let initialState = preferencesStore.loadRuntimeState()
        let engineRandom = SystemRandomNumberGenerator()
        let commands = SwitchablePetCommandHandler(current: PetEngineCommandHandler(
            engine: PetEngine(
                catalog: initialActionCatalog,
                initialState: initialState,
                isRandomWalkingEnabled: preferencesStore.isRandomWalkingEnabled,
                randomNumberGenerator: engineRandom
            ),
            catalog: initialActionCatalog
        ))
        let actionTriggerService = ActionTriggerService(commandHandler: commands)
        let viewModel = PetViewModel(runtimeState: commands.runtimeState, definition: definition)
        let launchAtLogin = LaunchAtLoginController()
        let settingsViewModel = SettingsViewModel(
            isPetVisible: preferencesStore.isPetVisible,
            petScale: initialState.scale,
            isRandomWalkingEnabled: preferencesStore.isRandomWalkingEnabled,
            isSoundEnabled: preferencesStore.isSoundEnabled,
            isLaunchAtLoginEnabled: launchAtLogin.isLaunchAtLoginEnabled,
            isSpeechBubbleEnabled: preferencesStore.isSpeechBubbleEnabled,
            bubbleFrequency: preferencesStore.bubbleFrequency,
            runtimeState: commands.runtimeState
        )

        let folderURL = Self.folderURL(for: definition, store: store)
        let renderer = rendererFactory.makeRenderer(for: definition, folderURL: folderURL)
        let initialFrameSize = PetView.renderSize(for: definition, state: commands.runtimeState)

        let quietModePolicy = QuietModePolicy()
        let microDialogService = MicroDialogService(quietModePolicy: quietModePolicy)
        let bubbleProfile = definition.resolvedBubbleProfile()
        let contextualProvider = ContextualBubblePhraseProvider(
            catalog: contentPackManager.enabledBubbleCatalog(
                merging: BubblePhraseCatalogBuilder().build(from: bubbleProfile)
            ),
            quietModePolicy: quietModePolicy
        )
        let sharedScheduler = BubbleScheduler()
        let bubbleEngine = BubbleEngine(
            profile: bubbleProfile,
            isEnabled: preferencesStore.isSpeechBubbleEnabled,
            frequency: preferencesStore.bubbleFrequency,
            phraseProvider: DefaultBubblePhraseProvider(profile: bubbleProfile),
            contextualPhraseProvider: contextualProvider,
            quietModePolicy: quietModePolicy,
            microDialogService: microDialogService,
            scheduler: sharedScheduler
        )
        let bubbleCommander = BubbleCommander(bubbleEngine: bubbleEngine)
        let libraryCommander = PetLibraryCommander(
            store: store,
            importer: importer,
            packageImporter: packageImporter,
            petdexPackageImporter: petdexPackageImporter,
            manifestWriter: manifestWriter,
            preferences: preferencesStore,
            actionPackOverrideStore: actionPackOverrideStore
        )
        let libraryViewModel = PetLibraryViewModel(
            store: store,
            selectedPetIdProvider: { [preferencesStore] in preferencesStore.selectedPetId }
        )
        let importViewModel = PetImportViewModel(
            imageSelecting: PetImageOpenPanel(),
            packageSelecting: PetPackageOpenPanel()
        )
        let petdexURLImportViewModel = PetdexURLImportViewModel()
        let actionLibraryViewModel = ActionLibraryViewModel(
            definition: definition,
            triggerService: actionTriggerService,
            previewProvider: ActionLibraryViewModel.defaultPreviewProvider(
                rendererFactory: rendererFactory,
                folderURLProvider: { [store] definition in
                    Self.folderURL(for: definition, store: store)
                }
            ),
            overrideStore: actionOverrideStore,
            actionPackOverrideStore: actionPackOverrideStore,
            actionPackCommander: libraryCommander
        )

        let companionPreferencesStore = CompanionPreferencesStore()
        let relationshipStore = RelationshipStore()
        let companionEventRouter = CompanionEventRouter(
            petId: definition.id,
            petDisplayName: definition.displayName,
            relationshipStore: relationshipStore,
            preferencesStore: companionPreferencesStore
        )
        let companionSettingsViewModel = CompanionshipSettingsViewModel(
            currentPetId: definition.id,
            relationship: companionEventRouter.context(runtimeState: commands.runtimeState).relationship,
            preferences: companionPreferencesStore.loadPreferences()
        )

        let aiPreferencesStore = AICompanionPreferencesStore()
        let aiMemoryStore = AIMemoryStore()
        let emotionalModelStore = EmotionalModelStore()
        let emotionalTrackingService = EmotionalTrackingService()
        let proactiveMemoryEngine = ProactiveMemoryEngine(petId: definition.id)

        let keychainStore = KeychainStore()
        let savedPrefs = aiPreferencesStore.loadPreferences()
        let savedProtocol = savedPrefs.providerProtocol
        let providerKeyId = savedProtocol == .anthropic ? "anthropic" : "http-openai"
        let hasExistingKey = keychainStore.loadAPIKey(for: providerKeyId) != nil
        let aiSettingsViewModel = AISettingsViewModel(
            preferences: savedPrefs,
            isConfigured: hasExistingKey,
            profiles: contentPackManager.availablePersonalityProfiles(base: AIPersonalityProfile.defaultProfiles),
            memoryViewModel: AIMemoryViewModel(memoryStore: aiMemoryStore, petId: definition.id),
            memoryManagementViewModel: MemoryManagementViewModel(
                memoryStore: aiMemoryStore,
                emotionalModelStore: emotionalModelStore,
                petId: definition.id
            )
        )

        let defaultEndpoint: String
        let defaultModel: String
        if savedProtocol == .anthropic {
            defaultEndpoint = savedPrefs.providerEndpoint ?? "https://api.anthropic.com"
            defaultModel = savedPrefs.providerModel ?? "claude-sonnet-4-20250514"
        } else {
            defaultEndpoint = savedPrefs.providerEndpoint ?? "https://api.openai.com/v1"
            defaultModel = savedPrefs.providerModel ?? "gpt-4o-mini"
        }
        let restoredConfig = AIProviderConfig(
            endpoint: URL(string: defaultEndpoint)!,
            model: defaultModel
        )
        let existingProvider: AIProviding
        if hasExistingKey {
            existingProvider = savedProtocol == .anthropic
                ? AnthropicAIProvider(config: restoredConfig, keychainStore: keychainStore)
                : HTTPAIProvider(config: restoredConfig, keychainStore: keychainStore)
        } else {
            existingProvider = MockAIProvider()
        }
        self.aiMemoryStore = aiMemoryStore
        self.emotionalModelStore = emotionalModelStore
        self.emotionalTrackingService = emotionalTrackingService
        self.proactiveMemoryEngine = proactiveMemoryEngine
        let aiSafetyService = AISafetyService()

        let aiVisualPreferencesStore = AIVisualPreferencesStore()

        let aiPersonalityEngine = AIPersonalityEngine(
            composer: AIPromptComposer(
                visualPromptPolicy: AIVisualPromptPolicy(),
                isVisualExpressionEnabledProvider: { [aiVisualPreferencesStore] in
                    aiVisualPreferencesStore.loadPreferences().isEnabled
                }
            )
        )
        let aiChatEngine = AIChatEngine(
            provider: existingProvider,
            memoryStore: aiMemoryStore,
            safetyService: aiSafetyService,
            personalityEngine: aiPersonalityEngine,
            memoryPromptComposer: MemoryPromptComposer(),
            emotionalModelStore: emotionalModelStore,
            personalityProfileProvider: { [aiPreferencesStore, contentPackManager] in
                let selectedId = aiPreferencesStore.loadPreferences().selectedPersonalityId
                let profiles = contentPackManager.availablePersonalityProfiles(base: AIPersonalityProfile.defaultProfiles)
                return profiles.first { $0.id == selectedId } ?? .gentle
            },
            visualActionParser: AIVisualActionParser()
        )

        self.preferencesStore = preferencesStore
        self.petCommands = commands
        self.actionTriggerService = actionTriggerService
        self.settingsViewModel = settingsViewModel
        self.petViewModel = viewModel
        self.launchAtLogin = launchAtLogin
        self.soundPlayer = PetSoundPlayer(isSoundEnabled: { [preferencesStore] in
            preferencesStore.isSoundEnabled
        })
        self.store = store
        self.bubbleEngine = bubbleEngine
        self.microDialogService = microDialogService
        self.quietModePolicy = quietModePolicy
        self.bubble = bubbleCommander
        self.library = libraryCommander
        self.companionPreferencesStore = companionPreferencesStore
        self.companionEventRouter = companionEventRouter
        self.companionSettingsViewModel = companionSettingsViewModel
        self.aiSettingsViewModel = aiSettingsViewModel
        self.aiPreferencesStore = aiPreferencesStore
        self.contentPackManager = contentPackManager
        self.libraryViewModel = libraryViewModel
        self.importViewModel = importViewModel
        self.petdexURLImportViewModel = petdexURLImportViewModel
        self.actionLibraryViewModel = actionLibraryViewModel
        self.rendererFactory = rendererFactory
        self.currentDefinition = definition

        let ibSettingsStore = InteractiveBubbleSettingsStore()
        let ibSettingsViewModel = InteractiveBubbleSettingsViewModel(
            settings: ibSettingsStore,
            isAIConfigured: aiSettingsViewModel.isConfigured
        )

        let visualProviderRegistry = VisualGenerationProviderRegistry()
        let visualGenerationService = VisualGenerationService(registry: visualProviderRegistry)
        let visualQuotaStore = AIVisualQuotaStore()
        let savedVisualPrefs = aiVisualPreferencesStore.loadPreferences()

        let mmxClient = MiniMaxCLIClient(processRunner: RealProcessRunner(), mmxPath: savedVisualPrefs.mmxPath)
        let mmxGenerator = MiniMaxCLIImageGenerator(client: mmxClient)
        visualProviderRegistry.register(mmxGenerator)

        let minimaxApiGenerator = MiniMaxAPIImageGenerator()
        let aliyunGenerator = AliyunImageGenerator()
        let siliconFlowGenerator = SiliconFlowImageGenerator()
        let openaiCompatibleGenerator = OpenAICompatibleImageGenerator()
        let tencentGenerator = TencentImageGenerator()
        let apiProviderConfigStore = APIProviderConfigStore()

        visualProviderRegistry.register(minimaxApiGenerator)
        visualProviderRegistry.register(aliyunGenerator)
        visualProviderRegistry.register(siliconFlowGenerator)
        visualProviderRegistry.register(openaiCompatibleGenerator)
        visualProviderRegistry.register(tencentGenerator)

        if savedVisualPrefs.selectedProviderId == nil {
            visualGenerationService.selectProvider(mmxGenerator.providerId)
        }

        let visualPolicy = AIVisualActionPolicy()
        let visualConfirmationController = AIVisualConfirmationController()
        let visualRateLimiter = AIVisualRateLimiter()
        let visualSafetyService = AIVisualSafetyService()
        let visualActionCoordinator = AIVisualActionCoordinator(
            policy: visualPolicy,
            confirmationController: visualConfirmationController,
            quotaStore: visualQuotaStore,
            rateLimiter: visualRateLimiter
        )
        let petVisualStateController = PetVisualStateController()
        let petVisualAssetStore = PetVisualAssetStore()
        let petVisualPreferenceStore = PetVisualPreferenceStore()
        let savedPetVisualPrefs = petVisualPreferenceStore.loadPreferences()
        let petVisualHistoryStore = PetVisualHistoryStore(
            assetStore: petVisualAssetStore,
            preferenceStore: petVisualPreferenceStore
        )
        let petReferenceImageProvider = PetReferenceImageProvider()
        let generationDiagnosticsStore = GenerationDiagnosticsStore()
        let petIdentityDescriptorStore = PetIdentityDescriptorStore(
            visualPreferenceStore: petVisualPreferenceStore
        )
        let promptStrategy = PromptStrategy()
        let referenceImagePipeline = ReferenceImagePipeline()
        let qualityGateChecker = QualityGateStore()
        let assetLifecycleManager = AssetLifecycleManager(assetStore: petVisualAssetStore)
        let userFeedbackStore = UserFeedbackStore()
        let visualActionMediator = AIVisualActionMediator(
            coordinator: visualActionCoordinator,
            generationService: visualGenerationService,
            assetStore: petVisualAssetStore,
            stateController: petVisualStateController,
            safetyService: visualSafetyService,
            quotaStore: visualQuotaStore,
            preferencesStore: aiVisualPreferencesStore,
            visualPreferenceStore: petVisualPreferenceStore,
            generationDiagnosticsRecorder: generationDiagnosticsStore,
            petIdentityDescriber: petIdentityDescriptorStore,
            promptStrategy: promptStrategy,
            referenceImageProvider: petReferenceImageProvider,
            referenceImagePipeline: referenceImagePipeline,
            qualityGateChecker: qualityGateChecker,
            lifecycleManager: assetLifecycleManager,
            feedbackStore: userFeedbackStore,
            getReferenceImage: { [weak rendererFactory] in
                guard let factory = rendererFactory else { return nil }
                let def = viewModel.definition
                guard let definition = def else { return nil }

                let petFolderURL = Self.folderURL(for: definition, store: store)

                if let previewName = definition.previewAssetName {
                    if let folder = petFolderURL,
                       let image = NSImage(contentsOf: folder.appendingPathComponent(previewName)) {
                        return image
                    }
                    if let url = SpriteSheetRenderer.bundledResourceURL(named: previewName),
                       let image = NSImage(contentsOf: url) {
                        return image
                    }
                }

                let renderer = factory.makeRenderer(for: definition, folderURL: petFolderURL)
                return renderer.fallbackImage()
            },
            viewModel: viewModel,
            hasActiveOverlayProvider: { [weak petVisualStateController] in
                petVisualStateController?.currentOverlay() != nil
            }
        )

        let aiVisualSettingsViewModel = AIVisualSettingsViewModel(
            preferences: savedVisualPrefs,
            providerInfos: visualGenerationService.availableProviders(),
            currentProviderId: savedVisualPrefs.selectedProviderId ?? visualGenerationService.currentProviderId(),
            isProviderConfigured: {
                if let id = savedVisualPrefs.selectedProviderId ?? visualGenerationService.currentProviderId() {
                    return visualGenerationService.availableProviders().first(where: { $0.providerId == id })?.isConfigured ?? false
                }
                return false
            }(),
            consistencyPreference: savedPetVisualPrefs.consistencyPreference(forPetId: definition.id),
            petVisualNotes: savedPetVisualPrefs.petVisualNotes?[definition.id] ?? "",
            mmxPath: savedVisualPrefs.mmxPath,
            petId: definition.id,
            quotaStore: visualQuotaStore,
            generationService: visualGenerationService
        )

        let aiVisualHistoryViewModel = AIVisualHistoryViewModel(
            historyStore: petVisualHistoryStore,
            petId: definition.id
        )
        aiVisualHistoryViewModel.onMarkFavorite = { assetId in
            try petVisualHistoryStore.markFavorite(assetId: assetId, petId: definition.id)
        }
        aiVisualHistoryViewModel.onUnmarkFavorite = { assetId in
            try petVisualHistoryStore.unmarkFavorite(assetId: assetId, petId: definition.id)
        }
        aiVisualHistoryViewModel.onRenameFavorite = { assetId, name in
            try petVisualHistoryStore.renameFavorite(assetId: assetId, petId: definition.id, name: name)
        }
        aiVisualHistoryViewModel.onDeleteRecord = { assetId in
            try petVisualHistoryStore.deleteRecord(assetId: assetId, petId: definition.id)
        }
        aiVisualHistoryViewModel.onSetActiveFavorite = { assetId in
            try petVisualHistoryStore.setActiveFavorite(assetId: assetId, petId: definition.id)
        }
        aiVisualHistoryViewModel.onClearActiveFavorite = {
            try petVisualHistoryStore.clearActiveFavorite(petId: definition.id)
        }
        aiVisualHistoryViewModel.onRecordFeedback = { asset, feedbackType in
            visualActionMediator.recordFeedback(type: feedbackType, asset: asset)
            let constraints = userFeedbackStore.learnedConstraintsFromStats(for: asset.petId)
            petIdentityDescriptorStore.updateLearnedConstraints(constraints, for: asset.petId)
        }
        aiVisualHistoryViewModel.onClearHistory = {
            try petVisualHistoryStore.clearHistory(petId: definition.id)
        }
        aiVisualHistoryViewModel.onClearAll = {
            try petVisualHistoryStore.clearAll(petId: definition.id)
        }
        aiVisualSettingsViewModel.historyModel = aiVisualHistoryViewModel

        Task { @MainActor in
            await mmxGenerator.refreshConfiguration()
            aiVisualSettingsViewModel.updateProviderInfos(visualGenerationService.availableProviders())
            aiVisualSettingsViewModel.updateCurrentProviderId(savedVisualPrefs.selectedProviderId ?? visualGenerationService.currentProviderId())
        }

        var capturedBubbleBridge: AIBubbleBridge?
        let capturedPetId = definition.id
        var capturedIBScheduler: InteractiveBubbleScheduler?
        var capturedIBPresenter: InteractiveBubblePresenter?
        var capturedIBContentGenerator: InteractiveBubbleContentGenerator?
        var capturedIBRecentTexts: [String] = []
        var capturedPetWindow: PetWindowController?
        let capturedViewModel = viewModel
        let capturedPetNickname = definition.displayName
        let capturedEmotionalModelStore = emotionalModelStore
        let capturedAIMemoryStore = aiMemoryStore
        let capturedPetVisualStateController = petVisualStateController
        let capturedPetIdentityDescriptorStore = petIdentityDescriptorStore
        var capturedVisualConfirmationPanel: NSPanel?

        visualActionMediator.onConfirmationRequested = { request in
            let panel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 340, height: 240),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            panel.title = "视觉变化确认"
            panel.isReleasedWhenClosed = false
            panel.level = .floating

            let confirmView = AIVisualConfirmationView(
                reason: request.reason.rawValue,
                description: request.candidate.description,
                onConfirm: {
                    visualActionMediator.confirmAction(requestId: request.id)
                    panel.orderOut(nil)
                    capturedVisualConfirmationPanel = nil
                },
                onCancel: {
                    visualActionMediator.rejectAction(requestId: request.id)
                    panel.orderOut(nil)
                    capturedVisualConfirmationPanel = nil
                }
            )
            panel.contentView = NSHostingView(rootView: confirmView)
            capturedVisualConfirmationPanel = panel

            if let petFrame = capturedPetWindow?.currentPanelFrame {
                panel.setFrameOrigin(NSPoint(x: petFrame.midX - 170, y: petFrame.maxY + 10))
            }
            panel.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }

        visualActionMediator.onVisualChanged = { _ in
            aiVisualSettingsViewModel.updateHasActiveOverlay(true)
            aiVisualSettingsViewModel.refreshUsage()
            let bubble = PetBubble(
                id: UUID(),
                text: "变了个样子～",
                priority: .relationship,
                createdAt: Date(),
                expiresAt: Date().addingTimeInterval(5)
            )
            capturedViewModel.update(bubble: bubble)
            capturedPetWindow?.updateBubble(bubble)
        }

        visualActionMediator.onVisualRestored = {
            aiVisualSettingsViewModel.updateHasActiveOverlay(false)
            let bubble = PetBubble(
                id: UUID(),
                text: "恢复原样啦～",
                priority: .relationship,
                createdAt: Date(),
                expiresAt: Date().addingTimeInterval(3)
            )
            capturedViewModel.update(bubble: bubble)
            capturedPetWindow?.updateBubble(bubble)
        }

        visualActionMediator.onPolicyDenied = { text in
            guard let text = text else { return }
            aiVisualSettingsViewModel.showFeedback(text)
            let bubble = PetBubble(
                id: UUID(),
                text: text,
                priority: .relationship,
                createdAt: Date(),
                expiresAt: Date().addingTimeInterval(4)
            )
            capturedViewModel.update(bubble: bubble)
            capturedPetWindow?.updateBubble(bubble)
        }

        visualActionMediator.onGenerationFailed = { _ in
            aiVisualSettingsViewModel.showFeedback("Generation failed. Check the image provider configuration.")
            aiVisualSettingsViewModel.refreshUsage()
            let bubble = PetBubble(
                id: UUID(),
                text: "没变出来，下次再试～",
                priority: .relationship,
                createdAt: Date(),
                expiresAt: Date().addingTimeInterval(3)
            )
            capturedViewModel.update(bubble: bubble)
            capturedPetWindow?.updateBubble(bubble)
        }

        let previewPresenter = PreviewPresenter(getWindowFrame: { [weak capturedPetWindow] in
            capturedPetWindow?.currentPanelFrame
        })

        visualActionMediator.onPreviewRequested = { asset, referencePreviewURL in
            let actions = PreviewActions(
                onApply: {
                    let prefs = await MainActor.run { aiVisualPreferencesStore.loadPreferences() }
                    let expiresAt = Date().addingTimeInterval(prefs.durationPreset.durationSeconds)
                    await MainActor.run {
                        visualActionMediator.applyAsset(asset, expiresAt: expiresAt)
                        aiVisualSettingsViewModel.updateHasActiveOverlay(true)
                        aiVisualSettingsViewModel.refreshUsage()
                    }
                },
                onDiscard: {
                    await MainActor.run {
                        visualActionMediator.discardAsset(asset)
                    }
                },
                onRetry: {
                    await MainActor.run {
                        visualActionMediator.retryAsset(asset, petId: capturedPetId, petName: capturedPetNickname)
                    }
                },
                onFeedback: { feedbackType in
                    await MainActor.run {
                        visualActionMediator.recordFeedback(type: feedbackType, asset: asset)
                    }

                    let feedbackStore = UserFeedbackStore()
                    let constraints = feedbackStore.learnedConstraintsFromStats(for: asset.petId)
                    capturedPetIdentityDescriptorStore.updateLearnedConstraints(constraints, for: asset.petId)
                }
            )
            previewPresenter.showPreview(asset: asset, referencePreviewURL: referencePreviewURL, actions: actions)
        }

        visualActionMediator.onGateRejected = { _, message in
            aiVisualSettingsViewModel.showFeedback(message)
            let bubble = PetBubble(
                id: UUID(),
                text: message,
                priority: .relationship,
                createdAt: Date(),
                expiresAt: Date().addingTimeInterval(5)
            )
            capturedViewModel.update(bubble: bubble)
            capturedPetWindow?.updateBubble(bubble)
        }

        self.petEngineTimer = PetEngineTimer { [weak commands, weak bubbleCommander, weak companionEventRouter] date in
            guard let commands else { return }
            commands.tick(at: date)
            if let router = companionEventRouter {
                let context = router.context(runtimeState: commands.runtimeState)
                bubbleCommander?.handleCompanionTick(context: context, at: date)
            } else {
                bubbleCommander?.handleTick(state: commands.runtimeState, at: date)
            }
            _ = capturedBubbleBridge?.checkAndEmitProactiveBubble(petId: capturedPetId)

            capturedPetVisualStateController.tickExpiry(viewModel: capturedViewModel)

            capturedIBPresenter?.checkTimeout(at: date)
            let relationshipContext = companionEventRouter?.context(runtimeState: commands.runtimeState)
            let emotionalModel = try? capturedEmotionalModelStore.loadModel(petId: capturedPetId)
            capturedIBScheduler?.updateFrequencyContext(
                runtimeState: commands.runtimeState,
                emotionalModel: emotionalModel,
                relationshipLevel: relationshipContext?.relationship.currentLevel ?? .acquaintance
            )
            if let ibScheduler = capturedIBScheduler,
               let ibPresenter = capturedIBPresenter,
               let ibContent = capturedIBContentGenerator,
               ibScheduler.checkTrigger(at: date) {
                let memorySnippets = capturedAIMemoryStore.loadAll(petId: capturedPetId)
                    .sorted { $0.importance > $1.importance }
                    .prefix(3)
                    .map(\.content)
                let bubbleContext = BubbleContext(
                    petId: capturedPetId,
                    petNickname: capturedPetNickname,
                    userNickname: "主人",
                    runtimeState: commands.runtimeState,
                    relationshipLevel: relationshipContext?.relationship.currentLevel ?? .acquaintance,
                    emotionalModel: emotionalModel,
                    recentBubbleTexts: capturedIBRecentTexts,
                    consecutiveNoResponse: ibScheduler.consecutiveNoResponse,
                    timeOfDay: .current,
                    memorySnippets: memorySnippets
                )
                Task {
                    let bubble = await ibContent.generate(context: bubbleContext) ?? ibContent.generateFallback(context: bubbleContext)
                    ibPresenter.show(bubble)
                    capturedViewModel.update(interactiveBubble: bubble)
                    capturedViewModel.update(bubble: nil)
                    capturedPetWindow?.updateInteractiveBubble(bubble)
                    capturedIBRecentTexts.append(bubble.text)
                    if capturedIBRecentTexts.count > 10 {
                        capturedIBRecentTexts.removeFirst(capturedIBRecentTexts.count - 10)
                    }
                }
            }
        }
        self.petWindow = PetWindowController(
            frameSize: initialFrameSize,
            initiallyVisible: preferencesStore.isPetVisible,
            frameStore: preferencesStore,
            contentViewProvider: { _ in
                NSHostingView(rootView: PetView(model: viewModel, definition: definition, renderer: renderer))
            }
        )
        capturedPetWindow = self.petWindow

        self.aiBubbleBridge = AIBubbleBridge(
            quietModePolicy: quietModePolicy,
            scheduler: sharedScheduler,
            getPreferences: { [companionPreferencesStore] in
                companionPreferencesStore.loadPreferences()
            },
            globalMinimumInterval: { [bubbleEngine] in
                bubbleEngine.effectiveMinimumInterval()
            },
            onBubbleEmitted: { [weak petViewModel, weak petWindow] (bubble: PetBubble) in
                petViewModel?.update(bubble: bubble)
                petWindow?.updateBubble(bubble)
            }
        )
        self.aiBubbleBridge.proactiveMemoryProducer = proactiveMemoryEngine
        self.aiBubbleBridge.memoryStore = aiMemoryStore
        self.aiBubbleBridge.emotionalModelStore = emotionalModelStore
        capturedBubbleBridge = self.aiBubbleBridge
        self.aiChatEngine = aiChatEngine
        self.chatPanelController = ChatPanelController(
            chatEngine: aiChatEngine,
            bubbleBridge: self.aiBubbleBridge,
            visualActionMediator: visualActionMediator,
            getPetWindowFrame: { [capturedPetWindow] in
                capturedPetWindow?.currentPanelFrame ?? .zero
            }
        )

        let ibScheduler = InteractiveBubbleScheduler(settings: ibSettingsStore)
        let ibPresenter = InteractiveBubblePresenter(settings: ibSettingsStore)
        let ibContentGenerator = InteractiveBubbleContentGenerator(
            aiProvider: existingProvider,
            safetyService: aiSafetyService
        )
        let ibOptionHandler = InteractiveBubbleOptionHandler()

        ibScheduler.isChatPanelOpen = { [chatPanelController] in
            chatPanelController.isPanelVisible
        }
        ibScheduler.hasHigherPriorityBubble = { [bubbleEngine] in
            guard let bubble = bubbleEngine.currentBubble else { return false }
            return bubble.priority.rawValue >= BubblePriority.state.rawValue
        }
        ibScheduler.globalMinInterval = { [bubbleEngine] in
            bubbleEngine.effectiveMinimumInterval()
        }
        ibPresenter.onTimeout = { [weak ibScheduler] in
            viewModel.update(interactiveBubble: nil)
            capturedPetWindow?.updateInteractiveBubble(nil)
            ibScheduler?.onBubbleDismissed()
        }
        ibPresenter.onFeedbackCompleted = {
            viewModel.update(interactiveBubbleFeedbackText: nil)
            capturedPetWindow?.updateInteractiveFeedback(nil)
            ibScheduler.onUserResponded()
        }
        let capturedChatPanelController = self.chatPanelController
        viewModel.onInteractiveBubbleOptionTap = { [weak commands] option in
            guard let commands else { return }
            guard let bubble = viewModel.interactiveBubble else { return }
            let result = OptionInteractionResult(bubble: bubble, selectedOption: option)
            var state = commands.runtimeState
            let outcome = ibOptionHandler.handle(result: result, state: &state)
            commands.applyInteractiveBubbleEffect(changes: outcome.stateChanges, animation: outcome.animationTrigger)
            if outcome.shouldOpenChat {
                ibPresenter.dismiss()
                viewModel.update(interactiveBubble: nil)
                capturedPetWindow?.updateInteractiveBubble(nil)
                capturedChatPanelController.showChatPanel(petId: definition.id)
                ibScheduler.onUserResponded()
            } else if let feedback = outcome.feedbackText {
                ibPresenter.dismissWithFeedback(feedback)
                viewModel.update(interactiveBubble: nil)
                capturedPetWindow?.updateInteractiveBubble(nil)
                viewModel.update(interactiveBubbleFeedbackText: feedback)
                capturedPetWindow?.updateInteractiveFeedback(feedback)
            } else {
                ibPresenter.dismiss()
                viewModel.update(interactiveBubble: nil)
                capturedPetWindow?.updateInteractiveBubble(nil)
                ibScheduler.onUserResponded()
            }
        }

        self.interactiveBubbleSettingsStore = ibSettingsStore
        self.aiVisualPreferencesStore = aiVisualPreferencesStore
        self.visualGenerationService = visualGenerationService
        self.visualProviderRegistry = visualProviderRegistry
        self.petVisualStateController = petVisualStateController
        self.petVisualPreferenceStore = petVisualPreferenceStore
        self.visualActionMediator = visualActionMediator
        self.mmxGenerator = mmxGenerator
        self.minimaxApiGenerator = minimaxApiGenerator
        self.aliyunGenerator = aliyunGenerator
        self.siliconFlowGenerator = siliconFlowGenerator
        self.openaiCompatibleGenerator = openaiCompatibleGenerator
        self.tencentGenerator = tencentGenerator
        self.apiProviderConfigStore = apiProviderConfigStore
        self.interactiveBubbleSettingsViewModel = ibSettingsViewModel
        self.aiVisualSettingsViewModel = aiVisualSettingsViewModel
        self.interactiveBubbleScheduler = ibScheduler
        self.interactiveBubblePresenter = ibPresenter
        self.interactiveBubbleContentGenerator = ibContentGenerator
        self.interactiveBubbleOptionHandler = ibOptionHandler
        capturedIBScheduler = ibScheduler
        capturedIBPresenter = ibPresenter
        capturedIBContentGenerator = ibContentGenerator

        self.petWindow.actionCatalogProvider = { [commands] in
            commands.catalog
        }
        self.petWindow.actionTriggerService = actionTriggerService
        self.petWindow.microDialogOptionsProvider = { [weak self] in
            guard let self else { return nil }
            return self.microDialogService.activeDialogOptions(now: Date())
        }

        self.petWindow.onVisibilityChanged = { [preferencesStore] isVisible in
            preferencesStore.isPetVisible = isVisible
            settingsViewModel.updatePetVisibility(isVisible)
        }
        commands.onStateChanged = { [weak self] state in
            guard let self else { return }
            self.petViewModel.update(state)
            self.settingsViewModel.updateRuntimeState(state)
            self.preferencesStore.saveRuntimeState(state)
            self.petWindow.updateFrameSize(PetView.renderSize(for: self.currentDefinition, state: state))
            self.actionLibraryViewModel.refreshEligibility()
        }
        bubbleCommander.onBubbleChanged = { [weak self] bubble in
            guard let self else { return }
            self.petViewModel.update(bubble: bubble)
            self.petWindow.updateBubble(bubble)
        }
        libraryCommander.onLibraryChanged = { [weak libraryViewModel] in
            libraryViewModel?.reload()
        }
        libraryCommander.onCurrentPetChanged = { [weak self] definition in
            self?.applyCurrentPet(definition)
        }
        libraryCommander.onImportFailed = { [weak libraryViewModel, weak importViewModel] error in
            libraryViewModel?.presentImportError(error)
            importViewModel?.reportImportFailed(error)
        }
        libraryCommander.onPetdexImportFailed = { [weak importViewModel] error in
            importViewModel?.reportPetdexImportFailed(error)
        }
        libraryCommander.onPetdexURLImportPhaseChanged = { [weak petdexURLImportViewModel] phase in
            petdexURLImportViewModel?.reportPhase(phase)
        }
        libraryCommander.onPetdexURLImportSucceeded = { [weak petdexURLImportViewModel] in
            petdexURLImportViewModel?.reportImportSucceeded()
        }
        libraryCommander.onPetdexURLImportFailed = { [weak petdexURLImportViewModel] error in
            petdexURLImportViewModel?.reportImportFailed(error)
        }
        libraryCommander.onPetdexURLImportCancelled = { [weak petdexURLImportViewModel] in
            petdexURLImportViewModel?.reportImportCancelled()
        }
        libraryCommander.onDeleteFailed = { [weak libraryViewModel] error in
            libraryViewModel?.presentImportError(error)
        }

        libraryViewModel.reload()
        ibScheduler.updateFrequencyContext(
            runtimeState: commands.runtimeState,
            emotionalModel: try? emotionalModelStore.loadModel(petId: definition.id),
            relationshipLevel: companionEventRouter.context(runtimeState: commands.runtimeState).relationship.currentLevel
        )
        ibScheduler.start()
        self.petEngineTimer.start()
    }

    func configureSettingsActions(coordinator: AppCoordinator, menuBarController: MenuBarController) {
        settingsViewModel.onPetVisibilityChanged = { [weak coordinator, weak menuBarController] isVisible in
            coordinator?.handle(isVisible ? .showPet : .hidePet)
            menuBarController?.refresh()
        }
        settingsViewModel.onScaleChanged = { [weak self] scale in
            self?.preferencesStore.petScale = scale
            self?.petCommands.setScale(scale)
        }
        settingsViewModel.onRandomWalkingChanged = { [weak self] enabled in
            self?.preferencesStore.isRandomWalkingEnabled = enabled
            self?.petCommands.setRandomWalkingEnabled(enabled)
        }
        settingsViewModel.onSoundChanged = { [weak self] enabled in
            self?.preferencesStore.isSoundEnabled = enabled
        }
        settingsViewModel.onLaunchAtLoginChanged = { [weak coordinator, weak menuBarController, weak settingsViewModel] enabled in
            coordinator?.handle(.setLaunchAtLogin(enabled))
            settingsViewModel?.updateLaunchAtLogin(coordinator?.menuState.isLaunchAtLoginEnabled ?? false)
            menuBarController?.refresh()
        }
        settingsViewModel.onResetPosition = { [weak coordinator] in
            coordinator?.handle(.resetPosition)
        }
        settingsViewModel.onSpeechBubbleEnabledChanged = { [weak self, weak coordinator] enabled in
            self?.preferencesStore.isSpeechBubbleEnabled = enabled
            coordinator?.handle(.setSpeechBubbleEnabled(enabled))
        }
        settingsViewModel.onBubbleFrequencyChanged = { [weak self, weak coordinator] frequency in
            self?.preferencesStore.bubbleFrequency = frequency
            coordinator?.handle(.setBubbleFrequency(frequency))
        }
        libraryViewModel.onImportPetImage = { [weak coordinator] url, displayName in
            coordinator?.handle(.importPetImage(url, displayName: displayName))
        }
        libraryViewModel.onImportPetPackage = { [weak coordinator] url in
            coordinator?.handle(.importPetPackage(url))
        }
        libraryViewModel.onSelectPet = { [weak coordinator] id in
            coordinator?.handle(.selectPet(id))
        }
        libraryViewModel.onDeletePet = { [weak coordinator] id in
            coordinator?.handle(.deletePet(id))
        }
        importViewModel.onImportRequested = { [weak coordinator] url, displayName in
            coordinator?.handle(.importPetImage(url, displayName: displayName))
        }
        importViewModel.onPackageImportRequested = { [weak coordinator] url in
            coordinator?.handle(.importPetPackage(url))
        }
        importViewModel.onPetdexPackageImportRequested = { [weak coordinator] url in
            coordinator?.handle(.importPetdexPackage(url))
        }
        petdexURLImportViewModel.onImportRequested = { [weak coordinator] input in
            coordinator?.handle(.importPetdexURL(input))
        }
        petdexURLImportViewModel.onCancelRequested = { [weak coordinator] in
            coordinator?.handle(.cancelPetdexURLImport)
        }
        actionLibraryViewModel.onActionMetadataSaved = { [weak self, weak menuBarController] petId in
            self?.reloadActionEditedPet(petId: petId)
            menuBarController?.refresh()
        }
        companionSettingsViewModel.onRelationshipPromptsChanged = { [weak self] enabled in
            guard let self else { return }
            var preferences = self.companionPreferencesStore.loadPreferences()
            preferences.showRelationshipPrompts = enabled
            self.companionPreferencesStore.savePreferences(preferences)
        }
        companionSettingsViewModel.onPetNicknameChanged = { [weak self] nickname in
            guard let self else { return }
            self.companionPreferencesStore.setPetNickname(nickname, for: self.companionSettingsViewModel.currentPetId)
        }
        companionSettingsViewModel.onUserNicknameChanged = { [weak self] nickname in
            guard let self else { return }
            self.companionPreferencesStore.setUserNickname(nickname)
        }
        companionSettingsViewModel.onQuietForOneHour = { [weak coordinator] in
            coordinator?.handle(.quietForOneHour)
        }
        companionSettingsViewModel.onClearQuietMode = { [weak coordinator] in
            coordinator?.handle(.clearQuietMode)
        }
        companionSettingsViewModel.onResetRelationship = { [weak self] in
            guard let self else { return }
            let state = self.petCommands.runtimeState
            _ = self.companionEventRouter.resetRelationship(runtimeState: state)
            self.companionSettingsViewModel.updateRelationship(
                self.companionEventRouter.context(runtimeState: state).relationship
            )
        }
        companionSettingsViewModel.onQuietHoursChanged = { [weak self] quietHours in
            guard let self else { return }
            var prefs = self.companionPreferencesStore.loadPreferences()
            prefs.quietHours = quietHours
            self.companionPreferencesStore.savePreferences(prefs)
            self.companionSettingsViewModel.updatePreferences(prefs)
        }
        coordinator.onQuietModeStateChanged = { [weak self, weak menuBarController] isActive in
            guard let self else { return }
            if isActive {
                self.companionPreferencesStore.quietForOneHour()
            } else {
                self.companionPreferencesStore.clearQuietMode()
            }
            let prefs = self.companionPreferencesStore.loadPreferences()
            self.companionSettingsViewModel.updatePreferences(prefs)
            if let quietUntil = prefs.quietUntil, isActive {
                self.companionSettingsViewModel.updateQuietState(.temporary(until: quietUntil))
            } else {
                self.companionSettingsViewModel.updateQuietState(.inactive)
            }
            menuBarController?.refresh()
        }

        interactiveBubbleSettingsViewModel.onOpenAISettings = { [weak self] in
            self?.aiSettingsViewModel.openProviderConfig()
        }

        aiSettingsViewModel.onAIEnabledChanged = { [weak self, weak menuBarController] enabled in
            guard let self else { return }
            self.aiPreferencesStore.setAIEnabled(enabled)
            self.aiSettingsViewModel.updatePreferences(self.aiPreferencesStore.loadPreferences())
            if !enabled {
                self.chatPanelController.closeChatPanel()
            }
            menuBarController?.refresh()
        }
        aiSettingsViewModel.onMemoryEnabledChanged = { [weak self] enabled in
            guard let self else { return }
            self.aiPreferencesStore.setMemoryEnabled(enabled)
            self.aiSettingsViewModel.updatePreferences(self.aiPreferencesStore.loadPreferences())
        }
        aiSettingsViewModel.onPersonalityChanged = { [weak self] profileId in
            guard let self else { return }
            self.aiPreferencesStore.setSelectedPersonalityId(profileId)
            self.aiSettingsViewModel.updatePreferences(self.aiPreferencesStore.loadPreferences())
        }
        aiSettingsViewModel.onInitiativeBubbleChanged = { [weak self] allowed in
            guard let self else { return }
            self.aiPreferencesStore.setAllowInitiativeBubble(allowed)
            self.aiSettingsViewModel.updatePreferences(self.aiPreferencesStore.loadPreferences())
        }
        aiSettingsViewModel.onProviderChanged = { [weak self] providerId in
            guard let self else { return }
            self.aiPreferencesStore.setSelectedProviderId(providerId)
            self.aiSettingsViewModel.updatePreferences(self.aiPreferencesStore.loadPreferences())
        }
        aiSettingsViewModel.onClearMemory = { [weak self] in
            guard let self else { return }
            try? self.aiMemoryStore.clearAll(petId: self.currentDefinition.id)
        }
        aiSettingsViewModel.onExportMemory = { [weak self] in
            guard let self else { return }
            _ = try? AIMemoryExporter(store: self.aiMemoryStore).exportWithPanel(petId: self.currentDefinition.id)
        }
        aiSettingsViewModel.onAPIKeySaved = { [weak self] key in
            guard let self else { return }
            let proto = self.aiSettingsViewModel.selectedProtocol
            let defaultEndpoint = proto == .anthropic
                ? "https://api.anthropic.com"
                : "https://api.openai.com/v1"
            let endpointString = self.aiSettingsViewModel.endpointInput.isEmpty ? defaultEndpoint : self.aiSettingsViewModel.endpointInput
            let defaultModel = proto == .anthropic ? "claude-sonnet-4-20250514" : "gpt-4o-mini"
            let config = AIProviderConfig(
                endpoint: URL(string: endpointString) ?? URL(string: defaultEndpoint)!,
                model: self.aiSettingsViewModel.modelInput.isEmpty ? defaultModel : self.aiSettingsViewModel.modelInput
            )
            let provider: AIProviding
            if proto == .anthropic {
                let anthropicProvider = AnthropicAIProvider(config: config)
                try? anthropicProvider.saveAPIKey(key)
                provider = anthropicProvider
            } else {
                let openaiProvider = HTTPAIProvider(config: config)
                try? openaiProvider.saveAPIKey(key)
                provider = openaiProvider
            }
            self.aiChatEngine.updateProvider(provider)
            var prefs = self.aiPreferencesStore.loadPreferences()
            prefs.providerEndpoint = endpointString
            prefs.providerModel = config.model
            prefs.providerProtocol = proto
            self.aiPreferencesStore.savePreferences(prefs)
            self.aiSettingsViewModel.updateIsConfigured(true)
            self.interactiveBubbleSettingsViewModel.updateAIConfigured(true)
        }

        aiVisualSettingsViewModel.onEnabledChanged = { [weak self] enabled in
            guard let self else { return }
            self.aiVisualPreferencesStore.setEnabled(enabled)
            self.aiVisualSettingsViewModel.updatePreferences(self.aiVisualPreferencesStore.loadPreferences())
        }
        aiVisualSettingsViewModel.onAutonomousFrequencyChanged = { [weak self] frequency in
            guard let self else { return }
            self.aiVisualPreferencesStore.setAutonomousFrequency(frequency)
            self.aiVisualSettingsViewModel.updatePreferences(self.aiVisualPreferencesStore.loadPreferences())
        }
        aiVisualSettingsViewModel.onDurationPresetChanged = { [weak self] preset in
            guard let self else { return }
            self.aiVisualPreferencesStore.setDurationPreset(preset)
            self.aiVisualSettingsViewModel.updatePreferences(self.aiVisualPreferencesStore.loadPreferences())
        }
        aiVisualSettingsViewModel.onIntensityChanged = { [weak self] intensity in
            guard let self else { return }
            self.aiVisualPreferencesStore.setIntensity(intensity)
            self.aiVisualSettingsViewModel.updatePreferences(self.aiVisualPreferencesStore.loadPreferences())
        }
        aiVisualSettingsViewModel.onProviderChanged = { [weak self] providerId in
            guard let self else { return }
            self.aiVisualPreferencesStore.setSelectedProviderId(providerId)
            self.aiVisualSettingsViewModel.updatePreferences(self.aiVisualPreferencesStore.loadPreferences())
        }
        aiVisualSettingsViewModel.onConsistencyPreferenceChanged = { [weak self] preference in
            guard let self else { return }
            self.petVisualPreferenceStore.savePreference(
                preference,
                forPetId: self.currentDefinition.id
            )
        }
        aiVisualSettingsViewModel.onPetVisualNotesChanged = { [weak self] notes in
            guard let self else { return }
            self.petVisualPreferenceStore.saveVisualNotes(
                notes,
                forPetId: self.currentDefinition.id
            )
        }
        aiVisualSettingsViewModel.onManualGenerationRequested = { [weak self] in
            guard let self else { return }
            self.aiVisualSettingsViewModel.clearFeedback()
            self.visualActionMediator.requestManualGeneration(
                petId: self.currentDefinition.id,
                petName: self.currentDefinition.displayName
            )
        }
        aiVisualSettingsViewModel.onRestoreRequested = { [weak self] in
            guard let self else { return }
            self.visualActionMediator.restoreVisual()
            self.aiVisualSettingsViewModel.updateHasActiveOverlay(false)
        }
        aiVisualSettingsViewModel.onRefreshProviderStatus = { [weak self] in
            guard let self else { return }
            let prefs = self.aiVisualPreferencesStore.loadPreferences()
            let newClient = MiniMaxCLIClient(processRunner: RealProcessRunner(), mmxPath: prefs.mmxPath)
            let newGenerator = MiniMaxCLIImageGenerator(client: newClient)
            self.visualProviderRegistry.unregister(providerId: self.mmxGenerator.providerId)
            self.visualProviderRegistry.register(newGenerator)
            self.mmxGenerator = newGenerator
            if prefs.selectedProviderId == nil {
                self.visualGenerationService.selectProvider(newGenerator.providerId)
            }
            await newGenerator.refreshConfiguration()
            let infos = self.visualGenerationService.availableProviders()
            self.aiVisualSettingsViewModel.updateProviderInfos(infos)
            self.aiVisualSettingsViewModel.updateCurrentProviderId(prefs.selectedProviderId ?? self.visualGenerationService.currentProviderId())
            if let info = infos.first(where: { $0.providerId == newGenerator.providerId }) {
                if info.isConfigured {
                    self.aiVisualSettingsViewModel.showFeedback("MiniMax CLI detected and authenticated.")
                } else {
                    self.aiVisualSettingsViewModel.showFeedback("mmx found but not logged in. Run `mmx auth login` in your command line.")
                }
            } else {
                self.aiVisualSettingsViewModel.showFeedback("mmx not found at \(prefs.mmxPath ?? "/usr/local/bin/mmx"). Please check the path.")
            }
        }
        aiVisualSettingsViewModel.onMmxPathChanged = { [weak self] path in
            guard let self else { return }
            self.aiVisualPreferencesStore.setMmxPath(path)
            self.aiVisualSettingsViewModel.updatePreferences(self.aiVisualPreferencesStore.loadPreferences())
        }

        aiVisualSettingsViewModel.onLoadProviderDefaults = { [weak self] providerId in
            guard let self else { return ProviderConfigFields() }
            let config = self.apiProviderConfigStore.load()
            var fields = ProviderConfigFields()
            switch providerId {
            case "aliyun":
                fields.model = config.aliyunModel
                fields.region = config.aliyunRegion
            case "siliconflow":
                fields.model = config.siliconFlowModel
            case "openai-compatible":
                fields.baseURL = config.openaiCompatibleBaseURL
                fields.model = config.openaiCompatibleModel
            case "tencent":
                fields.region = config.tencentRegion
            default:
                break
            }
            return fields
        }

        aiVisualSettingsViewModel.onProviderConfigSaved = { [weak self] providerId, fields in
            guard let self else { return }
            switch providerId {
            case "minimax-api":
                self.minimaxApiGenerator.saveAPIKey(fields.apiKey)
            case "aliyun":
                self.aliyunGenerator.saveAPIKey(fields.apiKey)
                var config = self.apiProviderConfigStore.load()
                if let model = fields.model, !model.isEmpty { config.aliyunModel = model }
                if let region = fields.region, !region.isEmpty { config.aliyunRegion = region }
                self.apiProviderConfigStore.save(config)
            case "siliconflow":
                self.siliconFlowGenerator.saveAPIKey(fields.apiKey)
                var config = self.apiProviderConfigStore.load()
                if let model = fields.model, !model.isEmpty { config.siliconFlowModel = model }
                self.apiProviderConfigStore.save(config)
            case "openai-compatible":
                self.openaiCompatibleGenerator.saveAPIKey(fields.apiKey)
                var config = self.apiProviderConfigStore.load()
                if let url = fields.baseURL, !url.isEmpty { config.openaiCompatibleBaseURL = url }
                if let model = fields.model, !model.isEmpty { config.openaiCompatibleModel = model }
                self.apiProviderConfigStore.save(config)
            case "tencent":
                if let sid = fields.secretId, let skey = fields.secretKey {
                    self.tencentGenerator.saveCredentials(secretId: sid, secretKey: skey)
                }
                var config = self.apiProviderConfigStore.load()
                if let region = fields.region, !region.isEmpty { config.tencentRegion = region }
                self.apiProviderConfigStore.save(config)
            default:
                break
            }
            let infos = self.visualGenerationService.availableProviders()
            self.aiVisualSettingsViewModel.updateProviderInfos(infos)
            self.aiVisualSettingsViewModel.updateCurrentProviderId(providerId)
            self.aiVisualSettingsViewModel.showFeedback("Configuration saved.")
        }

        aiVisualSettingsViewModel.onDeleteProviderConfig = { [weak self] providerId in
            guard let self else { return }
            switch providerId {
            case "minimax-api":
                self.minimaxApiGenerator.deleteAPIKey()
            case "aliyun":
                self.aliyunGenerator.deleteAPIKey()
            case "siliconflow":
                self.siliconFlowGenerator.deleteAPIKey()
            case "openai-compatible":
                self.openaiCompatibleGenerator.deleteAPIKey()
            case "tencent":
                self.tencentGenerator.deleteCredentials()
            default:
                break
            }
            let infos = self.visualGenerationService.availableProviders()
            self.aiVisualSettingsViewModel.updateProviderInfos(infos)
            self.aiVisualSettingsViewModel.updateCurrentProviderId(providerId)
            self.aiVisualSettingsViewModel.showFeedback("Configuration cleared.")
        }
    }

    func stop() {
        petEngineTimer.stop()
    }

    func refreshContentPackIntegrations() {
        aiSettingsViewModel.updateProfiles(contentPackPersonalityProfiles())
        applyCurrentPet(currentDefinition, reportImportSucceeded: false)
    }

    private func handleAIBubble(_ bubble: PetBubble) {
        petViewModel.update(bubble: bubble)
        petWindow.updateBubble(bubble)
    }

    private func applyCurrentPet(_ definition: PetDefinition, reportImportSucceeded: Bool = true) {
        let capturedStateController = petVisualStateController
        capturedStateController.clearAll(viewModel: petViewModel)

        currentDefinition = definition
        let actionCatalog = contentPackActionCatalog(for: definition)
        petCommands.replaceCurrent(
            catalog: actionCatalog,
            initialState: petCommands.runtimeState,
            isRandomWalkingEnabled: preferencesStore.isRandomWalkingEnabled
        )
        petViewModel.update(definition: definition)

        let folderURL = Self.folderURL(for: definition, store: store)
        let renderer = rendererFactory.makeRenderer(for: definition, folderURL: folderURL)
        let viewModel = petViewModel
        petWindow.updateContentView { _ in
            NSHostingView(rootView: PetView(model: viewModel, definition: definition, renderer: renderer))
        }

        let bubbleProfile = definition.resolvedBubbleProfile()
        bubbleEngine.profile = bubbleProfile
        bubbleEngine.updateContextualPhraseProvider(contentPackContextualProvider(for: bubbleProfile))
        let frameSize = PetView.renderSize(for: definition, state: petCommands.runtimeState)
        petWindow.updateFrameSize(frameSize)
        actionLibraryViewModel.refresh(definition: definition)
        libraryViewModel.reload()

        companionEventRouter.switchPet(id: definition.id, displayName: definition.displayName)
        companionSettingsViewModel.updatePetId(definition.id)
        let prefs = companionPreferencesStore.loadPreferences()
        companionSettingsViewModel.updatePreferences(prefs)
        companionSettingsViewModel.updateRelationship(
            companionEventRouter.context(runtimeState: petCommands.runtimeState).relationship
        )
        aiSettingsViewModel.memoryViewModel?.updatePetId(definition.id)
        aiSettingsViewModel.memoryManagementViewModel?.updatePetId(definition.id)
        let visualPrefs = petVisualPreferenceStore.loadPreferences()
        aiVisualSettingsViewModel.updateConsistencyControls(
            preference: visualPrefs.consistencyPreference(forPetId: definition.id),
            petVisualNotes: visualPrefs.petVisualNotes?[definition.id] ?? ""
        )
        if reportImportSucceeded {
            importViewModel.reportImportSucceeded()
        }
    }

    private func contentPackActionCatalog(for definition: PetDefinition) -> PetActionCatalog {
        contentPackManager.enabledActionCatalog(merging: definition.catalog)
    }

    private func contentPackPersonalityProfiles() -> [AIPersonalityProfile] {
        contentPackManager.availablePersonalityProfiles(base: AIPersonalityProfile.defaultProfiles)
    }

    private func contentPackContextualProvider(for profile: BubbleProfile) -> ContextualBubblePhraseProvider {
        ContextualBubblePhraseProvider(
            catalog: contentPackManager.enabledBubbleCatalog(
                merging: BubblePhraseCatalogBuilder().build(from: profile)
            ),
            quietModePolicy: quietModePolicy
        )
    }

    private func reloadActionEditedPet(petId: String) {
        guard petId == currentDefinition.id else {
            return
        }

        do {
            let definition = try store.loadDefinition(id: petId)
            applyCurrentPet(definition, reportImportSucceeded: false)
        } catch {
            DesktopPetLog.petLibrary.error("Failed to reload action overrides for pet \(petId, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }

    private static func folderURL(for definition: PetDefinition, store: PetLibraryStore) -> URL? {
        if definition.id == store.builtInPetId {
            return nil
        }
        return store.importedPetsDirectoryURL.appendingPathComponent(definition.id, isDirectory: true)
    }

    private static func fallbackDefinition() -> PetDefinition {
        PetDefinition(
            id: "starter-pet",
            displayName: "Starter Pet",
            description: "Fallback built-in desktop companion.",
            assetName: PetDefinition.placeholderAssetName,
            previewAssetName: PetDefinition.placeholderAssetName,
            frameSize: CGSizeCodable(width: 128, height: 128),
            spritesheet: SpriteSheetLayout(columns: 1, rows: 1),
            defaultScale: 1.0,
            animations: Dictionary(uniqueKeysWithValues: PetState.allCases.map { state in
                (
                    state,
                    AnimationClip(
                        state: state,
                        frames: [SpriteFrame(column: 0, row: 0)],
                        frameDurationMs: 160,
                        loop: state == .idle || state == .walking || state == .sleeping || state == .dragging,
                        nextState: state == .idle || state == .walking || state == .sleeping || state == .dragging ? nil : .idle
                    )
                )
            })
        )
    }
}
