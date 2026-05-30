import Foundation

public final class MockImageGenerator: VisualImageGenerating, @unchecked Sendable {
    public let providerId = "mock"
    public let displayName = "Mock Provider"
    public let capabilities: VisualGenerationCapabilities
    public let isConfigured: Bool

    private let queue = DispatchQueue(label: "mock-image-generator")
    private var _stubbedResult: Result<VisualGenerationResult, Error>?
    private var _stubbedQuota: VisualProviderQuotaSnapshot?
    public private(set) var lastRequest: VisualGenerationRequest?
    public private(set) var generateCallCount: Int = 0

    public init(
        isConfigured: Bool = true,
        capabilities: VisualGenerationCapabilities = .full
    ) {
        self.isConfigured = isConfigured
        self.capabilities = capabilities
    }

    public func generate(_ request: VisualGenerationRequest) async throws -> VisualGenerationResult {
        let result: Result<VisualGenerationResult, Error>? = queue.sync { _stubbedResult }
        queue.sync { lastRequest = request; generateCallCount += 1 }

        if let result = result {
            return try result.get()
        }
        return VisualGenerationResult(
            actionId: request.actionId,
            imageURL: request.outputDirectory.appendingPathComponent("\(request.outputPrefix).png"),
            providerId: providerId
        )
    }

    public func quotaSnapshot() async throws -> VisualProviderQuotaSnapshot? {
        queue.sync { _stubbedQuota }
    }

    public func stubResult(_ result: Result<VisualGenerationResult, Error>) {
        queue.sync { _stubbedResult = result }
    }

    public func stubQuota(_ snapshot: VisualProviderQuotaSnapshot?) {
        queue.sync { _stubbedQuota = snapshot }
    }
}
