@preconcurrency import AppKit
import Foundation

public enum ImportWizardSelection: Equatable, Sendable {
    case assignRole(ActionRole)
    case namedExtra(String)
    case ignore
}

public struct ImportWizardRow: Identifiable {
    public var id: String { actionId.rawValue }

    public let rowIndex: Int
    public let actionId: ActionId
    public let displayName: String
    public let previewFrame: SpriteFrame?
    public let previewImage: NSImage?
    public var selection: ImportWizardSelection
    public let notice: String?
}

@MainActor
public final class ImportWizardViewModel: ObservableObject {
    public static let phase3Notice = "Phase 3 起将参与加权抽样"
    public static let displayNameValidationMessage = "名称需 1–64 字符"

    @Published public private(set) var rows: [ImportWizardRow] = []
    @Published public private(set) var saveError: String?

    public let petId: String

    private let definition: PetDefinition
    private let overrideStore: PetActionOverrideStoring
    private let catalogBuilder: PetActionCatalogBuilding
    private let previewProvider: ActionLibraryViewModel.PreviewProvider
    private let onCommitSucceeded: ((String) -> Void)?
    private let onCancel: (() -> Void)?

    public init(
        definition: PetDefinition,
        overrideStore: PetActionOverrideStoring,
        catalogBuilder: PetActionCatalogBuilding = DefaultPetActionCatalogBuilder(),
        previewProvider: @escaping ActionLibraryViewModel.PreviewProvider,
        onCommitSucceeded: ((String) -> Void)? = nil,
        onCancel: (() -> Void)? = nil
    ) {
        self.definition = definition
        self.overrideStore = overrideStore
        self.catalogBuilder = catalogBuilder
        self.previewProvider = previewProvider
        self.onCommitSucceeded = onCommitSucceeded
        self.onCancel = onCancel
        self.petId = definition.id
        self.rows = Self.unmappedRows(
            in: definition,
            previewProvider: previewProvider
        )
    }

    public func assign(rowIndex: Int, role: ActionRole?, customName: String?) {
        let selection: ImportWizardSelection
        if let role {
            selection = .assignRole(role)
        } else if let customName {
            selection = .namedExtra(customName)
        } else {
            selection = .ignore
        }
        updateSelection(rowIndex: rowIndex, selection: selection)
    }

    public func cancel() {
        onCancel?()
    }

    @discardableResult
    public func commit() -> Bool {
        saveError = nil

        do {
            let existingOverrides = try overrideStore.load(petId: petId) ?? PetActionOverrideSet(
                petId: petId,
                overrides: []
            )
            let mergedOverrides = try makeMergedOverrides(existingOverrides: existingOverrides)
            try validateCatalog(with: mergedOverrides)
            try overrideStore.save(mergedOverrides, for: petId)
            onCommitSucceeded?(petId)
            return true
        } catch {
            saveError = (error as? LocalizedError)?.errorDescription ?? "保存失败"
            return false
        }
    }

    public func roleSelection(for rowIndex: Int) -> ActionRole {
        guard let selection = rows.first(where: { $0.rowIndex == rowIndex })?.selection,
              case .assignRole(let role) = selection else {
            return .idle
        }
        return role
    }

    public func customName(for rowIndex: Int) -> String {
        guard let row = rows.first(where: { $0.rowIndex == rowIndex }) else {
            return ""
        }
        switch row.selection {
        case .namedExtra(let name):
            return name
        case .assignRole, .ignore:
            return row.displayName
        }
    }

    public func selectionMode(for rowIndex: Int) -> ImportWizardSelectionMode {
        guard let selection = rows.first(where: { $0.rowIndex == rowIndex })?.selection else {
            return .namedExtra
        }
        switch selection {
        case .assignRole:
            return .assignRole
        case .namedExtra:
            return .namedExtra
        case .ignore:
            return .ignore
        }
    }

    public func setSelectionMode(_ mode: ImportWizardSelectionMode, rowIndex: Int) {
        guard let row = rows.first(where: { $0.rowIndex == rowIndex }) else {
            return
        }

        switch mode {
        case .assignRole:
            assign(rowIndex: rowIndex, role: .happy, customName: nil)
        case .namedExtra:
            let name = customName(for: rowIndex)
            assign(rowIndex: rowIndex, role: nil, customName: name.isEmpty ? row.displayName : name)
        case .ignore:
            assign(rowIndex: rowIndex, role: nil, customName: nil)
        }
    }

