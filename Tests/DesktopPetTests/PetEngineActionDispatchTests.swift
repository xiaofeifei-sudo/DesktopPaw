import Foundation
import DesktopPet

func runPetEngineActionDispatchTests() {
    let tests = PetEngineActionDispatchTests()
    tests.clickedSamplesInteractionActions()
    tests.clickedCanUseRolelessActions()
    tests.petRoutesToHappyWithFallbackToIdle()
    tests.feedRoutesToEatingWithFallbackToHappyThenIdle()
    tests.idleSchedulerWithEmptyPoolKeepsIdle()
    tests.idleSchedulerWithSingleCandidateChoosesIt()
    tests.idleSchedulerWithMultipleCandidatesUsesRng()
    tests.playActionExtraSwitchesToIdleWithExtraId()
    tests.playActionExtraExpiresBackToBaseIdle()
    tests.playActionExpirationStartsAtTriggerTime()
    tests.playActionUnknownIdKeepsCurrentState()
    tests.playActionWalkingSwitchesToWalking()
    tests.reactionDurationDefaultsToTwelveHundredMs()
    tests.idleScheduleNotTriggeredWhileDragging()
    tests.dragEndedClearsCurrentActionId()
    tests.poolEmptyAfterCatalogChange_keepsIdleNoCrash()
    tests.idleScheduleRespectsRandomDelay()
}

private struct PetEngineActionDispatchTests {
    private let referenceDate = Date(timeIntervalSince1970: 1_800_000_000)

    func clickedSamplesInteractionActions() {
        let catalog = makeCatalog()
        let engine = makeEngine(
            catalog: catalog,
            isRandomWalkingEnabled: false,
            randomNumberGenerator: FixedRandomNumberGenerator(value: 0)
        )

        let state = engine.handle(.clicked)

        expect(state.currentState == .walking, "click should sample from interaction actions instead of hard-coding jumping")
        expect(engine.currentActionId == ActionId(rawValue: "walk_default"), "currentActionId should reflect the sampled interaction action")
    }

    func clickedCanUseRolelessActions() {
        let extra = Action(id: ActionId(rawValue: "custom_wave")!, displayName: "Wave", role: nil, frames: [SpriteFrame(column: 0, row: 2)], frameDurationMs: 120, loop: false)
        let catalog = PetActionCatalog(petId: "roleless-click", actions: [extra], warnings: [])
        let engine = makeEngine(catalog: catalog, isRandomWalkingEnabled: false)

        let state = engine.handle(.clicked)

        expect(state.currentState == .idle, "roleless clicked action should use idle as the compatibility state")
        expect(engine.currentActionId == extra.id, "click should be able to play roleless custom actions")
    }

    func petRoutesToHappyWithFallbackToIdle() {
        // happy 缺失 → fallback 到 idle。
        let catalog = makeCatalog(missingRoles: [.happy])
        let engine = makeEngine(catalog: catalog, isRandomWalkingEnabled: false)

        let state = engine.handle(.pet)

        expect(state.currentState == .idle, "missing happy should fall back to idle for pet event")
        expect(engine.currentActionId == ActionId(rawValue: "idle_default"), "currentActionId should be idle_default after pet fallback")
    }

    func feedRoutesToEatingWithFallbackToHappyThenIdle() {
        // 缺 eating → fallback 到 happy。
        let catalogA = makeCatalog(missingRoles: [.eating])
        let engineA = makeEngine(catalog: catalogA, isRandomWalkingEnabled: false)
        _ = engineA.handle(.feed)
        expect(engineA.state.currentState == .happy, "missing eating should fall back to happy")

        // 缺 eating + happy → fallback 到 idle。
        let catalogB = makeCatalog(missingRoles: [.eating, .happy])
        let engineB = makeEngine(catalog: catalogB, isRandomWalkingEnabled: false)
        _ = engineB.handle(.feed)
        expect(engineB.state.currentState == .idle, "missing eating & happy should fall back to idle")
    }

