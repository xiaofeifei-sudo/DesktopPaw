import Foundation
import DesktopPet

func runAfterTagStateTests() {
    let tests = AfterTagStateTests()
    tests.startsWithoutPendingTag()
    tests.mapsReactionStatesToAfterTags()
    tests.nonReactionStatesDoNotChangePendingTag()
    tests.consumeClearsPendingTag()
    tests.cancelClearsPendingTag()
    tests.newMarkOverridesExistingPendingTag()
    tests.pendingTagPersistsUntilConsumedCancelledOrOverwritten()
}

private struct AfterTagStateTests {
    private let afterPet = ActionTag(rawValue: "after.pet")!
    private let afterFeed = ActionTag(rawValue: "after.feed")!
    private let afterClick = ActionTag(rawValue: "after.click")!

    func startsWithoutPendingTag() {
        let state: AfterTagStateMaintaining = DefaultAfterTagState()

        expect(state.pending == nil, "new after-tag state should start without pending tag")
    }

    func mapsReactionStatesToAfterTags() {
        assertMark(.happy, produces: afterPet)
        assertMark(.eating, produces: afterFeed)
        assertMark(.jumping, produces: afterClick)
    }

    func nonReactionStatesDoNotChangePendingTag() {
        for reaction in [PetState.idle, .walking, .sleeping, .dragging] {
            let state = DefaultAfterTagState(pending: afterPet)

            state.mark(after: reaction)

            expect(state.pending == afterPet, "\(reaction.rawValue) should not produce or clear an after tag")
        }
    }

    func consumeClearsPendingTag() {
        let state = DefaultAfterTagState()
        state.mark(after: .happy)

        state.consume()

        expect(state.pending == nil, "consume should clear pending after tag")
    }

    func cancelClearsPendingTag() {
        let state = DefaultAfterTagState()
        state.mark(after: .jumping)

        state.cancel()

        expect(state.pending == nil, "cancel should clear pending after tag")
    }

    func newMarkOverridesExistingPendingTag() {
        let state = DefaultAfterTagState()
        state.mark(after: .happy)

        state.mark(after: .eating)

        expect(state.pending == afterFeed, "new mark should overwrite existing pending after tag")
    }

    func pendingTagPersistsUntilConsumedCancelledOrOverwritten() {
        let state = DefaultAfterTagState()
        state.mark(after: .happy)

        state.mark(after: .idle)

        expect(state.pending == afterPet, "unmatched idle scheduling should leave pending tag intact")

        state.mark(after: .jumping)

        expect(state.pending == afterClick, "later reaction should overwrite persisted pending tag")
    }

    private func assertMark(_ reaction: PetState, produces expectedTag: ActionTag) {
        let state = DefaultAfterTagState()

        state.mark(after: reaction)

        expect(state.pending == expectedTag, "\(reaction.rawValue) should mark \(expectedTag.rawValue)")
    }
}
