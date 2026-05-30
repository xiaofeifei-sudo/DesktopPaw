import Foundation

public struct MemoryStatistics: Sendable, Equatable {
    public let totalCount: Int
    public let capacity: Int
    public let categoryCounts: [AIMemoryCategory: Int]
    public let utilizationRate: Double

    public init(totalCount: Int, capacity: Int, categoryCounts: [AIMemoryCategory: Int]) {
        self.totalCount = totalCount
        self.capacity = capacity
        self.categoryCounts = categoryCounts
        self.utilizationRate = capacity > 0 ? Double(totalCount) / Double(capacity) : 0
    }
}

public protocol AIMemoryStoring: AnyObject, Sendable {
    func loadAll(petId: String) -> [AIMemory]
    func add(_ memory: AIMemory, petId: String) throws
    func update(_ memory: AIMemory, petId: String) throws
    func delete(memoryId: String, petId: String) throws
    func clearAll(petId: String) throws
    func exportMemories(petId: String) throws -> URL
    func isMemoryEnabled(petId: String) -> Bool
    func setMemoryEnabled(_ enabled: Bool, petId: String)

    func loadByCategory(_ category: AIMemoryCategory, petId: String) -> [AIMemory]
    func search(keyword: String, petId: String) -> [AIMemory]
    func incrementAccessCount(id: String, petId: String) throws
    func deleteByCategory(_ category: AIMemoryCategory, petId: String) throws
    func memoryStatistics(petId: String) -> MemoryStatistics
}

public enum AIMemoryStoreError: Error, Sendable, Equatable, LocalizedError {
    case filterRejected(reason: String)
    case memoryNotFound(id: String)
    case storageError(String)
    case memoryDisabled

    public var errorDescription: String? {
        switch self {
        case .filterRejected(let reason):
            "记忆写入被拒绝：\(reason)"
        case .memoryNotFound(let id):
            "记忆不存在：\(id)"
        case .storageError(let message):
            "存储错误：\(message)"
        case .memoryDisabled:
            "记忆功能已关闭"
        }
    }
}

public final class AIMemoryStore: AIMemoryStoring, @unchecked Sendable {
    private let filter: AIMemoryFilter
    private let evictionEvaluator: MemoryEvictionEvaluating
    private let fileManager: FileManager
    private let capacity: Int
    private var enabledCache: [String: Bool] = [:]
    private var memoryCache: [String: [AIMemory]] = [:]

    public init(
        filter: AIMemoryFilter = AIMemoryFilter(),
        evictionEvaluator: MemoryEvictionEvaluating = MemoryEvictionEvaluator(),
        fileManager: FileManager = .default,
        capacity: Int = AIMemory.defaultCapacity
    ) {
        self.filter = filter
        self.evictionEvaluator = evictionEvaluator
        self.fileManager = fileManager
        self.capacity = capacity
    }

    public func loadAll(petId: String) -> [AIMemory] {
        guard isMemoryEnabled(petId: petId) else { return [] }
        return cachedMemories(petId: petId)
    }

    public func add(_ memory: AIMemory, petId: String) throws {
        guard isMemoryEnabled(petId: petId) else {
            throw AIMemoryStoreError.memoryDisabled
        }

        let filterResult = filter.filter(memory.content)
        guard filterResult.isAllowed else {
            throw AIMemoryStoreError.filterRejected(reason: filterResult.reason ?? "敏感内容")
        }

        var memories = cachedMemories(petId: petId)
        memories.append(memory)
        memories = evictIfNeeded(memories)
        try saveToDisk(memories, petId: petId)
        memoryCache[petId] = memories
    }

    public func update(_ memory: AIMemory, petId: String) throws {
        guard isMemoryEnabled(petId: petId) else {
            throw AIMemoryStoreError.memoryDisabled
        }

        let filterResult = filter.filter(memory.content)
        guard filterResult.isAllowed else {
            throw AIMemoryStoreError.filterRejected(reason: filterResult.reason ?? "敏感内容")
        }

        var memories = cachedMemories(petId: petId)
        guard let index = memories.firstIndex(where: { $0.id == memory.id }) else {
            throw AIMemoryStoreError.memoryNotFound(id: memory.id)
        }
        memories[index] = memory
        try saveToDisk(memories, petId: petId)
        memoryCache[petId] = memories
    }

    public func delete(memoryId: String, petId: String) throws {
        var memories = cachedMemories(petId: petId)
        let countBefore = memories.count
        memories.removeAll { $0.id == memoryId }
        guard memories.count < countBefore else {
            throw AIMemoryStoreError.memoryNotFound(id: memoryId)
        }
        try saveToDisk(memories, petId: petId)
        memoryCache[petId] = memories
    }

    public func clearAll(petId: String) throws {
        try saveToDisk([], petId: petId)
        memoryCache[petId] = []
    }

