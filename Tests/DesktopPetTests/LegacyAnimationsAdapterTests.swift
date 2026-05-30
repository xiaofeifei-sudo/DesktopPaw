import Foundation
import DesktopPet

func runLegacyAnimationsAdapterTests() {
    let tests = LegacyAnimationsAdapterTests()
    tests.emptyAnimationsReturnEmptyActions()
    tests.singleStateProducesOneAction()
    tests.actionIdMatchesStateDefaultPattern()
    tests.actionRoleMatchesLegacyState()
    tests.framesPreservedFromClip()
    tests.frameDurationAndLoopPreserved()
    tests.tagsAreEmpty()
    tests.nextActionIdDerivedFromNextState()
    tests.nextActionIdIsNilWhenNextStateAbsent()
    tests.allSevenStatesProduceSevenActions()
    tests.displayNameUsesRoleFallback()
}

private struct LegacyAnimationsAdapterTests {
    func emptyAnimationsReturnEmptyActions() {
        let adapter = LegacyAnimationsAdapter()
        let result = adapter.actions(from: [:])
        expect(result.isEmpty, "empty animations should produce zero actions")
    }

    func singleStateProducesOneAction() {
        let adapter = LegacyAnimationsAdapter()
        let clip = ManifestAnimationClip(
            frames: [SpriteFrame(column: 0, row: 0)],
            frameDurationMs: 160,
            loop: true
        )
        let result = adapter.actions(from: [.idle: clip])
        expect(result.count == 1, "single state should produce one action")
    }

    func actionIdMatchesStateDefaultPattern() {
        let adapter = LegacyAnimationsAdapter()
        let clip = ManifestAnimationClip(frames: [SpriteFrame(column: 0, row: 0)], frameDurationMs: 160, loop: true)
        let result = adapter.actions(from: [.walking: clip])
        expect(result.first?.id.rawValue == "walking_default", "action id should be `<state>_default`")
    }

    func actionRoleMatchesLegacyState() {
        let adapter = LegacyAnimationsAdapter()
        let clip = ManifestAnimationClip(frames: [SpriteFrame(column: 0, row: 0)], frameDurationMs: 160, loop: true)
        let result = adapter.actions(from: [.dragging: clip])
        expect(result.first?.role == .dragging, "action role should bridge from PetState")
    }

    func framesPreservedFromClip() {
        let adapter = LegacyAnimationsAdapter()
        let frames = [
            SpriteFrame(column: 0, row: 0),
            SpriteFrame(column: 1, row: 0),
            SpriteFrame(column: 2, row: 0)
        ]
        let clip = ManifestAnimationClip(frames: frames, frameDurationMs: 160, loop: true)
        let result = adapter.actions(from: [.happy: clip])
        expect(result.first?.frames == frames, "frames should be preserved as-is")
    }

    func frameDurationAndLoopPreserved() {
        let adapter = LegacyAnimationsAdapter()
        let clip = ManifestAnimationClip(
            frames: [SpriteFrame(column: 0, row: 0)],
            frameDurationMs: 120,
            loop: false
        )
        let result = adapter.actions(from: [.eating: clip])
        expect(result.first?.frameDurationMs == 120, "frameDurationMs should be preserved")
        expect(result.first?.loop == false, "loop should be preserved")
    }

    func tagsAreEmpty() {
        let adapter = LegacyAnimationsAdapter()
        let clip = ManifestAnimationClip(frames: [SpriteFrame(column: 0, row: 0)], frameDurationMs: 160, loop: true)
        let result = adapter.actions(from: [.sleeping: clip])
        expect(result.first?.tags.isEmpty == true, "legacy adapter should not synthesize tags")
    }

    func nextActionIdDerivedFromNextState() {
        let adapter = LegacyAnimationsAdapter()
        let clip = ManifestAnimationClip(
            frames: [SpriteFrame(column: 0, row: 0)],
            frameDurationMs: 120,
            loop: false,
            nextState: .idle
        )
        let result = adapter.actions(from: [.jumping: clip])
        expect(result.first?.nextActionId?.rawValue == "idle_default", "nextActionId should follow `<nextState>_default`")
    }

    func nextActionIdIsNilWhenNextStateAbsent() {
        let adapter = LegacyAnimationsAdapter()
        let clip = ManifestAnimationClip(frames: [SpriteFrame(column: 0, row: 0)], frameDurationMs: 160, loop: true)
        let result = adapter.actions(from: [.idle: clip])
        expect(result.first?.nextActionId == nil, "nextActionId should be nil when nextState is nil")
    }

    func allSevenStatesProduceSevenActions() {
        let adapter = LegacyAnimationsAdapter()
        let clip = ManifestAnimationClip(frames: [SpriteFrame(column: 0, row: 0)], frameDurationMs: 160, loop: true)
        var animations: [PetState: ManifestAnimationClip] = [:]
        for state in PetState.allCases {
            animations[state] = clip
        }
        let result = adapter.actions(from: animations)
        expect(result.count == 7, "all 7 PetState clips should produce 7 actions")
        let expectedIds: Set<String> = [
            "idle_default", "walking_default", "sleeping_default",
            "happy_default", "eating_default", "jumping_default", "dragging_default"
        ]
        let actualIds = Set(result.map { $0.id.rawValue })
        expect(actualIds == expectedIds, "expected ids \(expectedIds) but got \(actualIds)")
    }

    func displayNameUsesRoleFallback() {
        let adapter = LegacyAnimationsAdapter()
        let clip = ManifestAnimationClip(frames: [SpriteFrame(column: 0, row: 0)], frameDurationMs: 160, loop: true)
        let result = adapter.actions(from: [.walking: clip])
        expect(result.first?.displayName == "Walking", "displayName should fall back to capitalized role name")
    }
}
