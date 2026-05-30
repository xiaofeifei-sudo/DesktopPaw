import Foundation

public protocol AIVisualActionParsing: Sendable {
    func parse(from response: String, petId: String, source: AIVisualActionSource) -> AIVisualParseResult
}

public struct AIVisualParseResult: Sendable, Equatable {
    public let cleanedResponse: String
    public let candidates: [AIVisualActionCandidate]
    public let parseWarnings: [String]

    public init(
        cleanedResponse: String,
        candidates: [AIVisualActionCandidate],
        parseWarnings: [String]
    ) {
        self.cleanedResponse = cleanedResponse
        self.candidates = candidates
        self.parseWarnings = parseWarnings
    }
}

public final class AIVisualActionParser: AIVisualActionParsing, Sendable {
    public static let maxDescriptionLength = 200

    public init() {}

    public func parse(from response: String, petId: String, source: AIVisualActionSource) -> AIVisualParseResult {
        let (cleanedResponse, rawBlocks) = Self.extractVisualActionBlocks(from: response)

        var candidates: [AIVisualActionCandidate] = []
        var warnings: [String] = []

        for rawJSON in rawBlocks {
            do {
                let candidate = try Self.parseCandidate(from: rawJSON, petId: petId, source: source)
                candidates.append(candidate)
            } catch let error as AIVisualActionParseError {
                warnings.append(error.localizedDescription)
            } catch {
                warnings.append("Invalid visual action JSON: \(error.localizedDescription)")
            }
        }

        return AIVisualParseResult(
            cleanedResponse: cleanedResponse,
            candidates: candidates,
            parseWarnings: warnings
        )
    }

    // MARK: - Private

    private static func extractVisualActionBlocks(from text: String) -> (cleaned: String, blocks: [String]) {
        let openTag = "[VISUAL_ACTION]"
        let closeTag = "[/VISUAL_ACTION]"

        var blocks: [String] = []
        var result = text
        var searchStart = result.startIndex

        while let openRange = result.range(of: openTag, range: searchStart..<result.endIndex),
              let closeRange = result.range(of: closeTag, range: openRange.upperBound..<result.endIndex) {
            let jsonContent = String(result[openRange.upperBound..<closeRange.lowerBound])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            blocks.append(jsonContent)
            result.removeSubrange(openRange.lowerBound..<closeRange.upperBound)
            searchStart = openRange.lowerBound
        }

        return (result.trimmingCharacters(in: .whitespacesAndNewlines), blocks)
    }

    private static func parseCandidate(
        from rawJSON: String,
        petId: String,
        source: AIVisualActionSource
    ) throws -> AIVisualActionCandidate {
        guard let data = rawJSON.data(using: .utf8) else {
            throw AIVisualActionParseError.invalidJSON
        }

        let decoded: VisualActionJSON
        do {
            decoded = try JSONDecoder().decode(VisualActionJSON.self, from: data)
        } catch {
            throw AIVisualActionParseError.invalidJSON
        }

        guard let kind = AIVisualActionKind(rawValue: decoded.kind) else {
            throw AIVisualActionParseError.unknownKind(decoded.kind)
        }

        guard !decoded.description.isEmpty else {
            throw AIVisualActionParseError.emptyDescription
        }

        if decoded.description.count > maxDescriptionLength {
            throw AIVisualActionParseError.descriptionTooLong(decoded.description.count)
        }

        let renderMode = PetVisualRenderMode(rawValue: decoded.renderMode ?? "replaceWholeImage")
            ?? .replaceWholeImage

        let impact = AIVisualActionImpact(rawValue: decoded.impact ?? "low")
            ?? .low

        let durationSeconds = decoded.durationSeconds.map { max($0, 0) } ?? 60

        let resolvedSource: AIVisualActionSource
        if let sourceString = decoded.source,
           let jsonSource = AIVisualActionSource(rawValue: sourceString) {
            resolvedSource = jsonSource
        } else {
            resolvedSource = source
        }

        return AIVisualActionCandidate(
            id: UUID().uuidString,
            petId: petId,
            source: resolvedSource,
            kind: kind,
            description: decoded.description,
            promptHint: nil,
            renderMode: renderMode,
            requestedDurationSeconds: durationSeconds,
            impact: impact,
            createdAt: Date()
        )
    }
}

// MARK: - Internal JSON Decoding

private struct VisualActionJSON: Codable {
    let kind: String
    let description: String
    let renderMode: String?
    let durationSeconds: TimeInterval?
    let impact: String?
    let source: String?
}

// MARK: - Parse Errors

enum AIVisualActionParseError: Error, CustomStringConvertible, Equatable {
    case invalidJSON
    case unknownKind(String)
    case emptyDescription
    case descriptionTooLong(Int)

    var description: String {
        switch self {
        case .invalidJSON:
            return "Visual action JSON is invalid or malformed"
        case .unknownKind(let kind):
            return "Unknown visual action kind: \(kind)"
        case .emptyDescription:
            return "Visual action description is empty"
        case .descriptionTooLong(let count):
            return "Visual action description too long: \(count) chars (max \(AIVisualActionParser.maxDescriptionLength))"
        }
    }
}
