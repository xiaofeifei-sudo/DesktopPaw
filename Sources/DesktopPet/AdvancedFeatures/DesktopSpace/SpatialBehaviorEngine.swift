import Foundation

public struct SpatialBehaviorEngine: Sendable {
    public let screenDetector: ScreenBoundaryDetector
    public let windowDetector: WindowProximityDetector

    public struct Environment: Sendable {
        public let screens: [ScreenBoundaryDetector.ScreenInfo]
        public let windows: [WindowProximityDetector.WindowInfo]

        public init(
            screens: [ScreenBoundaryDetector.ScreenInfo],
            windows: [WindowProximityDetector.WindowInfo]
        ) {
            self.screens = screens
            self.windows = windows
        }
    }

    public struct PetState: Sendable {
        public let position: CGPoint
        public let isDragging: Bool

        public init(position: CGPoint, isDragging: Bool = false) {
            self.position = position
            self.isDragging = isDragging
        }
    }

    public init(
        screenDetector: ScreenBoundaryDetector = ScreenBoundaryDetector(),
        windowDetector: WindowProximityDetector = WindowProximityDetector()
    ) {
        self.screenDetector = screenDetector
        self.windowDetector = windowDetector
    }

    public func suggest(
        pet: PetState,
        environment: Environment,
        activityZones: [ActivityZone]
    ) -> SpatialSuggestion {
        let constrainedZone = activeConstraintZone(for: pet.position, zones: activityZones)
        if let zone = constrainedZone {
            return .constrainedToZone(zone)
        }

        if pet.isDragging {
            return .freeRoam
        }

        if let screenEdge = screenDetector.isNearScreenEdge(pet.position, screens: environment.screens) {
            return .lookToward(direction: opposingEdge(screenEdge))
        }

        let nearbyWindows = windowDetector.windowsNear(pet.position, windows: environment.windows)
        if let windowEdge = windowDetector.isNearWindowEdge(pet.position, windows: nearbyWindows) {
            return .sitOnEdge(edge: windowEdge)
        }

        return .freeRoam
    }

    private func activeConstraintZone(for position: CGPoint, zones: [ActivityZone]) -> ActivityZone? {
        zones.first { $0.contains(position) }
    }

    private func opposingEdge(_ edge: ScreenEdge) -> ScreenEdge {
        switch edge {
        case .top: return .bottom
        case .bottom: return .top
        case .left: return .right
        case .right: return .left
        }
    }
}
