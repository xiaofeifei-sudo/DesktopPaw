import Foundation
import DesktopPet

@MainActor
func runPetdexGracefulSynthesizerTests() {
    let tests = PetdexGracefulSynthesizerTests()
    tests.sixRowsMissingDraggingSynthesizesDragging()
    tests.sixRowsCompleteProducesNoSynthesis()
    tests.singleRowOnlyIdleSynthesizesDragging()
    tests.zeroRowsProducesNoSynthesis()
    tests.warningDetailContainsSynthesizedRoleName()
    tests.bothRequiredMissingSynthesizesIdleAndDragging()
    tests.synthesizedActionsAppendedAfterInputs()
    print("PetdexGracefulSynthesizerTests passed")
}

@MainActor
private struct PetdexGracefulSynthesizerTests {
    private let rowZeroFrames: [SpriteFrame] = [
        SpriteFrame(column: 0, row: 0),
        SpriteFrame(column: 1, row: 0),
        SpriteFrame(column: 2, row: 0)
    ]
    private let defaultDurationMs = 160

    func sixRowsMissingDraggingSynthesizesDragging() {
        let synthesizer = DefaultPetdexGracefulSynthesizer()
        let inputs = makeSixRowActions(includeIdle: true, includeDragging: false)

        let result = synthesizer.synthesizeRequiredRolesIfMissing(
            actions: inputs,
            rowZeroFrames: rowZeroFrames,
            frameDurationMs: defaultDurationMs
        )

        expect(result.synthesized.count == inputs.count + 1, "should append 1 synthesized action when only dragging is missing")
        expect(result.warnings.count == 1, "should emit exactly 1 warning when only dragging is missing")

        guard let synthesizedDragging = result.synthesized.last else {
            fail("expected synthesized action at end of array")
        }
        expect(synthesizedDragging.id.rawValue == "dragging_default", "synthesized id should be dragging_default")
        expect(synthesizedDragging.role == .dragging, "synthesized role should be dragging")
        expect(synthesizedDragging.loop == true, "synthesized dragging should loop")
        expect(synthesizedDragging.frames == rowZeroFrames, "synthesized dragging frames should match rowZeroFrames")
        expect(synthesizedDragging.frameDurationMs == defaultDurationMs, "synthesized dragging should use the supplied frame duration")
        expect(synthesizedDragging.nextActionId == nil, "synthesized dragging should not chain to a next action")
        expect(synthesizedDragging.tags.isEmpty, "synthesized dragging should have no tags")

        guard let warning = result.warnings.first else {
            fail("expected exactly 1 warning")
        }
        expect(warning.kind == .requiredRoleSynthesized, "warning kind should be requiredRoleSynthesized")
        expect(warning.role == .dragging, "warning role should be dragging")
        expect(warning.actionId?.rawValue == "dragging_default", "warning actionId should reference dragging_default")
        expect(warning.detail.contains("dragging"), "warning detail should contain 'dragging'")
    }

    func sixRowsCompleteProducesNoSynthesis() {
        let synthesizer = DefaultPetdexGracefulSynthesizer()
        let inputs = makeSixRowActions(includeIdle: true, includeDragging: true)

        let result = synthesizer.synthesizeRequiredRolesIfMissing(
            actions: inputs,
            rowZeroFrames: rowZeroFrames,
            frameDurationMs: defaultDurationMs
        )

        expect(result.synthesized.count == inputs.count, "complete six-row pack should not change action count")
        expect(result.synthesized == inputs, "complete six-row pack should not modify the action array")
        expect(result.warnings.isEmpty, "complete six-row pack should emit no warnings")
    }

    func singleRowOnlyIdleSynthesizesDragging() {
        let synthesizer = DefaultPetdexGracefulSynthesizer()
        let idleAction = makeAction(id: "idle_default", role: .idle)

        let result = synthesizer.synthesizeRequiredRolesIfMissing(
            actions: [idleAction],
            rowZeroFrames: rowZeroFrames,
            frameDurationMs: defaultDurationMs
        )

        expect(result.synthesized.count == 2, "1 input + synthesized dragging should yield 2 actions")
        expect(result.synthesized[0] == idleAction, "input idle action should be preserved at index 0")

        let synthesizedDragging = result.synthesized[1]
        expect(synthesizedDragging.role == .dragging, "second action should be synthesized dragging")
        expect(synthesizedDragging.id.rawValue == "dragging_default", "synthesized dragging id should be dragging_default")
        expect(synthesizedDragging.loop == true, "synthesized dragging should loop")

        expect(result.warnings.count == 1, "should emit exactly 1 warning for synthesized dragging")
        expect(result.warnings[0].role == .dragging, "warning role should be dragging")
    }

    func zeroRowsProducesNoSynthesis() {
        let synthesizer = DefaultPetdexGracefulSynthesizer()
        let inputs: [Action] = []

        let result = synthesizer.synthesizeRequiredRolesIfMissing(
            actions: inputs,
            rowZeroFrames: [],
            frameDurationMs: defaultDurationMs
        )

        expect(result.synthesized.isEmpty, "empty rowZeroFrames should not synthesize anything")
        expect(result.warnings.isEmpty, "empty rowZeroFrames should not emit warnings")
    }

