import Foundation

public protocol AIVisualActionPolicyEvaluating: Sendable {
    func evaluate(_ candidate: AIVisualActionCandidate, context: AIVisualActionContext) -> AIVisualActionDecision
}

public final class AIVisualActionPolicy: AIVisualActionPolicyEvaluating, Sendable {
    public init() {}

    public func evaluate(_ candidate: AIVisualActionCandidate, context: AIVisualActionContext) -> AIVisualActionDecision {
        if !context.isAIEnabled {
            return .deny(reason: .aiDisabled, userFacingText: "AI 功能未开启")
        }

        if !context.isVisualExpressionEnabled {
            return .deny(reason: .visualExpressionDisabled, userFacingText: "AI 视觉表达未开启")
        }

        if context.isQuietMode && candidate.source != .userRequest {
            return .deny(reason: .quietMode, userFacingText: "安静模式下不会主动变化")
        }

        if !context.isBubbleEnabled && candidate.source == .smartBubble {
            return .deny(reason: .bubbleDisabled, userFacingText: "气泡未开启")
        }

        if !candidate.kind.isPhase1Allowed {
            return .deny(reason: .kindNotAllowed, userFacingText: "当前阶段不支持「\(candidate.kind.rawValue)」类型的变化")
        }

        if context.isQuotaExceeded {
            return .deny(reason: .quotaExceeded, userFacingText: "今日的变化次数已用完")
        }

        if let resetAt = context.rateLimitResetAt {
            return .throttled(until: resetAt, userFacingText: "变化太频繁了，稍后再试")
        }

        if context.hasActiveOverlay {
            return .deny(reason: .generationInProgress, userFacingText: nil)
        }

        if !context.hasPreviousVisualAction {
            return .needsConfirmation(candidate, reason: .firstTrigger)
        }

        if candidate.impact == .high {
            return .needsConfirmation(candidate, reason: .highImpact)
        }

        return .allow(candidate)
    }
}
