import Foundation

public struct PetVisualAsset: Identifiable, Codable, Sendable, Equatable {
    public let id: String
    public let petId: String
    public let actionId: String
    public let providerId: String
    public let localURL: URL
    public let promptDigest: String
    public let kind: AIVisualActionKind
    public let renderMode: PetVisualRenderMode
    public let createdAt: Date
    public let expiresAt: Date?
    public var isFavorite: Bool
    public var favoriteName: String?
    public var lifecycleState: AssetLifecycleState
    public var gateResult: GateResult?
    public var referencePreviewURL: URL?
    public var generationDiagnosticsId: String?

    public init(
        id: String,
        petId: String,
        actionId: String,
        providerId: String,
        localURL: URL,
        promptDigest: String,
        kind: AIVisualActionKind,
        renderMode: PetVisualRenderMode,
        createdAt: Date = Date(),
        expiresAt: Date? = nil,
        isFavorite: Bool = false,
        favoriteName: String? = nil,
        lifecycleState: AssetLifecycleState = .applied,
        gateResult: GateResult? = nil,
        referencePreviewURL: URL? = nil,
        generationDiagnosticsId: String? = nil
    ) {
        self.id = id
        self.petId = petId
        self.actionId = actionId
        self.providerId = providerId
        self.localURL = localURL
        self.promptDigest = promptDigest
        self.kind = kind
        self.renderMode = renderMode
        self.createdAt = createdAt
        self.expiresAt = expiresAt
        self.isFavorite = isFavorite
        self.favoriteName = favoriteName
        self.lifecycleState = lifecycleState
        self.gateResult = gateResult
        self.referencePreviewURL = referencePreviewURL
        self.generationDiagnosticsId = generationDiagnosticsId
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        petId = try c.decode(String.self, forKey: .petId)
        actionId = try c.decode(String.self, forKey: .actionId)
        providerId = try c.decode(String.self, forKey: .providerId)
        localURL = try c.decode(URL.self, forKey: .localURL)
        promptDigest = try c.decode(String.self, forKey: .promptDigest)
        kind = try c.decode(AIVisualActionKind.self, forKey: .kind)
        renderMode = try c.decode(PetVisualRenderMode.self, forKey: .renderMode)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        expiresAt = try c.decodeIfPresent(Date.self, forKey: .expiresAt)
        isFavorite = try c.decode(Bool.self, forKey: .isFavorite)
        favoriteName = try c.decodeIfPresent(String.self, forKey: .favoriteName)
        lifecycleState = (try? c.decode(AssetLifecycleState.self, forKey: .lifecycleState)) ?? .applied
        gateResult = try c.decodeIfPresent(GateResult.self, forKey: .gateResult)
        referencePreviewURL = try c.decodeIfPresent(URL.self, forKey: .referencePreviewURL)
        generationDiagnosticsId = try c.decodeIfPresent(String.self, forKey: .generationDiagnosticsId)
    }

    public func isExpired(now: Date = Date()) -> Bool {
        guard let expiresAt else { return false }
        return now > expiresAt
    }
}

public enum PetVisualAssetError: Error, Equatable, LocalizedError {
    case imageLoadFailed
    case conversionFailed
    case metadataWriteFailed
    case metadataReadFailed(reason: String)
    case assetNotFound(assetId: String)
    case fileOperationFailed(String)
    case pendingDirectoryCreationFailed(String)

    public var errorDescription: String? {
        switch self {
        case .imageLoadFailed:
            return "Failed to load image file"
        case .conversionFailed:
            return "Failed to convert image to PNG"
        case .metadataWriteFailed:
            return "Failed to write asset metadata"
        case .metadataReadFailed(let reason):
            return "Failed to read asset metadata: \(reason)"
        case .assetNotFound(let id):
            return "Asset not found: \(id)"
        case .fileOperationFailed(let reason):
            return "File operation failed: \(reason)"
        case .pendingDirectoryCreationFailed(let reason):
            return "Failed to create pending directory: \(reason)"
        }
    }
}
