import SwiftUI

@MainActor
public struct PetLibraryView: View {
  public static let importImageButtonTitle = L10n.PetLibrary.importImage
  public static let importPackageButtonTitle = L10n.PetLibrary.importPackage
  public static let importPetdexZipButtonTitle = L10n.PetLibrary.importPetdexZip
  public static let importPetdexURLButtonTitle = L10n.PetLibrary.importPetdexURL
  public static let cancelPetdexURLButtonTitle = L10n.Common.cancel
  public static let petdexURLPlaceholder = "https://petdex.crafter.run/..."
  public static let importingMessage = L10n.PetLibrary.importing

  @ObservedObject private var libraryModel: PetLibraryViewModel
  @ObservedObject private var importModel: PetImportViewModel
  private let petdexURLImportModel: PetdexURLImportViewModel?
  private let actionLibraryModel: ActionLibraryViewModel?

  public init(
    libraryModel: PetLibraryViewModel,
    importModel: PetImportViewModel,
    petdexURLImportModel: PetdexURLImportViewModel? = nil,
    actionLibraryModel: ActionLibraryViewModel? = nil
  ) {
    self.libraryModel = libraryModel
    self.importModel = importModel
    self.petdexURLImportModel = petdexURLImportModel
    self.actionLibraryModel = actionLibraryModel
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      header
      petList
      if libraryModel.currentPetId != nil, let actionLibraryModel {
        Divider()
        ActionLibraryView(model: actionLibraryModel)
      }
      inlineMessages
      HStack(spacing: 8) {
        Button(Self.importImageButtonTitle) {
          importModel.requestImageImport()
        }
        Button(Self.importPackageButtonTitle) {
          importModel.requestPackageImport()
        }
        Button(Self.importPetdexZipButtonTitle) {
          importModel.requestPetdexPackageImport()
        }
      }
      if let petdexURLImportModel {
        PetdexURLImportControls(model: petdexURLImportModel)
      }
    }
  }

  private var header: some View {
    HStack {
      Text(L10n.PetLibrary.title)
        .font(.headline)
      Spacer()
      if let currentId = libraryModel.currentPetId,
         let current = libraryModel.items.first(where: { $0.id == currentId }) {
        Text("Current: \(current.displayName)")
          .foregroundStyle(.secondary)
      }
    }
  }

  private var petList: some View {
    VStack(alignment: .leading, spacing: 8) {
      if libraryModel.items.isEmpty {
        Text(L10n.PetLibrary.noPets)
          .foregroundStyle(.secondary)
      } else {
        ForEach(libraryModel.items, id: \.id) { item in
          PetLibraryRow(
            item: item,
            isCurrent: item.id == libraryModel.currentPetId,
            onUse: { libraryModel.selectPet(id: item.id) },
            onDelete: item.isImported ? { libraryModel.deletePet(id: item.id) } : nil
          )
        }
      }
    }
  }

  @ViewBuilder
  private var inlineMessages: some View {
    if let message = libraryModel.errorMessage {
      Text(message)
        .foregroundStyle(.red)
        .font(.callout)
    }
    if case let .failed(message) = importModel.state {
      Text(message)
        .foregroundStyle(.red)
        .font(.callout)
    }
    if case .inFlight = importModel.state {
      Text(Self.importingMessage)
        .foregroundStyle(.secondary)
        .font(.callout)
    }
  }
}

@MainActor
private struct PetdexURLImportControls: View {
  @ObservedObject var model: PetdexURLImportViewModel

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack(spacing: 8) {
        TextField(PetLibraryView.petdexURLPlaceholder, text: $model.input)
          .textFieldStyle(.roundedBorder)
          .disabled(model.isInFlight)
        if model.isInFlight {
          Button(PetLibraryView.cancelPetdexURLButtonTitle) {
            model.cancelImport()
          }
        } else {
          Button(PetLibraryView.importPetdexURLButtonTitle) {
            model.requestImport()
          }
          .disabled(!model.canSubmit)
        }
      }
      if let statusMessage = model.statusMessage {
        Text(statusMessage)
          .foregroundStyle(statusColor)
          .font(.callout)
      }
    }
  }

  private var statusColor: Color {
    switch model.state {
    case .failed:
      return .red
    case .idle, .downloading, .importing, .imported, .cancelled:
      return .secondary
    }
  }
}

@MainActor
private struct PetLibraryRow: View {
  let item: PetLibraryItem
  let isCurrent: Bool
  let onUse: () -> Void
  let onDelete: (() -> Void)?

  var body: some View {
    HStack(spacing: 12) {
      VStack(alignment: .leading, spacing: 2) {
        Text(item.displayName)
          .font(.body)
        Text(sourceLabel)
          .foregroundStyle(.secondary)
          .font(.caption)
      }
      Spacer()
      if isCurrent {
        Text(L10n.localize(cn: "使用中", en: "In Use"))
          .foregroundStyle(.secondary)
          .font(.caption)
      } else {
        Button("Use Pet", action: onUse)
      }
      if let onDelete {
        Button("Delete", role: .destructive, action: onDelete)
      }
    }
    .padding(.vertical, 4)
  }

  private var sourceLabel: String {
    item.source.displayName
  }
}
