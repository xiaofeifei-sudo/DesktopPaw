import Foundation

public struct VisualGenerationCapabilities: Sendable, Equatable {
    public let supportsReferenceImage: Bool
    public let supportsImageEdit: Bool
    public let supportsTransparentBackground: Bool
    public let supportsQuotaSnapshot: Bool
    public let supportsSubjectReference: Bool
    public let supportsNegativePrompt: Bool
    public let supportedOutputSizes: [CGSize]
    public let maxInputImageSize: Int
    public let supportsSeed: Bool
    public let supportsBase64Response: Bool

    public init(
        supportsReferenceImage: Bool = false,
        supportsImageEdit: Bool = false,
        supportsTransparentBackground: Bool = false,
        supportsQuotaSnapshot: Bool = false,
        supportsSubjectReference: Bool = false,
        supportsNegativePrompt: Bool = false,
        supportedOutputSizes: [CGSize] = [],
        maxInputImageSize: Int = 0,
        supportsSeed: Bool = false,
        supportsBase64Response: Bool = false
    ) {
        self.supportsReferenceImage = supportsReferenceImage
        self.supportsImageEdit = supportsImageEdit
        self.supportsTransparentBackground = supportsTransparentBackground
        self.supportsQuotaSnapshot = supportsQuotaSnapshot
        self.supportsSubjectReference = supportsSubjectReference
        self.supportsNegativePrompt = supportsNegativePrompt
        self.supportedOutputSizes = supportedOutputSizes
        self.maxInputImageSize = maxInputImageSize
        self.supportsSeed = supportsSeed
        self.supportsBase64Response = supportsBase64Response
    }

    public static let full = VisualGenerationCapabilities(
        supportsReferenceImage: true,
        supportsImageEdit: true,
        supportsTransparentBackground: true,
        supportsQuotaSnapshot: true,
        supportsSubjectReference: true,
        supportsNegativePrompt: true,
        supportedOutputSizes: [
            CGSize(width: 512, height: 512),
            CGSize(width: 768, height: 768),
            CGSize(width: 1024, height: 1024),
        ],
        maxInputImageSize: 4096,
        supportsSeed: true,
        supportsBase64Response: true
    )

    public static let basic = VisualGenerationCapabilities()
}

public protocol VisualImageGenerating: Sendable {
    var providerId: String { get }
    var displayName: String { get }
    var capabilities: VisualGenerationCapabilities { get }
    var isConfigured: Bool { get }

    func generate(_ request: VisualGenerationRequest) async throws -> VisualGenerationResult
    func quotaSnapshot() async throws -> VisualProviderQuotaSnapshot?
}

public struct ProviderInfo: Sendable, Equatable {
    public let providerId: String
    public let displayName: String
    public let isConfigured: Bool
    public let capabilities: VisualGenerationCapabilities

    public init(
        providerId: String,
        displayName: String,
        isConfigured: Bool,
        capabilities: VisualGenerationCapabilities
    ) {
        self.providerId = providerId
        self.displayName = displayName
        self.isConfigured = isConfigured
        self.capabilities = capabilities
    }
}
