import Foundation

/// 描述一次 idle 行为调度时所处的上下文。
///
/// Phase 1 的 `UniformIdleBehaviorScheduler` 不消费上下文中的字段，
/// 但 `mood` 与 `pendingAfterTag` 会在 Phase 3 的加权 / Tag 条件调度器中使用。
public struct IdleScheduleContext: Equatable, Sendable {
    /// 调度发生时刻。
    public let now: Date
    /// 当前情绪值（Phase 3 使用，Phase 1 调度器忽略）。
    public let mood: Double
    /// 上一动作触发的 `after.*` Tag（Phase 3 使用，Phase 1 调度器忽略）。
    public let pendingAfterTag: ActionTag?
    /// 调度开始时已经快照好的情绪等级；为 nil 时由加权调度器从 mood 推导。
    public let moodLevel: MoodLevel?
    /// 调度开始时已经快照好的时段集合；为 nil 时由加权调度器从 now 推导。
    public let timeSlots: Set<TimeSlot>?

    public init(
        now: Date,
        mood: Double,
        pendingAfterTag: ActionTag? = nil,
        moodLevel: MoodLevel? = nil,
        timeSlots: Set<TimeSlot>? = nil
    ) {
        self.now = now
        self.mood = mood
        self.pendingAfterTag = pendingAfterTag
        self.moodLevel = moodLevel
        self.timeSlots = timeSlots
    }
}
