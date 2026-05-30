import Foundation

public protocol RelationshipServicing: Sendable {
    func handle(
        event: CompanionEvent,
        petId: String,
        context: RelationshipRuleContext
    ) throws -> RelationshipUpdate

    func snapshot(petId: String) throws -> RelationshipSnapshot
    func reset(petId: String) throws -> RelationshipSnapshot
}

public final class RelationshipService: RelationshipServicing, RelationshipProgressing, @unchecked Sendable {
    private let store: RelationshipStoring

    public init(store: RelationshipStoring) {
        self.store = store
    }

    public func apply(
        event: CompanionEvent,
        to state: RelationshipState,
        context: RelationshipRuleContext
    ) -> RelationshipUpdate {
        guard let rule = RelationshipRule.rule(for: event) else {
            return RelationshipUpdate(
                previousState: state,
                state: state,
                pointsAdded: 0,
                appliedRule: nil,
                levelChange: nil
            )
        }

        return rule.apply(event: event, to: state, context: context)
    }

    public func handle(
        event: CompanionEvent,
        petId: String,
        context: RelationshipRuleContext
    ) throws -> RelationshipUpdate {
        let state = try store.loadState(petId: petId)
        let update = apply(event: event, to: state, context: context)

        if update.state != state {
            try store.saveState(update.state, petId: petId)
        }

        return update
    }

    public func snapshot(petId: String) throws -> RelationshipSnapshot {
        try store.loadState(petId: petId).snapshot
    }

    public func reset(petId: String) throws -> RelationshipSnapshot {
        try store.resetState(petId: petId)
        return try snapshot(petId: petId)
    }
}
