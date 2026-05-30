import Foundation

/// idle 行为抽样策略协议。
///
/// 实现需保证：调用 `nextAction(in:context:)` 不修改 `pool`、`context` 或任何外部状态；
/// 抽样结果只取决于实现自身持有的 RNG 与传入参数。
///
/// Phase 1 默认实现是 `UniformIdleBehaviorScheduler`（等概率）；
/// Phase 3 默认实现切换为 `WeightedIdleBehaviorScheduler`。
///
/// 协议本身不约束 `Sendable`，因为实现通常需要持有 `RandomNumberGenerating`，
/// 而后者是引用语义且当前未标注 `Sendable`。调用方在跨 actor 共享时需自行使用
/// `@unchecked Sendable` 或 actor 隔离来保证安全。
public protocol IdleBehaviorScheduling: AnyObject {
    func nextAction(
        in pool: IdleBehaviorPool,
        context: IdleScheduleContext
    ) -> Action?
}
