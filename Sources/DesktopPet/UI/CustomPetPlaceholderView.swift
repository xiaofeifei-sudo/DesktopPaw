import SwiftUI

public struct CustomPetPlaceholderView: View {
    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.PetLibrary.plannedNotice)
                .foregroundStyle(.secondary)
            Text("Reserved package folder: \(SettingsViewModel.customPetPackageFolder)")
                .textSelection(.enabled)
            Text("Future format: \(SettingsViewModel.customPetPackageFormat)")
                .textSelection(.enabled)
            Button(L10n.PetLibrary.importLater) {}
                .disabled(true)
        }
    }
}
