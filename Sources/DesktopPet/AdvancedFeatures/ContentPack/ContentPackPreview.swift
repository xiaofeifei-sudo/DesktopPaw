import Foundation

public struct ContentPackPreview: Equatable, Sendable {
    public let packId: String
    public let type: ContentPackType
    public let name: String
    public let previewPhrases: [String]
    public let phrases: [String]
    public let personalityName: String?
    public let actionNames: [String]

    public init(
        packId: String,
        type: ContentPackType,
        name: String,
        previewPhrases: [String],
        phrases: [String] = [],
        personalityName: String? = nil,
        actionNames: [String] = []
    ) {
        self.packId = packId
        self.type = type
        self.name = name
        self.previewPhrases = previewPhrases
        self.phrases = phrases
        self.personalityName = personalityName
        self.actionNames = actionNames
    }
}
