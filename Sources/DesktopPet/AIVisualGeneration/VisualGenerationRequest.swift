import Foundation

public struct VisualGenerationRequest: Sendable, Equatable {
    public let actionId: String
    public let petId: String
    public let prompt: String
    public let referenceImageURL: URL?
    public let aspectRatio: String
    public let outputDirectory: URL
    public let outputPrefix: String
    public let count: Int
    public let generationIntent: GenerationIntent?
    public let consistencyPreference: ConsistencyPreference?
    public let processedReferenceURL: URL?
    public let negativeConstraints: [String]?
    public let identityDescription: String?
    public let targetWidth: Int?
    public let targetHeight: Int?
    public let seed: Int?
    public let responseFormat: String?

    public init(
        actionId: String,
        petId: String,
        prompt: String,
        referenceImageURL: URL? = nil,
        aspectRatio: String = "1:1",
        outputDirectory: URL,
        outputPrefix: String,
        count: Int = 1,
        generationIntent: GenerationIntent? = nil,
        consistencyPreference: ConsistencyPreference? = nil,
        processedReferenceURL: URL? = nil,
        negativeConstraints: [String]? = nil,
        identityDescription: String? = nil,
        targetWidth: Int? = nil,
        targetHeight: Int? = nil,
        seed: Int? = nil,
        responseFormat: String? = nil
    ) {
        self.actionId = actionId
        self.petId = petId
        self.prompt = prompt
        self.referenceImageURL = referenceImageURL
        self.aspectRatio = aspectRatio
        self.outputDirectory = outputDirectory
        self.outputPrefix = outputPrefix
        self.count = count
        self.generationIntent = generationIntent
        self.consistencyPreference = consistencyPreference
        self.processedReferenceURL = processedReferenceURL
        self.negativeConstraints = negativeConstraints
        self.identityDescription = identityDescription
        self.targetWidth = targetWidth
        self.targetHeight = targetHeight
        self.seed = seed
        self.responseFormat = responseFormat
    }
}
