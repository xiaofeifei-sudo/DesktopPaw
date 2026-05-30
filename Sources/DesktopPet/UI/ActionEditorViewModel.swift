import Foundation

public struct ActionFrameDurationEditorItem: Identifiable, Equatable {
    public var id: Int { index }

    public let index: Int
    public let column: Int
    public let row: Int
    public var durationMs: Int
}

@MainActor
public final class ActionEditorViewModel: ObservableObject {
    public static let displayNameValidationMessage = "名称需 1–64 字符"
    public static let tagCharacterValidationMessage = "tag 仅允许小写字母、数字、:.-_"
    public static let moodValidationMessage = "mood: 取值仅限 high / medium / low / any"
    public static let tagLimitValidationMessage = "单个动作最多 16 个 tag"
    public static let packageTagLimitValidationMessage = "单个宠物最多 32 个 tag"
    public static let frameDurationValidationMessage = "每帧时长需在 50–1000ms 之间"
    public static let frameDurationRange = 50...1000

    @Published public var displayName: String
    @Published public var pendingTag = ""
    @Published public private(set) var tags: [String]
    @Published public private(set) var frameDurations: [ActionFrameDurationEditorItem]
    @Published public private(set) var displayNameError: String?
    @Published public private(set) var tagError: String?
    @Published public private(set) var frameDurationError: String?
    @Published public private(set) var saveError: String?
    @Published public private(set) var previewNotice: String?

    public let petId: String
    public let actionId: ActionId
    public let role: ActionRole?

    private let definition: PetDefinition
    private let action: Action
    private let overrideStore: PetActionOverrideStoring
    private let actionPackOverrideStore: ActionPackOverrideStoring?
    private let triggerService: ActionTriggerServicing
    private let catalogBuilder: PetActionCatalogBuilding
    private let onSaveSucceeded: ((String) -> Void)?
    private let onCancel: (() -> Void)?

    public init(
        definition: PetDefinition,
        action: Action,
        overrideStore: PetActionOverrideStoring,
        actionPackOverrideStore: ActionPackOverrideStoring? = nil,
        triggerService: ActionTriggerServicing,
        catalogBuilder: PetActionCatalogBuilding = DefaultPetActionCatalogBuilder(),
        onSaveSucceeded: ((String) -> Void)? = nil,
        onCancel: (() -> Void)? = nil
    ) {
        self.definition = definition
        self.action = action
        self.overrideStore = overrideStore
        self.actionPackOverrideStore = actionPackOverrideStore
        self.triggerService = triggerService
        self.catalogBuilder = catalogBuilder
        self.onSaveSucceeded = onSaveSucceeded
        self.onCancel = onCancel
        self.petId = definition.id
        self.actionId = action.id
        self.role = action.role
        self.displayName = action.displayName
        self.tags = action.tags.map(\.rawValue)
        self.frameDurations = action.frames.enumerated().map { index, frame in
            ActionFrameDurationEditorItem(
                index: index,
                column: frame.column,
                row: frame.row,
                durationMs: frame.durationMs ?? action.frameDurationMs
            )
        }
    }

    public var canPlayPreview: Bool {
        triggerService.eligibility(for: actionId) == .allowed
    }

    private var actionPackId: String? {
        Self.actionPackId(for: action)
    }

    @discardableResult
    public func addPendingTag() -> Bool {
        let added = addTag(pendingTag)
        if added {
            pendingTag = ""
        }
        return added
    }

    @discardableResult
    public func addTag(_ rawTag: String) -> Bool {
        tagError = nil
        let normalized = rawTag.trimmingCharacters(in: .whitespacesAndNewlines)

        guard tags.count < Self.maxTagsPerAction else {
            tagError = Self.tagLimitValidationMessage
            return false
        }

        guard let tag = validateTag(normalized) else {
            return false
        }

        guard !tags.contains(tag.rawValue) else {
            return true
        }

        tags.append(tag.rawValue)
        return true
    }

    public func removeTag(_ rawTag: String) {
        tags.removeAll { $0 == rawTag }
        tagError = nil
    }

