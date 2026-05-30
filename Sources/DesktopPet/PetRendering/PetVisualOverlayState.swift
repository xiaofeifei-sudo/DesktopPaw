import Foundation

public struct PetVisualOverlayState: Identifiable, Equatable, Sendable {
    public let id: String
    public let assetId: String
    public let imageURL: URL
    public let renderMode: PetVisualRenderMode
    public let startedAt: Date
    public let expiresAt: Date
    public let canRestore: Bool

    public init(
        id: String,
        assetId: String,
        imageURL: URL,
        renderMode: PetVisualRenderMode,
        startedAt: Date = Date(),
        expiresAt: Date,
        canRestore: Bool = true
    ) {
        self.id = id
        self.assetId = assetId
        self.imageURL = imageURL
        self.renderMode = renderMode
        self.startedAt = startedAt
        self.expiresAt = expiresAt
        self.canRestore = canRestore
    }

    public func isExpired(now: Date = Date()) -> Bool {
        now >= expiresAt
    }

    public var remainingSeconds: TimeInterval {
        max(0, expiresAt.timeIntervalSinceNow)
    }
}
