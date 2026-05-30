import Foundation

public protocol InputSyncServicing: Sendable {
    var isEnabled: Bool { get }
    func start(config: InputSyncConfig) throws
    func stop()
    func updateConfig(_ config: InputSyncConfig)
}

public struct InputSyncConfig: Codable, Equatable, Sendable {
    public var isEnabled: Bool
    public var syncIntensity: InputSyncIntensity
    public var trackKeyboard: Bool
    public var trackMouse: Bool
    public var respectQuietMode: Bool

    public init(
        isEnabled: Bool = false,
        syncIntensity: InputSyncIntensity = .moderate,
        trackKeyboard: Bool = true,
        trackMouse: Bool = true,
        respectQuietMode: Bool = true
    ) {
        self.isEnabled = isEnabled
        self.syncIntensity = syncIntensity
        self.trackKeyboard = trackKeyboard
        self.trackMouse = trackMouse
        self.respectQuietMode = respectQuietMode
    }

    public static let `default` = InputSyncConfig()
}

public enum InputSyncIntensity: String, Codable, CaseIterable, Sendable {
    case subtle
    case moderate
    case expressive
}

public enum InputSyncEvent: Sendable {
    case keyboardActivity
    case mouseActivity
    case idle
}

public enum InputSyncError: Error, LocalizedError {
    case accessibilityPermissionDenied
    case eventTapCreationFailed

    public var errorDescription: String? {
        switch self {
        case .accessibilityPermissionDenied:
            "输入同步需要辅助功能权限，请在系统设置 > 隐私与安全性 > 辅助功能中授权"
        case .eventTapCreationFailed:
            "无法创建输入事件监听器"
        }
    }
}
