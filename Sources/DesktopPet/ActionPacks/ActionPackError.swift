import Foundation

public enum ActionPackError: Error, Equatable, Sendable, LocalizedError {
    case unsupportedSchemaVersion(Int)
    case invalidPackId(String)
    case invalidResourceId(String)
    case invalidActionId(String)
    case invalidResourcePath(String)
    case manifestNotFound(URL)
    case manifestDecodingFailed(URL, underlying: String)
    case resourceNotFound(packId: String, resourceId: String, path: String)
    case resourceUnreadable(packId: String, resourceId: String, path: String)
    case unsupportedImageFormat(packId: String, path: String)
    case imageSizeMismatch(packId: String, resourceId: String, expected: CGSizeCodable, actual: CGSizeCodable)
    case frameSizeMismatch(packId: String, expected: CGSizeCodable, actual: CGSizeCodable)
    case frameOutOfBounds(actionId: String, frame: SpriteFrame, resource: String)
    case emptyActionFrames(actionId: String)
    case invalidFrameDuration(actionId: String, durationMs: Int)
    case duplicateResourceId(packId: String, resourceId: String)
    case writeFailed(packId: String, underlying: String)
    case tempDirectoryCleanupFailed(URL)
    case overrideDecodingFailed(underlying: String)

    public var errorDescription: String? {
        switch self {
        case .unsupportedSchemaVersion(let v):
            return "Unsupported action pack schema version: \(v). Expected \(ActionPackManifest.supportedSchemaVersion)."
        case .invalidPackId(let id):
            return "Invalid action pack id: \(id)."
        case .invalidResourceId(let id):
            return "Invalid resource id: \(id)."
        case .invalidActionId(let id):
            return "Invalid action id in action pack: \(id)."
        case .invalidResourcePath(let path):
            return "Invalid resource path: \(path). Path must be a top-level filename."
        case .manifestNotFound(let url):
            return "Action pack manifest not found at \(url.lastPathComponent)."
        case .manifestDecodingFailed(let url, let underlying):
            return "Failed to decode action pack manifest at \(url.lastPathComponent): \(underlying)"
        case .resourceNotFound(_, _, let path):
            return "Resource file not found: \(path)."
        case .resourceUnreadable(_, _, let path):
            return "Resource file unreadable: \(path)."
        case .unsupportedImageFormat(_, let path):
            return "Unsupported image format: \(path). Supported formats: PNG, JPG, JPEG."
        case .imageSizeMismatch(_, let resourceId, let expected, let actual):
            return "Image size mismatch for resource \(resourceId): expected \(Int(expected.width))x\(Int(expected.height)), got \(Int(actual.width))x\(Int(actual.height))."
        case .frameSizeMismatch(_, let expected, let actual):
            return "Action pack frame size \(Int(actual.width))x\(Int(actual.height)) does not match pet frame size \(Int(expected.width))x\(Int(expected.height))."
        case .frameOutOfBounds(let actionId, let frame, _):
            return "Frame (\(frame.column), \(frame.row)) out of bounds for action \(actionId)."
        case .emptyActionFrames(let actionId):
            return "Action \(actionId) has no frames."
        case .invalidFrameDuration(let actionId, let durationMs):
            return "Action \(actionId) has invalid frame duration: \(durationMs)ms."
        case .duplicateResourceId(_, let resourceId):
            return "Duplicate resource id within pack: \(resourceId)."
        case .writeFailed(_, let underlying):
            return "Failed to write action pack: \(underlying)."
        case .tempDirectoryCleanupFailed(let url):
            return "Failed to clean up temporary directory: \(url.lastPathComponent)."
        case .overrideDecodingFailed(let underlying):
            return "Failed to decode action pack overrides: \(underlying)."
        }
    }
}

public struct ActionPackWarning: Equatable, Sendable {
    public enum Kind: String, Equatable, Hashable, Sendable {
        case packSkipped
        case actionSkipped
        case actionIdConflict
        case nextActionIdNotFound
        case overrideFileCorrupted
    }

    public let kind: Kind
    public let packId: String?
    public let actionId: String?
    public let detail: String

    public init(
        kind: Kind,
        packId: String? = nil,
        actionId: String? = nil,
        detail: String
    ) {
        self.kind = kind
        self.packId = packId
        self.actionId = actionId
        self.detail = detail
    }
}
