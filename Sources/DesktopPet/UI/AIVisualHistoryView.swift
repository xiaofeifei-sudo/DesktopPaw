import SwiftUI

@MainActor
public struct AIVisualHistoryView: View {
    @ObservedObject private var model: AIVisualHistoryViewModel
    @Environment(\.dismiss) private var dismiss

    public init(model: AIVisualHistoryViewModel) {
        self.model = model
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("History")
                    .font(.headline)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Close")
            }
            .padding(.horizontal, 4)

            if model.favorites.isEmpty && model.historyItems.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if !model.favorites.isEmpty {
                            favoritesSection
                        }
                        if !model.historyItems.isEmpty {
                            historySection
                        }
                    }
                    .padding(.horizontal, 4)
                }

                Divider()

                actionsBar
            }

            if let message = model.feedbackMessage {
                feedbackBar(message)
            }
        }
        .padding(.top, 8)
        .onAppear {
            model.refresh()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("No visual changes yet")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }

    private var favoritesSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Favorites")
                .font(.subheadline.weight(.medium))

            ForEach(model.favorites) { asset in
                favoriteRow(asset)
            }
        }
    }

    private func favoriteRow(_ asset: PetVisualAsset) -> some View {
        HStack(spacing: 8) {
            thumbnailImage(asset.localURL)
                .frame(width: 36, height: 36)
                .clipShape(RoundedRectangle(cornerRadius: 4))

            VStack(alignment: .leading, spacing: 2) {
                Text(model.displayName(for: asset))
                    .font(.caption)
                    .lineLimit(1)
                if model.activeFavoriteId == asset.id {
                    Text("Regular Look")
                        .font(.caption2)
                        .foregroundStyle(.blue)
                }
            }

            Spacer()

            feedbackMenu(for: asset)

            Button {
                model.startEditing(asset)
            } label: {
                Image(systemName: "pencil")
                    .font(.caption)
            }
            .buttonStyle(.plain)

            Button(role: .destructive) {
                model.unmarkFavorite(asset.id)
            } label: {
                Image(systemName: "heart.slash")
                    .font(.caption)
            }
            .buttonStyle(.plain)
        }
        .padding(6)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .contextMenu {
            feedbackMenuItems(for: asset)
        }
        .sheet(isPresented: $model.showEditor) {
            if let editing = model.editingAsset {
                AIVisualFavoriteEditorView(
                    asset: editing,
                    name: model.displayName(for: editing),
                    isRegularLook: model.activeFavoriteId == editing.id,
                    onRename: { newName in
                        model.commitRename(editing.id, newName: newName)
                        model.showEditor = false
                    },
                    onSetRegularLook: {
                        model.setRegularLook(editing.id)
                        model.showEditor = false
                    },
                    onClearRegularLook: {
                        model.clearRegularLook()
                        model.showEditor = false
                    },
                    onDelete: {
                        model.deleteRecord(editing.id)
                        model.showEditor = false
                    },
                    onCancel: {
                        model.showEditor = false
                    }
                )
            }
        }
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("History")
                .font(.subheadline.weight(.medium))

            ForEach(model.historyItems) { asset in
                historyRow(asset)
            }
        }
    }

    private func historyRow(_ asset: PetVisualAsset) -> some View {
        HStack(spacing: 8) {
            thumbnailImage(asset.localURL)
                .frame(width: 36, height: 36)
                .clipShape(RoundedRectangle(cornerRadius: 4))

            VStack(alignment: .leading, spacing: 2) {
                Text("\(asset.kind.rawValue)")
                    .font(.caption)
                    .lineLimit(1)
                Text(formatDate(asset.createdAt))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            feedbackMenu(for: asset)

            Button {
                model.markFavorite(asset.id)
            } label: {
                Image(systemName: "heart")
                    .font(.caption)
            }
            .buttonStyle(.plain)

            Button(role: .destructive) {
                model.deleteRecord(asset.id)
            } label: {
                Image(systemName: "trash")
                    .font(.caption)
            }
            .buttonStyle(.plain)
        }
        .padding(6)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .contextMenu {
            feedbackMenuItems(for: asset)
        }
    }

    private func feedbackMenu(for asset: PetVisualAsset) -> some View {
        Menu {
            feedbackMenuItems(for: asset)
        } label: {
            Image(systemName: "bubble.left")
                .font(.caption)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help("反馈")
    }

    @ViewBuilder
    private func feedbackMenuItems(for asset: PetVisualAsset) -> some View {
        ForEach(PreviewFeedbackType.allCases, id: \.self) { type in
            Button(type.displayText) {
                model.recordFeedback(type, for: asset)
            }
        }
    }

    private var actionsBar: some View {
        HStack {
            if !model.historyItems.isEmpty {
                Button("Clear History") {
                    model.clearHistory()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            Spacer()
            if !model.favorites.isEmpty || !model.historyItems.isEmpty {
                Button("Clear All", role: .destructive) {
                    model.clearAll()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }

    private func feedbackBar(_ message: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "info.circle")
                .foregroundStyle(.secondary)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                model.clearFeedback()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption2)
            }
            .buttonStyle(.plain)
        }
    }

    private func thumbnailImage(_ url: URL) -> some View {
        Group {
            if let image = NSImage(contentsOf: url) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: "photo")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
