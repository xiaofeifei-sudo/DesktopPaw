import Foundation

public protocol DesktopSpaceServicing: Sendable {
    var isEnabled: Bool { get }
    func start()
    func stop()
    var activityZones: [ActivityZone] { get }
    func setActivityZones(_ zones: [ActivityZone])
    func setMovementConstrained(_ constrained: Bool)
    var isMovementConstrained: Bool { get }
}

public struct ActivityZone: Codable, Equatable, Sendable {
    public var id: String
    public var rect: CGRect

    public init(id: String, rect: CGRect) {
        self.id = id
        self.rect = rect
    }

    public func contains(_ point: CGPoint) -> Bool {
        rect.contains(point)
    }
}

public enum SpatialSuggestion: Equatable, Sendable {
    case lookToward(direction: ScreenEdge)
    case sitOnEdge(edge: ScreenEdge)
    case freeRoam
    case constrainedToZone(ActivityZone)
}

public enum ScreenEdge: String, Sendable, CaseIterable {
    case top
    case bottom
    case left
    case right
}

public enum DesktopSpaceError: Error, LocalizedError {
    case windowListUnavailable

    public var errorDescription: String? {
        switch self {
        case .windowListUnavailable:
            "无法获取桌面窗口信息"
        }
    }
}