    public func setFrameDuration(index: Int, durationMs: Int) {
        guard let itemIndex = frameDurations.firstIndex(where: { $0.index == index }) else {
            return
        }

        var updatedDurations = frameDurations
        updatedDurations[itemIndex].durationMs = durationMs
        frameDurations = updatedDurations
        frameDurationError = nil
    }

    public func durationMsForFrame(at index: Int) -> Int {
        frameDurations.first(where: { $0.index == index })?.durationMs ?? action.frameDurationMs
    }

    public func cancel() {
        onCancel?()
    }

    @discardableResult
    public func playPreview() -> ActionTriggerEligibility {
        let result = triggerService.trigger(actionId: actionId)
        previewNotice = Self.notice(for: result)
        return result
    }

    @discardableResult
    public func save() -> Bool {
        saveError = nil

        guard validateDisplayName() else {
            return false
        }

        guard let parsedTags = validateAllTags() else {
            return false
        }

        guard let parsedFrameDurations = validateFrameDurations() else {
            return false
        }

        do {
            try validateEditedCatalog(
                displayName: normalizedDisplayName(),
                tags: parsedTags,
                frameDurations: parsedFrameDurations
            )

            if actionPackId != nil {
                try saveActionPackOverride(
                    displayName: normalizedDisplayName(),
                    tags: parsedTags,
                    frameDurations: parsedFrameDurations
                )
            } else {
                let existingOverrides = try overrideStore.load(petId: petId) ?? PetActionOverrideSet(petId: petId, overrides: [])
                let mergedOverrides = makeMergedOverrides(
                    existingOverrides: existingOverrides,
                    displayName: normalizedDisplayName(),
                    tags: parsedTags,
                    frameDurations: parsedFrameDurations
                )
                try overrideStore.save(mergedOverrides, for: petId)
            }
            onSaveSucceeded?(petId)
            return true
        } catch let error as ActionCatalogError {
            applyCatalogError(error)
            return false
        } catch {
            saveError = (error as? LocalizedError)?.errorDescription ?? "保存失败"
            return false
        }
    }

    private func validateDisplayName() -> Bool {
        let normalized = normalizedDisplayName()
        guard (1...Self.maxDisplayNameLength).contains(normalized.count) else {
            displayNameError = Self.displayNameValidationMessage
            return false
        }

        displayNameError = nil
        return true
    }