    func warningDetailContainsSynthesizedRoleName() {
        let synthesizer = DefaultPetdexGracefulSynthesizer()

        let result = synthesizer.synthesizeRequiredRolesIfMissing(
            actions: [],
            rowZeroFrames: rowZeroFrames,
            frameDurationMs: defaultDurationMs
        )

        expect(result.warnings.count == 2, "missing both required roles should yield 2 warnings")

        let idleWarning = result.warnings.first { $0.role == .idle }
        let draggingWarning = result.warnings.first { $0.role == .dragging }

        guard let idleWarning else {
            fail("expected an idle synthesized warning")
        }
        guard let draggingWarning else {
            fail("expected a dragging synthesized warning")
        }

        expect(idleWarning.detail.contains("idle"), "idle warning detail should contain 'idle'")
        expect(draggingWarning.detail.contains("dragging"), "dragging warning detail should contain 'dragging'")
    }

    func bothRequiredMissingSynthesizesIdleAndDragging() {
        let synthesizer = DefaultPetdexGracefulSynthesizer()
        let happyAction = makeAction(id: "happy_default", role: .happy)

        let result = synthesizer.synthesizeRequiredRolesIfMissing(
            actions: [happyAction],
            rowZeroFrames: rowZeroFrames,
            frameDurationMs: defaultDurationMs
        )

        expect(result.synthesized.count == 3, "1 input + 2 synthesized should yield 3 actions")
        expect(result.synthesized[0] == happyAction, "input action should remain at index 0")

        let synthesizedRoles = result.synthesized.dropFirst().compactMap { $0.role }
        expect(synthesizedRoles.contains(.idle), "synthesized actions should include idle")
        expect(synthesizedRoles.contains(.dragging), "synthesized actions should include dragging")

        for synthesizedAction in result.synthesized.dropFirst() {
            expect(synthesizedAction.loop == true, "synthesized required actions should loop")
            expect(synthesizedAction.frames == rowZeroFrames, "synthesized required actions should reuse rowZeroFrames")
            expect(synthesizedAction.frameDurationMs == defaultDurationMs, "synthesized required actions should use the supplied duration")
        }

        expect(result.warnings.count == 2, "missing both required roles should yield 2 warnings")
        for warning in result.warnings {
            expect(warning.kind == .requiredRoleSynthesized, "all warnings should be requiredRoleSynthesized")
        }
    }

    func synthesizedActionsAppendedAfterInputs() {
        let synthesizer = DefaultPetdexGracefulSynthesizer()
        let walkingAction = makeAction(id: "walking_default", role: .walking)
        let sleepingAction = makeAction(id: "sleeping_default", role: .sleeping)
        let inputs = [walkingAction, sleepingAction]

        let result = synthesizer.synthesizeRequiredRolesIfMissing(
            actions: inputs,
            rowZeroFrames: rowZeroFrames,
            frameDurationMs: defaultDurationMs
        )

        expect(result.synthesized[0] == walkingAction, "input order should be preserved at index 0")
        expect(result.synthesized[1] == sleepingAction, "input order should be preserved at index 1")
        expect(result.synthesized[2].role == .idle, "idle should be synthesized first into index 2")
        expect(result.synthesized[3].role == .dragging, "dragging should be synthesized after idle into index 3")
    }

    // MARK: - Helpers

    private func makeAction(id: String, role: ActionRole?) -> Action {
        guard let actionId = ActionId(rawValue: id) else {
            fail("could not build ActionId for raw value \(id)")
        }
        return Action(
            id: actionId,
            displayName: id,
            role: role,
            tags: [],
            frames: [SpriteFrame(column: 0, row: 0)],
            frameDurationMs: 160,
            loop: true,
            nextActionId: nil
        )
    }

    private func makeSixRowActions(includeIdle: Bool, includeDragging: Bool) -> [Action] {
        // Build a 6-action pack mirroring a typical six-row layout.
        // Required roles: idle, dragging. Recommended roles: walking, sleeping, happy, eating.
        var actions: [Action] = []
        if includeIdle {
            actions.append(makeAction(id: "idle_default", role: .idle))
        } else {
            // Replace the idle slot with a different role so the pack still has 6 entries.
            actions.append(makeAction(id: "jumping_default", role: .jumping))
        }
        actions.append(makeAction(id: "walking_default", role: .walking))
        actions.append(makeAction(id: "sleeping_default", role: .sleeping))
        actions.append(makeAction(id: "happy_default", role: .happy))
        actions.append(makeAction(id: "eating_default", role: .eating))
        if includeDragging {
            actions.append(makeAction(id: "dragging_default", role: .dragging))
        } else {
            actions.append(makeAction(id: "extra_filler", role: nil))
        }
        return actions
    }
}
