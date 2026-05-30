public struct Action: Codable, Equatable, Sendable {
    public let id: ActionId
    public let displayName: String
    public let role: ActionRole?
    public let tags: [ActionTag]
    public let assetId: String?
    public let frames: [SpriteFrame]
    public let frameDurationMs: Int
    public let loop: Bool
    public let nextActionId: ActionId?

    public init(
        id: ActionId,
        displayName: String,
        role: ActionRole?,
        tags: [ActionTag] = [],
        assetId: String? = nil,
        frames: [SpriteFrame],
        frameDurationMs: Int,
        loop: Bool,
        nextActionId: ActionId? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.role = role
        self.tags = tags
        self.assetId = assetId
        self.frames = frames
        self.frameDurationMs = frameDurationMs
        self.loop = loop
        self.nextActionId = nextActionId
    }
}
