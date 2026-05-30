import SwiftUI

@MainActor
public struct ActionPackImportWizardView: View {
    @ObservedObject private var model: ActionPackImportWizardViewModel
    private let imagePanel: ActionPackImageOpenPanel

    public init(
        model: ActionPackImportWizardViewModel,
        imagePanel: ActionPackImageOpenPanel = ActionPackImageOpenPanel()
    ) {
        self.model = model
        self.imagePanel = imagePanel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            Divider()

            switch model.phase {
            case .selectImage:
                selectImagePhase
            case .selectFrames:
                selectFramesPhase
            case .configure:
                configurePhase
            case .preview:
                previewPhase
            }

            if let error = model.errorMessage {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.callout)
            }

            Divider()

            bottomButtons
        }
        .padding(20)
        .frame(width: 420)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("新增动作")
                .font(.headline)
            Spacer()
            phaseIndicator
        }
    }

    private var phaseIndicator: some View {
        HStack(spacing: 4) {
            phaseDot(.selectImage, label: "图片")
            phaseDot(.selectFrames, label: "选帧")
            phaseDot(.configure, label: "设置")
            phaseDot(.preview, label: "保存")
        }
        .font(.caption2)
    }

    private func phaseDot(_ phase: ActionPackImportWizardViewModel.Phase, label: String) -> some View {
        HStack(spacing: 2) {
            Circle()
                .fill(model.phase == phase ? Color.accentColor : Color.secondary.opacity(0.3))
                .frame(width: 6, height: 6)
            Text(label)
                .foregroundStyle(model.phase == phase ? .primary : .secondary)
        }
    }

    // MARK: - Phase 1: Select Image

    private var selectImagePhase: some View {
        VStack(spacing: 12) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)

            Text("选择一张或多张动作图片")
                .font(.callout)
                .foregroundStyle(.secondary)

            Text("系统会自动识别图片网格，你只需要选择帧和命名。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 12) {
                Button("选择图片") {
                    let urls = imagePanel.selectImages()
                    if urls.count == 1 {
                        model.selectImage(from: urls[0])
                    } else if urls.count > 1 {
                        model.selectMultipleImages(from: urls)
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    // MARK: - Phase 2: Select Frames

    private var selectFramesPhase: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("选择要使用的帧")
                .font(.callout)
                .foregroundStyle(.secondary)

            Text("点击帧可以切换选中/取消，拖拽可以调整顺序。")
                .font(.caption)
                .foregroundStyle(.secondary)

            // Grid preset buttons
            if model.availablePresets.count > 1 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(model.availablePresets.indices, id: \.self) { index in
                            let preset = model.availablePresets[index]
                            Button("\(preset.columns)×\(preset.rows)") {
                                model.applyPreset(preset)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                }
            }

            // Frame grid
            let columns = max(1, model.gridColumns)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: columns), spacing: 4) {
                ForEach(model.frames) { frame in
                    frameCell(frame)
                }
            }

            HStack {
                Text("已选 \(model.frames.filter { $0.isSelected }.count) 帧")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("全选") { model.selectAllFrames() }
                    .controlSize(.small)
                Button("取消全选") { model.deselectAllFrames() }
                    .controlSize(.small)
            }
        }
    }

    private func frameCell(_ frame: ActionPackFrameItem) -> some View {
        Button {
            model.toggleFrame(frame.id)
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(frame.isSelected ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(frame.isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
                    )

                if let image = frame.previewImage {
                    Image(nsImage: image)
                        .resizable()
                        .interpolation(.none)
                        .aspectRatio(contentMode: .fit)
                        .padding(2)
                } else {
                    Text("\(frame.column),\(frame.row)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if frame.isSelected {
                    VStack {
                        HStack {
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(Color.accentColor)
                        }
                        Spacer()
                    }
                    .padding(2)
                }
            }
        }
        .buttonStyle(.plain)
        .aspectRatio(1, contentMode: .fit)
    }

    // MARK: - Phase 3: Configure

    private var configurePhase: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("动作名称")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                TextField("例如：挥手、坐下、跳跃", text: $model.displayName)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("播放速度：\(Int(model.frameDurationMs))ms / 帧")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Slider(value: $model.frameDurationMs, in: 50...500, step: 10)
            }

            Toggle("循环播放", isOn: $model.loop)

            if let frameSize = model.frameSize {
                VStack(alignment: .leading, spacing: 4) {
                    Text("图片要求")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Text("每帧尺寸 \(Int(frameSize.width)) × \(Int(frameSize.height)) 像素，支持 PNG 和 JPG 格式。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Phase 4: Preview

    private var previewPhase: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("确认保存")
                .font(.callout)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 4) {
                LabeledContent("动作名称", value: model.displayName)
                LabeledContent("帧数", value: "\(model.frames.filter { $0.isSelected }.count)")
                LabeledContent("播放速度", value: "\(Int(model.frameDurationMs))ms / 帧")
                LabeledContent("循环播放", value: model.loop ? "是" : "否")
            }
            .font(.callout)
            .padding(12)
            .background(Color.secondary.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            Text("保存后可以在动作图鉴中找到这个新动作。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Bottom Buttons

    private var bottomButtons: some View {
        HStack {
            if model.phase != .selectImage {
                Button("上一步") {
                    model.goBack()
                }
            }

            Spacer()

            Button("取消") {
                model.cancel()
            }

            switch model.phase {
            case .selectImage:
                EmptyView()
            case .selectFrames:
                Button("下一步") {
                    model.proceedToConfigure()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!model.frames.contains { $0.isSelected })
            case .configure:
                Button("下一步") {
                    model.proceedToPreview()
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.displayName.trimmingCharacters(in: .whitespaces).isEmpty)
            case .preview:
                Button("保存") {
                    model.save()
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.isSaving)
            }
        }
    }
}
