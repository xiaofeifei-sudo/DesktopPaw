@preconcurrency import AppKit
import Foundation

public struct ActionLibraryRow: Identifiable {
  public var id: String { actionId.rawValue }

  public let actionId: ActionId
  public let displayName: String
  public let role: ActionRole?
  public let tags: [ActionTag]
  public let previewFrame: SpriteFrame?
  public let previewImage: NSImage?
  public let canPlay: Bool
  public let notice: String?
  public let deletablePackId: String?
}

@MainActor
public final class ActionLibraryViewModel: ObservableObject {
  public typealias PreviewProvider = @MainActor (
    _ definition: PetDefinition,
    _ action: Action,
    _ frame: SpriteFrame
  ) -> NSImage?

  @Published public private(set) var currentPetId: String?
  @Published public private(set) var rows: [ActionLibraryRow] = []
  @Published public var editingActionId: ActionId?
  @Published public private(set) var editorModel: ActionEditorViewModel?
  @Published public var isImportWizardPresented = false
  @Published public private(set) var importWizardModel: ImportWizardViewModel?
  @Published public var isActionPackWizardPresented = false
  @Published public private(set) var actionPackWizardModel: ActionPackImportWizardViewModel?

  public var onActionMetadataSaved: ((String) -> Void)?

  public var petFrameSize: CGSizeCodable? { definition?.frameSize }
  public var petDisplayName: String? { definition?.displayName }

  private var definition: PetDefinition?
  private let triggerService: ActionTriggerServicing
  private let previewProvider: PreviewProvider
  private let overrideStore: PetActionOverrideStoring
  private let actionPackOverrideStore: ActionPackOverrideStoring?
  private let catalogBuilder: PetActionCatalogBuilding
  private let actionPackCommander: PetLibraryCommander?

  public init(
    definition: PetDefinition? = nil,
    triggerService: ActionTriggerServicing,
    previewProvider: @escaping PreviewProvider,
    overrideStore: PetActionOverrideStoring = PetActionOverrideStore(),
    actionPackOverrideStore: ActionPackOverrideStoring? = nil,
    catalogBuilder: PetActionCatalogBuilding = DefaultPetActionCatalogBuilder(),
    actionPackCommander: PetLibraryCommander? = nil
  ) {
    self.definition = definition
    self.currentPetId = definition?.id
    self.triggerService = triggerService
    self.previewProvider = previewProvider
    self.overrideStore = overrideStore
    self.actionPackOverrideStore = actionPackOverrideStore
    self.catalogBuilder = catalogBuilder
    self.actionPackCommander = actionPackCommander
    rebuildRows()
  }

  public static func defaultPreviewProvider(
    rendererFactory: PetRenderableFactory = DefaultPetRenderableFactory(),
    folderURLProvider: @escaping @MainActor (PetDefinition) -> URL? = { _ in nil }
  ) -> PreviewProvider {
    { definition, action, frame in
      let renderer = rendererFactory.makeRenderer(
        for: definition,
        folderURL: folderURLProvider(definition)
      )
      return renderer.image(for: action.role?.legacyState ?? .idle, frame: frame)
    }
  }

  public func refresh(definition: PetDefinition?) {
    self.definition = definition
    currentPetId = definition?.id
    dismissEditor()
    dismissImportWizard()
    rebuildRows()
  }

  public func refreshEligibility() {
    guard let definition else {
      rows = []
      return
    }

    let existingPreviews = Dictionary(
      uniqueKeysWithValues: rows.map { row in
        (row.actionId, ActionLibraryPreview(frame: row.previewFrame, image: row.previewImage))
      }
    )
    rows = Self.sortedActions(in: definition.catalog).map { action in
      let previewFrame = action.frames.first
      let existingPreview = existingPreviews[action.id]
      let previewImage: NSImage?
      if existingPreview?.frame == previewFrame {
        previewImage = existingPreview?.image
      } else {
        previewImage = previewFrame.map { previewProvider(definition, action, $0) } ?? nil
      }
      return makeRow(
        action: action,
        previewFrame: previewFrame,
        previewImage: previewImage
      )
    }
  }

  @discardableResult
  public func playPreview(_ actionId: ActionId) -> ActionTriggerEligibility {
    let result = triggerService.trigger(actionId: actionId)
    rebuildRows()
    return result
  }

