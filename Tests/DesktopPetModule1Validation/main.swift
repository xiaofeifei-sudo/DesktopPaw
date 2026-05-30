import Foundation
import DesktopPet

@MainActor
func runModule1Validation() {
    print("=== Module 1 Validation ===")

    // 1.1 Data Model
    print("1.1 Data Model...")
    let allCases = AIMemoryCategory.allCases
    assert(allCases.contains(.emotion), "emotion category missing")
    assert(allCases.contains(.milestone), "milestone category missing")
    assert(allCases.contains(.routine), "routine category missing")
    assert(allCases.count == 7, "expected 7 categories, got \(allCases.count)")

    let memory = AIMemory(petId: "t", category: .preference, content: "test", source: .userProvided)
    assert(memory.importance == 0.5, "default importance wrong")
    assert(memory.accessCount == 0, "default accessCount wrong")
    assert(memory.expiresAt == nil, "default expiresAt wrong")
    assert(memory.tags.isEmpty, "default tags wrong")

    let json = """
    {"id":"a","petId":"b","category":"preference","content":"c","createdAt":725846400,"updatedAt":725846400,"source":"userProvided"}
    """.data(using: .utf8)!
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .secondsSince1970
    let migrated = try! decoder.decode(AIMemory.self, from: json)
    assert(migrated.importance == 0.5, "migrated importance wrong")
    assert(migrated.accessCount == 0, "migrated accessCount wrong")
    print("  PASSED: categories, fields, backward compat")

    // 1.3 Eviction
    print("1.3 Eviction Strategy...")
    let evaluator = MemoryEvictionEvaluator()

    let manyMemories = (0..<15).map { i in
        AIMemory(petId: "t", category: .interaction, content: "互动\(i)", createdAt: Date().addingTimeInterval(Double(i)), source: .aiExtracted)
    }
    let evicted = evaluator.evaluateEviction(memories: manyMemories, capacity: 10)
    assert(evicted.count == 5, "should evict 5, got \(evicted.count)")

    var withNick: [AIMemory] = [AIMemory(petId: "t", category: .nickname, content: "叫咪咪", createdAt: Date().addingTimeInterval(-100), source: .userProvided)]
    withNick += (0..<10).map { i in AIMemory(petId: "t", category: .interaction, content: "互动\(i)", createdAt: Date().addingTimeInterval(Double(i)), source: .aiExtracted) }
    let nickEvict = evaluator.evaluateEviction(memories: withNick, capacity: 5)
    assert(!nickEvict.contains(withNick[0].id), "nickname should be protected")

    var withMile: [AIMemory] = [AIMemory(petId: "t", category: .milestone, content: "毕业", createdAt: Date().addingTimeInterval(-100), source: .userProvided, importance: 0.9)]
    withMile += (0..<10).map { i in AIMemory(petId: "t", category: .interaction, content: "互动\(i)", createdAt: Date().addingTimeInterval(Double(i)), source: .aiExtracted) }
    let mileEvict = evaluator.evaluateEviction(memories: withMile, capacity: 5)
    assert(!mileEvict.contains(withMile[0].id), "milestone should be protected")

    let expired = AIMemory(petId: "t", category: .preference, content: "过期", createdAt: Date().addingTimeInterval(-200), source: .aiExtracted, expiresAt: Date().addingTimeInterval(-100))
    let recent = AIMemory(petId: "t", category: .interaction, content: "近期", createdAt: Date(), source: .aiExtracted)
    let expEvict = evaluator.evaluateEviction(memories: [expired, recent], capacity: 1)
    assert(expEvict.contains(expired.id), "expired should be evicted first")
    assert(!expEvict.contains(recent.id), "recent should be kept")
    print("  PASSED: basic, protected categories, expired removal")

    // 1.4 Filter
    print("1.4 Filter Enhancement...")
    let filter = AIMemoryFilter()

    let safe = filter.filter("喜欢吃苹果")
    assert(safe.isAllowed && !safe.isSensitive, "normal content should pass")

    let blocked = filter.filter("密码是abc123")
    assert(!blocked.isAllowed, "password should be blocked")

    let sensitive = filter.filter("最近压力很大，很焦虑")
    assert(sensitive.isAllowed, "emotional content should be allowed")
    assert(sensitive.isSensitive, "emotional content should be marked sensitive")

    let filterProtocol: AIMemoryFiltering = AIMemoryFilter()
    let protoResult = filterProtocol.filter("正常内容")
    assert(protoResult.isAllowed, "protocol conformance works")
    print("  PASSED: protocol, sensitive marking")

    // 1.5 Compression
    print("1.5 Compression...")
    let compressor = MemoryCompressor()

    let few = (0..<5).map { i in AIMemory(petId: "t", category: .preference, content: "p\(i)", source: .userProvided) }
    let noResult = try! compressor.compressIfNeeded(memories: few)
    assert(noResult.removedIds.isEmpty, "should not compress few memories")

    let withExpired2 = [
        AIMemory(petId: "t", category: .preference, content: "过期", source: .aiExtracted, expiresAt: Date().addingTimeInterval(-100)),
        AIMemory(petId: "t", category: .preference, content: "有效", source: .userProvided),
    ]
    let expResult = try! compressor.compressIfNeeded(memories: withExpired2)
    assert(expResult.removedIds.count == 1, "should remove 1 expired")

    var many2: [AIMemory] = []
    for i in 0..<25 {
        many2.append(AIMemory(petId: "t", category: .emotion, content: "情绪\(i)", createdAt: Date().addingTimeInterval(Double(i)), source: .aiExtracted))
    }
    let mergeResult = try! compressor.compressIfNeeded(memories: many2)
    assert(!mergeResult.removedIds.isEmpty, "should remove excess")
    assert(!mergeResult.createdMemories.isEmpty, "should create compressed")
    assert(mergeResult.createdMemories[0].tags.contains("compressed"), "should have compressed tag")
    print("  PASSED: expired, category merge, threshold")

    // 1.2 & 1.6 Store integration
    print("1.2 & 1.6 Store Integration...")
    let testPetId = "mod1-validate-\(UUID().uuidString.prefix(8))"
    let store = AIMemoryStore(fileManager: .default, capacity: 20)
    defer { try? store.clearAll(petId: testPetId) }

    let m1 = AIMemory(petId: testPetId, category: .preference, content: "喜欢蓝色", source: .userProvided, importance: 0.8, tags: ["color"])
    let m2 = AIMemory(petId: testPetId, category: .emotion, content: "压力大", source: .aiExtracted, tags: ["work"])
    let m3 = AIMemory(petId: testPetId, category: .milestone, content: "毕业了", source: .userProvided, importance: 0.9)
    try! store.add(m1, petId: testPetId)
    try! store.add(m2, petId: testPetId)
    try! store.add(m3, petId: testPetId)

    let prefs = store.loadByCategory(.preference, petId: testPetId)
    assert(prefs.count == 1, "should have 1 preference")

    let searchResult = store.search(keyword: "蓝色", petId: testPetId)
    assert(searchResult.count == 1, "search should find 1")
    let tagSearch = store.search(keyword: "work", petId: testPetId)
    assert(tagSearch.count == 1, "tag search should find 1")

    try! store.incrementAccessCount(id: m1.id, petId: testPetId)
    let loaded = store.loadAll(petId: testPetId)
    let updated = loaded.first { $0.id == m1.id }
    assert(updated?.accessCount == 1, "accessCount should be 1")

    try! store.deleteByCategory(.emotion, petId: testPetId)
    let afterDelete = store.loadAll(petId: testPetId)
    assert(afterDelete.count == 2, "should have 2 after deleteByCategory")

    let stats = store.memoryStatistics(petId: testPetId)
    assert(stats.totalCount == 2, "total should be 2")
    assert(stats.capacity == 20, "capacity should be 20")
    assert(stats.categoryCounts[.preference] == 1, "preference count should be 1")

    try! store.add(AIMemory(petId: testPetId, category: .routine, content: "晚9点活跃", source: .aiExtracted), petId: testPetId)
    let cached = store.loadAll(petId: testPetId)
    assert(cached.count == 3, "cache should reflect new add")
    print("  PASSED: loadByCategory, search, incrementAccessCount, deleteByCategory, statistics, cache")

    print("=== Module 1 All Validations PASSED ===")
}

runModule1Validation()
