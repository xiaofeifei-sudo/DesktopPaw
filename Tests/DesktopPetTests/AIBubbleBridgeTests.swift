import Foundation
import DesktopPet

@MainActor
func runAIBubbleBridgeTests() {
    let tests = AIBubbleBridgeTests()
    tests.emitBubbleReturnsTrueForValidResponse()
    tests.emitBubbleReturnsFalseWhenDisabled()
    tests.emitBubbleReturnsFalseInQuietMode()
    tests.emitBubbleReturnsFalseWhenNoBubbleText()
    tests.emitBubbleReturnsFalseWhenSchedulerBlocks()
    tests.emitBubbleCreatesCorrectPetBubble()
    tests.emitBubbleCallsOnBubbleEmitted()
    tests.emitBubbleTextDoesNotExceedLimit()
    tests.canEmitBubbleReturnsFalseWhenDisabled()
    tests.canEmitBubbleReturnsFalseInQuietMode()
    tests.canEmitBubbleReturnsTrueNormally()
    tests.canEmitBubbleRespectsInitiativeFrequency()
    tests.canEmitBubbleRespectsSchedulerGlobalInterval()
    tests.emitInitiativeBubbleUpdatesLastInitiativeTime()
    tests.emitInitiativeBubbleReturnsFalseWhenFrequencyNotMet()
    tests.closingAIDoesNotAffectRuleBubbles()
    tests.ruleBubbleEmissionNotBlockedByAIBridgeState()
}

@MainActor
private struct AIBubbleBridgeTests {
    private func makeBridge(
        isAIBubbleEnabled: Bool = true,
        initiativeInterval: TimeInterval = 1800,
        preferences: CompanionPreferences = CompanionPreferences(),
        quietModePolicy: QuietModeEvaluating? = nil,
        scheduler: BubbleScheduler = BubbleScheduler(),
        globalMinimumInterval: TimeInterval = 60.0
    ) -> AIBubbleBridge {
        AIBubbleBridge(
            quietModePolicy: quietModePolicy,
            scheduler: scheduler,
            getPreferences: { preferences },
            globalMinimumInterval: { globalMinimumInterval },
            onBubbleEmitted: { _ in },
            isAIBubbleEnabled: isAIBubbleEnabled,
            initiativeBubbleMinInterval: initiativeInterval,
            idGenerator: { UUID() }
        )
    }

    private func makeResponse(bubbleText: String? = "你好呀", panelText: String = "完整回复") -> AIChatResponse {
        AIChatResponse(
            message: AIChatMessage(role: .assistant, content: panelText),
            bubbleText: bubbleText,
            panelText: panelText,
            safetyLevel: .safe
        )
    }

    func emitBubbleReturnsTrueForValidResponse() {
        let bridge = makeBridge()
        let result = bridge.emitBubble(from: makeResponse(), petId: "test-pet")
        expect(result == true, "emitBubble should return true for valid response")
    }

    func emitBubbleReturnsFalseWhenDisabled() {
        let bridge = makeBridge(isAIBubbleEnabled: false)
        let result = bridge.emitBubble(from: makeResponse(), petId: "test-pet")
        expect(result == false, "emitBubble should return false when AI bubble disabled")
    }

    func emitBubbleReturnsFalseInQuietMode() {
        let prefs = CompanionPreferences(quietUntil: Date().addingTimeInterval(3600))
        let bridge = makeBridge(preferences: prefs)
        let result = bridge.emitBubble(from: makeResponse(), petId: "test-pet")
        expect(result == false, "emitBubble should return false in quiet mode")
    }

    func emitBubbleReturnsFalseWhenNoBubbleText() {
        let bridge = makeBridge()
        let result = bridge.emitBubble(from: makeResponse(bubbleText: nil), petId: "test-pet")
        expect(result == false, "emitBubble should return false when no bubble text")
    }

    func emitBubbleReturnsFalseWhenSchedulerBlocks() {
        let scheduler = BubbleScheduler()
        let existingBubble = PetBubble(
            id: UUID(),
            text: "existing",
            priority: .state,
            createdAt: Date(),
            expiresAt: Date().addingTimeInterval(10)
        )
        scheduler.register(existingBubble)

        let bridge = makeBridge(scheduler: scheduler, globalMinimumInterval: 60.0)
        let result = bridge.emitBubble(from: makeResponse(), petId: "test-pet")
        expect(result == false, "emitBubble should return false when scheduler blocks")
    }

    func emitBubbleCreatesCorrectPetBubble() {
        var captured: PetBubble?
        let scheduler = BubbleScheduler()
        let bridge = AIBubbleBridge(
            scheduler: scheduler,
            getPreferences: { CompanionPreferences() },
            globalMinimumInterval: { 60.0 },
            onBubbleEmitted: { bubble in captured = bubble },
            idGenerator: { UUID() }
        )

        _ = bridge.emitBubble(from: makeResponse(bubbleText: "你好呀"), petId: "test-pet")
        expect(captured != nil, "should create a bubble")
        expect(captured!.priority == .relationship, "AI bubble should have relationship priority")
        expect(captured!.text == "你好呀", "bubble text should match adapted text")
    }

    func emitBubbleCallsOnBubbleEmitted() {
        var callCount = 0
        let scheduler = BubbleScheduler()
        let bridge = AIBubbleBridge(
            scheduler: scheduler,
            getPreferences: { CompanionPreferences() },
            globalMinimumInterval: { 60.0 },
            onBubbleEmitted: { _ in callCount += 1 },
            idGenerator: { UUID() }
        )

        _ = bridge.emitBubble(from: makeResponse(), petId: "test-pet")
        expect(callCount == 1, "onBubbleEmitted should be called once")
    }

