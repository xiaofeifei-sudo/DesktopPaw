import Foundation

/// 描述 idle 期间随机调度的抽样空间。
///
/// 候选构成以 action catalog 为准，而不是固定状态集合。
/// 有语义 role 的旧包会排除 idle/sleeping/dragging 这类不适合作为 ambient 行为的动作；
/// 没有 role 的自定义/Petdex 动作会直接进入抽样池。
public struct IdleBehaviorPool: Equatable, Sendable {
    public let candidates: [Action]

    public var isEmpty: Bool {
        candidates.isEmpty
    }

    public init(candidates: [Action]) {
        self.candidates = candidates
    }

    /// 从 catalog 派生 idle 行为池。
    public static func from(catalog: PetActionCatalog) -> IdleBehaviorPool {
        IdleBehaviorPool(candidates: catalog.ambientActions)
    }
}
