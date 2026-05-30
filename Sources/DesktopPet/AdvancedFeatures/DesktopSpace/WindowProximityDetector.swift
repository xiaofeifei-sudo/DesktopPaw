import Foundation
import CoreGraphics

public struct WindowProximityDetector: Sendable {
    public struct WindowInfo: Equatable, Sendable {
        public let bounds: CGRect

        public init(bounds: CGRect) {
            self.bounds = bounds
        }
    }

    public let proximityThreshold: CGFloat

    public init(proximityThreshold: CGFloat = 30) {
        self.proximityThreshold = proximityThreshold
    }

    public func onScreenWindows() -> [WindowInfo] {
        guard let list = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else {
            return []
        }

        return list.compactMap { entry in
            guard let boundsDict = entry[kCGWindowBounds as String] as? [String: Any],
                  let x = boundsDict["X"] as? CGFloat,
                  let y = boundsDict["Y"] as? CGFloat,
                  let width = boundsDict["Width"] as? CGFloat,
                  let height = boundsDict["Height"] as? CGFloat else {
                return nil
            }
            return WindowInfo(bounds: CGRect(x: x, y: y, width: width, height: height))
        }
    }

    public func windowsNear(_ point: CGPoint, windows: [WindowInfo]) -> [WindowInfo] {
        windows.filter { window in
            let expanded = window.bounds.insetBy(dx: -proximityThreshold, dy: -proximityThreshold)
            return expanded.contains(point)
        }
    }

    public func nearestWindowEdge(for point: CGPoint, windows: [WindowInfo]) -> (edge: ScreenEdge, distance: CGFloat)? {
        var nearest: (edge: ScreenEdge, distance: CGFloat)?

        for window in windows {
            let edges: [(ScreenEdge, CGFloat)] = [
                (.top, window.bounds.maxY - point.y),
                (.bottom, point.y - window.bounds.minY),
                (.left, point.x - window.bounds.minX),
                (.right, window.bounds.maxX - point.x)
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

    public func isNearWindowEdge(_ point: CGPoint, windows: [WindowInfo]) -> ScreenEdge? {
        guard let (edge, distance) = nearestWindowEdge(for: point, windows: windows),
              distance <= proximityThreshold else {
            return nil
        }
        return edge
    }
}
