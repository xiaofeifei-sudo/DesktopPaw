import Foundation

public enum AIVisualCoordinatorEvent: Sendable, Equatable {
    case policyDenied(actionId: String, reason: AIVisualDenyReason)
    case confirmationRequested(actionId: String, request: AIVisualConfirmationRequest)
    case confirmed(actionId: String)
    case rejected(actionId: String)
    case readyForGeneration(actionId: String, candidate: AIVisualActionCandidate)
}

public final class AIVisualActionCoordinator: @unchecked Sendable {
    private let policy: AIVisualActionPolicyEvaluating
    private let confirmationController: AIVisualConfirmationControlling
    private let quotaStore: AIVisualQuotaStoring?
    private let rateLimiter: AIVisualRateLimiting?
    private let lock = NSLock()
    public var onEvent: (@Sendable (AIVisualCoordinatorEvent) -> Void)?

    public init(
        policy: AIVisualActionPolicyEvaluating,
        confirmationController: AIVisualConfirmationControlling,
        quotaStore: AIVisualQuotaStoring? = nil,
        rateLimiter: AIVisualRateLimiting? = nil
    ) {
        self.policy = policy
        self.confirmationController = confirmationController
        self.quotaStore = quotaStore
        self.rateLimiter = rateLimiter
    }

    public func processCandidate(
        _ candidate: AIVisualActionCandidate,
        context: AIVisualActionContext
    ) -> AIVisualActionDecision {
        let decision = policy.evaluate(candidate, context: context)

        switch decision {
        case .allow:
            onEvent?(.readyForGeneration(actionId: candidate.id, candidate: candidate))

        case .needsConfirmation(let c, let reason):
            let request = confirmationController.createRequest(for: c, reason: reason)
            onEvent?(.confirmationRequested(actionId: c.id, request: request))

        case .deny(let reason, _):
            onEvent?(.policyDenied(actionId: candidate.id, reason: reason))

        case .throttled:
            onEvent?(.policyDenied(actionId: candidate.id, reason: .rateLimited))
        }

        return decision
    }

    public func confirmAction(_ requestId: String) -> Result<AIVisualActionCandidate, AIVisualActionError> {
        guard let candidate = confirmationController.confirm(requestId) else {
            return .failure(.invalidCandidate(reason: "No pending confirmation for id: \(requestId)"))
        }
        onEvent?(.confirmed(actionId: candidate.id))
        onEvent?(.readyForGeneration(actionId: candidate.id, candidate: candidate))
        return .success(candidate)
    }

    public func rejectAction(_ requestId: String) {
        if let request = confirmationController.pendingRequest(for: requestId) {
            onEvent?(.rejected(actionId: request.candidate.id))
        }
        confirmationController.reject(requestId)
    }

    public func buildContext(
        isAIEnabled: Bool,
        isVisualExpressionEnabled: Bool,
        isQuietMode: Bool,
        isBubbleEnabled: Bool,
        petId: String,
        petName: String,
        petDescriptor: String? = nil,
        hasActiveOverlay: Bool = false,
        now: Date = Date(),
        preferredThemes: Set<AIVisualThemePreference> = [],
        dislikedContent: Set<AIVisualDislikedContent> = [],
        activeFavoriteId: String? = nil
    ) -> AIVisualActionContext {
        var isQuotaExceeded = false
        var rateLimitResetAt: Date?

        if let quotaStore = quotaStore {
            let snapshot = quotaStore.loadUsage(petId: petId, date: now)
            isQuotaExceeded = snapshot.dailyTotalCount >= quotaStore.config.dailyTotalLimit
                || snapshot.monthlyTotalCount >= quotaStore.config.monthlyTotalLimit
        }

        if let rateLimiter = rateLimiter {
            rateLimitResetAt = rateLimiter.nextAllowedTime(source: .chat, at: now)
        }

        return AIVisualActionContext(
            isAIEnabled: isAIEnabled,
            isVisualExpressionEnabled: isVisualExpressionEnabled,
            isQuietMode: isQuietMode,
            isBubbleEnabled: isBubbleEnabled,
            petId: petId,
            petName: petName,
            petDescriptor: petDescriptor,
            hasActiveOverlay: hasActiveOverlay,
            hasPreviousVisualAction: confirmationController.hasPreviousConfirmation,
            isQuotaExceeded: isQuotaExceeded,
            rateLimitResetAt: rateLimitResetAt,
            preferredThemes: preferredThemes,
            dislikedContent: dislikedContent,
            activeFavoriteId: activeFavoriteId
        )
    }
}