    func idleSchedulerWithEmptyPoolKeepsIdle() {
        let catalog = makeCatalog(missingRoles: [.walking, .happy, .eating, .jumping])
        let rng = SequenceRandomNumberGenerator(values: [20, 0])
        let engine = makeEngine(catalog: catalog, isRandomWalkingEnabled: true, randomNumberGenerator: rng)

        _ = engine.handle(.tick(referenceDate.addingTimeInterval(20)))

        expect(engine.state.currentState == .idle, "empty pool should leave engine in idle")
        expect(engine.currentActionId == nil, "empty pool should not set currentActionId")
    }

    func idleSchedulerWithSingleCandidateChoosesIt() {
        // 池仅含 1 个 extra。
        let extra = Action(
            id: ActionId(rawValue: "extra_only")!,
            displayName: "Extra Only",
            role: nil,
            tags: [],
            frames: [SpriteFrame(column: 0, row: 0)],
            frameDurationMs: 120,
            loop: false,
            nextActionId: ActionId(rawValue: "idle_default")
        )
        let catalog = makeCatalog(missingRoles: [.walking, .happy, .eating, .jumping], extras: [extra])
        let rng = SequenceRandomNumberGenerator(values: [20, 0])
        let engine = makeEngine(catalog: catalog, isRandomWalkingEnabled: true, randomNumberGenerator: rng)

        _ = engine.handle(.tick(referenceDate.addingTimeInterval(20)))

        expect(engine.state.currentState == .idle, "extra (no role) should map to idle state")
        expect(engine.currentActionId == ActionId(rawValue: "extra_only"), "currentActionId should be the extra")
    }

    func idleSchedulerWithMultipleCandidatesUsesRng() {
        // 池含 walking + 2 extras（共 3 候选）。SequenceRNG 控制选择。
        let extraA = Action(id: ActionId(rawValue: "extra_a")!, displayName: "A", role: nil, frames: [SpriteFrame(column: 0, row: 0)], frameDurationMs: 120, loop: false, nextActionId: ActionId(rawValue: "idle_default"))
        let extraB = Action(id: ActionId(rawValue: "extra_b")!, displayName: "B", role: nil, frames: [SpriteFrame(column: 0, row: 0)], frameDurationMs: 120, loop: false, nextActionId: ActionId(rawValue: "idle_default"))
        let catalog = makeCatalog(extras: [extraA, extraB])
        // 序列：第一次抽 idle 调度延迟（落在 [20, 60]，固定 20）；
        // 第二次（选 pool index）传入 [0,1]，0.9 -> floor(0.9*3)=2 -> 选 extraB
        let rng = SequenceRandomNumberGenerator(values: [20, 0.9])
        let engine = makeEngine(catalog: catalog, isRandomWalkingEnabled: true, randomNumberGenerator: rng)

        _ = engine.handle(.tick(referenceDate.addingTimeInterval(20)))

        expect(engine.state.currentState == .idle, "extra B should map to idle state")
        expect(engine.currentActionId == ActionId(rawValue: "extra_b"), "currentActionId should be extra_b for index 2")
        expect(engine.state.currentActionId == ActionId(rawValue: "extra_b"), "runtime state should expose extra_b for rendering")
    }

    func playActionExtraSwitchesToIdleWithExtraId() {
        // playAction(extra_1) 命中 extras → state == idle、currentActionId == extra_1。
        let extra1 = Action(id: ActionId(rawValue: "extra_1")!, displayName: "Extra 1", role: nil, frames: [SpriteFrame(column: 0, row: 0)], frameDurationMs: 120, loop: false, nextActionId: ActionId(rawValue: "idle_default"))
        let catalog = makeCatalog(extras: [extra1])
        let engine = makeEngine(catalog: catalog, isRandomWalkingEnabled: false)

        let state = engine.handle(.playAction(ActionId(rawValue: "extra_1")!))

        expect(state.currentState == .idle, "playAction(extra) should transition to idle state")
        expect(engine.currentActionId == ActionId(rawValue: "extra_1"), "currentActionId should be extra_1")
        expect(state.currentActionId == ActionId(rawValue: "extra_1"), "published runtime state should expose extra_1")
    }

