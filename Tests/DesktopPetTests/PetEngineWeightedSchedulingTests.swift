import Foundation
import DesktopPet

func runPetEngineWeightedSchedulingTests() {
    let tests = PetEngineWeightedSchedulingTests()
    tests.idleSchedulingUsesMoodSnapshotForHighLowWeights()
    tests.afterPetWeightsNextIdleOnlyOnce()
    tests.timeMorningWeightsIdleAction()
    tests.multiTagMatchesMultiplyWeights()
    tests.petReactionSamplesMultipleHappyActionsByWeight()
    tests.allZeroReactionCandidatesFallBackToIdle()
    tests.openTagsAreNeutralForIdleScheduling()
    tests.singleImageAndNoTagCatalogsKeepExistingBehavior()
}

private struct PetEngineWeightedSchedulingTests {
    func idleSchedulingUsesMoodSnapshotForHighLowWeights() {
        let initialDate = date(hour: 9, minute: 0)
        let high = extra("mood_high_extra", tags: ["mood:high"])
        let neutral = extra("mood_neutral_extra")
        let snapshotProvider = TrackingMoodSnapshotProvider(capturedAt: initialDate)
        let highBoostEngine = makeEngine(
            catalog: makeCatalog(extras: [high, neutral]),
            initialDate: initialDate,
            mood: 0.7,
            rng: SequenceRandomNumberGenerator(values: [20, 2.5]),
            moodSnapshotProvider: snapshotProvider
        )

        _ = highBoostEngine.handle(.tick(initialDate.addingTimeInterval(20)))

        expect(highBoostEngine.currentActionId == high.id, "mood:high extra should receive boosted weight at high mood")
        expect(snapshotProvider.snapshottedMoods.count == 1, "idle scheduling should take exactly one mood snapshot")
        expect(snapshotProvider.snapshottedMoods[0] >= MoodLevelClassifier.highThreshold, "snapshot should receive the current high mood")

        let low = extra("mood_low_extra", tags: ["mood:low"])
        let lowExcludedEngine = makeEngine(
            catalog: makeCatalog(extras: [low, high]),
            initialDate: initialDate,
            mood: 0.7,
            rng: SequenceRandomNumberGenerator(values: [20, 0.5])
        )

        _ = lowExcludedEngine.handle(.tick(initialDate.addingTimeInterval(20)))

        expect(lowExcludedEngine.currentActionId == high.id, "mood:low extra should be excluded at high mood")
    }

    func afterPetWeightsNextIdleOnlyOnce() {
        let initialDate = date(hour: 9, minute: 0)
        let afterPet = extra("after_pet_extra", tags: ["after.pet"])
        let neutral = extra("neutral_extra")
        let afterState = DefaultAfterTagState()
        let engine = makeEngine(
            catalog: makeCatalog(
                roleActions: [roleAction("happy_default", role: .happy)],
                extras: [afterPet, neutral]
            ),
            initialDate: initialDate,
            mood: 0.6,
            rng: SequenceRandomNumberGenerator(values: [20, 0, 20, 1.5, 20, 2.5, 20]),
            afterTagState: afterState
        )

        _ = engine.handle(.pet)
        _ = engine.handle(.tick(initialDate.addingTimeInterval(1.3)))

        expect(afterState.pending == tag("after.pet"), "happy completion should mark after.pet")

        _ = engine.handle(.tick(initialDate.addingTimeInterval(21.3)))

        expect(engine.currentActionId == afterPet.id, "after.pet extra should be boosted on the next idle schedule")
        expect(afterState.pending == nil, "after.pet should be consumed after the boosted hit")

        _ = engine.handle(.tick(initialDate.addingTimeInterval(41.3)))

        expect(engine.currentActionId == neutral.id, "after.pet boost should be one-shot after consume")
    }