  public func openEditor(for actionId: ActionId) {
    guard let definition, let action = definition.catalog.resolve(actionId: actionId) else {
      return
    }

    editingActionId = actionId
    editorModel = ActionEditorViewModel(
      definition: definition,
      action: action,
      overrideStore: overrideStore,
      actionPackOverrideStore: actionPackOverrideStore,
      triggerService: triggerService,
      catalogBuilder: catalogBuilder,
      onSaveSucceeded: { [weak self] petId in
        self?.dismissEditor()
        self?.onActionMetadataSaved?(petId)
      },
      onCancel: { [weak self] in
        self?.dismissEditor()
      }
    )
  }

  public func dismissEditor() {
    editingActionId = nil
    editorModel = nil
  }

  public func openImportWizard() {
    guard let definition else {
      return
    }

    importWizardModel = ImportWizardViewModel(
      definition: definition,
      overrideStore: overrideStore,
      catalogBuilder: catalogBuilder,
      previewProvider: previewProvider,
      onCommitSucceeded: { [weak self] petId in
        self?.dismissImportWizard()
        self?.onActionMetadataSaved?(petId)
      },
      onCancel: { [weak self] in
        self?.dismissImportWizard()
      }
    )
    isImportWizardPresented = true
  }

  public func dismissImportWizard() {
    isImportWizardPresented = false
    importWizardModel = nil
  }

  public func openActionPackImportWizard() {
    guard let definition else { return }

    actionPackWizardModel = ActionPackImportWizardViewModel(
      definition: definition,
      onSave: { [weak self] draft in
        guard let self, let petId = self.currentPetId else { return }
        guard let actionPackCommander = self.actionPackCommander else {
          self.actionPackWizardModel?.errorMessage = "保存失败：动作包写入器不可用。"
          self.actionPackWizardModel?.isSaving = false
          return
        }
        actionPackCommander.saveActionPackDraft(draft, forPetId: petId)
        self.dismissActionPackImportWizard()
        self.onActionMetadataSaved?(petId)
      },
      onCancel: { [weak self] in
        self?.dismissActionPackImportWizard()
      }
    )
    isActionPackWizardPresented = true
  }

  public func dismissActionPackImportWizard() {
    isActionPackWizardPresented = false
    actionPackWizardModel = nil
  }

  public func deleteActionPack(_ packId: String) {
    guard let petId = currentPetId, let actionPackCommander else { return }
    actionPackCommander.deleteActionPack(id: packId, forPetId: petId)
    onActionMetadataSaved?(petId)
  }

  public func disableAction(_ actionId: ActionId) {
    guard let petId = currentPetId else { return }
    actionPackCommander?.disableAction(actionId, forPetId: petId)
    onActionMetadataSaved?(petId)
  }

  public static func sortedActions(in catalog: PetActionCatalog) -> [Action] {
    let roleActions = roleOrder.flatMap { catalog.actions(for: $0) }
    let extraActions = catalog.extras.sorted { lhs, rhs in
      if lhs.displayName == rhs.displayName {
        return lhs.id.rawValue < rhs.id.rawValue
      }
      return lhs.displayName < rhs.displayName
    }
    return roleActions + extraActions
  }

  public static let roleOrder: [ActionRole] = [
    .idle,
    .walking,
    .sleeping,
    .happy,
    .eating,
    .jumping,
    .dragging
  ]

  private func rebuildRows() {
    guard let definition else {
      rows = []
      return
    }

    rows = Self.sortedActions(in: definition.catalog).map { action in
      let previewFrame = action.frames.first
      return makeRow(
        action: action,
        previewFrame: previewFrame,
        previewImage: previewFrame.map { previewProvider(definition, action, $0) } ?? nil
      )
    }
  }

  private func makeRow(
    action: Action,
    previewFrame: SpriteFrame?,
    previewImage: NSImage?
  ) -> ActionLibraryRow {
    let eligibility = triggerService.eligibility(for: action.id)
    return ActionLibraryRow(
      actionId: action.id,
      displayName: action.displayName,
      role: action.role,
      tags: action.tags,
      previewFrame: previewFrame,
      previewImage: previewImage,
      canPlay: eligibility == .allowed,
      notice: Self.notice(for: eligibility),
      deletablePackId: Self.deletablePackId(for: action)
    )
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

  private static func deletablePackId(for action: Action) -> String? {
    guard action.role == nil else { return nil }

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

private struct ActionLibraryPreview {
  let frame: SpriteFrame?
  let image: NSImage?
}