    private func updateSelection(rowIndex: Int, selection: ImportWizardSelection) {
        rows = rows.map { row in
            guard row.rowIndex == rowIndex else {
                return row
            }
            return ImportWizardRow(
                rowIndex: row.rowIndex,
                actionId: row.actionId,
                displayName: row.displayName,
                previewFrame: row.previewFrame,
                previewImage: row.previewImage,
                selection: selection,
                notice: notice(for: row.actionId, selection: selection)
            )
        }
    }

    private func notice(for actionId: ActionId, selection: ImportWizardSelection) -> String? {
        guard case .assignRole(let role) = selection else {
            return nil
        }

        let duplicate = definition.catalog.actions(for: role).contains { $0.id != actionId }
        return duplicate ? Self.phase3Notice : nil
    }

    private func makeMergedOverrides(
        existingOverrides: PetActionOverrideSet
    ) throws -> PetActionOverrideSet {
        var overridesByActionId = existingOverrides.overridesByActionId

        for row in rows {
            let existingOverride = overridesByActionId[row.actionId]

            switch row.selection {
            case .assignRole(let role):
                overridesByActionId[row.actionId] = PetActionOverride(
                    actionId: row.actionId,
                    displayName: existingOverride?.displayName,
                    tags: existingOverride?.tags,
                    role: role
                )
            case .namedExtra(let rawName):
                let displayName = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard (1...Self.maxDisplayNameLength).contains(displayName.count) else {
                    saveError = Self.displayNameValidationMessage
                    throw ImportWizardValidationError.invalidDisplayName
                }
                overridesByActionId[row.actionId] = PetActionOverride(
                    actionId: row.actionId,
                    displayName: displayName,
                    tags: existingOverride?.tags,
                    role: nil
                )
            case .ignore:
                overridesByActionId[row.actionId] = nil
            }
        }

        return PetActionOverrideSet(
            petId: petId,
            overrides: overridesByActionId.values.sorted { lhs, rhs in
                lhs.actionId.rawValue < rhs.actionId.rawValue
            }
        )
    }

    private func validateCatalog(with overrides: PetActionOverrideSet) throws {
        let input = PetActionCatalogBuildInput(
            petId: definition.id,
            schemaVersion: 2,
            legacyAnimations: nil,
            actions: definition.catalog.actions,
            spritesheet: definition.spritesheet
        )
        _ = try catalogBuilder.build(input: input, overrides: overrides)
    }

    private static func unmappedRows(
        in definition: PetDefinition,
        previewProvider: ActionLibraryViewModel.PreviewProvider
    ) -> [ImportWizardRow] {
        definition.catalog.extras
            .compactMap { action -> ImportWizardRow? in
                guard let previewFrame = action.frames.first,
                      previewFrame.row >= Self.firstPetdexExtraRowIndex else {
                    return nil
                }

                return ImportWizardRow(
                    rowIndex: previewFrame.row,
                    actionId: action.id,
                    displayName: action.displayName,
                    previewFrame: previewFrame,
                    previewImage: previewProvider(definition, action, previewFrame),
                    selection: .namedExtra(action.displayName),
                    notice: nil
                )
            }
            .sorted { lhs, rhs in
                if lhs.rowIndex == rhs.rowIndex {
                    return lhs.actionId.rawValue < rhs.actionId.rawValue
                }
                return lhs.rowIndex < rhs.rowIndex
            }
    }

    private static let firstPetdexExtraRowIndex = 7
    private static let maxDisplayNameLength = 64
}

public enum ImportWizardSelectionMode: String, CaseIterable, Identifiable, Sendable {
    case assignRole
    case namedExtra
    case ignore

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .assignRole:
            return "分配角色"
        case .namedExtra:
            return "命名 extra"
        case .ignore:
            return "忽略"
        }
    }
}

private enum ImportWizardValidationError: Error {
    case invalidDisplayName
}

extension ImportWizardValidationError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .invalidDisplayName:
            return "名称需 1–64 字符"
        }
    }
}
