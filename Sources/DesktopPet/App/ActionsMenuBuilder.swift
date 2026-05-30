@preconcurrency import AppKit

@MainActor
public protocol ActionsMenuBuilding {
    func buildMenu<TriggerResult>(
        catalog: PetActionCatalog,
        eligibility: @escaping (ActionId) -> ActionTriggerEligibility,
        trigger: @escaping (ActionId) -> TriggerResult
    ) -> NSMenu
}

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

        for action in submenuBuilder.visibleActions(from: actions) {
            menu.addItem(Self.menuItem(for: action, eligibility: eligibility, trigger: trigger))
        }

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
        item.isEnabled = eligibility(action.id) == .allowed
        return item
    }

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

@MainActor
public struct MoreSubmenuBuilder {
    public static let maximumVisibleActions = 12

    public init() {}

    public func visibleActions(from actions: [Action]) -> [Action] {
        Array(actions.prefix(Self.maximumVisibleActions))
    }

    public func overflowActions(from actions: [Action]) -> [Action] {
        guard actions.count > Self.maximumVisibleActions else {
            return []
        }
        return Array(actions.dropFirst(Self.maximumVisibleActions))
    }
}

@MainActor
public final class ActionsMenuItemTrigger: NSObject {
    public let actionId: ActionId
    private let triggerAction: (ActionId) -> Void

    public init(actionId: ActionId, trigger: @escaping (ActionId) -> Void) {
        self.actionId = actionId
        self.triggerAction = trigger
    }

    public func trigger() {
        triggerAction(actionId)
    }

    @objc public func executeAction(_ sender: NSMenuItem) {
        trigger()
    }
}
