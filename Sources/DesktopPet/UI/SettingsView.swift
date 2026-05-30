import SwiftUI

public struct SettingsView: View {
    @ObservedObject private var model: SettingsViewModel
    private let companionModel: CompanionshipSettingsViewModel?
    private let interactiveBubbleModel: InteractiveBubbleSettingsViewModel?
    private let aiModel: AISettingsViewModel?
    private let libraryModel: PetLibraryViewModel?
    private let importModel: PetImportViewModel?
    private let petdexURLImportModel: PetdexURLImportViewModel?
    private let aiVisualModel: AIVisualSettingsViewModel?
    private let actionLibraryModel: ActionLibraryViewModel?

    public init(
        model: SettingsViewModel,
        companionModel: CompanionshipSettingsViewModel? = nil,
        interactiveBubbleModel: InteractiveBubbleSettingsViewModel? = nil,
        aiModel: AISettingsViewModel? = nil,
        aiVisualModel: AIVisualSettingsViewModel? = nil,
        libraryModel: PetLibraryViewModel? = nil,
        importModel: PetImportViewModel? = nil,
        petdexURLImportModel: PetdexURLImportViewModel? = nil,
        actionLibraryModel: ActionLibraryViewModel? = nil
    ) {
        self.model = model
        self.companionModel = companionModel
        self.interactiveBubbleModel = interactiveBubbleModel
        self.aiModel = aiModel
        self.aiVisualModel = aiVisualModel
        self.libraryModel = libraryModel
        self.importModel = importModel
        self.petdexURLImportModel = petdexURLImportModel
        self.actionLibraryModel = actionLibraryModel
    }

    public var body: some View {
        Form {
            Section("Desktop Pet") {
                Toggle(
                    "Show Pet",
                    isOn: Binding(
                        get: { model.isPetVisible },
                        set: { model.setPetVisible($0) }
                    )
                )

                HStack {
                    Slider(
                        value: Binding(
                            get: { model.petScale },
                            set: { model.setPetScale($0) }
                        ),
                        in: PreferencesStore.petScaleRange,
                        step: 0.05
                    )
                    Text("\(model.petScale, specifier: "%.2f")x")
                        .monospacedDigit()
                        .frame(width: 56, alignment: .trailing)
                }

                Toggle(
                    "Random Walking",
                    isOn: Binding(
                        get: { model.isRandomWalkingEnabled },
                        set: { model.setRandomWalkingEnabled($0) }
                    )
                )

                Toggle(
                    "Sound",
                    isOn: Binding(
                        get: { model.isSoundEnabled },
                        set: { model.setSoundEnabled($0) }
                    )
                )

                Toggle(
                    "Launch at Login",
                    isOn: Binding(
                        get: { model.isLaunchAtLoginEnabled },
                        set: { model.setLaunchAtLoginEnabled($0) }
                    )
                )

                HStack {
                    Text("Status")
                    Spacer()
                    Text(model.petStatusText)
                        .foregroundStyle(.secondary)
                }

                Button("Reset Position") {
                    model.resetPosition()
                }
            }

            Section("Custom Pet") {
                if let libraryModel, let importModel {
                    PetLibraryView(
                        libraryModel: libraryModel,
                        importModel: importModel,
                        petdexURLImportModel: petdexURLImportModel,
                        actionLibraryModel: actionLibraryModel
                    )
                } else {
                    CustomPetPlaceholderView()
                }
            }

            Section("Speech Bubbles") {
                PetBubbleSettingsView(model: model)
            }

            if let interactiveBubbleModel {
                Section("Smart Bubbles") {
                    InteractiveBubbleSettingsView(model: interactiveBubbleModel)
                }
            }

            if let companionModel {
                Section("Companionship") {
                    CompanionshipSettingsView(model: companionModel)
                }
            }

            if let aiModel {
                Section("AI Companion") {
                    AISettingsView(model: aiModel)
                }
            }

            if let aiVisualModel {
                Section("AI Visual Expression") {
                    AIVisualSettingsView(model: aiVisualModel)
                }
            }
        }
        .formStyle(.grouped)
        .padding(20)
        .frame(width: 460, height: 680)
    }
}
