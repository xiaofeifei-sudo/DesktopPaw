import CoreGraphics
import Foundation

public struct MotionValue: Equatable, Sendable {
    public let offset: CGSize
    public let scale: Double
    public let rotationDegrees: Double
    public let opacity: Double

    public init(
        offset: CGSize,
        scale: Double,
        rotationDegrees: Double,
        opacity: Double
    ) {
        self.offset = offset
        self.scale = scale
        self.rotationDegrees = rotationDegrees
        self.opacity = opacity
    }

    public static let identity = MotionValue(
        offset: .zero,
        scale: 1.0,
        rotationDegrees: 0,
        opacity: 1.0
    )
}
