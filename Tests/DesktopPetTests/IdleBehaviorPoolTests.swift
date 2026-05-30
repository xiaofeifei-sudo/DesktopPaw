import Foundation
import DesktopPet

func runIdleBehaviorPoolTests() {
    let tests = IdleBehaviorPoolTests()
    tests.poolContainsNonDefaultCustomActions()
    tests.poolWithoutRolesContainsAllButDefault()
    tests.poolWithOnlyOneActionIsEmpty()
    tests.poolIncludesInteractiveLegacyRoles()
    tests.poolExcludesPassiveLegacyRoles()
}

private struct IdleBehaviorPoolTests {
    func poolContainsNonDefaultCustomActions() {
        let walking = makeAction(id: "walk_default", role: .walking)
        let extraA = makeAction(id: "extra_a", role: nil)
        let extraB = makeAction(id: "extra_b", role: nil)
        let catalog = PetActionCatalog(
            petId: "pet",
            actions: [walking, extraA, extraB],
            warnings: []
        )

        let pool = IdleBehaviorPool.from(catalog: catalog)

        expect(pool.candidates.count == 2, "pool should contain non-default extras")
        expect(!pool.candidates.contains(walking), "single role action should be treated as the default visual")
        expect(pool.candidates.contains(extraA), "pool should contain extra_a")
        expect(pool.candidates.contains(extraB), "pool should contain extra_b")
        expect(pool.isEmpty == false, "pool with candidates should not be empty")
    }

    func poolWithoutRolesContainsAllButDefault() {
        let extraA = makeAction(id: "extra_a", role: nil)
        let extraB = makeAction(id: "extra_b", role: nil)
        let catalog = PetActionCatalog(
            petId: "pet",
            actions: [extraA, extraB],
            warnings: []
        )

        let pool = IdleBehaviorPool.from(catalog: catalog)

        expect(pool.candidates == [extraB], "role-less catalogs should use the first action as default and schedule the rest")
    }

    func poolWithOnlyOneActionIsEmpty() {
        let walking = makeAction(id: "walk_default", role: .walking)
        let catalog = PetActionCatalog(
            petId: "pet",
            actions: [walking],
            warnings: []
        )

        let pool = IdleBehaviorPool.from(catalog: catalog)

        expect(pool.candidates.isEmpty, "single-action catalogs have no ambient alternatives")
    }

    func poolIncludesInteractiveLegacyRoles() {
        let idle = makeAction(id: "idle_default", role: .idle)
        let sleeping = makeAction(id: "sleep_default", role: .sleeping)
        let happy = makeAction(id: "happy_default", role: .happy)
        let eating = makeAction(id: "eat_default", role: .eating)
        let jumping = makeAction(id: "jump_default", role: .jumping)
        let dragging = makeAction(id: "drag_default", role: .dragging)
        let catalog = PetActionCatalog(
            petId: "pet",
            actions: [idle, sleeping, happy, eating, jumping, dragging],
            warnings: []
        )

        let pool = IdleBehaviorPool.from(catalog: catalog)

        expect(pool.candidates.contains(happy), "happy can participate in ambient action scheduling")
        expect(pool.candidates.contains(eating), "eating can participate in ambient action scheduling")
        expect(pool.candidates.contains(jumping), "jumping can participate in ambient action scheduling")
        expect(pool.candidates.contains(idle) == false, "idle must not be in the pool")
        expect(pool.candidates.contains(sleeping) == false, "sleeping must not be in the pool")
        expect(pool.candidates.contains(dragging) == false, "dragging must not be in the pool")
    }

    func poolExcludesPassiveLegacyRoles() {
        let idle = makeAction(id: "idle_default", role: .idle)
        let walking = makeAction(id: "walk_default", role: .walking)
        let sleeping = makeAction(id: "sleep_default", role: .sleeping)
        let happy = makeAction(id: "happy_default", role: .happy)
        let eating = makeAction(id: "eat_default", role: .eating)
        let jumping = makeAction(id: "jump_default", role: .jumping)
        let dragging = makeAction(id: "drag_default", role: .dragging)
        let extra = makeAction(id: "extra_only", role: nil)
        let catalog = PetActionCatalog(
            petId: "pet",
            actions: [idle, walking, sleeping, happy, eating, jumping, dragging, extra],
            warnings: []
        )

        let pool = IdleBehaviorPool.from(catalog: catalog)

        expect(pool.candidates.contains(walking), "walking should remain in the ambient pool when idle is the default")
        expect(pool.candidates.contains(happy), "happy should be in the ambient pool")
        expect(pool.candidates.contains(eating), "eating should be in the ambient pool")
        expect(pool.candidates.contains(jumping), "jumping should be in the ambient pool")
        expect(pool.candidates.contains(extra), "extras should be in the pool")
        expect(pool.candidates.contains(idle) == false, "idle must not be in the pool")
        expect(pool.candidates.contains(sleeping) == false, "sleeping must not be in the pool")
        expect(pool.candidates.contains(dragging) == false, "dragging must not be in the pool")
        expect(pool.candidates.count == 5, "pool should contain walking + interactive roles + extra")
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
