import Foundation

public enum ActionCatalogError: Error, Equatable, Sendable, LocalizedError {
    case missingRequiredRole(ActionRole)
    case duplicateActionId(ActionId)
    case unsupportedSchemaVersion(Int)
    case invalidActionId(String)
    case invalidActionTag(String)
    case tooManyTagsOnAction(actionId: ActionId, count: Int, limit: Int)
    case tooManyTagsInPackage(count: Int, limit: Int)
    case nextActionIdNotFound(ActionId)
    case frameOutOfBounds(actionId: ActionId, frame: SpriteFrame)

    public var errorDescription: String? {
        switch self {
        case .missingRequiredRole(let role):
            return "Pet package is missing required action role '\(role.rawValue)'."
        case .duplicateActionId(let actionId):
            return "Pet package contains duplicate action id '\(actionId.rawValue)'."
        case .unsupportedSchemaVersion(let version):
            return "Pet package uses unsupported action schema version \(version)."
        case .invalidActionId(let value):
            return "Action id '\(value)' is invalid. Use 1-64 lowercase letters, numbers, colon, dot, underscore, or hyphen."
        case .invalidActionTag(let value):
            return "Action tag '\(value)' is invalid. Use 1-64 lowercase letters, numbers, colon, dot, underscore, or hyphen."
        case .tooManyTagsOnAction(let actionId, let count, let limit):
            return "Action '\(actionId.rawValue)' has \(count) tags; maximum is \(limit)."
        case .tooManyTagsInPackage(let count, let limit):
            return "Pet package has \(count) action tags; maximum is \(limit)."
        case .nextActionIdNotFound(let actionId):
            return "Action nextActionId '\(actionId.rawValue)' does not exist in this pet package."
        case .frameOutOfBounds(let actionId, let frame):
            return "Action '\(actionId.rawValue)' references frame column \(frame.column), row \(frame.row) outside the spritesheet."
        }
    }
}
