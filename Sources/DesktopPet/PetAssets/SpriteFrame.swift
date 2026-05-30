public struct SpriteFrame: Codable, Equatable, Hashable, Sendable {
    public let assetId: String?
    public let column: Int
    public let row: Int
    public let durationMs: Int?

    public init(
        assetId: String? = nil,
        column: Int,
        row: Int,
        durationMs: Int? = nil
    ) {
        self.assetId = assetId
        self.column = column
        self.row = row
        self.durationMs = durationMs
    }
}
