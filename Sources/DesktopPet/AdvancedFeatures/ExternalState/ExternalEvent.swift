import Foundation

public protocol ExternalStateServicing: Sendable {
    var isEnabled: Bool { get }
    var socketPath: String { get }
    func startListening() throws
    func stopListening()
    func getActiveConnections() -> [ExternalConnection]
    func disconnect(_ connectionId: String)
    func registerActionMapping(event: String, actionId: String?, bubbleText: String?)
    func unregisterActionMapping(event: String)
    func getActionMappings() -> [EventActionMapping]
}

public struct ExternalEvent: Codable, Equatable, Sendable {
    public let event: String
    public let data: [String: String]

    public init(event: String, data: [String: String] = [:]) {
        self.event = event
        self.data = data
    }
}

public struct ExternalConnection: Identifiable, Equatable, Sendable {
    public let id: String
    public let connectedAt: Date
    public var isActive: Bool

    public init(id: String, connectedAt: Date = Date(), isActive: Bool = true) {
        self.id = id
        self.connectedAt = connectedAt
        self.isActive = isActive
    }
}

public enum ExternalStateError: Error, Equatable, LocalizedError {
    case socketCreationFailed(String)
    case alreadyListening
    case notListening

    public var errorDescription: String? {
        switch self {
        case .socketCreationFailed(let reason):
            "创建监听 socket 失败：\(reason)"
        case .alreadyListening:
            "已经在监听中"
        case .notListening:
            "未在监听状态"
        }
    }
}
