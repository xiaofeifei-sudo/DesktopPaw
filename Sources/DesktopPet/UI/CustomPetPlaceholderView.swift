import SwiftUI

public struct CustomPetPlaceholderView: View {
    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Custom pet packages are planned for a future version.")
                .foregroundStyle(.secondary)
            Text("Reserved package folder: \(SettingsViewModel.customPetPackageFolder)")
                .textSelection(.enabled)
            Text("Future format: \(SettingsViewModel.customPetPackageFormat)")
                .textSelection(.enabled)
            Button("Import Later") {}
                .disabled(true)
        }
    }
}
