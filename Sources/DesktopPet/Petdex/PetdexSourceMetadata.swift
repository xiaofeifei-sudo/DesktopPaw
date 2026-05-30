import Foundation

public struct PetdexSourceMetadata: Codable, Equatable, Sendable {
    public static let fileName = "petdex-source.json"

    public let source: PetSource
    public let petdexId: String
    public let originalDisplayName: String
    public let importedAt: Date

    public init(
        source: PetSource = .petdex,
        petdexId: String,
        originalDisplayName: String,
        importedAt: Date
    ) {
        self.source = source
        self.petdexId = petdexId
        self.originalDisplayName = originalDisplayName
        self.importedAt = importedAt
    }

    private enum CodingKeys: String, CodingKey {
        case source
        case petdexId
        case originalDisplayName
        case importedAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.source = try container.decode(PetSource.self, forKey: .source)
        self.petdexId = try container.decode(String.self, forKey: .petdexId)
        self.originalDisplayName = try container.decode(String.self, forKey: .originalDisplayName)

        let importedAtString = try container.decode(String.self, forKey: .importedAt)
        guard let importedAt = ISO8601DateFormatter().date(from: importedAtString) else {
            throw DecodingError.dataCorruptedError(
                forKey: .importedAt,
                in: container,
                debugDescription: "Petdex source importedAt must be an ISO-8601 timestamp."
            )
        }
        self.importedAt = importedAt
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(source, forKey: .source)
        try container.encode(petdexId, forKey: .petdexId)
        try container.encode(originalDisplayName, forKey: .originalDisplayName)
        try container.encode(ISO8601DateFormatter().string(from: importedAt), forKey: .importedAt)
    }
}
