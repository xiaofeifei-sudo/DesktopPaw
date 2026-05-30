import DesktopPet

func runActionRoleTests() {
    let tests = ActionRoleTests()
    tests.allRolesBridgeToPetState()
    tests.roleSetsMatchRequiredAndRecommendedPolicy()
}

private struct ActionRoleTests {
    func allRolesBridgeToPetState() {
        let expectedPairs: [(ActionRole, PetState)] = [
            (.idle, .idle),
            (.walking, .walking),
            (.sleeping, .sleeping),
            (.happy, .happy),
            (.eating, .eating),
            (.jumping, .jumping),
            (.dragging, .dragging)
        ]

        expect(ActionRole.allCases.count == expectedPairs.count, "ActionRole should expose exactly seven contract roles")

        for (role, state) in expectedPairs {
            expect(role.legacyState == state, "\(role) should bridge to \(state)")
            expect(ActionRole(legacyState: state) == role, "\(state) should bridge back to \(role)")
        }
    }

    func roleSetsMatchRequiredAndRecommendedPolicy() {
        expect(ActionRole.required == [.idle, .dragging], "required roles should be idle and dragging")
        expect(
            ActionRole.recommended == [.walking, .sleeping, .happy, .eating, .jumping],
            "recommended roles should be the remaining five non-required roles"
        )
        expect(ActionRole.required.isDisjoint(with: ActionRole.recommended), "required and recommended roles should not overlap")
    }
}
