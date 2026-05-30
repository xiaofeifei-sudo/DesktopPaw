import Foundation

public struct DialoguePack: Equatable, Sendable {
    public let manifest: ContentPackManifest
    public let entries: [DialoguePackEntry]

    public static func load(from packURL: URL, manifest: ContentPackManifest) throws -> DialoguePack {
        let url = packURL.appendingPathComponent("content/phrases.json")
        let data = try Data(contentsOf: url)
        let entries = try JSONDecoder().decode([DialoguePackEntry].self, from: data)
        return DialoguePack(manifest: manifest, entries: entries)
    }

    public func bubbleCatalog() -> BubblePhraseCatalog {
        let phrases = entries.enumerated().map { index, entry in
            let localId = entry.id ?? "phrase-\(index)"
            return BubblePhrase(
                id: "\(manifest.id):\(localId)",
                text: entry.text,
                triggers: [entry.trigger],
                priority: entry.bubblePriority,
                weight: entry.weight ?? 1.0
            )
        }
        return BubblePhraseCatalog(phrases: phrases)
    }
}
public struct DialoguePackEntry: Codable, Equatable, Sendable {
    public let id: String?
    public let trigger: BubbleTrigger
    public let text: String
    public let priority: String?
    public let weight: Double?
    public let safetyTags: [String]

    public init(
        id: String? = nil,
        trigger: BubbleTrigger,
        text: String,
        priority: String? = nil,
        weight: Double? = nil,
        safetyTags: [String] = []
    ) {
        self.id = id
        self.trigger = trigger
        self.text = text
        self.priority = priority
        self.weight = weight
        self.safetyTags = safetyTags
    }

    public var bubblePriority: BubblePriority {
        switch priority {
        case "decorative": .decorative
        case "relationship": .relationship
        case "state": .state
        case "interaction": .interaction
        default: .ambient
        }
    }
}
