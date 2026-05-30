import Foundation

public enum ActionPackSource: String, Codable, Equatable, Sendable {
    case localImage
    case aiGeneration
    case historyAsset
}

public struct ActionPackSourceMetadata: Codable, Equatable, Sendable {
    public let source: ActionPackSource
    public let createdAt: Date
    public let provider: String?
    public let model: String?
    public let prompt: String?
    public let negativePrompt: String?
    public let seed: String?
    public let inputImages: [String]
    public let notes: String?

    public init(
        source: ActionPackSource,
        createdAt: Date,
        provider: String? = nil,
        model: String? = nil,
        prompt: String? = nil,
        negativePrompt: String? = nil,
        seed: String? = nil,
        inputImages: [String] = [],
        notes: String? = nil
    ) {
        self.source = source
        self.createdAt = createdAt
        self.provider = provider
        self.model = model
        self.prompt = prompt
        self.negativePrompt = negativePrompt
        self.seed = seed
        self.inputImages = inputImages
        self.notes = notes
    }

    public func sanitized() -> ActionPackSourceMetadata {
        ActionPackSourceMetadata(
            source: source,
            createdAt: createdAt,
            provider: provider.map { Self.redactSensitive($0) },
            model: model.map { Self.redactSensitive($0) },
            prompt: prompt.map { Self.redactSensitive($0) },
            negativePrompt: negativePrompt.map { Self.redactSensitive($0) },
            seed: seed.map { Self.redactSensitive($0) },
            inputImages: inputImages.map { Self.redactSensitive($0) },
            notes: notes.map { Self.redactSensitive($0) }
        )
    }

    private static func redactSensitive(_ value: String) -> String {
        var result = value
        let patterns = [
            "(?i)(api[_-]?key|apikey|secret|token|password|credential)[=: ]+\\S+",
            "(?i)/Users/[^\\s]+",
            "(?i)/home/[^\\s]+",
            "(?i)C:\\\\Users\\\\[^\\s]+"
        ]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                result = regex.stringByReplacingMatches(
                    in: result,
                    range: NSRange(result.startIndex..., in: result),
                    withTemplate: "[REDACTED]"
                )
            }
        }
        return result
    }
}
