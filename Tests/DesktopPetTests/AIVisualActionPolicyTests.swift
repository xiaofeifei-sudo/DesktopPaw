import Foundation
import DesktopPet

@MainActor
func runAIVisualActionPolicyTests() {
    let tests = AIVisualActionPolicyTests()
    tests.denyWhenAIDisabled()
    tests.denyWhenVisualExpressionDisabled()
    tests.denyAutonomousInQuietMode()
    tests.allowUserRequestInQuietMode()
    tests.denyBubbleSourceWhenBubbleDisabled()
    tests.allowBubbleSourceWhenBubbleEnabled()
    tests.denyKindNotPhase1Allowed()
    tests.denyWhenActiveOverlay()
    tests.needsConfirmationOnFirstTrigger()
    tests.needsConfirmationForHighImpact()
    tests.allowLowImpactAfterFirstTrigger()
    tests.denyTakesPrecedenceOverConfirmation()
    tests.policyIsStateless()
    tests.allowAutonomousWhenNotQuietMode()
}

@MainActor
private struct AIVisualActionPolicyTests {
    private let policy = AIVisualActionPolicy()

    func denyWhenAIDisabled() {
        let candidate = makeCandidate()
        let ctx = makeContext(isAIEnabled: false)
        let decision = policy.evaluate(candidate, context: ctx)

        expect(decision == .deny(reason: .aiDisabled, userFacingText: "AI 功能未开启"),
               "should deny when AI is disabled")
    }

    func denyWhenVisualExpressionDisabled() {
        let candidate = makeCandidate()
        let ctx = makeContext(isAIEnabled: true, isVisualExpressionEnabled: false)
        let decision = policy.evaluate(candidate, context: ctx)

        expect(decision == .deny(reason: .visualExpressionDisabled, userFacingText: "AI 视觉表达未开启"),
               "should deny when visual expression is disabled")
    }

    func denyAutonomousInQuietMode() {
        let candidate = makeCandidate(source: .chat)
        let ctx = makeContext(isQuietMode: true)
        let decision = policy.evaluate(candidate, context: ctx)

        expect(decision == .deny(reason: .quietMode, userFacingText: "安静模式下不会主动变化"),
               "should deny autonomous action in quiet mode")
    }

    func allowUserRequestInQuietMode() {
        let candidate = makeCandidate(source: .userRequest)
        let ctx = makeContext(isQuietMode: true, hasPreviousVisualAction: true)
        let decision = policy.evaluate(candidate, context: ctx)

        if case .allow = decision {
            // expected
        } else {
            expect(false, "user request should be allowed in quiet mode (after first trigger)")
        }
    }

    func denyBubbleSourceWhenBubbleDisabled() {
        let candidate = makeCandidate(source: .smartBubble)
        let ctx = makeContext(isBubbleEnabled: false)
        let decision = policy.evaluate(candidate, context: ctx)

        expect(decision == .deny(reason: .bubbleDisabled, userFacingText: "气泡未开启"),
               "should deny smartBubble source when bubble is disabled")
    }

    func allowBubbleSourceWhenBubbleEnabled() {
        let candidate = makeCandidate(source: .smartBubble)
        let ctx = makeContext(isBubbleEnabled: true, hasPreviousVisualAction: true)
        let decision = policy.evaluate(candidate, context: ctx)

        if case .allow = decision {
            // expected
        } else {
            expect(false, "smartBubble source should be allowed when bubble is enabled")
        }
    }

    func denyKindNotPhase1Allowed() {
        let themeCandidate = makeCandidate(kind: .theme)
        let sceneCandidate = makeCandidate(kind: .scene)
        let ctx = makeContext()

        let themeDecision = policy.evaluate(themeCandidate, context: ctx)
        expect(themeDecision == .deny(reason: .kindNotAllowed, userFacingText: "当前阶段不支持「theme」类型的变化"),
               "should deny theme kind in Phase 1")

        let sceneDecision = policy.evaluate(sceneCandidate, context: ctx)
        expect(sceneDecision == .deny(reason: .kindNotAllowed, userFacingText: "当前阶段不支持「scene」类型的变化"),
               "should deny scene kind in Phase 1")
    }

