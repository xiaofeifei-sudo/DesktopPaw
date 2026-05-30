import Foundation
import DesktopPet

@MainActor
func runAIMemoryViewModelTests() {
    let tests = AIMemoryViewModelTests()
    tests.startEditingPopulatesDraft()
    tests.saveEditingUpdatesMemoryAndReloads()
    tests.cancelEditingClearsDraft()
}

@MainActor
private struct AIMemoryViewModelTests {
    func startEditingPopulatesDraft() {
        let store = MemoryViewModelStoreSpy(memories: [sampleMemory(content: "喜欢蓝色")])
        let model = AIMemoryViewModel(memoryStore: store, petId: "pet-a")
        model.loadMemories()

        model.startEditing(model.memories[0])

        expect(model.editingMemory?.content == "喜欢蓝色",
               "startEditing should expose the selected memory")
        expect(model.editedContent == "喜欢蓝色",
               "startEditing should populate editedContent")
    }

    func saveEditingUpdatesMemoryAndReloads() {
        let memory = sampleMemory(content: "喜欢蓝色")
        let store = MemoryViewModelStoreSpy(memories: [memory])
        let model = AIMemoryViewModel(memoryStore: store, petId: "pet-a")
        model.loadMemories()
        model.startEditing(memory)
        model.editedContent = "喜欢绿色"

        model.saveEditing()

        expect(store.updatedMemories.count == 1,
               "saveEditing should update one memory")
        expect(store.updatedMemories[0].content == "喜欢绿色",
               "saveEditing should persist edited content")
        expect(store.updatedMemories[0].id == memory.id,
               "saveEditing should preserve memory identity")
        expect(model.editingMemory == nil,
               "saveEditing should close editing state")
        expect(model.memories[0].content == "喜欢绿色",
               "saveEditing should reload edited memories")
    }

    func cancelEditingClearsDraft() {
        let memory = sampleMemory(content: "喜欢蓝色")
        let store = MemoryViewModelStoreSpy(memories: [memory])
        let model = AIMemoryViewModel(memoryStore: store, petId: "pet-a")

        model.startEditing(memory)
        model.editedContent = "临时内容"
        model.cancelEditing()

        expect(model.editingMemory == nil,
               "cancelEditing should clear editingMemory")
        expect(model.editedContent.isEmpty,
               "cancelEditing should clear editedContent")
        expect(store.updatedMemories.isEmpty,
               "cancelEditing should not update memory")
    }

    private func sampleMemory(content: String) -> AIMemory {
        AIMemory(
            id: "memory-1",
            petId: "pet-a",
            category: .preference,
            content: content,
            createdAt: Date(timeIntervalSince1970: 100),
            updatedAt: Date(timeIntervalSince1970: 100),
            source: .userProvided
        )
    }
}

private final class MemoryViewModelStoreSpy: AIMemoryStoring, @unchecked Sendable {
    private var storedMemories: [AIMemory]
    private(set) var updatedMemories: [AIMemory] = []

    init(memories: [AIMemory]) {
        self.storedMemories = memories
    }

    func loadAll(petId: String) -> [AIMemory] {
        storedMemories.filter { $0.petId == petId }
    }

    func add(_ memory: AIMemory, petId: String) throws {
        storedMemories.append(memory)
    }

    func update(_ memory: AIMemory, petId: String) throws {
        updatedMemories.append(memory)
        guard let index = storedMemories.firstIndex(where: { $0.id == memory.id }) else { return }
        storedMemories[index] = memory
    }

    func delete(memoryId: String, petId: String) throws {
        storedMemories.removeAll { $0.id == memoryId && $0.petId == petId }
    }

    func clearAll(petId: String) throws {
        storedMemories.removeAll { $0.petId == petId }
    }

    func exportMemories(petId: String) throws -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("memory.json")
    }

    func isMemoryEnabled(petId: String) -> Bool { true }
    func setMemoryEnabled(_ enabled: Bool, petId: String) {}

    func loadByCategory(_ category: AIMemoryCategory, petId: String) -> [AIMemory] {
        storedMemories.filter { $0.petId == petId && $0.category == category }
    }

    func search(keyword: String, petId: String) -> [AIMemory] {
        storedMemories.filter { $0.petId == petId && $0.content.localizedCaseInsensitiveContains(keyword) }
    }

    func incrementAccessCount(id: String, petId: String) throws {}

    func deleteByCategory(_ category: AIMemoryCategory, petId: String) throws {
        storedMemories.removeAll { $0.petId == petId && $0.category == category }
    }

    func memoryStatistics(petId: String) -> MemoryStatistics {
        let petMemories = storedMemories.filter { $0.petId == petId }
        var counts: [AIMemoryCategory: Int] = [:]
        for m in petMemories { counts[m.category, default: 0] += 1 }
        return MemoryStatistics(totalCount: petMemories.count, capacity: 1000, categoryCounts: counts)
    }
}
