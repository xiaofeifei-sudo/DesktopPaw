@preconcurrency import AppKit
import SwiftUI

@MainActor
public struct ActionLibraryView: View {
  @ObservedObject private var model: ActionLibraryViewModel
  @State private var copiedPromptId: String?
  @State private var pendingDelete: PendingActionDelete?

  public init(model: ActionLibraryViewModel) {
    self.model = model
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: 8) {
        Text("动作图鉴")
          .font(.headline)
        Spacer()
        Button {
          model.openActionPackImportWizard()
        } label: {
          Label("新增动作", systemImage: "plus.rectangle.on.rectangle")
        }
        Button {
          model.openImportWizard()
        } label: {
          Label("导入向导", systemImage: "square.and.arrow.down")
        }
      }

      if model.rows.isEmpty {
        Text("No actions available.")
          .foregroundStyle(.secondary)
          .font(.callout)
      } else {
        VStack(alignment: .leading, spacing: 6) {
          ForEach(model.rows) { row in
            ActionLibraryRowView(
              row: row,
              onPlay: { model.playPreview(row.actionId) },
              onEdit: { model.openEditor(for: row.actionId) },
              onDelete: { packId in
                pendingDelete = PendingActionDelete(
                  packId: packId,
                  displayName: row.displayName
                )
              }
            )
          }
        }
      }

      formatRequirements
    }
    .sheet(
      isPresented: Binding(
        get: { model.editorModel != nil },
        set: { isPresented in
          if !isPresented {
            model.dismissEditor()
          }
        }
      )
    ) {
      if let editorModel = model.editorModel {
        ActionEditorView(model: editorModel)
      }
    }
    .sheet(
      isPresented: Binding(
        get: { model.isImportWizardPresented },
        set: { isPresented in
          if !isPresented {
            model.dismissImportWizard()
          }
        }
      )
    ) {
      if let importWizardModel = model.importWizardModel {
        ImportWizardView(model: importWizardModel)
      }
    }
    .sheet(
      isPresented: Binding(
        get: { model.isActionPackWizardPresented },
        set: { isPresented in
          if !isPresented {
            model.dismissActionPackImportWizard()
          }
        }
      )
    ) {
      if let wizardModel = model.actionPackWizardModel {
        ActionPackImportWizardView(model: wizardModel)
      }
    }
    .confirmationDialog(
      "删除新增动作？",
      isPresented: Binding(
        get: { pendingDelete != nil },
        set: { isPresented in
          if !isPresented {
            pendingDelete = nil
          }
        }
      ),
      presenting: pendingDelete
    ) { action in
      Button("删除“\(action.displayName)”", role: .destructive) {
        model.deleteActionPack(action.packId)
        pendingDelete = nil
      }
      Button("取消", role: .cancel) {
        pendingDelete = nil
      }
    } message: { _ in
      Text("这会删除该新增动作及其图片资源。")
    }
  }

  @ViewBuilder
  private var formatRequirements: some View {
    if let frameSize = model.petFrameSize {
      DisclosureGroup {
        VStack(alignment: .leading, spacing: 6) {
          requirementRow("每帧尺寸", value: "\(Int(frameSize.width)) × \(Int(frameSize.height)) 像素")
          requirementRow("支持格式", value: "PNG、JPG")

          Divider()

          Text("常见图片尺寸参考")
            .font(.caption)
            .foregroundStyle(.secondary)
          let presets = [
            ("单帧", 1, 1),
            ("2帧横图", 2, 1),
            ("4帧横图", 4, 1),
            ("4×2 网格", 4, 2),
            ("8帧横图", 8, 1),
          ]
          ForEach(presets.indices, id: \.self) { index in
            let (label, cols, rows) = presets[index]
            let w = Int(frameSize.width) * cols
            let h = Int(frameSize.height) * rows
            requirementRow(label, value: "\(w) × \(h) 像素")
          }

          Divider()

          Text("推荐生成提示词")
            .font(.caption)
            .foregroundStyle(.secondary)

          ForEach(
            ActionImagePromptTemplate.options(
              frameSize: frameSize,
              petDisplayName: model.petDisplayName
            )
          ) { option in
            promptOption(option)
          }
        }
        .font(.caption)
      } label: {
        Label("新增动作图片要求", systemImage: "info.circle")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
  }

  private func requirementRow(_ label: String, value: String) -> some View {
    HStack {
      Text(label)
        .foregroundStyle(.secondary)
      Spacer()
      Text(value)
        .textSelection(.enabled)
    }
  }

  private func promptOption(_ option: ActionImagePromptOption) -> some View {
    VStack(alignment: .leading, spacing: 5) {
      HStack(alignment: .firstTextBaseline, spacing: 8) {
        HStack(spacing: 4) {
          Text(option.title)
            .fontWeight(option.isRecommended ? .semibold : .regular)
          if option.isRecommended {
            Text("推荐")
              .font(.caption2)
              .padding(.horizontal, 5)
              .padding(.vertical, 1)
              .background(Color.accentColor.opacity(0.14))
              .foregroundStyle(Color.accentColor)
              .clipShape(RoundedRectangle(cornerRadius: 4))
          }
        }

        Text(option.imageSizeText)
          .foregroundStyle(.secondary)
          .textSelection(.enabled)

        Spacer(minLength: 8)

        Button {
          copyPrompt(option)
        } label: {
          Label(
            copiedPromptId == option.id ? "已复制" : "复制",
            systemImage: copiedPromptId == option.id ? "checkmark" : "doc.on.doc"
          )
        }
        .buttonStyle(.borderless)
        .help("复制完整提示词")
      }

      Text(option.detail)
        .font(.caption2)
        .foregroundStyle(.secondary)

      Text(option.prompt)
        .font(.caption2)
        .foregroundStyle(.secondary)
        .lineLimit(4)
        .textSelection(.enabled)
    }
    .padding(8)
    .background(Color.secondary.opacity(0.07))
    .clipShape(RoundedRectangle(cornerRadius: 6))
  }

  private func copyPrompt(_ option: ActionImagePromptOption) {
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    pasteboard.setString(option.prompt, forType: .string)

    copiedPromptId = option.id
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
      if copiedPromptId == option.id {
        copiedPromptId = nil
      }
    }
  }
}

