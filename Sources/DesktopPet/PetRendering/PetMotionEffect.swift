import SwiftUI

public struct PetMotionEffect: ViewModifier {
    private let motionValue: MotionValue

    public init(motionValue: MotionValue) {
        self.motionValue = motionValue
    }

    public func body(content: Content) -> some View {
        content
            .scaleEffect(motionValue.scale)
            .rotationEffect(.degrees(motionValue.rotationDegrees))
            .offset(x: motionValue.offset.width, y: motionValue.offset.height)
            .opacity(motionValue.opacity)
    }
}

public extension View {
    func petMotionEffect(_ motionValue: MotionValue) -> some View {
        modifier(PetMotionEffect(motionValue: motionValue))
    }
}
