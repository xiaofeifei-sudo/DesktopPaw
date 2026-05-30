import SwiftUI

struct MemoryListView: View {
    let groups: [(category: AIMemoryCategory, memories: [AIMemory])]
    let onDelete: (AIMemory) -> Void
    let onEdit: (AIMemory) -> Void
    let onBatchDelete: (AIMemoryCategory) -> Void

    var body: some View {
        List {
            ForEach(groups, id: \.category) { group in
                Section {
                    ForEach(group.memories) { memory in
                        MemoryItemView(
                            memory: memory,
                            onDelete: { onDelete(memory) },
                            onEdit: { onEdit(memory) }
                        )
                    }
                } header: {
                    sectionHeader(for: group)
                }
            }
        }
        .listStyle(.inset)
    }

    private func sectionHeader(for group: (category: AIMemoryCategory, memories: [AIMemory])) -> some View {
        HStack {
            Text(group.category.displayName)
                .font(.subheadline.weight(.semibold))
            Text("(\(group.memories.count))")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .contextMenu {
            Button("Delete All \(group.category.displayName)", role: .destructive) {
                onBatchDelete(group.category)
            }
        }
    }
}

struct MemoryItemView: View {
    let memory: AIMemory
    let onDelete: () -> Void
    let onEdit: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                Text(memory.content)
                    .font(.body)
                    .lineLimit(3)

                HStack(spacing: 8) {
                    categoryTag
                    sourceTag
                    if memory.importance >= 0.8 {
                        importanceIndicator
                    }
                    if memory.expiresAt != nil && memory.expiresAt! < Date() {
                        expiredTag
                    }
                    Text(memory.updatedAt, style: .date)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            Button {
                onEdit()
            } label: {
                Image(systemName: "pencil")
            }
            .buttonStyle(.borderless)
            .controlSize(.small)

            Button(role: .destructive) {
                onDelete()
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .controlSize(.small)
        }
        .padding(.vertical, 2)
        .contextMenu {
            Button("Edit") { onEdit() }
            Divider()
            Button("Delete", role: .destructive) { onDelete() }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
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

    private var importanceIndicator: some View {
        Image(systemName: "star.fill")
            .font(.caption2)
            .foregroundStyle(.yellow)
    }

    private var expiredTag: some View {
        Text("Expired")
            .font(.caption2)
            .foregroundStyle(.red)
    }
}
