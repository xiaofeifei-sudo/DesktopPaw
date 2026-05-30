import SwiftUI

@MainActor
public struct CompanionshipSettingsView: View {
    @ObservedObject private var model: CompanionshipSettingsViewModel
    @State private var showingResetConfirmation = false

    public init(model: CompanionshipSettingsViewModel) {
        self.model = model
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            RelationshipStatusView(model: model)

            Toggle(
                "Show relationship prompts",
                isOn: Binding(
                    get: { model.preferences.showRelationshipPrompts },
                    set: { model.setRelationshipPromptsEnabled($0) }
                )
            )

            Divider()

            TextField("Pet nickname", text: Binding(
                get: { model.currentPetNickname ?? "" },
                set: { model.setPetNickname($0) }
            ))

            TextField("Your nickname", text: Binding(
                get: { model.preferences.userNickname ?? "" },
                set: { model.setUserNickname($0) }
            ))

            Divider()

            QuietModeSettingsView(model: model)

            Divider()

            Button("Reset relationship", role: .destructive) {
                showingResetConfirmation = true
            }
            .confirmationDialog(
                "Reset relationship?",
                isPresented: $showingResetConfirmation,
                titleVisibility: .visible
            ) {
                Button("Reset", role: .destructive) {
                    model.resetRelationship()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will reset your relationship with the current pet back to Lv.1. This cannot be undone.")
            }
        }
    }
}
