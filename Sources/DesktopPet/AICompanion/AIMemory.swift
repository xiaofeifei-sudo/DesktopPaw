import Foundation

public enum AIMemoryCategory: String, Codable, Sendable, CaseIterable {
    case preference
    case nickname
    case interaction
    case custom
    case emotion
    case milestone
    case routine
}

public enum AIMemorySource: String, Codable, Sendable {
    case userProvided
    case aiExtracted
    case systemGenerated
}

public struct AIMemory: Identifiable, Codable, Sendable, Equatable {
    public let id: String
    public let petId: String
    public let category: AIMemoryCategory
    public let content: String
    public let createdAt: Date
    public var updatedAt: Date
    public var source: AIMemorySource
    public var importance: Double
    public var accessCount: Int
    public var expiresAt: Date?
    public var tags: [String]

    private enum CodingKeys: String, CodingKey {
        case id, petId, category, content, createdAt, updatedAt, source
        case importance, accessCount, expiresAt, tags
    }

    public init(
        id: String = UUID().uuidString,
        petId: String,
        category: AIMemoryCategory,
        content: String,
        createdAt: Date = Date(),
        updatedAt: Date? = nil,
        source: AIMemorySource,
        importance: Double = 0.5,
        accessCount: Int = 0,
        expiresAt: Date? = nil,
        tags: [String] = []
    ) {
        self.id = id
        self.petId = petId
        self.category = category
        self.content = content
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
        self.source = source
        self.importance = importance
        self.accessCount = accessCount
        self.expiresAt = expiresAt
        self.tags = tags
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        petId = try container.decode(String.self, forKey: .petId)
        category = try container.decode(AIMemoryCategory.self, forKey: .category)
        content = try container.decode(String.self, forKey: .content)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        source = try container.decode(AIMemorySource.self, forKey: .source)
        importance = try container.decodeIfPresent(Double.self, forKey: .importance) ?? 0.5
        accessCount = try container.decodeIfPresent(Int.self, forKey: .accessCount) ?? 0
        expiresAt = try container.decodeIfPresent(Date.self, forKey: .expiresAt)
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
    }

    public static let defaultCapacity = 100
}
