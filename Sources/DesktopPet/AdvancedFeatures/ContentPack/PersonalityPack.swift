import Foundation

public struct PersonalityPack: Equatable, Sendable {
    public let manifest: ContentPackManifest
    public let payload: PersonalityPackPayload

    public static func load(from packURL: URL, manifest: ContentPackManifest) throws -> PersonalityPack {
        let url = packURL.appendingPathComponent("content/personality.json")
        let data = try Data(contentsOf: url)
        let payload = try JSONDecoder().decode(PersonalityPackPayload.self, from: data)
        return PersonalityPack(manifest: manifest, payload: payload)
    }

    public func profile() -> AIPersonalityProfile {
        AIPersonalityProfile(
            id: manifest.id,
            name: manifest.name,
            description: manifest.description,
            previewPhrases: payload.previewPhrases.isEmpty ? manifest.previewPhrases : payload.previewPhrases,
            toneGuidelines: payload.guidelines,
            responseMaxLength: 12,
            panelResponseMaxLength: 200,
            canInitiativeBubble: false,
            initiativeBubbleFrequency: 1800
        )
    }

    public func bubbleCatalog() -> BubblePhraseCatalog {
        let phrases = profile().previewPhrases.enumerated().map { index, phrase in
            BubblePhrase(
                id: "\(manifest.id):personality-phrase-\(index)",
                text: phrase,
                triggers: [.idle],
                priority: .ambient,
                weight: 1.0
            )
        }
        return BubblePhraseCatalog(phrases: phrases)
    }
}

public struct PersonalityPackPayload: Codable, Equatable, Sendable {
    public let guidelines: String
    public let previewPhrases: [String]

    public init(guidelines: String, previewPhrases: [String]) {
        self.guidelines = guidelines
        self.previewPhrases = previewPhrases
    }
}
