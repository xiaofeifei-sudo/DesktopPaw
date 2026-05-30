import Foundation
import AppKit

public struct ScreenBoundaryDetector: Sendable {
    public struct ScreenInfo: Equatable, Sendable {
        public let frame: CGRect
        public let visibleFrame: CGRect

        public init(frame: CGRect, visibleFrame: CGRect) {
            self.frame = frame
            self.visibleFrame = visibleFrame
        }
    }

    public let edgeThreshold: CGFloat

    public init(edgeThreshold: CGFloat = 40) {
        self.edgeThreshold = edgeThreshold
    }

    public func currentScreens() -> [ScreenInfo] {
        NSScreen.screens.map { screen in
            ScreenInfo(frame: screen.frame, visibleFrame: screen.visibleFrame)
        }
    }

    public func nearestScreenEdge(for point: CGPoint, screens: [ScreenInfo]) -> (edge: ScreenEdge, distance: CGFloat)? {
        var nearest: (edge: ScreenEdge, distance: CGFloat)?

        for screen in screens {
            let bounds = screen.visibleFrame
            let edges: [(ScreenEdge, CGFloat)] = [
                (.top, bounds.maxY - point.y),
                (.bottom, point.y - bounds.minY),
                (.left, point.x - bounds.minX),
                (.right, bounds.maxX - point.x)
            ]

            for (edge, distance) in edges {
                let absDistance = abs(distance)
                if nearest == nil || absDistance < nearest!.distance {
                    nearest = (edge, absDistance)
                }
            }
        }

        return nearest
    }

    public func isNearScreenEdge(_ point: CGPoint, screens: [ScreenInfo]) -> ScreenEdge? {
        guard let (edge, distance) = nearestScreenEdge(for: point, screens: screens),
              distance <= edgeThreshold else {
            return nil
        }
        return edge
    }

    public func containingScreen(for point: CGPoint, screens: [ScreenInfo]) -> ScreenInfo? {
        screens.first { $0.visibleFrame.contains(point) }
    }
}
