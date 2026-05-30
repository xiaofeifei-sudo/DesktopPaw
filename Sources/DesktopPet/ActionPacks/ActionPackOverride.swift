import Foundation

public struct ActionPackActionOverride: Codable, Equatable, Sendable {
    public let actionId: ActionId
    public let disabled: Bool?
    public let displayName: String?
    public let tags: [ActionTag]?
    public let frameDurationsMs: [Int]?
    public let sortOrder: Int?

    public init(
        actionId: ActionId,
        disabled: Bool? = nil,
        displayName: String? = nil,
        tags: [ActionTag]? = nil,
        frameDurationsMs: [Int]? = nil,
        sortOrder: Int? = nil
    ) {
        self.actionId = actionId
        self.disabled = disabled
        self.displayName = displayName
        self.tags = tags
        self.frameDurationsMs = frameDurationsMs
        self.sortOrder = sortOrder
    }
}

public struct ActionPackOverrideSet: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1

    public let schemaVersion: Int
    public let petId: String
    public let disabledPackIds: [String]
    public let actionOverrides: [ActionPackActionOverride]

    public init(
        schemaVersion: Int = ActionPackOverrideSet.currentSchemaVersion,
        petId: String,
        disabledPackIds: [String] = [],
        actionOverrides: [ActionPackActionOverride] = []
    ) {
        self.schemaVersion = schemaVersion
        self.petId = petId
        self.disabledPackIds = disabledPackIds
        self.actionOverrides = actionOverrides
    }

    public func isPackDisabled(_ packId: String) -> Bool {
        disabledPackIds.contains(packId)
    }

    public func isActionDisabled(_ actionId: ActionId) -> Bool {
        actionOverrides.first(where: { $0.actionId == actionId })?.disabled == true
    }

    public func override(for actionId: ActionId) -> ActionPackActionOverride? {
        actionOverrides.first { $0.actionId == actionId }
    }

    public func displayNameOverride(for actionId: ActionId) -> String? {
        actionOverrides.first(where: { $0.actionId == actionId })?.displayName
    }

    public func tagsOverride(for actionId: ActionId) -> [ActionTag]? {
        actionOverrides.first(where: { $0.actionId == actionId })?.tags
    }

    public func frameDurationsOverride(for actionId: ActionId) -> [Int]? {
        actionOverrides.first(where: { $0.actionId == actionId })?.frameDurationsMs
    }

    public func sortOrderOverride(for actionId: ActionId) -> Int? {
        actionOverrides.first(where: { $0.actionId == actionId })?.sortOrder
    }

    // MARK: - Mutation Helpers

    public func disablingPack(_ packId: String) -> ActionPackOverrideSet {
        guard !disabledPackIds.contains(packId) else { return self }
        return ActionPackOverrideSet(
            schemaVersion: schemaVersion,
            petId: petId,
            disabledPackIds: disabledPackIds + [packId],
            actionOverrides: actionOverrides
        )
    }

    public func disablingAction(_ actionId: ActionId) -> ActionPackOverrideSet {
        if let index = actionOverrides.firstIndex(where: { $0.actionId == actionId }) {
            let existing = actionOverrides[index]
            let updated = ActionPackActionOverride(
                actionId: actionId,
                disabled: true,
                displayName: existing.displayName,
                tags: existing.tags,
                frameDurationsMs: existing.frameDurationsMs,
                sortOrder: existing.sortOrder
            )
            var newOverrides = actionOverrides
            newOverrides[index] = updated
            return ActionPackOverrideSet(
                schemaVersion: schemaVersion,
                petId: petId,
                disabledPackIds: disabledPackIds,
                actionOverrides: newOverrides
            )
        } else {
            let override = ActionPackActionOverride(actionId: actionId, disabled: true)
            return ActionPackOverrideSet(
                schemaVersion: schemaVersion,
                petId: petId,
                disabledPackIds: disabledPackIds,
                actionOverrides: actionOverrides + [override]
            )
        }
    }

    public func settingDisplayName(_ name: String, for actionId: ActionId) -> ActionPackOverrideSet {
        if let index = actionOverrides.firstIndex(where: { $0.actionId == actionId }) {
            let existing = actionOverrides[index]
            let updated = ActionPackActionOverride(
                actionId: actionId,
                disabled: existing.disabled,
                displayName: name,
                tags: existing.tags,
                frameDurationsMs: existing.frameDurationsMs,
                sortOrder: existing.sortOrder
            )
            var newOverrides = actionOverrides
            newOverrides[index] = updated
            return ActionPackOverrideSet(
                schemaVersion: schemaVersion,
                petId: petId,
                disabledPackIds: disabledPackIds,
                actionOverrides: newOverrides
            )
        } else {
            let override = ActionPackActionOverride(actionId: actionId, displayName: name)
            return ActionPackOverrideSet(
                schemaVersion: schemaVersion,
                petId: petId,
                disabledPackIds: disabledPackIds,
                actionOverrides: actionOverrides + [override]
            )
        }
    }

    public func settingTags(_ tags: [ActionTag], for actionId: ActionId) -> ActionPackOverrideSet {
        if let index = actionOverrides.firstIndex(where: { $0.actionId == actionId }) {
            let existing = actionOverrides[index]
            let updated = ActionPackActionOverride(
                actionId: actionId,
                disabled: existing.disabled,
                displayName: existing.displayName,
                tags: tags,
                frameDurationsMs: existing.frameDurationsMs,
                sortOrder: existing.sortOrder
            )
            var newOverrides = actionOverrides
            newOverrides[index] = updated
            return ActionPackOverrideSet(
                schemaVersion: schemaVersion,
                petId: petId,
                disabledPackIds: disabledPackIds,
                actionOverrides: newOverrides
            )
        } else {
            let override = ActionPackActionOverride(actionId: actionId, tags: tags)
            return ActionPackOverrideSet(
                schemaVersion: schemaVersion,
                petId: petId,
                disabledPackIds: disabledPackIds,
                actionOverrides: actionOverrides + [override]
            )
        }
    }

    public func settingFrameDurations(_ durations: [Int], for actionId: ActionId) -> ActionPackOverrideSet {
        if let index = actionOverrides.firstIndex(where: { $0.actionId == actionId }) {
            let existing = actionOverrides[index]
            let updated = ActionPackActionOverride(
                actionId: actionId,
                disabled: existing.disabled,
                displayName: existing.displayName,
                tags: existing.tags,
                frameDurationsMs: durations,
                sortOrder: existing.sortOrder
            )
            var newOverrides = actionOverrides
            newOverrides[index] = updated
            return ActionPackOverrideSet(
                schemaVersion: schemaVersion,
                petId: petId,
                disabledPackIds: disabledPackIds,
                actionOverrides: newOverrides
            )
        } else {
            let override = ActionPackActionOverride(actionId: actionId, frameDurationsMs: durations)
            return ActionPackOverrideSet(
                schemaVersion: schemaVersion,
                petId: petId,
                disabledPackIds: disabledPackIds,
                actionOverrides: actionOverrides + [override]
            )
        }
    }

    public func settingSortOrder(_ sortOrder: Int, for actionId: ActionId) -> ActionPackOverrideSet {
        if let index = actionOverrides.firstIndex(where: { $0.actionId == actionId }) {
            let existing = actionOverrides[index]
            let updated = ActionPackActionOverride(
                actionId: actionId,
                disabled: existing.disabled,
                displayName: existing.displayName,
                tags: existing.tags,
                frameDurationsMs: existing.frameDurationsMs,
                sortOrder: sortOrder
            )
            var newOverrides = actionOverrides
            newOverrides[index] = updated
            return ActionPackOverrideSet(
                schemaVersion: schemaVersion,
                petId: petId,
                disabledPackIds: disabledPackIds,
                actionOverrides: newOverrides
            )
        } else {
            let override = ActionPackActionOverride(actionId: actionId, sortOrder: sortOrder)
            return ActionPackOverrideSet(
                schemaVersion: schemaVersion,
                petId: petId,
                disabledPackIds: disabledPackIds,
                actionOverrides: actionOverrides + [override]
            )
        }
    }
}
