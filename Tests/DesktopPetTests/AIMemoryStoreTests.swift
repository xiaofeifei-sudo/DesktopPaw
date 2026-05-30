import Foundation
import DesktopPet

@MainActor
func runAIMemoryStoreTests() {
    let tests = AIMemoryStoreTests()
    tests.addAndLoad()
    tests.updateMemory()
    tests.deleteMemory()
    tests.clearAll()
    tests.memoryDisabledBlocksReadWrite()
    tests.memoryDisabledDefaultIsEnabled()
    tests.sensitiveContentRejected()
    tests.capacityEviction()
    tests.nicknamePreservedDuringEviction()
    tests.loadEmptyWhenNoFile()
    tests.updateNonexistentThrows()
    tests.deleteNonexistentThrows()
    tests.exportMemories()
}

@MainActor
private struct AIMemoryStoreTests {
    private func makeStore(capacity: Int = AIMemory.defaultCapacity) -> AIMemoryStore {
        AIMemoryStore(fileManager: .default, capacity: capacity)
    }

    private let testPetId = "test-memory-pet-\(UUID().uuidString.prefix(8))"

    func addAndLoad() {
        let store = makeStore()
        defer { try? store.clearAll(petId: testPetId) }

        let memory = AIMemory(
            petId: testPetId,
            category: .preference,
            content: "喜欢蓝色",
            source: .userProvided
        )
        try! store.add(memory, petId: testPetId)

        let loaded = store.loadAll(petId: testPetId)
        expect(loaded.count == 1, "should have 1 memory, got \(loaded.count)")
        expect(loaded[0].content == "喜欢蓝色", "content should match")
        expect(loaded[0].category == .preference, "category should match")
        expect(loaded[0].source == .userProvided, "source should match")
    }

    func updateMemory() {
        let store = makeStore()
        defer { try? store.clearAll(petId: testPetId) }

        let memory = AIMemory(
            petId: testPetId,
            category: .custom,
            content: "原始内容",
            source: .userProvided
        )
        try! store.add(memory, petId: testPetId)

        let updated = AIMemory(
            id: memory.id,
            petId: testPetId,
            category: .custom,
            content: "更新后内容",
            createdAt: memory.createdAt,
            updatedAt: Date(),
            source: .userProvided
        )
        try! store.update(updated, petId: testPetId)

        let loaded = store.loadAll(petId: testPetId)
        expect(loaded.count == 1, "should still have 1 memory")
        expect(loaded[0].content == "更新后内容", "content should be updated")
        expect(loaded[0].updatedAt >= memory.createdAt, "updatedAt should be newer")
    }

    func deleteMemory() {
        let store = makeStore()
        defer { try? store.clearAll(petId: testPetId) }

        let m1 = AIMemory(petId: testPetId, category: .preference, content: "记忆1", source: .userProvided)
        let m2 = AIMemory(petId: testPetId, category: .interaction, content: "记忆2", source: .aiExtracted)
        try! store.add(m1, petId: testPetId)
        try! store.add(m2, petId: testPetId)

        try! store.delete(memoryId: m1.id, petId: testPetId)

        let loaded = store.loadAll(petId: testPetId)
        expect(loaded.count == 1, "should have 1 memory after deletion, got \(loaded.count)")
        expect(loaded[0].id == m2.id, "remaining memory should be m2")
    }

    func clearAll() {
        let store = makeStore()
        defer { try? store.clearAll(petId: testPetId) }

        let m1 = AIMemory(petId: testPetId, category: .preference, content: "a", source: .userProvided)
        let m2 = AIMemory(petId: testPetId, category: .preference, content: "b", source: .userProvided)
        try! store.add(m1, petId: testPetId)
        try! store.add(m2, petId: testPetId)

        try! store.clearAll(petId: testPetId)

        let loaded = store.loadAll(petId: testPetId)
        expect(loaded.isEmpty, "should have no memories after clear")
    }

    func memoryDisabledBlocksReadWrite() {
        let store = makeStore()
        defer {
            store.setMemoryEnabled(true, petId: testPetId)
            try? store.clearAll(petId: testPetId)
        }

        store.setMemoryEnabled(false, petId: testPetId)
        expect(!store.isMemoryEnabled(petId: testPetId), "should be disabled")

        let loaded = store.loadAll(petId: testPetId)
        expect(loaded.isEmpty, "loadAll should return empty when disabled")

        let memory = AIMemory(petId: testPetId, category: .preference, content: "test", source: .userProvided)
        var threw = false
        do {
            try store.add(memory, petId: testPetId)
        } catch let error as AIMemoryStoreError {
            threw = true
            expect(error == .memoryDisabled, "should throw memoryDisabled")
        } catch {
            fail("unexpected error: \(error)")
        }
        expect(threw, "add should throw when memory disabled")
    }

