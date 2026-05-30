import Foundation

public final class MiniMaxCLIImageGenerator: VisualImageGenerating, @unchecked Sendable {
    public let providerId = MiniMaxCLIClient.providerId
    public let displayName = "MiniMax CLI"
    public let capabilities = VisualGenerationCapabilities(
        supportsReferenceImage: true,
        supportsImageEdit: false,
        supportsTransparentBackground: false,
        supportsQuotaSnapshot: true
    )

    private let client: MiniMaxCLIClient
    private let queue = DispatchQueue(label: "minimax-cli-image-generator")
    private var _cachedConfigured: Bool?

    public init(client: MiniMaxCLIClient) {
        self.client = client
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

    public func generate(_ request: VisualGenerationRequest) async throws -> VisualGenerationResult {
        guard isConfigured else {
            throw VisualGenerationError.notConfigured(providerId: providerId)
        }

        let outputDir = request.outputDirectory
        try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

        let result: SubprocessResult
        do {
            result = try await client.generateImage(
                prompt: request.prompt,
                referenceImagePath: request.referenceImageURL?.path,
                outputDirectory: outputDir,
                outputPrefix: request.outputPrefix
            )
        } catch let error as VisualGenerationError {
            throw error
        } catch {
            throw VisualGenerationError.unknown(providerId: providerId, underlying: String(describing: error))
        }

        guard result.isSuccess else {
            try? FileManager.default.removeItem(at: outputDir)
            if result.stderr.contains("quota") || result.stderr.contains("limit") {
                throw VisualGenerationError.quotaExceeded(providerId: providerId)
            }
            throw VisualGenerationError.invalidOutput(
                providerId: providerId,
                reason: "mmx exited with code \(result.exitCode): \(shortened(result.stderr))"
            )
        }

        let imageURL = try locateOutputImage(in: outputDir, prefix: request.outputPrefix)
        return VisualGenerationResult(
            actionId: request.actionId,
            imageURL: imageURL,
            providerId: providerId
        )
    }

    public func quotaSnapshot() async throws -> VisualProviderQuotaSnapshot? {
        guard isConfigured else { return nil }
        do {
            let raw = try await client.fetchQuotaRaw()
            guard let imageQuota = MiniMaxCLIQuotaParser.parseImageQuota(from: raw) else {
                return nil
            }
            return VisualProviderQuotaSnapshot(
                providerId: providerId,
                dailyLimit: imageQuota.intervalTotal,
                dailyUsed: imageQuota.intervalUsed,
                monthlyLimit: nil,
                monthlyUsed: nil,
                fetchedAt: Date()
            )
        } catch {
            return nil
        }
    }

    private func locateOutputImage(in directory: URL, prefix: String) throws -> URL {
        let fm = FileManager.default
        let contents = try fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        let imageExtensions: Set<String> = ["png", "jpg", "jpeg", "webp"]
        let matches = contents.filter { url in
            let ext = url.pathExtension.lowercased()
            return imageExtensions.contains(ext) && url.lastPathComponent.hasPrefix(prefix)
        }
        guard let first = matches.first else {
            throw VisualGenerationError.invalidOutput(
                providerId: providerId,
                reason: "no output image found in \(directory.path)"
            )
        }
        return first
    }

    private func shortened(_ text: String) -> String {
        guard text.count > 200 else { return text }
        return String(text.prefix(200)) + "..."
    }
}
