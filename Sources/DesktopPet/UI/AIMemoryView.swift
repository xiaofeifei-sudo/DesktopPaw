import SwiftUI

@MainActor
public struct AIMemoryView: View {
    @ObservedObject private var model: AIMemoryViewModel

    public init(model: AIMemoryViewModel) {
        self.model = model
    }

    public var body: some View {
        VStack(spacing: 0) {
            if model.memories.isEmpty {
                emptyState
            } else {
                memoryList
            }

            Divider()

            HStack {
                Spacer()
                Button("Export") {
                    model.exportMemories()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                Button("Clear All", role: .destructive) {
                    model.showClearConfirmation = true
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(8)
        }
        .frame(minWidth: 300, minHeight: 300)
        .alert("Export Complete", isPresented: $model.showExportSuccess) {
            Button("OK") {}
        } message: {
            Text("Memories exported successfully.")
        }
        .alert("Export Failed", isPresented: Binding(
            get: { model.exportError != nil },
            set: { if !$0 { model.exportError = nil } }
        )) {
            Button("OK") { model.exportError = nil }
        } message: {
            Text(model.exportError ?? "Unknown error")
        }
        .confirmationDialog(
            "Clear all AI memories?",
            isPresented: $model.showClearConfirmation,
            titleVisibility: .visible
        ) {
            Button("Clear All", role: .destructive) {
                model.clearAll()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete all AI memories. This cannot be undone.")
        }
        .sheet(isPresented: Binding(
            get: { model.editingMemory != nil },
            set: { if !$0 { model.cancelEditing() } }
        )) {
            editMemorySheet
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "brain")
                .font(.system(size: 32))
                .foregroundStyle(.tertiary)
            Text("No memories yet")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Memories will be created as you chat with your pet.")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var memoryList: some View {
        List {
            ForEach(model.memories) { memory in
                MemoryRow(memory: memory) { action in
                    switch action {
                    case .edit:
                        model.startEditing(memory)
                    case .delete:
                        model.delete(memory)
                    }
                }
            }
        }
        .listStyle(.inset)
    }

    private var editMemorySheet: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Edit Memory")
                .font(.headline)

            TextEditor(text: $model.editedContent)
                .frame(width: 320, height: 120)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(nsColor: .separatorColor))
                )

            HStack {
                Spacer()
                Button("Cancel") {
                    model.cancelEditing()
                }
                .keyboardShortcut(.cancelAction)

                Button("Save") {
                    model.saveEditing()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(model.editedContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 360)
    }
}

private enum MemoryAction {
    case edit
    case delete
}

private struct MemoryRow: View {
    let memory: AIMemory
    let onAction: (MemoryAction) -> Void

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(memory.content)
                    .font(.body)
                HStack(spacing: 8) {
                    categoryTag
                    sourceTag
                    Text(memory.updatedAt, style: .date)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer()
            Button {
                onAction(.edit)
            } label: {
                Image(systemName: "pencil")
            }
            .buttonStyle(.borderless)
            .controlSize(.small)

            Button(role: .destructive) {
                onAction(.delete)
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .controlSize(.small)
        }
    }

    private var categoryTag: some View {
        Text(memory.category.displayName)
            .font(.caption2)
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 3))
    }

    private var sourceTag: some View {
        Text(memory.source.displayName)
            .font(.caption2)
            .foregroundStyle(.secondary)
    }
}

extension AIMemoryCategory {
    public var displayName: String {
        switch self {
        case .preference: "偏好"
        case .nickname: "昵称"
        case .interaction: "互动"
        case .custom: "自定义"
        case .emotion: "情绪"
        case .milestone: "里程碑"
        case .routine: "日常习惯"
        }
    }
}

extension AIMemorySource {
    public var displayName: String {
        switch self {
        case .userProvided: "用户"
        case .aiExtracted: "AI"
        case .systemGenerated: "系统"
        }
    }
}

@MainActor
public final class AIMemoryViewModel: ObservableObject {
    @Published public private(set) var memories: [AIMemory] = []
    @Published public private(set) var editingMemory: AIMemory?
    @Published public var editedContent = ""
    @Published public var showClearConfirmation = false
    @Published public var showExportSuccess = false
    @Published public var exportError: String?

    private let memoryStore: AIMemoryStoring
    public private(set) var petId: String

    public init(memoryStore: AIMemoryStoring, petId: String) {
        self.memoryStore = memoryStore
        self.petId = petId
    }

    public func loadMemories() {
        memories = memoryStore.loadAll(petId: petId)
    }

    public func delete(_ memory: AIMemory) {
        try? memoryStore.delete(memoryId: memory.id, petId: petId)
        loadMemories()
    }

    public func clearAll() {
        try? memoryStore.clearAll(petId: petId)
        loadMemories()
    }

    public func exportMemories() {
        do {
            showExportSuccess = try AIMemoryExporter(store: memoryStore).exportWithPanel(petId: petId)
        } catch {
            exportError = error.localizedDescription
        }
    }

    public func startEditing(_ memory: AIMemory) {
        editingMemory = memory
        editedContent = memory.content
    }

    public func saveEditing() {
        guard let memory = editingMemory else { return }
        let trimmed = editedContent.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let updated = AIMemory(
            id: memory.id,
            petId: memory.petId,
            category: memory.category,
            content: trimmed,
            createdAt: memory.createdAt,
            updatedAt: Date(),
            source: memory.source,
            importance: memory.importance,
            accessCount: memory.accessCount,
            expiresAt: memory.expiresAt,
            tags: memory.tags
        )

        do {
            try memoryStore.update(updated, petId: petId)
            cancelEditing()
            loadMemories()
        } catch {
            exportError = error.localizedDescription
        }
    }

    public func cancelEditing() {
        editingMemory = nil
        editedContent = ""
    }

    public func updatePetId(_ petId: String) {
        self.petId = petId
    }
}
