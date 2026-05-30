import SwiftUI

@MainActor
public struct ImportWizardView: View {
  @ObservedObject private var model: ImportWizardViewModel

  public init(model: ImportWizardViewModel) {
    self.model = model
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Text("导入向导")
          .font(.headline)
        Spacer()
      }

      if model.rows.isEmpty {
        Text("No extra Petdex rows available.")
          .foregroundStyle(.secondary)
          .font(.callout)
      } else {
        VStack(alignment: .leading, spacing: 8) {
          ForEach(model.rows) { row in
            ImportWizardRowView(model: model, row: row)
          }
        }
      }

      if let saveError = model.saveError {
        Text(saveError)
          .foregroundStyle(.red)
          .font(.caption)
      }

      HStack {
        Spacer()
        Button("Cancel") {
          model.cancel()
        }
        Button("Save") {
          model.commit()
        }
        .keyboardShortcut(.defaultAction)
      }
    }
    .padding(20)
    .frame(width: 520)
  }
}

@MainActor
private struct ImportWizardRowView: View {
  @ObservedObject var model: ImportWizardViewModel
  let row: ImportWizardRow

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack(alignment: .center, spacing: 10) {
        preview

        VStack(alignment: .leading, spacing: 4) {
          Text("Row \(row.rowIndex)")
            .font(.body)
          Text(row.actionId.rawValue)
            .font(.caption)
            .foregroundStyle(.secondary)
        }

        Spacer(minLength: 8)

        Picker(
          "处理",
          selection: Binding(
            get: { model.selectionMode(for: row.rowIndex) },
            set: { model.setSelectionMode($0, rowIndex: row.rowIndex) }
          )
        ) {
          ForEach(ImportWizardSelectionMode.allCases) { mode in
            Text(mode.title).tag(mode)
          }
        }
        .labelsHidden()
        .frame(width: 130)
      }

      controls

      if let notice = row.notice {
        Text(notice)
          .foregroundStyle(.secondary)
          .font(.caption)
      }
    }
    .padding(.vertical, 6)
  }

  @ViewBuilder
  private var controls: some View {
    switch row.selection {
    case .assignRole:
      Picker(
        "角色",
        selection: Binding(
          get: { model.roleSelection(for: row.rowIndex) },
          set: { model.assign(rowIndex: row.rowIndex, role: $0, customName: nil) }
        )
      ) {
        ForEach(ActionRole.allCases, id: \.self) { role in
          Text(role.rawValue).tag(role)
        }
      }
    case .namedExtra:
      TextField(
        "Display name",
        text: Binding(
          get: { model.customName(for: row.rowIndex) },
          set: { model.assign(rowIndex: row.rowIndex, role: nil, customName: $0) }
        )
      )
      .textFieldStyle(.roundedBorder)
    case .ignore:
      EmptyView()
    }
  }

  @ViewBuilder
  private var preview: some View {
    if let previewImage = row.previewImage {
      Image(nsImage: previewImage)
        .resizable()
        .interpolation(.none)
        .scaledToFit()
        .frame(width: 44, height: 44)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    } else {
      ZStack {
        RoundedRectangle(cornerRadius: 6)
          .fill(Color.secondary.opacity(0.08))
        Image(systemName: "photo")
          .foregroundStyle(.secondary)
      }
      .frame(width: 44, height: 44)
    }
  }
}
