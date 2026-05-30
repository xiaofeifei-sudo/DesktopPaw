public struct PetActionCatalog: Equatable, Sendable {
    public let petId: String
    public let actions: [Action]
    public let actionsById: [ActionId: Action]
    public let actionsByRole: [ActionRole: [Action]]
    public let extras: [Action]
    public let warnings: [ActionImportWarning]

    public init(petId: String, actions: [Action], warnings: [ActionImportWarning]) {
        self.petId = petId
        self.actions = actions
        self.warnings = warnings

        var byId: [ActionId: Action] = [:]
        var byRole: [ActionRole: [Action]] = [:]
        var extras: [Action] = []
        for action in actions {
            byId[action.id] = action
            if let role = action.role {
                byRole[role, default: []].append(action)
            } else {
                extras.append(action)
            }
        }
        self.actionsById = byId
        self.actionsByRole = byRole
        self.extras = extras
    }

    public func resolve(actionId: ActionId) -> Action? {
        actionsById[actionId]
    }

    public func actions(for role: ActionRole) -> [Action] {
        actionsByRole[role] ?? []
    }

    public func extras(matching tag: ActionTag) -> [Action] {
        extras.filter { $0.tags.contains(tag) }
    }

    public var defaultAction: Action? {
        actions(for: .idle).first
            ?? actions.first(where: { $0.loop })
            ?? actions.first
    }

    public var ambientActions: [Action] {
        let defaultActionId = defaultAction?.id
        let candidates = actions.filter { action in
            guard action.id != defaultActionId else {
                return false
            }
            guard let role = action.role else {
                return true
            }
            return role != .sleeping && role != .dragging
        }
        if !candidates.isEmpty {
            return candidates
        }
        guard actions.allSatisfy({ $0.role == nil }) else {
            return []
        }
        return actions.filter { $0.id != defaultActionId }
    }

    public var interactionActions: [Action] {
        let defaultActionId = defaultAction?.id
        let candidates = actions.filter { action in
            guard action.id != defaultActionId else {
                return false
            }
            guard let role = action.role else {
                return true
            }
            return role != .idle && role != .sleeping && role != .dragging
        }
        return candidates.isEmpty ? ambientActions : candidates
    }
}