    private func normalizedDisplayName() -> String {
        displayName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func validateAllTags() -> [ActionTag]? {
        var parsedTags: [ActionTag] = []
        for rawTag in tags {
            guard let tag = validateTag(rawTag) else {
                return nil
            }
            parsedTags.append(tag)
        }
        return parsedTags
    }

    private func validateFrameDurations() -> [Int]? {
        let durations = frameDurations.map(\.durationMs)
        guard durations.allSatisfy({ Self.frameDurationRange.contains($0) }) else {
            frameDurationError = Self.frameDurationValidationMessage
            return nil
        }

        frameDurationError = nil
        return durations
    }

    private func validateTag(_ rawTag: String) -> ActionTag? {
        guard let tag = ActionTag(rawValue: rawTag) else {
            tagError = Self.tagCharacterValidationMessage
            return nil
        }

        switch tag.prefix {
        case .mood:
            guard let value = tag.value, Self.allowedMoodValues.contains(value) else {
                tagError = Self.moodValidationMessage
                return nil
            }
        case .after:
            guard let value = tag.value, Self.allowedAfterValues.contains(value) else {
                tagError = "after. 取值仅限 pet / feed / clicked"
                return nil
            }
        case .time:
            guard let value = tag.value, Self.allowedTimeValues.contains(value) else {
                tagError = "time. 取值仅限 morning / afternoon / evening / night / workday / weekend"
                return nil
            }
        case nil:
            break
        }

        tagError = nil
        return tag
    }

    private func makeMergedOverrides(
        existingOverrides: PetActionOverrideSet,
        displayName: String,
        tags: [ActionTag],
        frameDurations: [Int]
    ) -> PetActionOverrideSet {
        var overridesByActionId = existingOverrides.overridesByActionId
        let existingOverride = overridesByActionId[actionId]
        overridesByActionId[actionId] = PetActionOverride(
            actionId: actionId,
            displayName: displayName,
            tags: tags,
            role: existingOverride?.role,
            frameDurationsMs: frameDurations
        )

        return PetActionOverrideSet(
            petId: petId,
            overrides: overridesByActionId.values.sorted { lhs, rhs in
                lhs.actionId.rawValue < rhs.actionId.rawValue
            }
        )
    }

    private func saveActionPackOverride(
        displayName: String,
        tags: [ActionTag],
        frameDurations: [Int]
    ) throws {
        guard let actionPackOverrideStore else {
            saveError = "保存失败"
            throw ActionEditorSaveError.actionPackOverrideStoreUnavailable
        }

        var overrides = actionPackOverrideStore.load(petId: petId) ?? ActionPackOverrideSet(petId: petId)
        overrides = overrides
            .settingDisplayName(displayName, for: actionId)
            .settingTags(tags, for: actionId)
            .settingFrameDurations(frameDurations, for: actionId)
        try actionPackOverrideStore.save(overrides, petId: petId)
    }

    private func validateEditedCatalog(
        displayName: String,
        tags: [ActionTag],
        frameDurations: [Int]
    ) throws {
        let editedActions = definition.catalog.actions.map { existingAction -> Action in
            guard existingAction.id == actionId else {
                return existingAction
            }

            return Action(
                id: existingAction.id,
                displayName: displayName,
                role: existingAction.role,
                tags: tags,
                assetId: existingAction.assetId,
                frames: frames(existingAction.frames, applyingDurations: frameDurations),
                frameDurationMs: existingAction.frameDurationMs,
                loop: existingAction.loop,
                nextActionId: existingAction.nextActionId
            )
        }

        let input = PetActionCatalogBuildInput(
            petId: definition.id,
            schemaVersion: 2,
            legacyAnimations: nil,
            actions: editedActions,
            // Composed catalogs can include action-pack frames whose coordinates are scoped to their own assets.
            spritesheet: nil
        )
        _ = try catalogBuilder.build(input: input, overrides: nil)
    }

    private func frames(_ frames: [SpriteFrame], applyingDurations durations: [Int]) -> [SpriteFrame] {
        guard durations.count == frames.count else {
            return frames
        }

        return frames.enumerated().map { index, frame in
            SpriteFrame(
                assetId: frame.assetId,
                column: frame.column,
                row: frame.row,
                durationMs: durations[index]
            )
        }
    }

    private func applyCatalogError(_ error: ActionCatalogError) {
        switch error {
        case .tooManyTagsOnAction:
            tagError = Self.tagLimitValidationMessage
        case .tooManyTagsInPackage:
            tagError = Self.packageTagLimitValidationMessage
        default:
            saveError = "保存失败"
        }
    }

    private static func notice(for eligibility: ActionTriggerEligibility) -> String? {
        switch eligibility {
        case .allowed:
            return nil
        case .rejectedBusy(let reason):
            return reason
        case .rejectedThrottled:
            return "动作触发太快，稍后再试"
        case .rejectedUnknownActionId:
            return "动作不可用"
        }
    }

    private static let maxDisplayNameLength = 64
    private static let maxTagsPerAction = 16
    private static let allowedMoodValues: Set<String> = ["high", "medium", "low", "any"]
    private static let allowedAfterValues: Set<String> = ["pet", "feed", "clicked", "click"]
    private static let allowedTimeValues: Set<String> = [
        "morning",
        "afternoon",
        "evening",
        "night",
        "workday",
        "weekend"
    ]

    private static func actionPackId(for action: Action) -> String? {
        let assetIds = [action.assetId] + action.frames.map(\.assetId)
        for assetId in assetIds.compactMap({ $0 }) {
            guard let separator = assetId.firstIndex(of: "/"),
                  separator > assetId.startIndex
            else {
                continue
            }

            let packId = String(assetId[..<separator])
            if packId != "base" {
                return packId
            }
        }
        return nil
    }
}

private enum ActionEditorSaveError: Error {
    case actionPackOverrideStoreUnavailable
}
