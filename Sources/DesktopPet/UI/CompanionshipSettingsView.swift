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
                L10n.Companionship.showRelationshipPrompts,
                isOn: Binding(
                    get: { model.preferences.showRelationshipPrompts },
                    set: { model.setRelationshipPromptsEnabled($0) }
                )
            )

            Divider()

            TextField(L10n.Companionship.petNickname, text: Binding(
                get: { model.currentPetNickname ?? "" },
                set: { model.setPetNickname($0) }
            ))

            TextField(L10n.Settings.yourNickname, text: Binding(
                get: { model.preferences.userNickname ?? "" },
                set: { model.setUserNickname($0) }
            ))

            Divider()

            QuietModeSettingsView(model: model)

            Divider()

            Button(L10n.Companionship.resetRelationship, role: .destructive) {
                showingResetConfirmation = true
            }
            .confirmationDialog(
                L10n.Companionship.resetConfirmTitle,
                isPresented: $showingResetConfirmation,
                titleVisibility: .visible
            ) {
                Button(L10n.Companionship.reset, role: .destructive) {
                    model.resetRelationship()
                }
                Button(L10n.Common.cancel, role: .cancel) {}
            } message: {
                Text(L10n.Companionship.resetMessage)
            }
        }
    }
}
