import SwiftUI

@MainActor
public struct AIVisualFavoriteEditorView: View {
    private let asset: PetVisualAsset
    @State private var name: String
    private let isRegularLook: Bool
    private let onRename: (String?) -> Void
    private let onSetRegularLook: () -> Void
    private let onClearRegularLook: () -> Void
    private let onDelete: () -> Void
    private let onCancel: () -> Void

    public init(
        asset: PetVisualAsset,
        name: String,
        isRegularLook: Bool,
        onRename: @escaping (String?) -> Void,
        onSetRegularLook: @escaping () -> Void,
        onClearRegularLook: @escaping () -> Void,
        onDelete: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.asset = asset
        self._name = State(initialValue: name)
        self.isRegularLook = isRegularLook
        self.onRename = onRename
        self.onSetRegularLook = onSetRegularLook
        self.onClearRegularLook = onClearRegularLook
        self.onDelete = onDelete
        self.onCancel = onCancel
    }

    public var body: some View {
        VStack(spacing: 16) {
            Text("Edit Favorite")
                .font(.headline)

            if let image = NSImage(contentsOf: asset.localURL) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Name")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("Favorite name", text: $name)
                    .textFieldStyle(.roundedBorder)
            }

            if isRegularLook {
                Button("Remove as Regular Look") {
                    onClearRegularLook()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            } else {
                Button("Set as Regular Look") {
                    onSetRegularLook()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            Divider()

            HStack {
                Button("Delete Favorite", role: .destructive) {
                    onDelete()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Spacer()

                Button("Cancel") {
                    onCancel()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button("Save") {
                    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                    onRename(trimmed.isEmpty ? nil : trimmed)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding(20)
        .frame(width: 280)
    }
}
