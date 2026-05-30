import DesktopPet
import Foundation

func runAnimationPlayerTests() {
    let tests = AnimationPlayerTests()
    tests.loopingClipWrapsToFirstFrame()
    tests.nonLoopingClipCompletesWithNextState()
    tests.perFrameDurationOverridesDefaultDuration()
    tests.reducedMotionKeepsLoopingClipOnFirstFrame()
    tests.largeElapsedLoopingClipAdvancesInBoundedTime()
}

private struct AnimationPlayerTests {
    func loopingClipWrapsToFirstFrame() {
        var player = AnimationPlayer(clip: clip(loop: true))

        expect(player.advance(by: 100).frame == SpriteFrame(column: 1, row: 0), "loop should advance to second frame")
        expect(player.advance(by: 100).frame == SpriteFrame(column: 0, row: 0), "loop should wrap to first frame")
        expect(!player.isComplete, "looping clip should not complete")
    }

    func nonLoopingClipCompletesWithNextState() {
        var player = AnimationPlayer(clip: clip(loop: false, nextState: .idle))

        let result = player.advance(by: 200)

        expect(result.frame == SpriteFrame(column: 1, row: 0), "non-looping clip should stop on final frame")
        expect(result.completedNextState == .idle, "non-looping clip should report next state")
        expect(player.isComplete, "non-looping clip should complete")
    }

    func perFrameDurationOverridesDefaultDuration() {
        let customClip = AnimationClip(
            state: .idle,
            frames: [
                SpriteFrame(column: 0, row: 0, durationMs: 250),
                SpriteFrame(column: 1, row: 0)
            ],
            frameDurationMs: 100,
            loop: true
        )
        var player = AnimationPlayer(clip: customClip)

        expect(
            player.advance(by: 100).frame == SpriteFrame(column: 0, row: 0, durationMs: 250),
            "per-frame duration should keep the first frame active"
        )
        expect(player.advance(by: 150).frame == SpriteFrame(column: 1, row: 0), "per-frame duration should eventually advance")
    }

    func reducedMotionKeepsLoopingClipOnFirstFrame() {
        var player = AnimationPlayer(clip: clip(loop: true), reducedMotion: true)

        let result = player.advance(by: 1_000)

        expect(result.frame == SpriteFrame(column: 0, row: 0), "reduced motion should keep first frame")
        expect(result.completedNextState == nil, "looping reduced motion should not request next state")
        expect(!player.isComplete, "looping reduced motion should not complete")
    }

    func largeElapsedLoopingClipAdvancesInBoundedTime() {
        let fastClip = AnimationClip(
            state: .idle,
            frames: [
                SpriteFrame(column: 0, row: 0),
                SpriteFrame(column: 1, row: 0),
                SpriteFrame(column: 2, row: 0)
            ],
            frameDurationMs: 1,
            loop: true
        )
        var player = AnimationPlayer(clip: fastClip)

        let start = Date()
        let result = player.advance(by: 50_000_000)
        let elapsed = Date().timeIntervalSince(start)

        expect(result.frame == SpriteFrame(column: 2, row: 0), "large elapsed should land on the modulo frame")
        expect(elapsed < 0.25, "large elapsed should not advance one frame at a time; took \(elapsed)s")
    }

    private func clip(loop: Bool, nextState: PetState? = nil) -> AnimationClip {
        AnimationClip(
            state: .idle,
            frames: [
                SpriteFrame(column: 0, row: 0),
                SpriteFrame(column: 1, row: 0)
            ],
            frameDurationMs: 100,
            loop: loop,
            nextState: nextState
        )
    }
}
