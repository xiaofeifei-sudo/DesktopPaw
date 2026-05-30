import Foundation
import DesktopPet

@MainActor
func runAIVisualActionDomainTests() {
    let tests = AIVisualActionDomainTests()
    tests.actionKindRawValues()
    tests.actionKindPhase1Allowed()
    tests.actionKindPhase1Restricted()
    tests.actionSourceRawValues()
    tests.actionImpactRawValues()
    tests.renderModeRawValues()
    tests.candidateInitClampsDurationToMin()
    tests.candidateInitClampsDurationToMax()
    tests.candidateInitKeepsValidDuration()
    tests.candidateIsCodable()
    tests.candidateIsEquatable()
    tests.candidateWithDifferentIdNotEqual()
    tests.contextIsCodable()
    tests.contextIsEquatable()
    tests.decisionAllowEquality()
    tests.decisionDenyEquality()
    tests.decisionNeedsConfirmationEquality()
    tests.decisionThrottledEquality()
    tests.confirmationReasonRawValues()
    tests.denyReasonRawValues()
    tests.errorEquality()
    tests.clampDurationStaticMethod()
    tests.candidateDefaultCreatedAt()
}

@MainActor
private struct AIVisualActionDomainTests {
    func actionKindRawValues() {
        expect(AIVisualActionKind.expression.rawValue == "expression", "expression rawValue")
        expect(AIVisualActionKind.pose.rawValue == "pose", "pose rawValue")
        expect(AIVisualActionKind.accessory.rawValue == "accessory", "accessory rawValue")
        expect(AIVisualActionKind.ambience.rawValue == "ambience", "ambience rawValue")
        expect(AIVisualActionKind.theme.rawValue == "theme", "theme rawValue")
        expect(AIVisualActionKind.scene.rawValue == "scene", "scene rawValue")
    }

    func actionKindPhase1Allowed() {
        expect(AIVisualActionKind.expression.isPhase1Allowed, "expression should be Phase 1 allowed")
        expect(AIVisualActionKind.pose.isPhase1Allowed, "pose should be Phase 1 allowed")
        expect(AIVisualActionKind.accessory.isPhase1Allowed, "accessory should be Phase 1 allowed")
        expect(AIVisualActionKind.ambience.isPhase1Allowed, "ambience should be Phase 1 allowed")
    }

    func actionKindPhase1Restricted() {
        expect(!AIVisualActionKind.theme.isPhase1Allowed, "theme should not be Phase 1 allowed")
        expect(!AIVisualActionKind.scene.isPhase1Allowed, "scene should not be Phase 1 allowed")
    }

    func actionSourceRawValues() {
        expect(AIVisualActionSource.chat.rawValue == "chat", "chat rawValue")
        expect(AIVisualActionSource.smartBubble.rawValue == "smartBubble", "smartBubble rawValue")
        expect(AIVisualActionSource.relationshipEvent.rawValue == "relationshipEvent", "relationshipEvent rawValue")
        expect(AIVisualActionSource.userRequest.rawValue == "userRequest", "userRequest rawValue")
    }

    func actionImpactRawValues() {
        expect(AIVisualActionImpact.low.rawValue == "low", "low rawValue")
        expect(AIVisualActionImpact.medium.rawValue == "medium", "medium rawValue")
        expect(AIVisualActionImpact.high.rawValue == "high", "high rawValue")
    }

    func renderModeRawValues() {
        expect(PetVisualRenderMode.replaceWholeImage.rawValue == "replaceWholeImage", "replaceWholeImage rawValue")
        expect(PetVisualRenderMode.overlayImage.rawValue == "overlayImage", "overlayImage rawValue")
    }

    func candidateInitClampsDurationToMin() {
        let candidate = makeCandidate(duration: 5)
        expect(candidate.requestedDurationSeconds == AIVisualActionCandidate.minDurationSeconds,
               "duration below min should be clamped to \(AIVisualActionCandidate.minDurationSeconds)")
    }

    func candidateInitClampsDurationToMax() {
        let candidate = makeCandidate(duration: 9999)
        expect(candidate.requestedDurationSeconds == AIVisualActionCandidate.maxDurationSeconds,
               "duration above max should be clamped to \(AIVisualActionCandidate.maxDurationSeconds)")
    }

    func candidateInitKeepsValidDuration() {
        let candidate = makeCandidate(duration: 120)
        expect(candidate.requestedDurationSeconds == 120, "valid duration should not be clamped")
    }

    func candidateIsCodable() {
        let candidate = makeCandidate(duration: 60)
        let encoder = JSONEncoder()
        let data = try! encoder.encode(candidate)
        let decoder = JSONDecoder()
        let decoded = try! decoder.decode(AIVisualActionCandidate.self, from: data)
        expect(decoded == candidate, "decoded candidate should equal original")
    }

    func candidateIsEquatable() {
        let now = Date()
        let a = makeCandidate(id: "1", duration: 60, createdAt: now)
        let b = makeCandidate(id: "1", duration: 60, createdAt: now)
        expect(a == b, "candidates with same values should be equal")
    }

    func candidateWithDifferentIdNotEqual() {
        let a = makeCandidate(id: "1", duration: 60)
        let b = makeCandidate(id: "2", duration: 60)
        expect(a != b, "candidates with different ids should not be equal")
    }

