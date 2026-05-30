import Foundation

/// Phase 1 默认 idle 行为调度器：从池中等概率抽取一个候选。
///
/// 使用注入的 `RandomNumberGenerating` 在 `[0, 1]` 内取样，
/// 通过 `floor(value * count)` 映射到候选索引；越界值（罕见）会 clamp 到最后一个候选。
///
/// 抽样过程不修改 catalog / pool / context，也不持有调用方状态。
public final class UniformIdleBehaviorScheduler: IdleBehaviorScheduling {
    private let randomNumberGenerator: RandomNumberGenerating

    public init(randomNumberGenerator: RandomNumberGenerating) {
        self.randomNumberGenerator = randomNumberGenerator
    }

    public func nextAction(
        in pool: IdleBehaviorPool,
        context: IdleScheduleContext
    ) -> Action? {
        guard !pool.isEmpty else {
            return nil
        }
        let count = pool.candidates.count
        let value = randomNumberGenerator.nextDouble(in: 0...1)
        var index = Int((value * Double(count)).rounded(.down))
        if index < 0 {
            index = 0
        } else if index >= count {
            index = count - 1
        }
        return pool.candidates[index]
    }
}
