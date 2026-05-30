import Foundation

public protocol MemoryEvictionEvaluating: Sendable {
    func evaluateEviction(memories: [AIMemory], capacity: Int) -> [String]
}

public struct MemoryEvictionEvaluator: MemoryEvictionEvaluating, Sendable {
    public init() {}

    public func evaluateEviction(memories: [AIMemory], capacity: Int) -> [String] {
        let overloaded = memories.count - capacity
        guard overloaded > 0 else { return [] }

        let now = Date()
        var scored: [(memory: AIMemory, score: Double)] = []

        for memory in memories {
            if let expiresAt = memory.expiresAt, expiresAt < now {
                scored.append((memory, .infinity))
                continue
            }
            let score = evictionScore(memory: memory, now: now)
            scored.append((memory, score))
        }

        scored.sort { $0.score > $1.score }

        return Array(scored.prefix(overloaded)).map(\.memory.id)
    }

    private func evictionScore(memory: AIMemory, now: Date) -> Double {
        let daysSinceUpdate = now.timeIntervalSince(memory.updatedAt) / 86400
        let timeDecay = min(daysSinceUpdate / 90.0, 1.0)
        let lowImportance = 1.0 - memory.importance
        let lowAccess = 1.0 - min(Double(memory.accessCount) / 10.0, 1.0)
        let categoryWeight = categoryEvictionWeight(memory.category)
        let expired = memory.expiresAt.map { $0 < now ? 1.0 : 0.0 } ?? 0.0

        return timeDecay * 0.3 + lowImportance * 0.25 + lowAccess * 0.2 + categoryWeight * 0.15 + expired * 0.1
    }

    private func categoryEvictionWeight(_ category: AIMemoryCategory) -> Double {
        switch category {
        case .nickname: 0.0
        case .milestone: 0.1
        case .custom: 0.2
        case .preference: 0.6
        case .routine: 0.7
        case .emotion: 0.7
        case .interaction: 0.9
        }
    }
}