private struct PendingActionDelete: Identifiable {
  var id: String { packId }

  let packId: String
  let displayName: String
}

@MainActor
private struct ActionLibraryRowView: View {
  let row: ActionLibraryRow
  let onPlay: () -> Void
  let onEdit: () -> Void
  let onDelete: (String) -> Void

  var body: some View {
    HStack(alignment: .center, spacing: 10) {
      preview

      VStack(alignment: .leading, spacing: 4) {
        Text(row.displayName)
          .font(.body)
          .lineLimit(1)
        HStack(spacing: 4) {
          if let role = row.role {
            ActionBadge(text: role.rawValue, kind: .role)
          } else if row.tags.isEmpty {
            ActionBadge(text: "extra", kind: .extra)
          } else {
            ForEach(row.tags, id: \.rawValue) { tag in
              ActionBadge(text: tag.rawValue, kind: .extra)
            }
          }
        }
        if let notice = row.notice {
          Text(notice)
            .foregroundStyle(.secondary)
            .font(.caption)
            .lineLimit(2)
        }
      }

      Spacer(minLength: 8)

      Button {
        onPlay()
      } label: {
        Label("试播", systemImage: "play.fill")
      }
      .disabled(!row.canPlay)

      Button {
        onEdit()
      } label: {
        Image(systemName: "pencil")
      }
      .help("编辑")

      if let packId = row.deletablePackId {
        Button(role: .destructive) {
          onDelete(packId)
        } label: {
          Image(systemName: "trash")
        }
        .help("删除新增动作")
      }
    }
    .padding(.vertical, 4)
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

@MainActor
private struct ActionBadge: View {
  enum Kind {
    case role
    case extra
  }

  let text: String
  let kind: Kind

  var body: some View {
    Text(text)
      .font(.caption2)
      .lineLimit(1)
      .padding(.horizontal, 6)
      .padding(.vertical, 2)
      .background(background)
      .foregroundStyle(foreground)
      .clipShape(RoundedRectangle(cornerRadius: 4))
  }

  private var background: Color {
    switch kind {
    case .role:
      return Color.accentColor.opacity(0.14)
    case .extra:
      return Color.secondary.opacity(0.10)
    }
  }

  private var foreground: Color {
    switch kind {
    case .role:
      return .accentColor
    case .extra:
      return .secondary
    }
  }
}

@MainActor
public struct ActionEditorView: View {
  @ObservedObject private var model: ActionEditorViewModel

  public init(model: ActionEditorViewModel) {
    self.model = model
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Text("动作编辑")
          .font(.headline)
        Spacer()
        Button {
          model.playPreview()
        } label: {
          Label("试播", systemImage: "play.fill")
        }
        .disabled(!model.canPlayPreview)
      }

      Text(model.actionId.rawValue)
        .font(.caption)
        .foregroundStyle(.secondary)

      VStack(alignment: .leading, spacing: 4) {
        Text("名称")
          .font(.caption)
          .foregroundStyle(.secondary)
        TextField("Display name", text: $model.displayName)
          .textFieldStyle(.roundedBorder)
        if let displayNameError = model.displayNameError {
          Text(displayNameError)
            .foregroundStyle(.red)
            .font(.caption)
        }
      }

      VStack(alignment: .leading, spacing: 6) {
        Text("Tags")
          .font(.caption)
          .foregroundStyle(.secondary)
        if model.tags.isEmpty {
          Text("None")
            .foregroundStyle(.secondary)
            .font(.caption)
        } else {
          FlowTagList(tags: model.tags, onRemove: { model.removeTag($0) })
        }
        HStack(spacing: 8) {
          TextField("tag", text: $model.pendingTag)
            .textFieldStyle(.roundedBorder)
            .onSubmit {
              model.addPendingTag()
            }
          Button {
            model.addPendingTag()
          } label: {
            Image(systemName: "plus")
          }
          .help("添加 tag")
        }
        if let tagError = model.tagError {
          Text(tagError)
            .foregroundStyle(.red)
            .font(.caption)
        }
      }

      VStack(alignment: .leading, spacing: 6) {
        Text("每帧时长")
          .font(.caption)
          .foregroundStyle(.secondary)
        ScrollView {
          VStack(alignment: .leading, spacing: 6) {
            ForEach(model.frameDurations) { item in
              HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                  Text("第 \(item.index + 1) 帧")
                    .font(.caption)
                  Text("(\(item.column), \(item.row))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
                .frame(width: 78, alignment: .leading)

                Stepper(
                  value: Binding(
                    get: { model.durationMsForFrame(at: item.index) },
                    set: { model.setFrameDuration(index: item.index, durationMs: $0) }
                  ),
                  in: ActionEditorViewModel.frameDurationRange,
                  step: 10
                ) {
                  Text("\(model.durationMsForFrame(at: item.index))ms")
                    .monospacedDigit()
                    .frame(width: 58, alignment: .trailing)
                }
              }
            }
          }
        }
        .frame(maxHeight: 190)
        if let frameDurationError = model.frameDurationError {
          Text(frameDurationError)
            .foregroundStyle(.red)
            .font(.caption)
        }
      }

      if let previewNotice = model.previewNotice {
        Text(previewNotice)
          .foregroundStyle(.secondary)
          .font(.caption)
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
          model.save()
        }
        .keyboardShortcut(.defaultAction)
      }
    }
    .padding(20)
    .frame(width: 440)
  }
}

@MainActor
private struct FlowTagList: View {
  let tags: [String]
  let onRemove: (String) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      ForEach(tags, id: \.self) { tag in
        HStack(spacing: 6) {
          Text(tag)
            .font(.caption)
            .lineLimit(1)
          Button {
            onRemove(tag)
          } label: {
            Image(systemName: "xmark.circle.fill")
          }
          .buttonStyle(.plain)
          .help("移除 tag")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.secondary.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 4))
      }
    }
  }
}
