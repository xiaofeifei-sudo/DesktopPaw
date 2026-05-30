import Foundation
import DesktopPet

@MainActor
func runAppCoordinatorAICompanionTests() {
    let tests = AppCoordinatorAICompanionTests()
    tests.sendChatMessageRoutesWhenAIEnabled()
    tests.sendChatMessageDoesNotRouteWhenAIDisabled()
    tests.disablingAIClosesChatPanel()
    tests.memoryCommandsRouteToMemoryStore()
    tests.preferenceCommandsPersistChanges()
}

@MainActor
private struct AppCoordinatorAICompanionTests {
    func sendChatMessageRoutesWhenAIEnabled() {
        let harness = makeHarness()
        harness.preferencesStore.setAIEnabled(true)

        harness.coordinator.handle(.sendChatMessage(text: "你好", petId: "pet-a"))

        expect(harness.chatPanel.sentMessages == [SentChatMessage(text: "你好", petId: "pet-a")],
               "sendChatMessage should route to chat panel when AI is enabled")
    }

    func sendChatMessageDoesNotRouteWhenAIDisabled() {
        let harness = makeHarness()

        harness.coordinator.handle(.sendChatMessage(text: "你好", petId: "pet-a"))

        expect(harness.chatPanel.sentMessages.isEmpty,
               "sendChatMessage should not route while AI is disabled")
    }

    func disablingAIClosesChatPanel() {
        let harness = makeHarness()
        harness.preferencesStore.setAIEnabled(true)
        harness.chatPanel.showChatPanel(petId: "pet-a")

        harness.coordinator.handle(.toggleAI(enabled: false))

        expect(!harness.preferencesStore.loadPreferences().isAIEnabled,
               "toggleAI(false) should persist disabled preference")
        expect(harness.chatPanel.closeCount == 1,
               "toggleAI(false) should close the chat panel")
    }

    func memoryCommandsRouteToMemoryStore() {
        let harness = makeHarness()

        harness.coordinator.handle(.clearAIMemory(petId: "pet-a"))
        harness.coordinator.handle(.deleteAIMemory(memoryId: "memory-1", petId: "pet-a"))
        harness.coordinator.handle(.exportAIMemory(petId: "pet-a"))

        expect(harness.memoryStore.clearedPetIds == ["pet-a"],
               "clearAIMemory should clear memories for the pet")
        expect(harness.memoryStore.deleted == [DeletedMemory(memoryId: "memory-1", petId: "pet-a")],
               "deleteAIMemory should delete the requested memory")
        expect(harness.memoryStore.exportedPetIds == ["pet-a"],
               "exportAIMemory should export memories for the pet")
    }

    func preferenceCommandsPersistChanges() {
        let harness = makeHarness()
        let preferences = AICompanionPreferences(
            isAIEnabled: true,
            selectedProviderId: "mock",
            selectedPersonalityId: "built-in-gentle"
        )

        harness.coordinator.handle(.updateAIPreferences(preferences))
        harness.coordinator.handle(.selectPersonality(profileId: "built-in-playful"))

        let saved = harness.preferencesStore.loadPreferences()
        expect(saved.isAIEnabled, "updateAIPreferences should persist AI enabled state")
        expect(saved.selectedProviderId == "mock", "updateAIPreferences should persist selected provider")
        expect(saved.selectedPersonalityId == "built-in-playful",
               "selectPersonality should update selected personality")
    }

    private func makeHarness() -> AICompanionCoordinatorHarness {
        let chatPanel = CoordinatorAIChatPanelSpy()
        let memoryStore = CoordinatorAIMemoryStoreSpy()
        let defaults = UserDefaults(suiteName: "test-ai-coordinator-\(UUID().uuidString)")!
        let preferencesStore = AICompanionPreferencesStore(userDefaults: defaults)
        let coordinator = AppCoordinator(
            petWindow: CoordinatorAIWindowSpy(),
            petCommands: CoordinatorAICommandSpy(),
            settingsWindow: CoordinatorAISettingsSpy(),
            launchAtLogin: CoordinatorAILaunchSpy(),
            application: CoordinatorAIApplicationSpy(),
            chatPanel: chatPanel,
            aiPreferencesStore: preferencesStore,
            aiMemoryStore: memoryStore
        )
        return AICompanionCoordinatorHarness(
            coordinator: coordinator,
            chatPanel: chatPanel,
            memoryStore: memoryStore,
            preferencesStore: preferencesStore
        )
    }
}

