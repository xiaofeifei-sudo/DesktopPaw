import Foundation

public final class MiniMaxCLIVideoGenerator: VisualVideoGenerating, @unchecked Sendable {
    public let providerId = "minimax-cli-video"
    public let displayName = "MiniMax CLI Video (Hailuo)"

    private let client: MiniMaxCLIClient
    private let processRunner: ProcessRunning
    private let queue = DispatchQueue(label: "minimax-cli-video-generator")
    private var _cachedConfigured: Bool?

    public init(client: MiniMaxCLIClient, processRunner: ProcessRunning) {
        self.client = client
        self.processRunner = processRunner
    }

    public var isConfigured: Bool {
        queue.sync {
            if let cached = _cachedConfigured { return cached }
            return false
        }
    }

    public func refreshConfiguration() async {
        let available = await client.checkAvailability()
        if available {
            let auth = (try? await client.checkAuthStatus()) ?? MiniMaxAuthStatus(isAuthenticated: false)
            queue.sync { _cachedConfigured = auth.isAuthenticated }
        } else {
            queue.sync { _cachedConfigured = false }
        }
    }

    public func generateVideo(_ request: VisualVideoGenerationRequest) async throws -> VisualVideoGenerationResult {
        guard isConfigured else {
            throw VisualGenerationError.notConfigured(providerId: providerId)
        }

        guard let executableURL = client.executableURL() else {
            throw VisualGenerationError.notConfigured(providerId: providerId)
        }

        let outputDir = request.outputDirectory
        try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

        let outputFile = outputDir.appendingPathComponent("\(request.experimentId).mp4")

        var arguments = [
            "video", "generate",
            "--prompt", request.prompt,
            "--model", request.model.rawValue,
            "--download", outputFile.path
        ]

        if let firstFrame = request.firstFrameImageURL {
            arguments += ["--first-frame", firstFrame.path]
        }

        let startTime = Date()

        let result: SubprocessResult
        do {
            result = try await processRunner.run(
                executableURL: executableURL,
                arguments: arguments,
                currentDirectoryURL: outputDir
            )
        } catch {
            throw VisualGenerationError.unknown(providerId: providerId, underlying: String(describing: error))
        }

        let elapsed = Date().timeIntervalSince(startTime)

        guard result.isSuccess else {
            try? FileManager.default.removeItem(at: outputDir)
            if result.stderr.contains("quota") || result.stderr.contains("limit") {
                throw VisualGenerationError.quotaExceeded(providerId: providerId)
            }
            throw VisualGenerationError.invalidOutput(
                providerId: providerId,
                reason: "mmx video generate exited with code \(result.exitCode): \(shortened(result.stderr))"
            )
        }

        guard FileManager.default.fileExists(atPath: outputFile.path) else {
            throw VisualGenerationError.invalidOutput(
                providerId: providerId,
                reason: "video output file not found at \(outputFile.path)"
            )
        }

        return VisualVideoGenerationResult(
            experimentId: request.experimentId,
            videoURL: outputFile,
            model: request.model,
            durationSeconds: elapsed
        )
    }

    private func shortened(_ text: String) -> String {
        guard text.count > 200 else { return text }
        return String(text.prefix(200)) + "..."
    }
}
