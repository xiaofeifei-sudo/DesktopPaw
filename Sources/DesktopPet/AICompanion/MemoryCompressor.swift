import Foundation

public protocol MemoryCompressing: Sendable {
    func compressIfNeeded(memories: [AIMemory]) throws -> CompressionResult
}

public struct CompressionResult: Sendable, Equatable {
    public let removedIds: [String]
    public let createdMemories: [AIMemory]

    public init(removedIds: [String], createdMemories: [AIMemory]) {
        self.removedIds = removedIds
        self.createdMemories = createdMemories
    }

    public static let none = CompressionResult(removedIds: [], createdMemories: [])
}

public struct MemoryCompressor: MemoryCompressing, Sendable {
    private let categoryThreshold = 20
    private let interactionThreshold = 30

    public init() {}

    public func compressIfNeeded(memories: [AIMemory]) throws -> CompressionResult {
        let now = Date()
        var expiredIds = [String]()
        var remaining = [AIMemory]()

        for memory in memories {
            if let expiresAt = memory.expiresAt, expiresAt < now {
                expiredIds.append(memory.id)
            } else {
                remaining.append(memory)
            }
        }

        var allRemovedIds = expiredIds
        var createdMemories = [AIMemory]()

        let categoryGroups = Dictionary(grouping: remaining) { $0.category }

        for (category, group) in categoryGroups {
            let threshold = category == .interaction ? interactionThreshold : categoryThreshold
            guard group.count > threshold else { continue }

            let sorted = group.sorted { $0.updatedAt > $1.updatedAt }
            let toKeep = sorted.prefix(threshold / 2)
            let toRemove = sorted.dropFirst(threshold / 2)

            allRemovedIds.append(contentsOf: toRemove.map(\.id))

            let summaryContent = summarize(
                category: category,
                memories: Array(toRemove),
                petId: group.first?.petId ?? ""
            )
            if !summaryContent.isEmpty {
                let compressed = AIMemory(
                    petId: group.first?.petId ?? "",
                    category: category,
                    content: summaryContent,
                    source: .systemGenerated,
                    importance: 0.4,
                    tags: ["compressed"]
                )
                createdMemories.append(compressed)
            }
        }

        if allRemovedIds.isEmpty && createdMemories.isEmpty {
            return .none
        }

        return CompressionResult(removedIds: allRemovedIds, createdMemories: createdMemories)
    }

    private func summarize(category: AIMemoryCategory, memories: [AIMemory], petId: String) -> String {
        guard !memories.isEmpty else { return "" }

        switch category {
        case .interaction:
            let count = memories.count
            let dateRange: String = {
                let dates = memories.map(\.updatedAt).sorted()
                let formatter = DateFormatter()
                formatter.dateFormat = "M/d"
                return "\(formatter.string(from: dates.first!))-\(formatter.string(from: dates.last!))"
            }()
            return "[归纳] \(dateRange)期间共\(count)次互动摘要"
        default:
            let contents = memories.map(\.content).joined(separator: "；")
            return "[合并] \(contents)"
        }
    }
}