    func contextIsCodable() {
        let ctx = AIVisualActionContext(
            isAIEnabled: true,
            isVisualExpressionEnabled: false,
            isQuietMode: false,
            isBubbleEnabled: true,
            petId: "pet-1",
            petName: "Mimi",
            petDescriptor: "A cute cat",
            hasActiveOverlay: false
        )
        let encoder = JSONEncoder()
        let data = try! encoder.encode(ctx)
        let decoder = JSONDecoder()
        let decoded = try! decoder.decode(AIVisualActionContext.self, from: data)
        expect(decoded == ctx, "decoded context should equal original")
    }

    func contextIsEquatable() {
        let a = AIVisualActionContext(
            isAIEnabled: true, isVisualExpressionEnabled: false,
            isQuietMode: false, isBubbleEnabled: true,
            petId: "p1", petName: "Mimi"
        )
        let b = AIVisualActionContext(
            isAIEnabled: true, isVisualExpressionEnabled: false,
            isQuietMode: false, isBubbleEnabled: true,
            petId: "p1", petName: "Mimi"
        )
        expect(a == b, "identical contexts should be equal")
    }

    func decisionAllowEquality() {
        let candidate = makeCandidate(duration: 60)
        let a: AIVisualActionDecision = .allow(candidate)
        let b: AIVisualActionDecision = .allow(candidate)
        expect(a == b, ".allow decisions with same candidate should be equal")
    }

    func decisionDenyEquality() {
        let a: AIVisualActionDecision = .deny(reason: .aiDisabled, userFacingText: nil)
        let b: AIVisualActionDecision = .deny(reason: .aiDisabled, userFacingText: nil)
        expect(a == b, ".deny decisions with same reason should be equal")
    }

    func decisionNeedsConfirmationEquality() {
        let candidate = makeCandidate(duration: 60)
        let a: AIVisualActionDecision = .needsConfirmation(candidate, reason: .firstTrigger)
        let b: AIVisualActionDecision = .needsConfirmation(candidate, reason: .firstTrigger)
        expect(a == b, ".needsConfirmation with same values should be equal")
    }

    func decisionThrottledEquality() {
        let date = Date(timeIntervalSince1970: 1000)
        let a: AIVisualActionDecision = .throttled(until: date, userFacingText: "wait")
        let b: AIVisualActionDecision = .throttled(until: date, userFacingText: "wait")
        expect(a == b, ".throttled with same values should be equal")
    }

    func confirmationReasonRawValues() {
        expect(AIVisualConfirmationReason.firstTrigger.rawValue == "firstTrigger", "firstTrigger rawValue")
        expect(AIVisualConfirmationReason.highImpact.rawValue == "highImpact", "highImpact rawValue")
        expect(AIVisualConfirmationReason.sceneOrTheme.rawValue == "sceneOrTheme", "sceneOrTheme rawValue")
        expect(AIVisualConfirmationReason.userRequest.rawValue == "userRequest", "userRequest rawValue")
    }

    func denyReasonRawValues() {
        expect(AIVisualDenyReason.aiDisabled.rawValue == "aiDisabled", "aiDisabled rawValue")
        expect(AIVisualDenyReason.visualExpressionDisabled.rawValue == "visualExpressionDisabled", "visualExpressionDisabled rawValue")
        expect(AIVisualDenyReason.quietMode.rawValue == "quietMode", "quietMode rawValue")
        expect(AIVisualDenyReason.bubbleDisabled.rawValue == "bubbleDisabled", "bubbleDisabled rawValue")
        expect(AIVisualDenyReason.quotaExceeded.rawValue == "quotaExceeded", "quotaExceeded rawValue")
        expect(AIVisualDenyReason.rateLimited.rawValue == "rateLimited", "rateLimited rawValue")
        expect(AIVisualDenyReason.safetyRejected.rawValue == "safetyRejected", "safetyRejected rawValue")
        expect(AIVisualDenyReason.generationInProgress.rawValue == "generationInProgress", "generationInProgress rawValue")
        expect(AIVisualDenyReason.kindNotAllowed.rawValue == "kindNotAllowed", "kindNotAllowed rawValue")
    }

    func errorEquality() {
        let a = AIVisualActionError.aiDisabled
        let b = AIVisualActionError.aiDisabled
        expect(a == b, "same errors should be equal")

        let c = AIVisualActionError.quotaExceeded
        expect(a != c, "different errors should not be equal")

        let d = AIVisualActionError.safetyRejected(reason: "test")
        let e = AIVisualActionError.safetyRejected(reason: "test")
        expect(d == e, "errors with same associated values should be equal")
    }

    func clampDurationStaticMethod() {
        expect(AIVisualActionCandidate.clampDuration(0) == AIVisualActionCandidate.minDurationSeconds,
               "clamp 0 should return min")
        expect(AIVisualActionCandidate.clampDuration(100) == 100,
               "clamp 100 should return 100")
        expect(AIVisualActionCandidate.clampDuration(9999) == AIVisualActionCandidate.maxDurationSeconds,
               "clamp 9999 should return max")
    }

    func candidateDefaultCreatedAt() {
        let before = Date()
        let candidate = makeCandidate(duration: 60)
        let after = Date()
        expect(candidate.createdAt >= before && candidate.createdAt <= after,
               "createdAt should default to now")
    }

    private func makeCandidate(
        id: String = "action-1",
        duration: TimeInterval,
        createdAt: Date = Date()
    ) -> AIVisualActionCandidate {
        AIVisualActionCandidate(
            id: id,
            petId: "pet-1",
            source: .chat,
            kind: .expression,
            description: "happy face",
            renderMode: .replaceWholeImage,
            requestedDurationSeconds: duration,
            impact: .low,
            createdAt: createdAt
        )
    }
}
