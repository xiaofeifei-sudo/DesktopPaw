import Foundation

public enum ContentPackType: String, Codable, CaseIterable, Sendable {
    case dialogue
    case personality
    case action
}

public struct ContentPack: Identifiable, Equatable, Sendable {
    public var id: String { manifest.id }
    public let manifest: ContentPackManifest
    public let installedURL: URL
    public var isEnabled: Bool

    public init(manifest: ContentPackManifest, installedURL: URL, isEnabled: Bool) {
        self.manifest = manifest
        self.installedURL = installedURL
        self.isEnabled = isEnabled
    }
}

public enum ContentPackError: Error, Equatable, LocalizedError {
    case validationFailed(ContentPackValidationResult)
    case packNotFound(String)
    case unsupportedPackType(ContentPackType)
    case storageError(String)

    public var errorDescription: String? {
        switch self {
        case .validationFailed(let result):
            "内容包校验失败：\(result.errors.map(\.message).joined(separator: "；"))"
        case .packNotFound(let packId):
            "内容包不存在：\(packId)"
        case .unsupportedPackType(let type):
            "暂不支持的内容包类型：\(type.rawValue)"
        case .storageError(let message):
            "内容包存储错误：\(message)"
        }
    }
}

public protocol ContentPackManaging: Sendable {
    func importPack(from url: URL) throws -> ContentPack
    func validatePack(at url: URL) -> ContentPackValidationResult
    func getInstalledPacks() -> [ContentPack]
    func enablePack(_ packId: String) throws
    func disablePack(_ packId: String) throws
    func removePack(_ packId: String) throws
    func previewPack(_ packId: String) throws -> ContentPackPreview
    func restoreDefaultContent() throws
}
