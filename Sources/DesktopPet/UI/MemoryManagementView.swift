import SwiftUI

@MainActor
public final class MemoryManagementViewModel: ObservableObject {
    @Published public private(set) var memories: [AIMemory] = []
    @Published public private(set) var emotionalModel: AIEmotionalModel?
    @Published public private(set) var statistics: MemoryStatistics?
    @Published public var searchText = ""
    @Published public var selectedCategory: AIMemoryCategory? = nil
    @Published public var showAddSheet = false
    @Published public var showStatistics = false
    @Published public var editingMemory: AIMemory?
    @Published public var editedContent = ""
    @Published public var showClearConfirmation = false
    @Published public var showExportSuccess = false
    @Published public var exportError: String?
    @Published public var showBatchDeleteConfirmation = false
    @Published public var batchDeleteCategory: AIMemoryCategory?

    private let memoryStore: AIMemoryStoring
    private let emotionalModelStore: EmotionalModelStoring?
    public private(set) var petId: String

    public init(
        memoryStore: AIMemoryStoring,
        emotionalModelStore: EmotionalModelStoring? = nil,
        petId: String
    ) {
        self.memoryStore = memoryStore
        self.emotionalModelStore = emotionalModelStore
        self.petId = petId
    }

    // MARK: - Category Display Order

    static let categoryDisplayOrder: [AIMemoryCategory] = [
        .nickname, .milestone, .custom, .preference, .routine, .emotion, .interaction
    ]

    // MARK: - Computed

    public var filteredMemories: [AIMemory] {
        var result = memories

        if let category = selectedCategory {
            result = result.filter { $0.category == category }
        }

        if !searchText.isEmpty {
            let keyword = searchText.lowercased()
            result = result.filter {
                $0.content.lowercased().contains(keyword)
                    || $0.tags.contains { $0.lowercased().contains(keyword) }
            }
        }

        return result.sorted { $0.updatedAt > $1.updatedAt }
    }

    public var groupedMemories: [(category: AIMemoryCategory, memories: [AIMemory])] {
        let filtered = filteredMemories
        var groups: [AIMemoryCategory: [AIMemory]] = [:]
        for memory in filtered {
            groups[memory.category, default: []].append(memory)
        }
        return Self.categoryDisplayOrder.compactMap { category in
            guard let items = groups[category], !items.isEmpty else { return nil }
            return (category: category, memories: items.sorted { $0.updatedAt > $1.updatedAt })
        }
    }

    public var hasEmotionalData: Bool {
        guard let model = emotionalModel else { return false }
        return model.totalSessions > 0
    }

    // MARK: - Data Loading

    public func loadData() {
        memories = memoryStore.loadAll(petId: petId)
        statistics = memoryStore.memoryStatistics(petId: petId)
        if let store = emotionalModelStore {
            emotionalModel = try? store.loadModel(petId: petId)
        }
    }

    // MARK: - CRUD

    public func delete(_ memory: AIMemory) {
        try? memoryStore.delete(memoryId: memory.id, petId: petId)
        loadData()
    }

    public func addMemory(content: String, category: AIMemoryCategory) {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let memory = AIMemory(
            petId: petId,
            category: category,
            content: trimmed,
            source: .userProvided,
            importance: 0.9
        )
        try? memoryStore.add(memory, petId: petId)
        loadData()
    }

    public func deleteByCategory(_ category: AIMemoryCategory) {
        try? memoryStore.deleteByCategory(category, petId: petId)
        loadData()
    }

    public func clearAll() {
        try? memoryStore.clearAll(petId: petId)
        loadData()
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
            loadData()
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

// MARK: - MemoryManagementView

@MainActor
public struct MemoryManagementView: View {
    @ObservedObject private var model: MemoryManagementViewModel
    @Environment(\.dismiss) private var dismiss

    public init(model: MemoryManagementViewModel) {
        self.model = model
    }

    public var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()

            if model.filteredMemories.isEmpty {
                emptyState
            } else {
                MemoryListView(
                    groups: model.groupedMemories,
                    onDelete: { model.delete($0) },
                    onEdit: { model.startEditing($0) },
                    onBatchDelete: { category in
                        model.batchDeleteCategory = category
                        model.showBatchDeleteConfirmation = true
                    }
                )
            }

            Divider()
            bottomBar
        }
        .frame(minWidth: 440, minHeight: 420)
        .onAppear { model.loadData() }
        .sheet(isPresented: $model.showAddSheet) {
            MemoryAddView { content, category in
                model.addMemory(content: content, category: category)
                model.showAddSheet = false
            }
        }
        .sheet(isPresented: Binding(
            get: { model.editingMemory != nil },
            set: { if !$0 { model.cancelEditing() } }
        )) {
            editMemorySheet
        }
        .sheet(isPresented: $model.showStatistics) {
            if let stats = model.statistics {
                MemoryStatisticsView(
                    statistics: stats,
                    emotionalModel: model.hasEmotionalData ? model.emotionalModel : nil
                )
            }
        }
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
            Button("Clear All", role: .destructive) { model.clearAll() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete all AI memories. This cannot be undone.")
        }
        .confirmationDialog(
            "Delete all memories in this category?",
            isPresented: $model.showBatchDeleteConfirmation,
            titleVisibility: .visible
        ) {
            if let category = model.batchDeleteCategory {
                Button("Delete All \(category.displayName)", role: .destructive) {
                    model.deleteByCategory(category)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete all memories in the selected category.")
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search memories...", text: $model.searchText)
                    .textFieldStyle(.plain)
                if !model.searchText.isEmpty {
                    Button {
                        model.searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 6))

            Menu {
                Button("All") { model.selectedCategory = nil }
                Divider()
                ForEach(AIMemoryCategory.allCases, id: \.self) { category in
                    Button(category.displayName) { model.selectedCategory = category }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(model.selectedCategory?.displayName ?? "All")
                        .font(.caption)
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            Spacer()

            Button {
                model.showStatistics = true
            } label: {
                Image(systemName: "chart.pie")
            }
            .buttonStyle(.borderless)
            .help("Statistics")

            Button {
                model.showAddSheet = true
            } label: {
                Image(systemName: "plus")
            }
            .buttonStyle(.borderless)
            .help("Add Memory")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "brain")
                .font(.system(size: 32))
                .foregroundStyle(.tertiary)
            Text("No memories yet")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Memories will be created as you chat with your pet.\nYou can also add memories manually using the + button.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack {
            if let stats = model.statistics, stats.totalCount > 0 {
                Text("\(stats.totalCount) memories")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Close") { dismiss() }
                .keyboardShortcut(.cancelAction)
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
        .padding(.horizontal, 4)
    }

    // MARK: - Edit Sheet

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
                Button("Cancel") { model.cancelEditing() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") { model.saveEditing() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(model.editedContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 360)
    }
}
