import Foundation
import DesktopPet

@MainActor
func runMemoryModule1Tests() {
    let tests = MemoryModule1Tests()
    tests.newCategoryEnumValues()
    tests.newFieldsDefaultValues()
    tests.backwardCompatibleDecoding()
    tests.newFieldsEncoded()
    tests.loadByCategory()
    tests.searchByKeyword()
    tests.searchByTag()
    tests.incrementAccessCount()
    tests.incrementAccessCountNotFound()
    tests.deleteByCategory()
    tests.memoryStatistics()
    tests.evictionEvaluatorBasic()
    tests.evictionProtectsNickname()
    tests.evictionProtectsMilestone()
    tests.evictionProtectsCustom()
    tests.evictionRemovesExpired()
    tests.evictionScoresByFormula()
    tests.filterProtocolConformance()
    tests.filterSensitiveContent()
    tests.filterSensitiveAllowedButMarked()
    tests.filterResultEquality()
    tests.compressorExpiredRemoval()
    tests.compressorCategoryMerge()
    tests.compressorInteractionSummary()
    tests.compressorNoCompressionNeeded()
    tests.storeBackupOnSave()
    tests.storeCacheInvalidation()
}

@MainActor
private struct MemoryModule1Tests {
    private func makeStore(capacity: Int = AIMemory.defaultCapacity) -> AIMemoryStore {
        AIMemoryStore(fileManager: .default, capacity: capacity)
    }

    private let testPetId = "mod1-test-\(UUID().uuidString.prefix(8))"

    // MARK: - 1.1 Data Model

    func newCategoryEnumValues() {
        let allCases = AIMemoryCategory.allCases
        expect(allCases.contains(.emotion), "should contain emotion")
        expect(allCases.contains(.milestone), "should contain milestone")
        expect(allCases.contains(.routine), "should contain routine")
        expect(allCases.count == 7, "should have 7 categories, got \(allCases.count)")
    }

    func newFieldsDefaultValues() {
        let memory = AIMemory(
            petId: testPetId,
            category: .preference,
            content: "test",
            source: .userProvided
        )
        expect(memory.importance == 0.5, "default importance should be 0.5")
        expect(memory.accessCount == 0, "default accessCount should be 0")
        expect(memory.expiresAt == nil, "default expiresAt should be nil")
        expect(memory.tags.isEmpty, "default tags should be empty")
    }

    func backwardCompatibleDecoding() {
        let json = """
        {"id":"a","petId":"b","category":"preference","content":"c","createdAt":725846400,"updatedAt":725846400,"source":"userProvided"}
        """.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let memory = try! decoder.decode(AIMemory.self, from: json)
        expect(memory.importance == 0.5, "migrated importance should be 0.5")
        expect(memory.accessCount == 0, "migrated accessCount should be 0")
        expect(memory.expiresAt == nil, "migrated expiresAt should be nil")
        expect(memory.tags.isEmpty, "migrated tags should be empty")
    }