    func memoryDisabledDefaultIsEnabled() {
        let store = makeStore()
        let freshPetId = "fresh-pet-\(UUID().uuidString.prefix(8))"
        expect(store.isMemoryEnabled(petId: freshPetId), "memory should be enabled by default")
    }

    func sensitiveContentRejected() {
        let store = makeStore()
        defer { try? store.clearAll(petId: testPetId) }

        let memory = AIMemory(petId: testPetId, category: .custom, content: "密码是abc123", source: .userProvided)
        var threw = false
        do {
            try store.add(memory, petId: testPetId)
        } catch let error as AIMemoryStoreError {
            threw = true
            if case .filterRejected = error {
            } else {
                fail("expected filterRejected, got \(error)")
            }
        } catch {
            fail("unexpected error: \(error)")
        }
        expect(threw, "sensitive content should be rejected")
    }

    func capacityEviction() {
        let capacity = 5
        let store = makeStore(capacity: capacity)
        let evictionPetId = "evict-pet-\(UUID().uuidString.prefix(8))"
        defer { try? store.clearAll(petId: evictionPetId) }

        for i in 0..<capacity + 3 {
            let memory = AIMemory(
                petId: evictionPetId,
                category: .interaction,
                content: "互动\(i)",
                createdAt: Date().addingTimeInterval(Double(i)),
                source: .aiExtracted
            )
            try! store.add(memory, petId: evictionPetId)
        }

        let loaded = store.loadAll(petId: evictionPetId)
        expect(loaded.count <= capacity, "should not exceed capacity, got \(loaded.count)")
    }

    func nicknamePreservedDuringEviction() {
        let capacity = 3
        let store = makeStore(capacity: capacity)
        let nickPetId = "nick-pet-\(UUID().uuidString.prefix(8))"
        defer { try? store.clearAll(petId: nickPetId) }

        let nickname = AIMemory(
            petId: nickPetId,
            category: .nickname,
            content: "叫咪咪",
            createdAt: Date().addingTimeInterval(-100),
            source: .userProvided
        )
        try! store.add(nickname, petId: nickPetId)

        for i in 0..<capacity + 1 {
            let memory = AIMemory(
                petId: nickPetId,
                category: .interaction,
                content: "互动\(i)",
                createdAt: Date().addingTimeInterval(Double(i)),
                source: .aiExtracted
            )
            try! store.add(memory, petId: nickPetId)
        }

        let loaded = store.loadAll(petId: nickPetId)
        let hasNickname = loaded.contains { $0.category == .nickname }
        expect(hasNickname, "nickname should be preserved during eviction")
    }

    func loadEmptyWhenNoFile() {
        let store = makeStore()
        let emptyPetId = "empty-pet-\(UUID().uuidString.prefix(8))"
        let loaded = store.loadAll(petId: emptyPetId)
        expect(loaded.isEmpty, "should return empty when no file exists")
    }

    func updateNonexistentThrows() {
        let store = makeStore()
        defer { try? store.clearAll(petId: testPetId) }

        let memory = AIMemory(
            petId: testPetId,
            category: .preference,
            content: "不存在",
            source: .userProvided
        )
        var threw = false
        do {
            try store.update(memory, petId: testPetId)
        } catch let error as AIMemoryStoreError {
            threw = true
            if case .memoryNotFound = error {
            } else {
                fail("expected memoryNotFound, got \(error)")
            }
        } catch {
            fail("unexpected error: \(error)")
        }
        expect(threw, "update nonexistent should throw")
    }

    func deleteNonexistentThrows() {
        let store = makeStore()
        defer { try? store.clearAll(petId: testPetId) }

        var threw = false
        do {
            try store.delete(memoryId: "nonexistent-id", petId: testPetId)
        } catch let error as AIMemoryStoreError {
            threw = true
            if case .memoryNotFound = error {
            } else {
                fail("expected memoryNotFound, got \(error)")
            }
        } catch {
            fail("unexpected error: \(error)")
        }
        expect(threw, "delete nonexistent should throw")
    }

    func exportMemories() {
        let store = makeStore()
        defer { try? store.clearAll(petId: testPetId) }

        let m1 = AIMemory(petId: testPetId, category: .preference, content: "导出测试", source: .userProvided)
        try! store.add(m1, petId: testPetId)

        let url = try! store.exportMemories(petId: testPetId)
        let data = try! Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try! decoder.decode([AIMemory].self, from: data)
        expect(decoded.count == 1, "exported data should have 1 memory")
        expect(decoded[0].content == "导出测试", "exported content should match")

        try? FileManager.default.removeItem(at: url)
    }
}
