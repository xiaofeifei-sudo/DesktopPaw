import Foundation
import DesktopPet

@MainActor
func runMotionProviderTests() {
    let tests = MotionProviderTests()
    tests.identityWhenReducedMotion()
    tests.identityWhenStateIsDragging()
    tests.identityForNoneKind()
    tests.identityWhenNonLoopMotionElapsed()
    tests.bobReturnsVerticalOffsetOnLoop()
    tests.bounceReturnsScaleAndUpwardOffset()
    tests.shakeReturnsHorizontalOscillation()
    tests.jumpProducesParabolicArc()
    tests.tiltReturnsRotationDegrees()
    tests.driftReturnsHorizontalDisplacement()
    tests.allDefaultStateMotionsResolveWithoutCrash()
    tests.loopMotionWrapsAroundDuration()
}

@MainActor
private struct MotionProviderTests {
    private let provider = DefaultPetMotionProvider()

    func identityWhenReducedMotion() {
        let value = provider.motionValue(
            for: .happy,
            profile: MotionProfileDefaults.singleImageDefault(),
            elapsed: 0.1,
            reducedMotion: true
        )
        expect(value == .identity, "reduced motion should always return identity")
    }

    func identityWhenStateIsDragging() {
        let value = provider.motionValue(
            for: .dragging,
            profile: MotionProfileDefaults.singleImageDefault(),
            elapsed: 0.05,
            reducedMotion: false
        )
        expect(value == .identity, "dragging should suppress autonomous motion")
    }

    func identityForNoneKind() {
        let profile = MotionProfile(stateMotions: [
            .idle: StateMotion(kind: .none, amplitude: 10, durationMs: 1_000, loop: true)
        ])
        let value = provider.motionValue(for: .idle, profile: profile, elapsed: 0.5, reducedMotion: false)
        expect(value == .identity, "none kind should yield identity")
    }

    func identityWhenNonLoopMotionElapsed() {
        let profile = MotionProfile(stateMotions: [
            .happy: StateMotion(kind: .bounce, amplitude: 10, durationMs: 200, loop: false)
        ])
        let value = provider.motionValue(for: .happy, profile: profile, elapsed: 5.0, reducedMotion: false)
        expect(value == .identity, "completed non-loop motion should return identity")
    }

    func bobReturnsVerticalOffsetOnLoop() {
        let profile = MotionProfile(stateMotions: [
            .idle: StateMotion(kind: .bob, amplitude: 8, durationMs: 1_000, loop: true)
        ])
        let quarter = provider.motionValue(for: .idle, profile: profile, elapsed: 0.25, reducedMotion: false)
        expect(approxEqual(quarter.offset.height, 8.0), "bob at quarter cycle should reach +amplitude")
        expect(approxEqual(quarter.offset.width, 0), "bob should not produce horizontal offset")
        expect(approxEqual(quarter.scale, 1.0), "bob should not modify scale")
        expect(approxEqual(quarter.rotationDegrees, 0), "bob should not rotate")
    }

    func bounceReturnsScaleAndUpwardOffset() {
        let profile = MotionProfile(stateMotions: [
            .happy: StateMotion(kind: .bounce, amplitude: 10, durationMs: 400, loop: false)
        ])
        let mid = provider.motionValue(for: .happy, profile: profile, elapsed: 0.2, reducedMotion: false)
        expect(mid.offset.height < 0, "bounce midway should lift the pet (negative y)")
        expect(mid.scale > 1.0, "bounce midway should slightly enlarge the pet")
        expect(approxEqual(mid.offset.width, 0), "bounce should not move horizontally")
    }

    func shakeReturnsHorizontalOscillation() {
        let profile = MotionProfile(stateMotions: [
            .eating: StateMotion(kind: .shake, amplitude: 6, durationMs: 360, loop: false)
        ])
        let earlyValue = provider.motionValue(for: .eating, profile: profile, elapsed: 0.03, reducedMotion: false)
        expect(abs(earlyValue.offset.width) > 0, "shake should move horizontally during playback")
        expect(approxEqual(earlyValue.offset.height, 0), "shake should not move vertically")
    }

    func jumpProducesParabolicArc() {
        let profile = MotionProfile(stateMotions: [
            .jumping: StateMotion(kind: .jump, amplitude: 18, durationMs: 400, loop: false)
        ])
        let mid = provider.motionValue(for: .jumping, profile: profile, elapsed: 0.2, reducedMotion: false)
        expect(approxEqual(mid.offset.height, -18, tolerance: 0.001), "jump apex should equal -amplitude")
        expect(approxEqual(mid.offset.width, 0), "jump should not move horizontally")
    }

    func tiltReturnsRotationDegrees() {
        let profile = MotionProfile(stateMotions: [
            .idle: StateMotion(kind: .tilt, amplitude: 6, durationMs: 1_000, loop: true)
        ])
        let value = provider.motionValue(for: .idle, profile: profile, elapsed: 0.25, reducedMotion: false)
        expect(approxEqual(value.rotationDegrees, 6.0), "tilt at quarter cycle should reach +amplitude degrees")
        expect(approxEqual(value.offset.width, 0), "tilt should not produce horizontal offset")
    }

    func driftReturnsHorizontalDisplacement() {
        let profile = MotionProfile(stateMotions: [
            .walking: StateMotion(kind: .drift, amplitude: 6, durationMs: 1_200, loop: true)
        ])
        let value = provider.motionValue(for: .walking, profile: profile, elapsed: 0.3, reducedMotion: false)
        expect(approxEqual(value.offset.width, 6.0), "drift at quarter cycle should reach +amplitude horizontally")
        expect(approxEqual(value.offset.height, 0), "drift should not produce vertical offset")
    }

    func allDefaultStateMotionsResolveWithoutCrash() {
        let profile = MotionProfileDefaults.singleImageDefault()
        for state in PetState.allCases {
            let value = provider.motionValue(for: state, profile: profile, elapsed: 0.1, reducedMotion: false)
            expect(value.scale.isFinite, "default motion for \(state) should produce finite scale")
            expect(value.offset.width.isFinite, "default motion for \(state) should produce finite x offset")
            expect(value.offset.height.isFinite, "default motion for \(state) should produce finite y offset")
            expect(value.rotationDegrees.isFinite, "default motion for \(state) should produce finite rotation")
        }
    }

    func loopMotionWrapsAroundDuration() {
        let profile = MotionProfile(stateMotions: [
            .idle: StateMotion(kind: .bob, amplitude: 4, durationMs: 1_000, loop: true)
        ])
        let firstCycle = provider.motionValue(for: .idle, profile: profile, elapsed: 0.25, reducedMotion: false)
        let secondCycle = provider.motionValue(for: .idle, profile: profile, elapsed: 1.25, reducedMotion: false)
        expect(approxEqual(firstCycle.offset.height, secondCycle.offset.height), "looping bob should wrap modulo duration")
    }
}

private func approxEqual(_ lhs: Double, _ rhs: Double, tolerance: Double = 0.0001) -> Bool {
    abs(lhs - rhs) <= tolerance
}
