@preconcurrency import AppKit

/// 宠物右键菜单构建器协议
///
/// 支持两种构建方式：
/// 1. 直接注入 eligibility/trigger 闭包（灵活、可测试）
/// 2. 注入 ActionTriggerServicing（便捷封装）
@MainActor
public protocol PetContextMenuBuilding {
    /// 使用闭包构建菜单
    func buildMenu<TriggerResult>(
        catalog: PetActionCatalog,
        eligibility: @escaping (ActionId) -> ActionTriggerEligibility,
        trigger: @escaping (ActionId) -> TriggerResult
    ) -> NSMenu

    /// 使用 ActionTriggerService 构建菜单（推荐）
    func buildMenu(
        catalog: PetActionCatalog,
        triggerService: ActionTriggerServicing
    ) -> NSMenu
}

/// 宠物右键菜单构建器默认实现
///
/// 内部委托给 ActionsMenuBuilder 完成实际菜单构建。
@MainActor
public final class PetContextMenuBuilder: PetContextMenuBuilding {
    private let actionsMenuBuilder: any ActionsMenuBuilding

    public init(actionsMenuBuilder: any ActionsMenuBuilding = ActionsMenuBuilder()) {
        self.actionsMenuBuilder = actionsMenuBuilder
    }

    public func buildMenu<TriggerResult>(
        catalog: PetActionCatalog,
        eligibility: @escaping (ActionId) -> ActionTriggerEligibility,
        trigger: @escaping (ActionId) -> TriggerResult
    ) -> NSMenu {
        actionsMenuBuilder.buildMenu(
            catalog: catalog,
            eligibility: eligibility,
            trigger: trigger
        )
    }

    /// 便捷方法：从 triggerService 自动提取 eligibility 和 trigger
    public func buildMenu(
        catalog: PetActionCatalog,
        triggerService: ActionTriggerServicing
    ) -> NSMenu {
        buildMenu(
            catalog: catalog,
            eligibility: { actionId in
                triggerService.eligibility(for: actionId)
            },
            trigger: { actionId in
                triggerService.trigger(actionId: actionId)
            }
        )
    }
}
