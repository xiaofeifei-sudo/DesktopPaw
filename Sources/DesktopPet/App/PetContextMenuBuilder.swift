@preconcurrency import AppKit

@MainActor
public protocol PetContextMenuBuilding {
    func buildMenu<TriggerResult>(
        catalog: PetActionCatalog,
        eligibility: @escaping (ActionId) -> ActionTriggerEligibility,
        trigger: @escaping (ActionId) -> TriggerResult
    ) -> NSMenu

    func buildMenu(
        catalog: PetActionCatalog,
        triggerService: ActionTriggerServicing
    ) -> NSMenu
}

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