@MainActor
private struct AICompanionCoordinatorHarness {
    let coordinator: AppCoordinator
    let chatPanel: CoordinatorAIChatPanelSpy
    let memoryStore: CoordinatorAIMemoryStoreSpy
    let preferencesStore: AICompanionPreferencesStore
}

private struct SentChatMessage: Equatable {
    let text: String
    let petId: String
}

private struct DeletedMemory: Equatable {
    let memoryId: String
    let petId: String
}

@MainActor
private final class CoordinatorAIChatPanelSpy: ChatPanelControlling {
    private(set) var visible = false
    private(set) var closeCount = 0
    private(set) var sentMessages: [SentChatMessage] = []

    var isPanelVisible: Bool { visible }

    func showChatPanel(petId: String) {
        visible = true
    }

    func closeChatPanel() {
        visible = false
        closeCount += 1
    }

    func sendMessage(_ text: String, petId: String) {
        sentMessages.append(SentChatMessage(text: text, petId: petId))
    }
}

private final class CoordinatorAIMemoryStoreSpy: AIMemoryStoring, @unchecked Sendable {
    private(set) var clearedPetIds: [String] = []
    private(set) var deleted: [DeletedMemory] = []
    private(set) var exportedPetIds: [String] = []

    func loadAll(petId: String) -> [AIMemory] { [] }
    func add(_ memory: AIMemory, petId: String) throws {}
    func update(_ memory: AIMemory, petId: String) throws {}

    func delete(memoryId: String, petId: String) throws {
        deleted.append(DeletedMemory(memoryId: memoryId, petId: petId))
    }

    func clearAll(petId: String) throws {
        clearedPetIds.append(petId)
    }

    func exportMemories(petId: String) throws -> URL {
        exportedPetIds.append(petId)
        return URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("memory.json")
    }

    func isMemoryEnabled(petId: String) -> Bool { true }
    func setMemoryEnabled(_ enabled: Bool, petId: String) {}

    func loadByCategory(_ category: AIMemoryCategory, petId: String) -> [AIMemory] { [] }

    func search(keyword: String, petId: String) -> [AIMemory] { [] }

    func incrementAccessCount(id: String, petId: String) throws {}

    func deleteByCategory(_ category: AIMemoryCategory, petId: String) throws {}

    func memoryStatistics(petId: String) -> MemoryStatistics {
        MemoryStatistics(totalCount: 0, capacity: 1000, categoryCounts: [:])
    }
}

@MainActor
private final class CoordinatorAICommandSpy: PetCommandHandling {
    var runtimeState = PetRuntimeState.defaultState(at: Date())
    var catalog = PetActionCatalog(petId: "test", actions: [], warnings: [])
    var isSleeping: Bool { false }

    func clicked() {}
    func pet() {}
    func feed() {}
    func sleep() {}
    func wake() {}
    func dragStarted() {}
    func dragEnded() {}
    func playAction(_ id: ActionId) {}
    func setScale(_ scale: Double) {}
    func setRandomWalkingEnabled(_ enabled: Bool) {}
    func tick(at date: Date) {}
}

@MainActor
private final class CoordinatorAIWindowSpy: PetWindowControlling {
    var isPetVisible = true
    func showPet() { isPetVisible = true }
    func hidePet() { isPetVisible = false }
    func resetPosition() {}
    func saveStateBeforeQuit() {}
}

@MainActor
private final class CoordinatorAISettingsSpy: SettingsWindowControlling {
    func showSettings() {}
}

@MainActor
private final class CoordinatorAILaunchSpy: LaunchAtLoginControlling {
    var isLaunchAtLoginEnabled = false
    func setLaunchAtLoginEnabled(_ enabled: Bool) { isLaunchAtLoginEnabled = enabled }
}

@MainActor
private final class CoordinatorAIApplicationSpy: ApplicationTerminating {
    func terminate() {}
}
