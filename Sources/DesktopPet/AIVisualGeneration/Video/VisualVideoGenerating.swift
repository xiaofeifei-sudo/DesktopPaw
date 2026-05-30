import Foundation

public enum HailuoModel: String, Codable, Sendable, Equatable, CaseIterable {
    case fast = "MiniMax-Hailuo-2.3-Fast"
    case standard = "MiniMax-Hailuo-2.3"
}

public struct VisualVideoGenerationRequest: Sendable, Equatable {
    public let experimentId: String
    public let petId: String
    public let prompt: String
    public let model: HailuoModel
    public let firstFrameImageURL: URL?
    public let outputDirectory: URL

    public init(
        experimentId: String,
        petId: String,
        prompt: String,
        model: HailuoModel,
        firstFrameImageURL: URL? = nil,
        outputDirectory: URL
    ) {
        self.experimentId = experimentId
        self.petId = petId
        self.prompt = prompt
        self.model = model
        self.firstFrameImageURL = firstFrameImageURL
        self.outputDirectory = outputDirectory
    }
}

public struct VisualVideoGenerationResult: Sendable, Equatable {
    public let experimentId: String
    public let videoURL: URL
    public let model: HailuoModel
    public let durationSeconds: Double

    public init(
        experimentId: String,
        videoURL: URL,
        model: HailuoModel,
        durationSeconds: Double
    ) {
        self.experimentId = experimentId
        self.videoURL = videoURL
        self.model = model
        self.durationSeconds = durationSeconds
    }
}

public protocol VisualVideoGenerating: Sendable {
    var providerId: String { get }
    var displayName: String { get }
    var isConfigured: Bool { get }

    func generateVideo(_ request: VisualVideoGenerationRequest) async throws -> VisualVideoGenerationResult
    func refreshConfiguration() async
}
