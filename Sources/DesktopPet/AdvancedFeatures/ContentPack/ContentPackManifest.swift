import Foundation

public struct ContentPackManifest: Codable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let author: String
    public let version: String
    public let type: ContentPackType
    public let description: String
    public let previewPhrases: [String]
    public let safetyTags: [String]
    public let compatiblePetVersion: String

    public init(
        id: String,
        name: String,
        author: String,
        version: String,
        type: ContentPackType,
        description: String,
        previewPhrases: [String],
        safetyTags: [String],
        compatiblePetVersion: String
    ) {
        self.id = id
        self.name = name
        self.author = author
        self.version = version
        self.type = type
        self.description = description
        self.previewPhrases = previewPhrases
        self.safetyTags = safetyTags
        self.compatiblePetVersion = compatiblePetVersion
    }

    public static func load(from packURL: URL, decoder: JSONDecoder = JSONDecoder()) throws -> ContentPackManifest {
        let manifestURL = packURL.appendingPathComponent("manifest.json")
        let data = try Data(contentsOf: manifestURL)
        return try decoder.decode(ContentPackManifest.self, from: data)
    }
}
