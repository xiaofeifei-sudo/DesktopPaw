import Foundation

/// 动作触发资格判定结果
public enum ActionTriggerEligibility: Equatable {
    /// 允许触发
    case allowed
    /// 拒绝：宠物正忙（如睡觉、拖拽中）
    case rejectedBusy(reason: String)
    /// 拒绝：触发太频繁（被节流）
    case rejectedThrottled
    /// 拒绝：未知动作 ID（目录中不存在）
    case rejectedUnknownActionId
}

/// 动作触发服务协议
///
/// 负责在触发动作之前检查资格（宠物状态、节流限制、动作有效性），
/// 并提供统一的触发入口。
@MainActor
public protocol ActionTriggerServicing: AnyObject {
    /// 当触发被拒绝时的回调
    var onTriggerRejected: ((ActionId, ActionTriggerEligibility) -> Void)? { get set }

    /// 查询指定动作的触发资格（不实际触发）
    func eligibility(for actionId: ActionId) -> ActionTriggerEligibility

    /// 尝试触发动作，返回结果
    @discardableResult
    func trigger(actionId: ActionId) -> ActionTriggerEligibility
}

/// 动作触发服务的默认实现
///
/// 规则：
/// - 动作 ID 必须在目录中存在
/// - 两次触发间隔不得短于 throttleInterval（默认 1 秒）
/// - 宠物处于 sleeping/dragging 状态时拒绝
@MainActor
public final class ActionTriggerService: ActionTriggerServicing {
    /// 忙状态拒绝原因文案
    public static let busyReason = "宠物正忙，稍后再试"

    /// 底层宠物命令处理器
    private let commandHandler: PetCommandHandling
    /// 当前时间获取闭包（便于测试注入）
    private let now: () -> Date
    /// 触发节流间隔
    private let throttleInterval: TimeInterval
    /// 上次触发时间
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

    // MARK: - 公共接口

    public func eligibility(for actionId: ActionId) -> ActionTriggerEligibility {
        eligibility(for: actionId, at: now())
    }

    @discardableResult
    public func trigger(actionId: ActionId) -> ActionTriggerEligibility {
        let date = now()
        let result = eligibility(for: actionId, at: date)

        switch result {
        case .allowed:
            // 记录触发时间，执行动作
            lastTriggeredAt = date
            commandHandler.playAction(actionId)
        case .rejectedBusy, .rejectedThrottled, .rejectedUnknownActionId:
            // 通知外部触发被拒绝
            onTriggerRejected?(actionId, result)
        }

        return result
    }

    // MARK: - 资格判定逻辑

    /// 核心资格检查：有效性 → 节流 → 状态
    private func eligibility(for actionId: ActionId, at date: Date) -> ActionTriggerEligibility {
        // 1. 动作 ID 有效性检查
        guard commandHandler.catalog.resolve(actionId: actionId) != nil else {
            return .rejectedUnknownActionId
        }

        // 2. 节流检查
        if let lastTriggeredAt, date.timeIntervalSince(lastTriggeredAt) < throttleInterval {
            return .rejectedThrottled
        }

        // 3. 状态检查
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
