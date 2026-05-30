public enum ActionFallbackChain {
    public static let chain: [ActionRole: [ActionRole]] = [
        .walking: [.idle],
        .sleeping: [.idle],
        .happy: [.idle],
        .eating: [.happy, .idle],
        .jumping: [.happy, .idle]
    ]
}

public protocol ActionFallbackResolving: Sendable {
    func resolve(role: ActionRole, in catalog: PetActionCatalog) -> Action?
}

public struct DefaultActionFallbackResolver: ActionFallbackResolving {
    public init() {}

    public func resolve(role: ActionRole, in catalog: PetActionCatalog) -> Action? {
        if let direct = catalog.actions(for: role).first {
            return direct
        }
        guard let fallbackOrder = ActionFallbackChain.chain[role] else {
            return nil
        }
        for candidate in fallbackOrder {
            if let action = catalog.actions(for: candidate).first {
                return action
            }
        }
        return nil
    }
}
