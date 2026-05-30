import Foundation
import DesktopPet

func runPetActionCatalogTests() {
    let tests = PetActionCatalogTests()
    tests.emptyCatalogHasNoIndexes()
    tests.roleActionAppearsInActionsByRole()
    tests.extraActionAppearsInExtras()
    tests.actionsByIdProvidesO1Lookup()
    tests.resolveByActionIdReturnsMatchingAction()
    tests.resolveByActionIdReturnsNilWhenMissing()
    tests.actionsForRoleReturnsArray()
    tests.actionsForRoleReturnsEmptyWhenAbsent()
    tests.extrasMatchingTagFiltersOnlyExtras()
    tests.extrasMatchingTagIgnoresRoleActions()
    tests.warningsArePreservedOnCatalog()
    tests.equalCatalogsAreEquatable()
}

private struct PetActionCatalogTests {
    func emptyCatalogHasNoIndexes() {
        let catalog = PetActionCatalog(petId: "pet", actions: [], warnings: [])
        expect(catalog.actions.isEmpty, "expected no actions")
        expect(catalog.actionsById.isEmpty, "expected no actionsById entries")
        expect(catalog.actionsByRole.isEmpty, "expected no actionsByRole entries")
        expect(catalog.extras.isEmpty, "expected no extras entries")
        expect(catalog.warnings.isEmpty, "expected no warnings")
    }

    func roleActionAppearsInActionsByRole() {
        let idle = makeAction(id: "idle_default", role: .idle)
        let walking = makeAction(id: "walk_default", role: .walking)
        let catalog = PetActionCatalog(petId: "pet", actions: [idle, walking], warnings: [])

        expect(catalog.actionsByRole[.idle] == [idle], "idle action should be indexed by role")
        expect(catalog.actionsByRole[.walking] == [walking], "walking action should be indexed by role")
        expect(catalog.extras.isEmpty, "role actions should not be in extras")
    }

    func extraActionAppearsInExtras() {
        let extra = makeAction(id: "extra_1", role: nil)
        let catalog = PetActionCatalog(petId: "pet", actions: [extra], warnings: [])

        expect(catalog.extras == [extra], "extra should appear in extras")
        expect(catalog.actionsByRole.isEmpty, "extra should not be in actionsByRole")
    }

    func actionsByIdProvidesO1Lookup() {
        let idle = makeAction(id: "idle_default", role: .idle)
        let extra = makeAction(id: "extra_1", role: nil)
        let catalog = PetActionCatalog(petId: "pet", actions: [idle, extra], warnings: [])

        expect(catalog.actionsById[idle.id] == idle, "actionsById should locate idle action")
        expect(catalog.actionsById[extra.id] == extra, "actionsById should locate extra action")
        expect(catalog.actionsById.count == 2, "actionsById should have one entry per action")
    }

    func resolveByActionIdReturnsMatchingAction() {
        let extra = makeAction(id: "extra_1", role: nil)
        let catalog = PetActionCatalog(petId: "pet", actions: [extra], warnings: [])

        expect(catalog.resolve(actionId: extra.id) == extra, "resolve(actionId:) should return matching action")
    }

    func resolveByActionIdReturnsNilWhenMissing() {
        let catalog = PetActionCatalog(petId: "pet", actions: [], warnings: [])
        let unknown = ActionId(rawValue: "unknown_id")!

        expect(catalog.resolve(actionId: unknown) == nil, "resolve(actionId:) should return nil for unknown id")
    }

    func actionsForRoleReturnsArray() {
        let happy = makeAction(id: "happy_default", role: .happy)
        let catalog = PetActionCatalog(petId: "pet", actions: [happy], warnings: [])

        expect(catalog.actions(for: .happy) == [happy], "actions(for:) should return role-bound actions")
    }

    func actionsForRoleReturnsEmptyWhenAbsent() {
        let catalog = PetActionCatalog(petId: "pet", actions: [], warnings: [])
        expect(catalog.actions(for: .walking) == [], "actions(for:) should return empty array when role missing")
    }

    func extrasMatchingTagFiltersOnlyExtras() {
        let tag = ActionTag(rawValue: "mood:high")!
        let extraWithTag = makeAction(id: "extra_a", role: nil, tags: [tag])
        let extraWithoutTag = makeAction(id: "extra_b", role: nil)
        let catalog = PetActionCatalog(
            petId: "pet",
            actions: [extraWithTag, extraWithoutTag],
            warnings: []
        )

        expect(catalog.extras(matching: tag) == [extraWithTag], "extras(matching:) should filter by tag")
    }

    func extrasMatchingTagIgnoresRoleActions() {
        let tag = ActionTag(rawValue: "mood:high")!
        let happyWithTag = makeAction(id: "happy_default", role: .happy, tags: [tag])
        let extraWithTag = makeAction(id: "extra_1", role: nil, tags: [tag])
        let catalog = PetActionCatalog(
            petId: "pet",
            actions: [happyWithTag, extraWithTag],
            warnings: []
        )

        let matched = catalog.extras(matching: tag)
        expect(matched == [extraWithTag], "extras(matching:) should not include role-bound actions even when tag matches")
    }

    func warningsArePreservedOnCatalog() {
        let warning = ActionImportWarning(kind: .roleFallbackUsed, detail: "missing walking", role: .walking)
        let catalog = PetActionCatalog(petId: "pet", actions: [], warnings: [warning])

        expect(catalog.warnings == [warning], "warnings array should be exposed")
    }

    func equalCatalogsAreEquatable() {
        let action = makeAction(id: "idle_default", role: .idle)
        let lhs = PetActionCatalog(petId: "pet", actions: [action], warnings: [])
        let rhs = PetActionCatalog(petId: "pet", actions: [action], warnings: [])

        expect(lhs == rhs, "catalogs with same inputs should be equal")
    }

    private func makeAction(
        id rawId: String,
        role: ActionRole?,
        tags: [ActionTag] = []
    ) -> Action {
        Action(
            id: ActionId(rawValue: rawId)!,
            displayName: rawId,
            role: role,
            tags: tags,
            frames: [SpriteFrame(column: 0, row: 0)],
            frameDurationMs: 160,
            loop: true
        )
    }
}