    func timeMorningWeightsIdleAction() {
        let initialDate = date(hour: 9, minute: 0)
        let morning = extra("morning_extra", tags: ["time.morning"])
        let neutral = extra("plain_extra")
        let engine = makeEngine(
            catalog: makeCatalog(extras: [morning, neutral]),
            initialDate: initialDate,
            mood: 0.5,
            rng: SequenceRandomNumberGenerator(values: [20, 2.5])
        )

        _ = engine.handle(.tick(initialDate.addingTimeInterval(20)))

        expect(engine.currentActionId == morning.id, "time.morning extra should be boosted during the morning slot")
    }

    func multiTagMatchesMultiplyWeights() {
        let initialDate = date(hour: 9, minute: 0)
        let multi = extra("multi_match_extra", tags: ["mood:high", "time.morning"])
        let neutral = extra("neutral_multi_extra")
        let engine = makeEngine(
            catalog: makeCatalog(extras: [multi, neutral]),
            initialDate: initialDate,
            mood: 0.8,
            rng: SequenceRandomNumberGenerator(values: [20, 8.5])
        )

        _ = engine.handle(.tick(initialDate.addingTimeInterval(20)))

        expect(engine.currentActionId == multi.id, "mood + time tags should multiply their weights")
    }

    func petReactionSamplesMultipleHappyActionsByWeight() {
        let initialDate = date(hour: 9, minute: 0)
        let lowHappy = roleAction("happy_low", role: .happy, tags: ["mood:low"])
        let highHappy = roleAction("happy_high", role: .happy, tags: ["mood:high"])
        let engine = makeEngine(
            catalog: makeCatalog(roleActions: [lowHappy, highHappy]),
            initialDate: initialDate,
            mood: 0.6,
            rng: FixedRandomNumberGenerator(value: 0),
            isRandomWalkingEnabled: false
        )

        _ = engine.handle(.pet)

        expect(engine.state.currentState == .happy, "pet should still enter the happy role")
        expect(engine.currentActionId == highHappy.id, "multiple happy actions should be sampled by current tag weights")
    }

    func allZeroReactionCandidatesFallBackToIdle() {
        let initialDate = date(hour: 9, minute: 0)
        let lowHappy = roleAction("happy_low_only", role: .happy, tags: ["mood:low"])
        let engine = makeEngine(
            catalog: makeCatalog(roleActions: [lowHappy]),
            initialDate: initialDate,
            mood: 0.7,
            rng: FixedRandomNumberGenerator(value: 0),
            isRandomWalkingEnabled: false
        )

        _ = engine.handle(.pet)

        expect(engine.state.currentState == .idle, "all-zero happy candidates should fall back through happy -> idle")
        expect(engine.currentActionId == ActionId(rawValue: "idle_default"), "idle fallback action should be selected")
    }

    func openTagsAreNeutralForIdleScheduling() {
        let initialDate = date(hour: 9, minute: 0)
        let open = extra("open_tag_extra", tags: ["vibe:cozy"])
        let neutral = extra("neutral_open_extra")
        let engine = makeEngine(
            catalog: makeCatalog(extras: [open, neutral]),
            initialDate: initialDate,
            mood: 0.5,
            rng: SequenceRandomNumberGenerator(values: [20, 0.5])
        )

        _ = engine.handle(.tick(initialDate.addingTimeInterval(20)))

        expect(engine.currentActionId == open.id, "open tags should be neutral rather than excluded")
    }

    func singleImageAndNoTagCatalogsKeepExistingBehavior() {
        let initialDate = date(hour: 9, minute: 0)
        let singleImageCatalog = PetActionCatalog(
            petId: "single-image",
            actions: [roleAction("idle_default", role: .idle)],
            warnings: []
        )
        let singleImageEngine = makeEngine(
            catalog: singleImageCatalog,
            initialDate: initialDate,
            mood: 0.5,
            rng: FixedRandomNumberGenerator(value: 20)
        )

        _ = singleImageEngine.handle(.tick(initialDate.addingTimeInterval(20)))

        expect(singleImageEngine.state.currentState == .idle, "single-image idle-only catalog should remain idle")
        expect(singleImageEngine.currentActionId == nil, "empty idle pool should not assign an action id")

        let noTagEngine = makeEngine(
            catalog: makeStandardCatalog(),
            initialDate: initialDate,
            mood: 0.5,
            rng: SequenceRandomNumberGenerator(values: [20, 0])
        )

        _ = noTagEngine.handle(.tick(initialDate.addingTimeInterval(20)))

        expect(noTagEngine.state.currentState == .walking, "untagged built-in style catalog should still schedule walking")
        expect(noTagEngine.currentActionId == ActionId(rawValue: "walk_default"), "untagged walking action should be selected")
    }

