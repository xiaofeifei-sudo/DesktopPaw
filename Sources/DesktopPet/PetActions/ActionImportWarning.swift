public struct ActionImportWarning: Equatable, Sendable {
    public enum Kind: String, Equatable, Hashable, Sendable {
        case extraRowsIgnored
        case roleFallbackUsed
        case requiredRoleSynthesized
        case duplicateActionId
        case schemaVersionUnsupported
    }

    public let kind: Kind
    public let detail: String
    public let role: ActionRole?
    public let actionId: ActionId?

    public init(
        kind: Kind,
        detail: String,
        role: ActionRole? = nil,
        actionId: ActionId? = nil
    ) {
        self.kind = kind
        self.detail = detail
        self.role = role
        self.actionId = actionId
    }
}