    func newFieldsEncoded() {
        let date = Date().addingTimeInterval(86400)
        let memory = AIMemory(
            petId: testPetId,
            category: .emotion,
            content: "压力大",
            source: .aiExtracted,
            importance: 0.8,
            accessCount: 3,
            expiresAt: date,
            tags: ["work", "stress"]
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try! encoder.encode(memory)
        let json = String(data: data, encoding: .utf8)!
        expect(json.contains("\"importance\" : 0.8"), "should encode importance")
        expect(json.contains("\"accessCount\" : 3"), "should encode accessCount")
        expect(json.contains("\"stress\"") && json.contains("\"work\""), "should encode tags")
    }

    // MARK: - 1.2 Storage Protocol

    func loadByCategory() {
        let store = makeStore()
        defer { try? store.clearAll(petId: testPetId) }

        try! store.add(AIMemory(petId: testPetId, category: .preference, content: "p1", source: .userProvided), petId: testPetId)
        try! store.add(AIMemory(petId: testPetId, category: .emotion, content: "e1", source: .aiExtracted), petId: testPetId)
        try! store.add(AIMemory(petId: testPetId, category: .preference, content: "p2", source: .userProvided), petId: testPetId)

        let prefs = store.loadByCategory(.preference, petId: testPetId)
        expect(prefs.count == 2, "should load 2 preferences, got \(prefs.count)")
        let emotions = store.loadByCategory(.emotion, petId: testPetId)
        expect(emotions.count == 1, "should load 1 emotion")
        let milestones = store.loadByCategory(.milestone, petId: testPetId)
        expect(milestones.isEmpty, "should load 0 milestones")
    }

    func searchByKeyword() {
        let store = makeStore()
        defer { try? store.clearAll(petId: testPetId) }

        try! store.add(AIMemory(petId: testPetId, category: .preference, content: "喜欢蓝色", source: .userProvided), petId: testPetId)
        try! store.add(AIMemory(petId: testPetId, category: .routine, content: "晚上九点活跃", source: .aiExtracted), petId: testPetId)

        let results = store.search(keyword: "蓝色", petId: testPetId)
        expect(results.count == 1, "should find 1 result for '蓝色'")
        expect(results[0].content == "喜欢蓝色", "content should match")
    }

    func searchByTag() {
        let store = makeStore()
        defer { try? store.clearAll(petId: testPetId) }

        try! store.add(AIMemory(petId: testPetId, category: .emotion, content: "开心", source: .aiExtracted, tags: ["mood", "happy"]), petId: testPetId)
        try! store.add(AIMemory(petId: testPetId, category: .preference, content: "喜欢猫", source: .userProvided, tags: ["pet"]), petId: testPetId)

        let results = store.search(keyword: "happy", petId: testPetId)
        expect(results.count == 1, "should find 1 result by tag 'happy'")
    }

    func incrementAccessCount() {
        let store = makeStore()
        defer { try? store.clearAll(petId: testPetId) }

        let memory = AIMemory(petId: testPetId, category: .preference, content: "test", source: .userProvided)
        try! store.add(memory, petId: testPetId)

        try! store.incrementAccessCount(id: memory.id, petId: testPetId)
        try! store.incrementAccessCount(id: memory.id, petId: testPetId)

        let loaded = store.loadAll(petId: testPetId)
        let updated = loaded.first { $0.id == memory.id }
        expect(updated?.accessCount == 2, "accessCount should be 2, got \(updated?.accessCount ?? -1)")
    }

    func incrementAccessCountNotFound() {
        let store = makeStore()
        defer { try? store.clearAll(petId: testPetId) }

        var threw = false
        do {
            try store.incrementAccessCount(id: "nonexistent", petId: testPetId)
        } catch let error as AIMemoryStoreError {
            threw = true
            if case .memoryNotFound = error {
            } else {
                fail("expected memoryNotFound, got \(error)")
            }
        } catch {
            fail("unexpected error: \(error)")
        }
        expect(threw, "should throw memoryNotFound")
    }

    func deleteByCategory() {
        let store = makeStore()
        defer { try? store.clearAll(petId: testPetId) }

        try! store.add(AIMemory(petId: testPetId, category: .interaction, content: "i1", source: .aiExtracted), petId: testPetId)
        try! store.add(AIMemory(petId: testPetId, category: .preference, content: "p1", source: .userProvided), petId: testPetId)
        try! store.add(AIMemory(petId: testPetId, category: .interaction, content: "i2", source: .aiExtracted), petId: testPetId)

        try! store.deleteByCategory(.interaction, petId: testPetId)

        let loaded = store.loadAll(petId: testPetId)
        expect(loaded.count == 1, "should have 1 memory after deleteByCategory")
        expect(loaded[0].category == .preference, "remaining should be preference")
    }

    func memoryStatistics() {
        let store = makeStore(capacity: 10)
        defer { try? store.clearAll(petId: testPetId) }

        try! store.add(AIMemory(petId: testPetId, category: .nickname, content: "n", source: .userProvided), petId: testPetId)
        try! store.add(AIMemory(petId: testPetId, category: .preference, content: "p1", source: .userProvided), petId: testPetId)
        try! store.add(AIMemory(petId: testPetId, category: .preference, content: "p2", source: .userProvided), petId: testPetId)

        let stats = store.memoryStatistics(petId: testPetId)
        expect(stats.totalCount == 3, "totalCount should be 3, got \(stats.totalCount)")
        expect(stats.capacity == 10, "capacity should be 10")
        expect(stats.utilizationRate == 0.3, "utilizationRate should be 0.3")
        expect(stats.categoryCounts[.nickname] == 1, "nickname count should be 1")
        expect(stats.categoryCounts[.preference] == 2, "preference count should be 2")
    }

    // MARK: - 1.3 Eviction Strategy

    func evictionEvaluatorBasic() {
        let evaluator = MemoryEvictionEvaluator()
        let memories = (0..<15).map { i in
            AIMemory(
                petId: "test", category: .interaction,
                content: "互动\(i)", createdAt: Date().addingTimeInterval(Double(i)),
                source: .aiExtracted
            )
        }
        let toEvict = evaluator.evaluateEviction(memories: memories, capacity: 10)
        expect(toEvict.count == 5, "should evict 5 memories, got \(toEvict.count)")
    }

    func evictionProtectsNickname() {
        let evaluator = MemoryEvictionEvaluator()
        var memories: [AIMemory] = [
            AIMemory(petId: "test", category: .nickname, content: "叫咪咪", createdAt: Date().addingTimeInterval(-100), source: .userProvided)
        ]
        for i in 0..<10 {
            memories.append(AIMemory(petId: "test", category: .interaction, content: "互动\(i)", createdAt: Date().addingTimeInterval(Double(i)), source: .aiExtracted))
        }
        let toEvict = evaluator.evaluateEviction(memories: memories, capacity: 5)
        let evictedIds = Set(toEvict)
        let nicknameEvicted = memories.contains { $0.category == .nickname && evictedIds.contains($0.id) }
        expect(!nicknameEvicted, "nickname should not be evicted")
    }

    func evictionProtectsMilestone() {
        let evaluator = MemoryEvictionEvaluator()
        var memories: [AIMemory] = [
            AIMemory(petId: "test", category: .milestone, content: "毕业了", createdAt: Date().addingTimeInterval(-100), source: .userProvided, importance: 0.9)
        ]
        for i in 0..<10 {
            memories.append(AIMemory(petId: "test", category: .interaction, content: "互动\(i)", createdAt: Date().addingTimeInterval(Double(i)), source: .aiExtracted))
        }
        let toEvict = evaluator.evaluateEviction(memories: memories, capacity: 5)
        let evictedIds = Set(toEvict)
        let milestoneEvicted = memories.contains { $0.category == .milestone && evictedIds.contains($0.id) }
        expect(!milestoneEvicted, "milestone should not be evicted")
    }

    func evictionProtectsCustom() {
        let evaluator = MemoryEvictionEvaluator()
        var memories: [AIMemory] = [
            AIMemory(petId: "test", category: .custom, content: "我的猫叫小橘", createdAt: Date().addingTimeInterval(-100), source: .userProvided, importance: 0.9)
        ]
        for i in 0..<10 {
            memories.append(AIMemory(petId: "test", category: .interaction, content: "互动\(i)", createdAt: Date().addingTimeInterval(Double(i)), source: .aiExtracted))
        }
        let toEvict = evaluator.evaluateEviction(memories: memories, capacity: 5)
        let evictedIds = Set(toEvict)
        let customEvicted = memories.contains { $0.category == .custom && evictedIds.contains($0.id) }
        expect(!customEvicted, "custom should not be evicted when interaction memories available")
    }

    func evictionRemovesExpired() {
        let evaluator = MemoryEvictionEvaluator()
        let expiredMemory = AIMemory(
            petId: "test", category: .preference, content: "明天有会议",
            createdAt: Date().addingTimeInterval(-200),
            source: .aiExtracted,
            expiresAt: Date().addingTimeInterval(-100)
        )
        let recentMemory = AIMemory(
            petId: "test", category: .interaction, content: "今天聊天",
            createdAt: Date(), source: .aiExtracted
        )
        let memories = [expiredMemory, recentMemory]
        let toEvict = evaluator.evaluateEviction(memories: memories, capacity: 1)
        expect(toEvict.contains(expiredMemory.id), "expired memory should be evicted first")
        expect(!toEvict.contains(recentMemory.id), "recent memory should not be evicted")
    }

    func evictionScoresByFormula() {
        let evaluator = MemoryEvictionEvaluator()
        let oldLowImportance = AIMemory(
            petId: "test", category: .interaction, content: "旧的低重要度",
            createdAt: Date().addingTimeInterval(-90 * 86400),
            updatedAt: Date().addingTimeInterval(-90 * 86400),
            source: .aiExtracted,
            importance: 0.1,
            accessCount: 0
        )
        let newHighImportance = AIMemory(
            petId: "test", category: .preference, content: "新的高重要度",
            createdAt: Date(),
            source: .userProvided,
            importance: 0.9,
            accessCount: 5
        )
        let memories = [oldLowImportance, newHighImportance]
        let toEvict = evaluator.evaluateEviction(memories: memories, capacity: 1)
        expect(toEvict.contains(oldLowImportance.id), "old low importance should be evicted")
        expect(!toEvict.contains(newHighImportance.id), "new high importance should be kept")
    }

    // MARK: - 1.4 Filter

    func filterProtocolConformance() {
        let filter: AIMemoryFiltering = AIMemoryFilter()
        let result = filter.filter("喜欢吃苹果")
        expect(result.isAllowed, "normal content should be allowed")
    }

    func filterSensitiveContent() {
        let filter = AIMemoryFilter()
        let result = filter.filter("密码是abc123")
        expect(!result.isAllowed, "password content should be rejected")
        expect(result.reason != nil, "should have reason")
    }

    func filterSensitiveAllowedButMarked() {
        let filter = AIMemoryFilter()
        let result = filter.filter("最近压力很大，工作不开心")
        expect(result.isAllowed, "emotional content should be allowed")
        expect(result.isSensitive, "emotional content should be marked as sensitive")
    }

    func filterResultEquality() {
        let a = MemoryFilterResult.allowed
        let b = MemoryFilterResult(isAllowed: true)
        expect(a == b, "allowed results should be equal")

        let c = MemoryFilterResult(isAllowed: false, reason: "test")
        let d = MemoryFilterResult(isAllowed: false, reason: "test")
        expect(c == d, "rejected results with same reason should be equal")

        let sensitive = MemoryFilterResult(isAllowed: true, isSensitive: true)
        let normal = MemoryFilterResult(isAllowed: true, isSensitive: false)
        expect(sensitive != normal, "sensitive and normal results should not be equal")
    }

    // MARK: - 1.5 Compression

    func compressorExpiredRemoval() {
        let compressor = MemoryCompressor()
        let memories = [
            AIMemory(petId: "t", category: .preference, content: "过期", source: .aiExtracted, expiresAt: Date().addingTimeInterval(-100)),
            AIMemory(petId: "t", category: .preference, content: "有效", source: .userProvided),
        ]
        let result = try! compressor.compressIfNeeded(memories: memories)
        expect(result.removedIds.count == 1, "should remove 1 expired memory")
        expect(result.removedIds[0] == memories[0].id, "should remove the expired one")
    }

    func compressorCategoryMerge() {
        let compressor = MemoryCompressor()
        var memories: [AIMemory] = []
        for i in 0..<25 {
            memories.append(AIMemory(
                petId: "t", category: .emotion,
                content: "情绪\(i)",
                createdAt: Date().addingTimeInterval(Double(i)),
                source: .aiExtracted
            ))
        }
        let result = try! compressor.compressIfNeeded(memories: memories)
        expect(!result.removedIds.isEmpty, "should remove some memories")
        expect(!result.createdMemories.isEmpty, "should create compressed memories")
        expect(result.createdMemories[0].tags.contains("compressed"), "compressed memory should have tag")
    }

    func compressorInteractionSummary() {
        let compressor = MemoryCompressor()
        var memories: [AIMemory] = []
        for i in 0..<35 {
            memories.append(AIMemory(
                petId: "t", category: .interaction,
                content: "互动\(i)",
                createdAt: Date().addingTimeInterval(Double(i)),
                source: .aiExtracted
            ))
        }
        let result = try! compressor.compressIfNeeded(memories: memories)
        expect(!result.removedIds.isEmpty, "should remove some interaction memories")
        let created = result.createdMemories.first
        expect(created != nil, "should create a summary memory")
        expect(created?.source == .systemGenerated, "summary should be system generated")
    }

    func compressorNoCompressionNeeded() {
        let compressor = MemoryCompressor()
        let memories = (0..<5).map { i in
            AIMemory(petId: "t", category: .preference, content: "偏好\(i)", source: .userProvided)
        }
        let result = try! compressor.compressIfNeeded(memories: memories)
        expect(result.removedIds.isEmpty, "should not remove anything")
        expect(result.createdMemories.isEmpty, "should not create anything")
    }

    // MARK: - 1.6 Persistence

    func storeBackupOnSave() {
        let store = makeStore()
        defer { try? store.clearAll(petId: testPetId) }

        let m1 = AIMemory(petId: testPetId, category: .preference, content: "first", source: .userProvided)
        try! store.add(m1, petId: testPetId)

        let m2 = AIMemory(petId: testPetId, category: .custom, content: "second", source: .userProvided)
        try! store.add(m2, petId: testPetId)

        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let backupUrl = appSupport
            .appendingPathComponent("DesktopPet")
            .appendingPathComponent(testPetId)
            .appendingPathComponent("ai-memory.json.backup")
        let backupExists = FileManager.default.fileExists(atPath: backupUrl.path)
        expect(backupExists, "backup file should exist after save")
    }

    func storeCacheInvalidation() {
        let store = makeStore()
        defer { try? store.clearAll(petId: testPetId) }

        let m1 = AIMemory(petId: testPetId, category: .preference, content: "cached", source: .userProvided)
        try! store.add(m1, petId: testPetId)

        let first = store.loadAll(petId: testPetId)
        expect(first.count == 1, "first load should have 1")

        try! store.add(AIMemory(petId: testPetId, category: .custom, content: "new", source: .userProvided), petId: testPetId)

        let second = store.loadAll(petId: testPetId)
        expect(second.count == 2, "second load should have 2 after cache update")
    }
}
