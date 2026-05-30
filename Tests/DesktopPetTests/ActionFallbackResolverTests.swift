import Foundation
import DesktopPet

func runActionFallbackResolverTests() {
    let tests = ActionFallbackResolverTests()
    tests.fallbackChainCoversFiveRoles()
    tests.fallbackChainExcludesIdleAndDragging()
    tests.existingRoleResolvesDirectly()
    tests.walkingMissingFallsBackToIdle()
    tests.sleepingMissingFallsBackToIdle()
    tests.happyMissingFallsBackToIdle()
    tests.eatingMissingFallsBackToHappyThenIdle()
    tests.jumpingMissingFallsBackToHappyThenIdle()
    tests.idleMissingReturnsNil()
    tests.draggingMissingReturnsNil()
}

private struct ActionFallbackResolverTests {
    func fallbackChainCoversFiveRoles() {
        let chain = ActionFallbackChain.chain
        expect(chain[.walking] == [.idle], "walking → [idle]")
        expect(chain[.sleeping] == [.idle], "sleeping → [idle]")
        expect(chain[.happy] == [.idle], "happy → [idle]")
        expect(chain[.eating] == [.happy, .idle], "eating → [happy, idle]")
        expect(chain[.jumping] == [.happy, .idle], "jumping → [happy, idle]")
    }

    func fallbackChainExcludesIdleAndDragging() {
        let chain = ActionFallbackChain.chain
        expect(chain[.idle] == nil, "idle is required and must not have fallback chain")
        expect(chain[.dragging] == nil, "dragging is required and must not have fallback chain")
    }

    func existingRoleResolvesDirectly() {
        let walking = makeAction(id: "walk_default", role: .walking)
        let idle = makeAction(id: "idle_default", role: .idle)
        let catalog = PetActionCatalog(petId: "pet", actions: [walking, idle], warnings: [])

        let resolver = DefaultActionFallbackResolver()
        expect(resolver.resolve(role: .walking, in: catalog) == walking, "walking present should resolve directly")
        expect(resolver.resolve(role: .idle, in: catalog) == idle, "idle present should resolve directly")
    }

    func walkingMissingFallsBackToIdle() {
        let idle = makeAction(id: "idle_default", role: .idle)
        let catalog = PetActionCatalog(petId: "pet", actions: [idle], warnings: [])

        let resolver = DefaultActionFallbackResolver()
        expect(resolver.resolve(role: .walking, in: catalog) == idle, "walking missing should fallback to idle")
    }

    func sleepingMissingFallsBackToIdle() {
        let idle = makeAction(id: "idle_default", role: .idle)
        let catalog = PetActionCatalog(petId: "pet", actions: [idle], warnings: [])

        let resolver = DefaultActionFallbackResolver()
        expect(resolver.resolve(role: .sleeping, in: catalog) == idle, "sleeping missing should fallback to idle")
    }

    func happyMissingFallsBackToIdle() {
        let idle = makeAction(id: "idle_default", role: .idle)
        let catalog = PetActionCatalog(petId: "pet", actions: [idle], warnings: [])

        let resolver = DefaultActionFallbackResolver()
        expect(resolver.resolve(role: .happy, in: catalog) == idle, "happy missing should fallback to idle")
    }

    func eatingMissingFallsBackToHappyThenIdle() {
        let happy = makeAction(id: "happy_default", role: .happy)
        let idle = makeAction(id: "idle_default", role: .idle)
        let catalogWithHappy = PetActionCatalog(petId: "pet", actions: [happy, idle], warnings: [])
        let catalogWithoutHappy = PetActionCatalog(petId: "pet", actions: [idle], warnings: [])

        let resolver = DefaultActionFallbackResolver()
        expect(resolver.resolve(role: .eating, in: catalogWithHappy) == happy, "eating missing should prefer happy when present")
        expect(resolver.resolve(role: .eating, in: catalogWithoutHappy) == idle, "eating missing should fallback to idle when happy absent")
    }

    func jumpingMissingFallsBackToHappyThenIdle() {
        let happy = makeAction(id: "happy_default", role: .happy)
        let idle = makeAction(id: "idle_default", role: .idle)
        let catalogWithHappy = PetActionCatalog(petId: "pet", actions: [happy, idle], warnings: [])
        let catalogWithoutHappy = PetActionCatalog(petId: "pet", actions: [idle], warnings: [])

        let resolver = DefaultActionFallbackResolver()
        expect(resolver.resolve(role: .jumping, in: catalogWithHappy) == happy, "jumping missing should prefer happy when present")
        expect(resolver.resolve(role: .jumping, in: catalogWithoutHappy) == idle, "jumping missing should fallback to idle when happy absent")
    }

    func idleMissingReturnsNil() {
        let walking = makeAction(id: "walk_default", role: .walking)
        let catalog = PetActionCatalog(petId: "pet", actions: [walking], warnings: [])

        let resolver = DefaultActionFallbackResolver()
        expect(resolver.resolve(role: .idle, in: catalog) == nil, "idle is required: missing should return nil")
    }

    func draggingMissingReturnsNil() {
        let idle = makeAction(id: "idle_default", role: .idle)
        let catalog = PetActionCatalog(petId: "pet", actions: [idle], warnings: [])

        let resolver = DefaultActionFallbackResolver()
        expect(resolver.resolve(role: .dragging, in: catalog) == nil, "dragging is required: missing should return nil")
    }

    private func makeAction(id rawId: String, role: ActionRole?) -> Action {
        Action(
            id: ActionId(rawValue: rawId)!,
            displayName: rawId,
            role: role,
            tags: [],
            frames: [SpriteFrame(column: 0, row: 0)],
            frameDurationMs: 160,
            loop: true
        )
    }
}
