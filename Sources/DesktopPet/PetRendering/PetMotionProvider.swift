import CoreGraphics
import Foundation

public protocol PetMotionProviding: Sendable {
    func motionValue(
        for state: PetState,
        profile: MotionProfile,
        elapsed: TimeInterval,
        reducedMotion: Bool
    ) -> MotionValue
}

public struct DefaultPetMotionProvider: PetMotionProviding {
    public init() {}

    public func motionValue(
        for state: PetState,
        profile: MotionProfile,
        elapsed: TimeInterval,
        reducedMotion: Bool
    ) -> MotionValue {
        if reducedMotion {
            return .identity
        }

        if state == .dragging {
            return .identity
        }

        let motion = profile.motion(for: state)

        guard motion.kind != .none, motion.durationMs > 0, motion.amplitude > 0 else {
            return .identity
        }

        guard let progress = phase(for: motion, elapsed: elapsed) else {
            return .identity
        }

        switch motion.kind {
        case .none:
            return .identity
        case .bob:
            return bob(amplitude: motion.amplitude, progress: progress)
        case .bounce:
            return bounce(amplitude: motion.amplitude, progress: progress)
        case .shake:
            return shake(amplitude: motion.amplitude, progress: progress)
        case .jump:
            return jump(amplitude: motion.amplitude, progress: progress)
        case .tilt:
            return tilt(amplitude: motion.amplitude, progress: progress)
        case .drift:
            return drift(amplitude: motion.amplitude, progress: progress)
        }
    }

    private func phase(for motion: StateMotion, elapsed: TimeInterval) -> Double? {
        let durationSec = Double(motion.durationMs) / 1000.0
        guard durationSec > 0, elapsed >= 0 else {
            return nil
        }

        if motion.loop {
            let p = elapsed.truncatingRemainder(dividingBy: durationSec) / durationSec
            return p
        }

        let p = elapsed / durationSec
        if p >= 1.0 {
            return nil
        }
        return p
    }

    private func bob(amplitude: Double, progress: Double) -> MotionValue {
        let y = amplitude * sin(2 * .pi * progress)
        return MotionValue(
            offset: CGSize(width: 0, height: y),
            scale: 1.0,
            rotationDegrees: 0,
            opacity: 1.0
        )
    }

    private func bounce(amplitude: Double, progress: Double) -> MotionValue {
        let lift = sin(.pi * progress)
        let scaleBoost = 1.0 + 0.12 * lift
        let y = -amplitude * lift
        return MotionValue(
            offset: CGSize(width: 0, height: y),
            scale: scaleBoost,
            rotationDegrees: 0,
            opacity: 1.0
        )
    }

    private func shake(amplitude: Double, progress: Double) -> MotionValue {
        let x = amplitude * sin(2 * .pi * 3 * progress)
        return MotionValue(
            offset: CGSize(width: x, height: 0),
            scale: 1.0,
            rotationDegrees: 0,
            opacity: 1.0
        )
    }

    private func jump(amplitude: Double, progress: Double) -> MotionValue {
        let parabola = 4 * progress * (1 - progress)
        let y = -amplitude * parabola
        return MotionValue(
            offset: CGSize(width: 0, height: y),
            scale: 1.0,
            rotationDegrees: 0,
            opacity: 1.0
        )
    }

    private func tilt(amplitude: Double, progress: Double) -> MotionValue {
        let degrees = amplitude * sin(2 * .pi * progress)
        return MotionValue(
            offset: .zero,
            scale: 1.0,
            rotationDegrees: degrees,
            opacity: 1.0
        )
    }

    private func drift(amplitude: Double, progress: Double) -> MotionValue {
        let x = amplitude * sin(2 * .pi * progress)
        return MotionValue(
            offset: CGSize(width: x, height: 0),
            scale: 1.0,
            rotationDegrees: 0,
            opacity: 1.0
        )
    }
}
