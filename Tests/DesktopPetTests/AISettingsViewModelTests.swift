import Foundation
import DesktopPet

@MainActor
func runAISettingsViewModelTests() {
    let tests = AISettingsViewModelTests()
    tests.openMemoryManagerLoadsMemoriesAndShowsManager()
    tests.updateProfilesRefreshesPersonalityOptions()
}

@MainActor
private struct AISettingsViewModelTests {
    func openMemoryManagerLoadsMemoriesAndShowsManager() {
        let memory = AIMemory(
            id: "memory-1",
            petId: "pet-a",
            category: .preference,
            content: "喜欢安静",
            createdAt: Date(timeIntervalSince1970: 100),
            updatedAt: Date(timeIntervalSince1970: 100),
            source: .userProvided
        )
        let store = AISettingsMemoryStoreSpy(memories: [memory])
        let memoryModel = AIMemoryViewModel(memoryStore: store, petId: "pet-a")
        let model = AISettingsViewModel(memoryViewModel: memoryModel)

        model.openMemoryManager()

        expect(model.showMemoryManager,
               "openMemoryManager should show memory manager when memory model is available")
        expect(memoryModel.memories == [memory],
               "openMemoryManager should load current pet memories before presenting")
    }

    func updateProfilesRefreshesPersonalityOptions() {
        let packProfile = AIPersonalityProfile(
            id: "pack.personality",
            name: "内容包人格",
            description: "来自内容包",
            previewPhrases: ["你好"],
            toneGuidelines: "保持安全边界",
            responseMaxLength: 12,
            panelResponseMaxLength: 200,
            canInitiativeBubble: false,
            initiativeBubbleFrequency: 1800
        )
        let model = AISettingsViewModel()

        model.updateProfiles(AIPersonalityProfile.defaultProfiles + [packProfile])

        expect(model.personalityProfiles.contains { $0.id == "pack.personality" },
               "updateProfiles should expose enabled personality pack profiles")
    }
}

private final class AISettingsMemoryStoreSpy: AIMemoryStoring, @unchecked Sendable {
    private var memories: [AIMemory]

    init(memories: [AIMemory]) {
        self.memories = memories
    }

    func loadAll(petId: String) -> [AIMemory] {
        memories.filter { $0.petId == petId }
    }

    func add(_ memory: AIMemory, petId: String) throws {
        memories.append(memory)
    }

    func update(_ memory: AIMemory, petId: String) throws {
        guard let index = memories.firstIndex(where: { $0.id == memory.id }) else { return }
        memories[index] = memory
    }

    func delete(memoryId: String, petId: String) throws {
        memories.removeAll { $0.id == memoryId && $0.petId == petId }
    }

    func clearAll(petId: String) throws {
        memories.removeAll { $0.petId == petId }
    }

    func exportMemories(petId: String) throws -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("memory.json")
    }

    func isMemoryEnabled(petId: String) -> Bool { true }
    func setMemoryEnabled(_ enabled: Bool, petId: String) {}

    func loadByCategory(_ category: AIMemoryCategory, petId: String) -> [AIMemory] {
        memories.filter { $0.petId == petId && $0.category == category }
    }

    func search(keyword: String, petId: String) -> [AIMemory] {
        memories.filter { $0.petId == petId && $0.content.localizedCaseInsensitiveContains(keyword) }
    }

    func incrementAccessCount(id: String, petId: String) throws {}

    func deleteByCategory(_ category: AIMemoryCategory, petId: String) throws {
        memories.removeAll { $0.petId == petId && $0.category == category }
    }

    func memoryStatistics(petId: String) -> MemoryStatistics {
        let petMemories = memories.filter { $0.petId == petId }
        var counts: [AIMemoryCategory: Int] = [:]
        for m in petMemories { counts[m.category, default: 0] += 1 }
        return MemoryStatistics(totalCount: petMemories.count, capacity: 1000, categoryCounts: counts)
    }
}