    func denyWhenActiveOverlay() {
        let candidate = makeCandidate()
        let ctx = makeContext(hasActiveOverlay: true)
        let decision = policy.evaluate(candidate, context: ctx)

        expect(decision == .deny(reason: .generationInProgress, userFacingText: nil),
               "should deny when there is an active overlay")
    }

    func needsConfirmationOnFirstTrigger() {
        let candidate = makeCandidate()
        let ctx = makeContext(hasPreviousVisualAction: false)
        let decision = policy.evaluate(candidate, context: ctx)

        if case .needsConfirmation(let c, reason: .firstTrigger) = decision {
            expect(c.id == candidate.id, "should return same candidate")
        } else {
            expect(false, "first trigger should require confirmation")
        }
    }

    func needsConfirmationForHighImpact() {
        let candidate = makeCandidate(impact: .high)
        let ctx = makeContext(hasPreviousVisualAction: true)
        let decision = policy.evaluate(candidate, context: ctx)

        if case .needsConfirmation(_, reason: .highImpact) = decision {
            // expected
        } else {
            expect(false, "high impact should require confirmation")
        }
    }

    func allowLowImpactAfterFirstTrigger() {
        let candidate = makeCandidate(impact: .low)
        let ctx = makeContext(hasPreviousVisualAction: true)
        let decision = policy.evaluate(candidate, context: ctx)

        if case .allow(let c) = decision {
            expect(c.id == candidate.id, "should return same candidate")
        } else {
            expect(false, "low impact after first trigger should be allowed")
        }
    }

    func denyTakesPrecedenceOverConfirmation() {
        let candidate = makeCandidate(impact: .high)
        let ctx = makeContext(isAIEnabled: false)
        let decision = policy.evaluate(candidate, context: ctx)

        expect(decision == .deny(reason: .aiDisabled, userFacingText: "AI 功能未开启"),
               "hard deny should take precedence over confirmation")
    }

    func policyIsStateless() {
        let candidate = makeCandidate()
        let ctx1 = makeContext(hasPreviousVisualAction: false)
        let ctx2 = makeContext(hasPreviousVisualAction: true)

        let decision1 = policy.evaluate(candidate, context: ctx1)
        let decision2 = policy.evaluate(candidate, context: ctx2)

        if case .needsConfirmation = decision1 {
            // expected
        } else {
            expect(false, "first call should need confirmation")
        }

        if case .allow = decision2 {
            // expected
        } else {
            expect(false, "second call with hasPrevious should allow")
        }
    }

    func allowAutonomousWhenNotQuietMode() {
        let candidate = makeCandidate(source: .chat)
        let ctx = makeContext(isQuietMode: false, hasPreviousVisualAction: true)
        let decision = policy.evaluate(candidate, context: ctx)

        if case .allow = decision {
            // expected
        } else {
            expect(false, "chat source should be allowed when not in quiet mode")
        }
    }

    private func makeCandidate(
        source: AIVisualActionSource = .chat,
        kind: AIVisualActionKind = .expression,
        impact: AIVisualActionImpact = .low
    ) -> AIVisualActionCandidate {
        AIVisualActionCandidate(
            id: "action-1",
            petId: "pet-1",
            source: source,
            kind: kind,
            description: "happy face",
            renderMode: .replaceWholeImage,
            requestedDurationSeconds: 60,
            impact: impact
        )
    }

    private func makeContext(
        isAIEnabled: Bool = true,
        isVisualExpressionEnabled: Bool = true,
        isQuietMode: Bool = false,
        isBubbleEnabled: Bool = true,
        hasActiveOverlay: Bool = false,
        hasPreviousVisualAction: Bool = false
    ) -> AIVisualActionContext {
        AIVisualActionContext(
            isAIEnabled: isAIEnabled,
            isVisualExpressionEnabled: isVisualExpressionEnabled,
            isQuietMode: isQuietMode,
            isBubbleEnabled: isBubbleEnabled,
            petId: "pet-1",
            petName: "Mimi",
            hasActiveOverlay: hasActiveOverlay,
            hasPreviousVisualAction: hasPreviousVisualAction
        )
    }
}