    public func exportMemories(petId: String) throws -> URL {
        let memories = cachedMemories(petId: petId)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(memories)

        let tempDir = fileManager.temporaryDirectory
        let fileName = "ai-memory-\(petId)-\(Int(Date().timeIntervalSince1970)).json"
        let url = tempDir.appendingPathComponent(fileName)
        try data.write(to: url)
        return url
    }

    public func isMemoryEnabled(petId: String) -> Bool {
        if let cached = enabledCache[petId] {
            return cached
        }
        let key = memoryEnabledKey(petId: petId)
        let value = UserDefaults.standard.object(forKey: key) as? Bool ?? true
        enabledCache[petId] = value
        return value
    }

    public func setMemoryEnabled(_ enabled: Bool, petId: String) {
        let key = memoryEnabledKey(petId: petId)
        UserDefaults.standard.set(enabled, forKey: key)
        enabledCache[petId] = enabled
        if !enabled {
            memoryCache.removeValue(forKey: petId)
        }
    }

    public func loadByCategory(_ category: AIMemoryCategory, petId: String) -> [AIMemory] {
        guard isMemoryEnabled(petId: petId) else { return [] }
        return cachedMemories(petId: petId).filter { $0.category == category }
    }

    public func search(keyword: String, petId: String) -> [AIMemory] {
        guard isMemoryEnabled(petId: petId) else { return [] }
        let lowercased = keyword.lowercased()
        return cachedMemories(petId: petId).filter { memory in
            memory.content.lowercased().contains(lowercased) ||
            memory.tags.contains { $0.lowercased().contains(lowercased) }
        }
    }

    public func incrementAccessCount(id: String, petId: String) throws {
        var memories = cachedMemories(petId: petId)
        guard let index = memories.firstIndex(where: { $0.id == id }) else {
            throw AIMemoryStoreError.memoryNotFound(id: id)
        }
        memories[index].accessCount += 1
        try saveToDisk(memories, petId: petId)
        memoryCache[petId] = memories
    }

    public func deleteByCategory(_ category: AIMemoryCategory, petId: String) throws {
        var memories = cachedMemories(petId: petId)
        memories.removeAll { $0.category == category }
        try saveToDisk(memories, petId: petId)
        memoryCache[petId] = memories
    }

    public func memoryStatistics(petId: String) -> MemoryStatistics {
        let memories = cachedMemories(petId: petId)
        var categoryCounts: [AIMemoryCategory: Int] = [:]
        for category in AIMemoryCategory.allCases {
            categoryCounts[category] = 0
        }
        for memory in memories {
            categoryCounts[memory.category, default: 0] += 1
        }
        return MemoryStatistics(
            totalCount: memories.count,
            capacity: capacity,
            categoryCounts: categoryCounts
        )
    }

    // MARK: - Private

    private func memoryFileURL(petId: String) -> URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport
            .appendingPathComponent("DesktopPet")
            .appendingPathComponent(petId)
            .appendingPathComponent("ai-memory.json")
    }

    private func backupFileURL(petId: String) -> URL {
        memoryFileURL(petId: petId).appendingPathExtension("backup")
    }

    private func memoryEnabledKey(petId: String) -> String {
        "ai-memory-enabled-\(petId)"
    }

    private func cachedMemories(petId: String) -> [AIMemory] {
        if let cached = memoryCache[petId] {
            return cached
        }
        let loaded = loadFromDisk(petId: petId)
        memoryCache[petId] = loaded
        return loaded
    }

    private func loadFromDisk(petId: String) -> [AIMemory] {
        let url = memoryFileURL(petId: petId)
        guard fileManager.fileExists(atPath: url.path) else { return [] }
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode([AIMemory].self, from: data)
        } catch {
            DesktopPetLog.aiCompanion.warning("Failed to load memories for \(petId): \(error.localizedDescription)")
            return []
        }
    }

    private func saveToDisk(_ memories: [AIMemory], petId: String) throws {
        let url = memoryFileURL(petId: petId)
        let directory = url.deletingLastPathComponent()

        if !fileManager.fileExists(atPath: directory.path) {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }

        if fileManager.fileExists(atPath: url.path) {
            let backupUrl = backupFileURL(petId: petId)
            try? fileManager.removeItem(at: backupUrl)
            try? fileManager.copyItem(at: url, to: backupUrl)
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(memories)
        try data.write(to: url, options: .atomic)
    }

    private func evictIfNeeded(_ memories: [AIMemory]) -> [AIMemory] {
        guard memories.count > capacity else { return memories }

        let idsToRemove = evictionEvaluator.evaluateEviction(memories: memories, capacity: capacity)
        let removeSet = Set(idsToRemove)
        return memories.filter { !removeSet.contains($0.id) }
    }
}