    func playActionExtraExpiresBackToBaseIdle() {
        let extra1 = Action(
            id: ActionId(rawValue: "extra_1")!,
            displayName: "Extra 1",
            role: nil,
            frames: [SpriteFrame(column: 0, row: 7), SpriteFrame(column: 1, row: 7)],
            frameDurationMs: 100,
            loop: false,
            nextActionId: ActionId(rawValue: "idle_default")
        )
        let catalog = makeCatalog(extras: [extra1])
        let engine = makeEngine(catalog: catalog, isRandomWalkingEnabled: false)

        _ = engine.handle(.playAction(ActionId(rawValue: "extra_1")!))
        _ = engine.handle(.tick(referenceDate.addingTimeInterval(0.19)))

        expect(engine.state.currentState == .idle, "extra should stay in idle while playing")
        expect(engine.currentActionId == ActionId(rawValue: "extra_1"), "extra should remain current before its duration elapses")

        _ = engine.handle(.tick(referenceDate.addingTimeInterval(0.2)))

        expect(engine.state.currentState == .idle, "expired extra should return to base idle")
        expect(engine.currentActionId == nil, "expired extra should clear currentActionId")
        expect(engine.state.currentActionId == nil, "published runtime state should clear expired extra action id")
    }

    func playActionExpirationStartsAtTriggerTime() {
        var triggerDate = referenceDate.addingTimeInterval(0.95)
        let extra1 = Action(
            id: ActionId(rawValue: "extra_1")!,
            displayName: "Extra 1",
            role: nil,
            frames: [SpriteFrame(column: 0, row: 7), SpriteFrame(column: 1, row: 7)],
            frameDurationMs: 100,
            loop: false,
            nextActionId: ActionId(rawValue: "idle_default")
        )
        let catalog = makeCatalog(extras: [extra1])
        let engine = makeEngine(catalog: catalog, isRandomWalkingEnabled: false, now: { triggerDate })

        _ = engine.handle(.playAction(ActionId(rawValue: "extra_1")!))
        _ = engine.handle(.tick(referenceDate.addingTimeInterval(1.0)))

        expect(engine.currentActionId == ActionId(rawValue: "extra_1"), "action triggered just before a tick should not expire using the previous tick time")

        triggerDate = referenceDate.addingTimeInterval(1.2)
        _ = engine.handle(.tick(referenceDate.addingTimeInterval(1.16)))

        expect(engine.currentActionId == nil, "action should expire after its duration from the trigger time")
    }

    func playActionUnknownIdKeepsCurrentState() {
        // 未知 actionId → 保持当前状态。
        let catalog = makeCatalog()
        let engine = makeEngine(catalog: catalog, isRandomWalkingEnabled: false)
        _ = engine.handle(.clicked)
        expect(engine.state.currentState == .jumping, "click should enter jumping")

        let state = engine.handle(.playAction(ActionId(rawValue: "missing_action")!))

        expect(state.currentState == .jumping, "unknown actionId should keep current state")
    }

    func playActionWalkingSwitchesToWalking() {
        // playAction(walk_default) → walking。
        let catalog = makeCatalog()
        let engine = makeEngine(catalog: catalog, isRandomWalkingEnabled: false)

        let state = engine.handle(.playAction(ActionId(rawValue: "walk_default")!))

        expect(state.currentState == .walking, "playAction(walk_default) should transition to walking")
        expect(engine.currentActionId == ActionId(rawValue: "walk_default"), "currentActionId should be walk_default")
    }

    func reactionDurationDefaultsToTwelveHundredMs() {
        let catalog = makeCatalog()
        let engine = makeEngine(catalog: catalog, isRandomWalkingEnabled: false)

        _ = engine.handle(.clicked)
        expect(engine.state.currentState == .jumping, "click should enter jumping")
        // 1.1s 后未到 1.2s，仍然 jumping。
        _ = engine.handle(.tick(referenceDate.addingTimeInterval(1.1)))
        expect(engine.state.currentState == .jumping, "before reactionDuration jumping should not exit")
        // 1.3s 后超 1.2s，回到 idle。
        _ = engine.handle(.tick(referenceDate.addingTimeInterval(1.3)))
        expect(engine.state.currentState == .idle, "after reactionDuration jumping should return to idle")
    }

