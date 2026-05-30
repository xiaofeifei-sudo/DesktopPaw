import Foundation
import DesktopPet

@MainActor
func runPetEngineCommandHandlerActionsTests() {
    let tests = PetEngineCommandHandlerActionsTests()
    tests.exposesInjectedCatalogToUILayer()
    tests.playActionPublishesStateAndSetsCurrentActionId()
    tests.playActionUnknownIdDoesNotCrash()
    tests.preservesExistingCommandBehaviors()
}

@MainActor
private struct PetEngineCommandHandlerActionsTests {
    private let referenceDate = Date(timeIntervalSince1970: 1_800_000_000)

    func exposesInjectedCatalogToUILayer() {
        let catalog = makeCatalog(petId: "actions-catalog-test")
        let handler = makeHandler(catalog: catalog)

        let exposed: PetActionCatalog = (handler as PetCommandHandling).catalog

        expect(exposed.petId == "actions-catalog-test", "catalog.petId should match the injected catalog")
        expect(exposed.actions.count == catalog.actions.count, "catalog.actions count should equal injected actions")
        expect(exposed.resolve(actionId: ActionId(rawValue: "idle_default")!) != nil, "catalog should resolve idle_default action")
        expect(exposed.actions(for: .walking).count == 1, "catalog should expose walking actions for UI use")
    }

    func playActionPublishesStateAndSetsCurrentActionId() {
        let catalog = makeCatalog(petId: "actions-play-action-test")
        let handler = makeHandler(catalog: catalog)

        var publishedStates: [PetRuntimeState] = []
        handler.onStateChanged = { publishedStates.append($0) }

        handler.playAction(ActionId(rawValue: "extra_1")!)

        expect(publishedStates.count == 1, "playAction should publish a runtime state through onStateChanged")
        expect(handler.engine.currentActionId == ActionId(rawValue: "extra_1"), "playAction should set currentActionId to extra_1")
        expect(handler.runtimeState.currentActionId == ActionId(rawValue: "extra_1"), "runtimeState should carry currentActionId for UI rendering")
        expect(publishedStates.last?.currentActionId == ActionId(rawValue: "extra_1"), "published state should carry currentActionId")
        expect(publishedStates.last == handler.runtimeState, "published state should match handler runtimeState")
    }

    func playActionUnknownIdDoesNotCrash() {
        let catalog = makeCatalog(petId: "actions-unknown-test")
        let handler = makeHandler(catalog: catalog)

        var publishedStates: [PetRuntimeState] = []
        handler.onStateChanged = { publishedStates.append($0) }
        let initialState = handler.runtimeState
        let initialActionId = handler.engine.currentActionId

        handler.playAction(ActionId(rawValue: "unknown")!)

        expect(publishedStates.count == 1, "unknown playAction should still publish the current runtime state")
        expect(handler.runtimeState == initialState, "unknown playAction should keep runtimeState unchanged")
        expect(handler.engine.currentActionId == initialActionId, "unknown playAction should keep currentActionId unchanged")
    }

    func preservesExistingCommandBehaviors() {
        let catalog = makeCatalog(petId: "actions-behavior-test")
        let handler = makeHandler(catalog: catalog)

        var publishedStates: [PetRuntimeState] = []
        handler.onStateChanged = { publishedStates.append($0) }

        handler.clicked()
        expect(handler.runtimeState.currentState == .walking, "clicked should sample an interaction action instead of hard-coding jumping")
        handler.pet()
        expect(handler.runtimeState.currentState == .happy, "pet should still drive engine to happy role")
        handler.feed()
        expect(handler.runtimeState.currentState == .eating, "feed should still drive engine to eating role")
        handler.sleep()
        expect(handler.isSleeping, "sleep should mark handler as sleeping")
        handler.wake()
        expect(!handler.isSleeping, "wake should clear sleeping flag")
        handler.dragStarted()
        expect(handler.runtimeState.currentState == .dragging, "dragStarted should drive engine to dragging role")
        handler.dragEnded()
        expect(handler.runtimeState.currentState == .idle, "dragEnded should return engine to idle")

        let initialScale = handler.runtimeState.scale
        handler.setScale(initialScale + 0.25)
        expect(abs(handler.runtimeState.scale - (initialScale + 0.25)) < 0.0001, "setScale should propagate to engine state")

        handler.tick(at: referenceDate.addingTimeInterval(1))
        expect(publishedStates.count >= 1, "tick should publish a runtime state through onStateChanged")
    }

    private func makeHandler(catalog: PetActionCatalog) -> PetEngineCommandHandler {
        let rng = FixedRandomNumberGenerator(value: 0)
        let engine = PetEngine(
            catalog: catalog,
            scheduler: UniformIdleBehaviorScheduler(randomNumberGenerator: rng),
            initialDate: referenceDate,
            isRandomWalkingEnabled: false,
            randomNumberGenerator: rng
        )
        return PetEngineCommandHandler(engine: engine, catalog: catalog)
    }

    private func makeCatalog(petId: String) -> PetActionCatalog {
        let allRoles: [ActionRole] = [.idle, .walking, .sleeping, .happy, .eating, .jumping, .dragging]
        let actions = allRoles.map { makeRoleAction(for: $0) } + [makeExtraAction()]
        return PetActionCatalog(petId: petId, actions: actions, warnings: [])
    }

    private func makeExtraAction() -> Action {
        Action(
            id: ActionId(rawValue: "extra_1")!,
            displayName: "Extra 1",
            role: nil,
            tags: [],
            frames: [SpriteFrame(column: 0, row: 0)],
            frameDurationMs: 120,
            loop: false,
            nextActionId: ActionId(rawValue: "idle_default")
        )
    }

    private func makeRoleAction(for role: ActionRole) -> Action {
        let id: String
        let loop: Bool
        let frameDurationMs: Int
        let next: ActionId?
        switch role {
        case .idle:
            id = "idle_default"; loop = true; frameDurationMs = 160; next = nil
        case .walking:
            id = "walk_default"; loop = true; frameDurationMs = 160; next = nil
        case .sleeping:
            id = "sleep_default"; loop = true; frameDurationMs = 300; next = nil
        case .happy:
            id = "happy_default"; loop = false; frameDurationMs = 120; next = ActionId(rawValue: "idle_default")
        case .eating:
            id = "eat_default"; loop = false; frameDurationMs = 120; next = ActionId(rawValue: "idle_default")
        case .jumping:
            id = "jump_default"; loop = false; frameDurationMs = 110; next = ActionId(rawValue: "idle_default")
        case .dragging:
            id = "drag_default"; loop = true; frameDurationMs = 160; next = nil
        }
        return Action(
            id: ActionId(rawValue: id)!,
            displayName: id,
            role: role,
            tags: [],
            frames: [SpriteFrame(column: 0, row: 0)],
            frameDurationMs: frameDurationMs,
            loop: loop,
            nextActionId: next
        )
    }
}
