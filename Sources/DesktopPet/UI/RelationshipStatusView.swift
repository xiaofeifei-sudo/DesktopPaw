import SwiftUI

@MainActor
public struct RelationshipStatusView: View {
    @ObservedObject private var model: CompanionshipSettingsViewModel

    public init(model: CompanionshipSettingsViewModel) {
        self.model = model
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Relationship")
                    .font(.headline)
                Spacer()
                Text(model.levelDisplayText)
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: model.progressFraction)
                .progressViewStyle(.linear)

            HStack {
                Text(model.progressText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
    }
}
