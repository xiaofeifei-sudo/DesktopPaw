import SwiftUI

public struct SettingsView: View {
    @ObservedObject private var model: SettingsViewModel
    @ObservedObject private var languageManager: LanguageManager
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
        actionLibraryModel: ActionLibraryViewModel? = nil,
        languageManager: LanguageManager? = nil
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
        self.languageManager = languageManager ?? LanguageManager()
    }

    public var body: some View {
        Form {
            Section(L10n.Settings.desktopPet) {
                Toggle(
                    L10n.Settings.showPet,
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
                    L10n.Settings.randomWalking,
                    isOn: Binding(
                        get: { model.isRandomWalkingEnabled },
                        set: { model.setRandomWalkingEnabled($0) }
                    )
                )

                Toggle(
                    L10n.Settings.sound,
                    isOn: Binding(
                        get: { model.isSoundEnabled },
                        set: { model.setSoundEnabled($0) }
                    )
                )

                Toggle(
                    L10n.Settings.launchAtLogin,
                    isOn: Binding(
                        get: { model.isLaunchAtLoginEnabled },
                        set: { model.setLaunchAtLoginEnabled($0) }
                    )
                )

                HStack {
                    Text(L10n.Settings.status)
                    Spacer()
                    Text(model.petStatusText)
                        .foregroundStyle(.secondary)
                }

                Button(L10n.Settings.resetPosition) {
                    model.resetPosition()
                }
            }

            Section(L10n.Settings.customPet) {
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

            Section(L10n.Settings.speechBubbles) {
                PetBubbleSettingsView(model: model)
            }

            if let interactiveBubbleModel {
                Section(L10n.Settings.smartBubbles) {
                    InteractiveBubbleSettingsView(model: interactiveBubbleModel)
                }
            }

            if let companionModel {
                Section(L10n.Settings.companionship) {
                    CompanionshipSettingsView(model: companionModel)
                }
            }

            if let aiModel {
                Section(L10n.Settings.aiCompanion) {
                    AISettingsView(model: aiModel)
                }
            }

            if let aiVisualModel {
                Section(L10n.Settings.aiVisualExpression) {
                    AIVisualSettingsView(model: aiVisualModel)
                }
            }

            Section(L10n.Settings.language) {
                Picker(L10n.Settings.language, selection: $languageManager.currentLanguage) {
                    ForEach(AppLanguage.allCases, id: \.self) { lang in
                        Text(lang.displayName).tag(lang)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
        .formStyle(.grouped)
        .padding(20)
        .frame(width: 460, height: 680)
    }
}