    func emitBubbleTextDoesNotExceedLimit() {
        var captured: PetBubble?
        let scheduler = BubbleScheduler()
        let bridge = AIBubbleBridge(
            scheduler: scheduler,
            getPreferences: { CompanionPreferences() },
            globalMinimumInterval: { 60.0 },
            onBubbleEmitted: { bubble in captured = bubble },
            idGenerator: { UUID() }
        )

        let longText = "今天天气真好想出去玩呀哈哈啊" // 14 CJK chars, will be truncated
        _ = bridge.emitBubble(from: makeResponse(bubbleText: longText), petId: "test-pet")
        expect(captured != nil, "should create bubble even for long text")
        let cjk = AIChatBubbleAdapter.cjkCount(captured!.text.replacingOccurrences(of: "…", with: ""))
        expect(cjk <= 12, "adapted text should not exceed 12 CJK characters")
    }

    func canEmitBubbleReturnsFalseWhenDisabled() {
        let bridge = makeBridge(isAIBubbleEnabled: false)
        expect(bridge.canEmitBubble(petId: "test-pet") == false, "canEmitBubble should return false when disabled")
    }

    func canEmitBubbleReturnsFalseInQuietMode() {
        let prefs = CompanionPreferences(quietUntil: Date().addingTimeInterval(3600))
        let bridge = makeBridge(preferences: prefs)
        expect(bridge.canEmitBubble(petId: "test-pet") == false, "canEmitBubble should return false in quiet mode")
    }

    func canEmitBubbleReturnsTrueNormally() {
        let bridge = makeBridge()
        expect(bridge.canEmitBubble(petId: "test-pet") == true, "canEmitBubble should return true under normal conditions")
    }

    func canEmitBubbleRespectsInitiativeFrequency() {
        let scheduler = BubbleScheduler()
        let bridge = AIBubbleBridge(
            scheduler: scheduler,
            getPreferences: { CompanionPreferences() },
            globalMinimumInterval: { 0.0 },
            onBubbleEmitted: { _ in },
            initiativeBubbleMinInterval: 1800,
            idGenerator: { UUID() }
        )

        _ = bridge.emitInitiativeBubble(text: "你好", petId: "test-pet")
        expect(bridge.canEmitBubble(petId: "test-pet") == false, "canEmitBubble should return false right after initiative bubble")
    }

    func canEmitBubbleRespectsSchedulerGlobalInterval() {
        let scheduler = BubbleScheduler()
        let existingBubble = PetBubble(
            id: UUID(),
            text: "existing",
            priority: .state,
            createdAt: Date(),
            expiresAt: Date().addingTimeInterval(10)
        )
        scheduler.register(existingBubble)

        let bridge = makeBridge(scheduler: scheduler, globalMinimumInterval: 60.0)
        expect(bridge.canEmitBubble(petId: "test-pet") == false, "canEmitBubble should respect scheduler global interval")
    }

    func emitInitiativeBubbleUpdatesLastInitiativeTime() {
        let scheduler = BubbleScheduler()
        let bridge = AIBubbleBridge(
            scheduler: scheduler,
            getPreferences: { CompanionPreferences() },
            globalMinimumInterval: { 0.0 },
            onBubbleEmitted: { _ in },
            initiativeBubbleMinInterval: 1800,
            idGenerator: { UUID() }
        )

        expect(bridge.lastInitiativeBubbleAt == nil, "lastInitiativeBubbleAt should be nil initially")
        _ = bridge.emitInitiativeBubble(text: "你好", petId: "test-pet")
        expect(bridge.lastInitiativeBubbleAt != nil, "lastInitiativeBubbleAt should be set after initiative bubble")
    }

    func emitInitiativeBubbleReturnsFalseWhenFrequencyNotMet() {
        let scheduler = BubbleScheduler()
        let bridge = AIBubbleBridge(
            scheduler: scheduler,
            getPreferences: { CompanionPreferences() },
            globalMinimumInterval: { 0.0 },
            onBubbleEmitted: { _ in },
            initiativeBubbleMinInterval: 1800,
            idGenerator: { UUID() }
        )

        _ = bridge.emitInitiativeBubble(text: "你好", petId: "test-pet")
        let result = bridge.emitInitiativeBubble(text: "又来了", petId: "test-pet")
        expect(result == false, "emitInitiativeBubble should return false when frequency not met")
    }

    func closingAIDoesNotAffectRuleBubbles() {
        let scheduler = BubbleScheduler()
        let _ = makeBridge(isAIBubbleEnabled: false, scheduler: scheduler)

        let ruleBubble = PetBubble(
            id: UUID(),
            text: "规则气泡",
            priority: .relationship,
            createdAt: Date(),
            expiresAt: Date().addingTimeInterval(5)
        )
        scheduler.register(ruleBubble)
        expect(scheduler.currentBubble != nil, "rule bubble should still be registered")
        expect(scheduler.currentBubble?.text == "规则气泡", "rule bubble should not be affected by AI being off")
    }

    func ruleBubbleEmissionNotBlockedByAIBridgeState() {
        let scheduler = BubbleScheduler()
        let _ = makeBridge(isAIBubbleEnabled: false, scheduler: scheduler)

        let canEmit = scheduler.canEmit(priority: .relationship, at: Date(), minimumInterval: 0)
        expect(canEmit == true, "scheduler should allow rule bubbles regardless of AI bridge state")
    }

}
