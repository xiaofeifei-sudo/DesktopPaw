@preconcurrency import AppKit
import Foundation
import UniformTypeIdentifiers

public struct ActionPackFrameItem: Identifiable, Equatable {
    public let id: String
    public let column: Int
    public let row: Int
    public var isSelected: Bool
    public var previewImage: NSImage?

    public init(column: Int, row: Int, isSelected: Bool = true, previewImage: NSImage? = nil) {
        self.id = "\(column)_\(row)"
        self.column = column
        self.row = row
        self.isSelected = isSelected
        self.previewImage = previewImage
    }
}

@MainActor
public final class ActionPackImportWizardViewModel: ObservableObject {
    // MARK: - Published State

    @Published public var phase: Phase = .selectImage
    @Published public var displayName: String = ""
    @Published public var frameDurationMs: Double = 160
    @Published public var loop: Bool = false
    @Published public var frames: [ActionPackFrameItem] = []
    @Published public var gridColumns: Int = 1
    @Published public var gridRows: Int = 1
    @Published public var errorMessage: String?
    @Published public var isSaving: Bool = false
    @Published public var availablePresets: [GridPreset] = []

    public enum Phase: Equatable {
        case selectImage
        case selectFrames
        case configure
        case preview
    }

    // MARK: - Dependencies

    private let definition: PetDefinition
    private let draftBuilder: ActionPackDraftBuilder
    private let onSave: (ActionPackDraft) -> Void
    private let onCancel: () -> Void

    public var frameSize: CGSizeCodable? { definition.frameSize }

    private var selectedImageData: Data?
    private var normalizedImage: NormalizedActionImage?

    public init(
        definition: PetDefinition,
        draftBuilder: ActionPackDraftBuilder = ActionPackDraftBuilder(),
        onSave: @escaping (ActionPackDraft) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.definition = definition
        self.draftBuilder = draftBuilder
        self.onSave = onSave
        self.onCancel = onCancel
    }

    // MARK: - Image Selection

    public func selectImage(from url: URL) {
        guard let data = try? Data(contentsOf: url) else {
            errorMessage = "无法读取图片文件。请确认文件格式为 PNG 或 JPG。"
            return
        }

        selectedImageData = data

        do {
            let normalizer = DefaultActionImageNormalizer()
            let normalized = try normalizer.normalize(
                .singleImage(data),
                targetFrameSize: definition.frameSize
            )
            normalizedImage = normalized

            let analyzer = DefaultActionGridAnalyzer()
            let analysis = analyzer.analyze(normalized, targetFrameSize: definition.frameSize)
            gridColumns = analysis.columns
            gridRows = analysis.rows
            availablePresets = analysis.suggestedPresets

            generateFrames()
            phase = .selectFrames
            errorMessage = nil
        } catch {
            errorMessage = "图片处理失败：\(error.localizedDescription)"
        }
    }

    public func selectMultipleImages(from urls: [URL]) {
        let images = urls.compactMap { try? Data(contentsOf: $0) }
        guard !images.isEmpty else {
            errorMessage = "无法读取所选图片。请确认文件格式为 PNG 或 JPG。"
            return
        }

        do {
            let normalizer = DefaultActionImageNormalizer()
            let normalized = try normalizer.normalize(
                .multipleImages(images),
                targetFrameSize: definition.frameSize
            )
            normalizedImage = normalized

            let analyzer = DefaultActionGridAnalyzer()
            let analysis = analyzer.analyze(normalized, targetFrameSize: definition.frameSize)
            gridColumns = analysis.columns
            gridRows = analysis.rows
            availablePresets = analysis.suggestedPresets

            generateFrames()
            phase = .selectFrames
            errorMessage = nil
        } catch {
            errorMessage = "图片处理失败：\(error.localizedDescription)"
        }
    }

    // MARK: - Grid Preset

    public func applyPreset(_ preset: GridPreset) {
        gridColumns = preset.columns
        gridRows = preset.rows
        generateFrames()
    }

    // MARK: - Frame Selection

    public func toggleFrame(_ frameId: String) {
        guard let index = frames.firstIndex(where: { $0.id == frameId }) else { return }
        frames[index].isSelected.toggle()
    }

    public func selectAllFrames() {
        for i in frames.indices {
            frames[i].isSelected = true
        }
    }

    public func deselectAllFrames() {
        for i in frames.indices {
            frames[i].isSelected = false
        }
    }

    public func moveFrame(from source: IndexSet, to destination: Int) {
        frames.move(fromOffsets: source, toOffset: destination)
    }

    // MARK: - Navigation

    public func proceedToConfigure() {
        let selectedCount = frames.filter { $0.isSelected }.count
        guard selectedCount > 0 else {
            errorMessage = "请至少选择一帧。"
            return
        }
        errorMessage = nil
        phase = .configure
    }

    public func proceedToPreview() {
        guard !displayName.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "请输入动作名称。"
            return
        }
        errorMessage = nil
        phase = .preview
    }

    public func goBack() {
        switch phase {
        case .selectImage:
            cancel()
        case .selectFrames:
            phase = .selectImage
        case .configure:
            phase = .selectFrames
        case .preview:
            phase = .configure
        }
    }

    public func cancel() {
        onCancel()
    }

    // MARK: - Save

    public func save() {
        guard !displayName.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "请输入动作名称。"
            return
        }

        let selectedFrames: [ActionFrameSelection] = frames
            .filter { $0.isSelected }
            .enumerated()
            .map { index, item in
                ActionFrameSelection(
                    column: item.column,
                    row: item.row,
                    durationMs: Int(frameDurationMs)
                )
            }

        guard !selectedFrames.isEmpty else {
            errorMessage = "请至少选择一帧。"
            return
        }

        isSaving = true
        errorMessage = nil

        do {
            let draft = try draftBuilder.buildDraft(
                input: .singleImage(selectedImageData ?? Data()),
                displayName: displayName.trimmingCharacters(in: .whitespaces),
                targetFrameSize: definition.frameSize,
                frameDurationMs: Int(frameDurationMs),
                loop: loop,
                gridOverride: (columns: gridColumns, rows: gridRows),
                selectedFrames: selectedFrames,
                source: .localImage
            )
            onSave(draft)
        } catch {
            errorMessage = "保存失败：\(error.localizedDescription)"
            isSaving = false
        }
    }

    // MARK: - Helpers

    private func generateFrames() {
        frames = (0..<gridRows).flatMap { row in
            (0..<gridColumns).map { col in
                ActionPackFrameItem(column: col, row: row)
            }
        }
    }
}
