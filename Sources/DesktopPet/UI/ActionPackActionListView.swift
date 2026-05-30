import SwiftUI

@MainActor
public struct ActionPackActionListView: View {
    @ObservedObject private var model: ActionLibraryViewModel

    public init(model: ActionLibraryViewModel) {
        self.model = model
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("追加动作管理")
                .font(.headline)

            let extraRows = model.rows.filter { $0.role == nil }

            if extraRows.isEmpty {
                Text("暂无追加动作。")
                    .foregroundStyle(.secondary)
                    .font(.callout)
            } else {
                ForEach(extraRows) { row in
                    HStack(spacing: 10) {
                        if let image = row.previewImage {
                            Image(nsImage: image)
                                .resizable()
                                .interpolation(.none)
                                .scaledToFit()
                                .frame(width: 36, height: 36)
                                .background(Color.secondary.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        } else {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.secondary.opacity(0.08))
                                .frame(width: 36, height: 36)
                                .overlay(Image(systemName: "photo").foregroundStyle(.secondary))
                        }

                        Text(row.displayName)
                            .font(.body)
                            .lineLimit(1)

                        Spacer()

                        Button {
                            model.disableAction(row.actionId)
                        } label: {
                            Label("禁用", systemImage: "eye.slash")
                        }
                        .controlSize(.small)
                    }
                    .padding(.vertical, 4)

                    if row.id != extraRows.last?.id {
                        Divider()
                    }
                }
            }
        }
        .padding(20)
        .frame(width: 360)
    }
}