    func idleScheduleNotTriggeredWhileDragging() {
        // 拖拽期间即使到点也不调度 idle 行为池。
        let catalog = makeCatalog()
        let rng = SequenceRandomNumberGenerator(values: [20, 0])
        let engine = makeEngine(catalog: catalog, isRandomWalkingEnabled: true, randomNumberGenerator: rng)
        _ = engine.handle(.dragStarted)
        let state = engine.handle(.tick(referenceDate.addingTimeInterval(30)))
        expect(state.currentState == .dragging, "dragging should hold while ticking past schedule delay")
    }

    func dragEndedClearsCurrentActionId() {
        let catalog = makeCatalog()
        let rng = SequenceRandomNumberGenerator(values: [20, 0])
        let engine = makeEngine(catalog: catalog, isRandomWalkingEnabled: true, randomNumberGenerator: rng)

        _ = engine.handle(.tick(referenceDate.addingTimeInterval(20)))
        expect(engine.state.currentState == .walking, "tick should trigger walking via fixed RNG")
        let walkingId = engine.currentActionId
        expect(walkingId == ActionId(rawValue: "walk_default"), "walking action id should be set")

        _ = engine.handle(.dragStarted)
        expect(engine.state.currentState == .dragging, "dragStarted should switch to dragging")
        expect(engine.currentActionId == nil, "currentActionId should be nil while dragging")

        _ = engine.handle(.dragEnded)
        expect(engine.state.currentState == .idle, "dragEnded should return to idle")
        expect(engine.currentActionId == nil, "currentActionId should be cleared after dragEnded")
    }

    func poolEmptyAfterCatalogChange_keepsIdleNoCrash() {
        // 池为空（缺 walking + 无 extras）情况下连续多次 tick 不会崩溃，状态保持 idle。
        let catalog = makeCatalog(missingRoles: [.walking, .happy, .eating, .jumping])
        let rng = SequenceRandomNumberGenerator(values: [20, 20, 20])
        let engine = makeEngine(catalog: catalog, isRandomWalkingEnabled: true, randomNumberGenerator: rng)

        _ = engine.handle(.tick(referenceDate.addingTimeInterval(20)))
        _ = engine.handle(.tick(referenceDate.addingTimeInterval(40)))
        _ = engine.handle(.tick(referenceDate.addingTimeInterval(60)))

        expect(engine.state.currentState == .idle, "empty pool keeps engine in idle without errors")
    }

    func idleScheduleRespectsRandomDelay() {
        let catalog = makeCatalog()
        let rng = SequenceRandomNumberGenerator(values: [20, 0])
        let engine = makeEngine(catalog: catalog, isRandomWalkingEnabled: true, randomNumberGenerator: rng)

        _ = engine.handle(.tick(referenceDate.addingTimeInterval(19)))
        expect(engine.state.currentState == .idle, "before scheduled delay engine should remain idle")
        _ = engine.handle(.tick(referenceDate.addingTimeInterval(20)))
        expect(engine.state.currentState == .walking, "at scheduled delay engine should transition to walking via pool")
    }

    private func makeEngine(
        catalog: PetActionCatalog,
        isRandomWalkingEnabled: Bool,
        randomNumberGenerator: RandomNumberGenerating? = nil,
        now: (() -> Date)? = nil
    ) -> PetEngine {
        let rng: RandomNumberGenerating = randomNumberGenerator ?? FixedRandomNumberGenerator(value: 20)
        return PetEngine(
            catalog: catalog,
            scheduler: UniformIdleBehaviorScheduler(randomNumberGenerator: rng),
            initialDate: referenceDate,
            isRandomWalkingEnabled: isRandomWalkingEnabled,
            randomNumberGenerator: rng,
            now: now ?? { referenceDate }
        )
    }

    private func makeCatalog(missingRoles: Set<ActionRole> = [], extras: [Action] = []) -> PetActionCatalog {
        var actions: [Action] = []
        let allRoles: [ActionRole] = [.idle, .walking, .sleeping, .happy, .eating, .jumping, .dragging]
        for role in allRoles where !missingRoles.contains(role) {
            actions.append(makeRoleAction(for: role))
        }
        actions.append(contentsOf: extras)
        return PetActionCatalog(petId: "dispatch-test-pet", actions: actions, warnings: [])
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
