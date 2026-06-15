@preconcurrency import AppKit

/// 动作菜单构建器协议
///
/// 将宠物动作目录转换为 macOS 原生 NSMenu，
/// 支持资格检查和触发回调注入。
@MainActor
public protocol ActionsMenuBuilding {
    func buildMenu<TriggerResult>(
        catalog: PetActionCatalog,
        eligibility: @escaping (ActionId) -> ActionTriggerEligibility,
        trigger: @escaping (ActionId) -> TriggerResult
    ) -> NSMenu
}

/// 动作菜单构建器默认实现
///
/// 按角色顺序排列动作（idle → walking → ... → dragging），
/// 超过最大显示数（12 个）的动作收入 "More" 子菜单。
@MainActor
public final class ActionsMenuBuilder: ActionsMenuBuilding {
    public init() {}

    public func buildMenu<TriggerResult>(
        catalog: PetActionCatalog,
        eligibility: @escaping (ActionId) -> ActionTriggerEligibility,
        trigger: @escaping (ActionId) -> TriggerResult
    ) -> NSMenu {
        let actions = Self.sortedActions(in: catalog)
        let menu = NSMenu(title: "Actions")
        let submenuBuilder = MoreSubmenuBuilder()

        // 先添加可见动作
        for action in submenuBuilder.visibleActions(from: actions) {
            menu.addItem(Self.menuItem(for: action, eligibility: eligibility, trigger: trigger))
        }

        // 溢出动作放入 "More" 子菜单
        let overflow = submenuBuilder.overflowActions(from: actions)
        if !overflow.isEmpty {
            let moreItem = NSMenuItem(title: "More", action: nil, keyEquivalent: "")
            let moreMenu = NSMenu(title: "More")
            for action in overflow {
                moreMenu.addItem(Self.menuItem(for: action, eligibility: eligibility, trigger: trigger))
            }
            moreItem.submenu = moreMenu
            menu.addItem(moreItem)
        }

        return menu
    }

    // MARK: - 排序与菜单项构建

    /// 按角色优先级排序，角色外的 extras 按名称字母序
    private static func sortedActions(in catalog: PetActionCatalog) -> [Action] {
        let roleActions = roleOrder.flatMap { catalog.actions(for: $0) }
        let extraActions = catalog.extras.sorted { lhs, rhs in
            if lhs.displayName == rhs.displayName {
                return lhs.id.rawValue < rhs.id.rawValue
            }
            return lhs.displayName < rhs.displayName
        }
        return roleActions + extraActions
    }

    /// 构建单个动作菜单项，绑定触发 handler
    private static func menuItem<TriggerResult>(
        for action: Action,
        eligibility: (ActionId) -> ActionTriggerEligibility,
        trigger: @escaping (ActionId) -> TriggerResult
    ) -> NSMenuItem {
        let handler = ActionsMenuItemTrigger(actionId: action.id) { actionId in
            _ = trigger(actionId)
        }
        let item = NSMenuItem(
            title: action.displayName,
            action: #selector(ActionsMenuItemTrigger.executeAction(_:)),
            keyEquivalent: ""
        )
        item.target = handler
        item.representedObject = handler
        // 仅允许的动作可点击
        item.isEnabled = eligibility(action.id) == .allowed
        return item
    }

    /// 菜单中的角色排列顺序
    private static let roleOrder: [ActionRole] = [
        .idle,
        .walking,
        .sleeping,
        .happy,
        .eating,
        .jumping,
        .dragging
    ]
}

/// "More" 子菜单拆分策略
///
/// 当动作数量超过 maximumVisibleActions 时，
/// 超出的部分被放入 "More" → 子菜单。
@MainActor
public struct MoreSubmenuBuilder {
    /// 一级菜单最多显示的动作数
    public static let maximumVisibleActions = 12

    public init() {}

    /// 取前 N 个可见动作
    public func visibleActions(from actions: [Action]) -> [Action] {
        Array(actions.prefix(Self.maximumVisibleActions))
    }

    /// 超出部分的溢出动作
    public func overflowActions(from actions: [Action]) -> [Action] {
        guard actions.count > Self.maximumVisibleActions else {
            return []
        }
        return Array(actions.dropFirst(Self.maximumVisibleActions))
    }
}

/// 动作菜单项的触发 handler
///
/// 遵循 NSObject 以支持 NSMenuItem 的 action/target 机制。
@MainActor
public final class ActionsMenuItemTrigger: NSObject {
    /// 关联的动作 ID
    public let actionId: ActionId
    /// 实际触发闭包
    private let triggerAction: (ActionId) -> Void

    public init(actionId: ActionId, trigger: @escaping (ActionId) -> Void) {
        self.actionId = actionId
        self.triggerAction = trigger
    }

    public func trigger() {
        triggerAction(actionId)
    }

    /// NSMenuItem 的 action selector 入口
    @objc public func executeAction(_ sender: NSMenuItem) {
        trigger()
    }
}
