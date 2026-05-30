import CoreGraphics
import AppKit

public struct ScreenGeometry: Equatable {
    private static let defaultEdgeInset: CGFloat = 24

    public let visibleFrames: [CGRect]

    public init(visibleFrames: [CGRect]) {
        self.visibleFrames = visibleFrames
    }

    @MainActor
    public static func current() -> ScreenGeometry {
        var frames: [CGRect] = []

        if let mainFrame = NSScreen.main?.visibleFrame {
            frames.append(mainFrame)
        }

        for screen in NSScreen.screens {
            let frame = screen.visibleFrame
            if !frames.contains(frame) {
                frames.append(frame)
            }
        }

        return ScreenGeometry(visibleFrames: frames)
    }

    public func visibleFrame(containing point: CGPoint) -> CGRect? {
        visibleFrames.first { $0.contains(point) }
    }

    public func isFrameVisible(_ frame: CGRect) -> Bool {
        guard !frame.isNull, !frame.isEmpty else {
            return false
        }

        return visibleFrames.contains { visibleFrame in
            let intersection = visibleFrame.intersection(frame)
            return intersection.width > 0 && intersection.height > 0
        }
    }

    public func defaultPetFrame(frameSize: CGSize) -> CGRect {
        guard let visibleFrame = visibleFrames.first else {
            return CGRect(origin: .zero, size: frameSize)
        }

        return defaultPetFrame(frameSize: frameSize, in: visibleFrame)
    }

    public func clamp(frame: CGRect) -> CGRect {
        guard !visibleFrames.isEmpty else {
            return frame
        }

        let targetFrame = visibleFrame(containing: center(of: frame))
            ?? nearestVisibleFrame(to: center(of: frame))
            ?? visibleFrames[0]

        return clamp(frame: frame, to: targetFrame)
    }

    public func startupFrame(savedFrame: CGRect?, frameSize: CGSize) -> CGRect {
        guard let savedFrame, isFrameVisible(savedFrame) else {
            return defaultPetFrame(frameSize: frameSize)
        }

        return clamp(frame: savedFrame)
    }

    private func defaultPetFrame(frameSize: CGSize, in visibleFrame: CGRect) -> CGRect {
        let x = max(visibleFrame.minX, visibleFrame.maxX - frameSize.width - Self.defaultEdgeInset)
        let y = max(visibleFrame.minY, visibleFrame.minY + Self.defaultEdgeInset)
        return CGRect(origin: CGPoint(x: x, y: y), size: frameSize)
    }

    private func clamp(frame: CGRect, to visibleFrame: CGRect) -> CGRect {
        let width = frame.width
        let height = frame.height

        let minX = visibleFrame.minX
        let maxX = max(visibleFrame.minX, visibleFrame.maxX - width)
        let minY = visibleFrame.minY
        let maxY = max(visibleFrame.minY, visibleFrame.maxY - height)

        let clampedX = min(max(frame.minX, minX), maxX)
        let clampedY = min(max(frame.minY, minY), maxY)

        return CGRect(x: clampedX, y: clampedY, width: width, height: height)
    }

    private func nearestVisibleFrame(to point: CGPoint) -> CGRect? {
        visibleFrames.min { lhs, rhs in
            distanceSquared(from: center(of: lhs), to: point) < distanceSquared(from: center(of: rhs), to: point)
        }
    }

    private func center(of frame: CGRect) -> CGPoint {
        CGPoint(x: frame.midX, y: frame.midY)
    }

    private func distanceSquared(from lhs: CGPoint, to rhs: CGPoint) -> CGFloat {
        let dx = lhs.x - rhs.x
        let dy = lhs.y - rhs.y
        return dx * dx + dy * dy
    }
}
