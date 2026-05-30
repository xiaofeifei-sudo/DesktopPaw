import Foundation

public enum ActionTriggerEligibility: Equatable {
    case allowed
    case rejectedBusy(reason: String)
    case rejectedThrottled
    case rejectedUnknownActionId
}

@MainActor
public protocol ActionTriggerServicing: AnyObject {
    var onTriggerRejected: ((ActionId, ActionTriggerEligibility) -> Void)? { get set }

    func eligibility(for actionId: ActionId) -> ActionTriggerEligibility

    @discardableResult
    func trigger(actionId: ActionId) -> ActionTriggerEligibility
}

@MainActor
public final class ActionTriggerService: ActionTriggerServicing {
    public static let busyReason = "宠物正忙，稍后再试"

    private let commandHandler: PetCommandHandling
    private let now: () -> Date
    private let throttleInterval: TimeInterval
    private var lastTriggeredAt: Date?

    public var onTriggerRejected: ((ActionId, ActionTriggerEligibility) -> Void)?

    public init(
        commandHandler: PetCommandHandling,
        throttleInterval: TimeInterval = 1.0,
        now: @escaping () -> Date = { Date() }
    ) {
        self.commandHandler = commandHandler
        self.throttleInterval = throttleInterval
        self.now = now
    }

    public func eligibility(for actionId: ActionId) -> ActionTriggerEligibility {
        eligibility(for: actionId, at: now())
    }

    @discardableResult
    public func trigger(actionId: ActionId) -> ActionTriggerEligibility {
        let date = now()
        let result = eligibility(for: actionId, at: date)

        switch result {
        case .allowed:
            lastTriggeredAt = date
            commandHandler.playAction(actionId)
        case .rejectedBusy, .rejectedThrottled, .rejectedUnknownActionId:
            onTriggerRejected?(actionId, result)
        }

        return result
    }

    private func eligibility(for actionId: ActionId, at date: Date) -> ActionTriggerEligibility {
        guard commandHandler.catalog.resolve(actionId: actionId) != nil else {
            return .rejectedUnknownActionId
        }

        if let lastTriggeredAt, date.timeIntervalSince(lastTriggeredAt) < throttleInterval {
            return .rejectedThrottled
        }

        let state = commandHandler.runtimeState
        if state.isDragging {
            return .rejectedBusy(reason: Self.busyReason)
        }

        switch state.currentState {
        case .sleeping, .dragging:
            return .rejectedBusy(reason: Self.busyReason)
        case .idle, .walking, .happy, .eating, .jumping:
            return .allowed
        }
    }
}
