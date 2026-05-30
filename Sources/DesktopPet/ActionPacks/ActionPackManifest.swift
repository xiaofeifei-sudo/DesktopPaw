import Foundation

public enum ActionPackResourceKind: String, Codable, Sendable {
    case gridImage
}

public struct ActionPackResource: Codable, Equatable, Sendable {
    public let id: String
    public let kind: ActionPackResourceKind
    public let path: String
    public let frameSize: CGSizeCodable
    public let grid: SpriteSheetLayout
    public let previewFrame: SpriteFrame?

    public init(
        id: String,
        kind: ActionPackResourceKind,
        path: String,
        frameSize: CGSizeCodable,
        grid: SpriteSheetLayout,
        previewFrame: SpriteFrame? = nil
    ) {
        self.id = id
        self.kind = kind
        self.path = path
        self.frameSize = frameSize
        self.grid = grid
        self.previewFrame = previewFrame
    }
}

public struct ActionPackManifest: Codable, Equatable, Sendable {
    public static let supportedSchemaVersion = 1

    public let schemaVersion: Int
    public let id: String
    public let displayName: String
    public let createdAt: Date
    public let resources: [ActionPackResource]
    public let actions: [Action]

    public init(
        schemaVersion: Int,
        id: String,
        displayName: String,
        createdAt: Date,
        resources: [ActionPackResource],
        actions: [Action]
    ) {
        self.schemaVersion = schemaVersion
        self.id = id
        self.displayName = displayName
        self.createdAt = createdAt
        self.resources = resources
        self.actions = actions
    }
}