    private func makeEngine(
        catalog: PetActionCatalog,
        initialDate: Date,
        mood: Double,
        rng: RandomNumberGenerating,
        isRandomWalkingEnabled: Bool = true,
        moodSnapshotProvider: MoodSnapshotProviding = SystemMoodSnapshot(),
        afterTagState: AfterTagStateMaintaining = DefaultAfterTagState()
    ) -> PetEngine {
        let initialState = PetRuntimeState(
            currentState: .idle,
            mood: mood,
            hunger: 0.4,
            energy: 0.8,
            lastInteractionAt: initialDate,
            isDragging: false,
            scale: 1
        )
        return PetEngine(
            catalog: catalog,
            moodSnapshotProvider: moodSnapshotProvider,
            afterTagState: afterTagState,
            initialState: initialState,
            initialDate: initialDate,
            isRandomWalkingEnabled: isRandomWalkingEnabled,
            randomNumberGenerator: rng,
            now: { initialDate }
        )
    }

    private func makeCatalog(
        roleActions: [Action] = [],
        extras: [Action] = []
    ) -> PetActionCatalog {
        var actions = [
            roleAction("idle_default", role: .idle),
            roleAction("drag_default", role: .dragging)
        ]
        actions.append(contentsOf: roleActions)
        actions.append(contentsOf: extras)
        return PetActionCatalog(petId: "weighted-engine-test", actions: actions, warnings: [])
    }

    private func roleAction(_ rawId: String, role: ActionRole, tags rawTags: [String] = []) -> Action {
        makeAction(
            id: rawId,
            role: role,
            tags: rawTags.map(tag),
            frameDurationMs: 120,
            loop: role == .idle || role == .walking || role == .sleeping || role == .dragging,
            nextActionId: role == .idle || role == .walking || role == .sleeping || role == .dragging
                ? nil
                : ActionId(rawValue: "idle_default")
        )
    }

    private func extra(_ rawId: String, tags rawTags: [String] = []) -> Action {
        makeAction(
            id: rawId,
            role: nil,
            tags: rawTags.map(tag),
            frameDurationMs: 120,
            loop: false,
            nextActionId: ActionId(rawValue: "idle_default")
        )
    }

    private func tag(_ rawValue: String) -> ActionTag {
        guard let tag = ActionTag(rawValue: rawValue) else {
            fail("test tag should be valid: \(rawValue)")
        }
        return tag
    }

    private func date(hour: Int, minute: Int) -> Date {
        var components = DateComponents()
        components.calendar = Calendar.current
        components.timeZone = Calendar.current.timeZone
        components.year = 2026
        components.month = 5
        components.day = 14
        components.hour = hour
        components.minute = minute
        guard let date = components.date else {
            fail("test date should be constructible")
        }
        return date
    }
}

private final class TrackingMoodSnapshotProvider: MoodSnapshotProviding {
    private let capturedAt: Date
    private(set) var snapshottedMoods: [Double] = []

    init(capturedAt: Date) {
        self.capturedAt = capturedAt
    }

    func snapshot(currentMood: Double) -> MoodSnapshot {
        snapshottedMoods.append(currentMood)
        return MoodSnapshot(
            mood: currentMood,
            level: MoodLevelClassifier.level(for: currentMood),
            capturedAt: capturedAt
        )
    }
}
