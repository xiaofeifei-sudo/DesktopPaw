import Foundation

public struct AdvancedPreferences: Codable, Equatable, Sendable {
    public var inputSyncConfig: InputSyncConfig
    public var desktopSpaceEnabled: Bool
    public var desktopSpaceEdgeThreshold: Double
    public var isMovementConstrained: Bool
    public var externalStateEnabled: Bool
    public var externalStateSocketPath: String

    public init(
        inputSyncConfig: InputSyncConfig = .default,
        desktopSpaceEnabled: Bool = false,
        desktopSpaceEdgeThreshold: Double = 40,
        isMovementConstrained: Bool = false,
        externalStateEnabled: Bool = false,
        externalStateSocketPath: String = ""
    ) {
        self.inputSyncConfig = inputSyncConfig
        self.desktopSpaceEnabled = desktopSpaceEnabled
        self.desktopSpaceEdgeThreshold = desktopSpaceEdgeThreshold
        self.isMovementConstrained = isMovementConstrained
        self.externalStateEnabled = externalStateEnabled
        self.externalStateSocketPath = externalStateSocketPath
    }

    public static let `default` = AdvancedPreferences()

    public static func defaultSocketPath(fileManager: FileManager = .default) -> String {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport
            .appendingPathComponent("DesktopPet", isDirectory: true)
            .appendingPathComponent("external-state.sock")
            .path
    }
}
