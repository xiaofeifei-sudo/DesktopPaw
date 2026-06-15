import SwiftUI

@MainActor
public struct AISettingsView: View {
    @ObservedObject private var model: AISettingsViewModel

    public init(model: AISettingsViewModel) {
        self.model = model
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            aiToggleSection
            if model.isAIEnabled {
                Divider()
                providerSection
                Divider()
                personalitySection
                Divider()
                initiativeBubbleSection
                Divider()
                memoryToggleSection
                Divider()
                memoryActionsSection
            }

            Spacer(minLength: 0)
        }
        .sheet(isPresented: $model.showPrivacyNotice) {
            privacyNoticeSheet
        }
        .sheet(isPresented: $model.showProviderConfig) {
            providerConfigSheet
        }
        .sheet(isPresented: $model.showMemoryManager) {
            if let memoryManagementViewModel = model.memoryManagementViewModel {
                MemoryManagementView(model: memoryManagementViewModel)
            } else if let memoryViewModel = model.memoryViewModel {
                AIMemoryView(model: memoryViewModel)
            }
        }
    }

    private var aiToggleSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.AI.title)
                    .font(.headline)
                Text(L10n.AI.aiOffWarning)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if model.isAIEnabled {
                Button(L10n.AI.disableAI, role: .destructive) {
                    model.disableAI()
                }
                .buttonStyle(.bordered)
            } else {
                Button(L10n.AI.enableAI) {
                    model.requestEnableAI()
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private var providerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(L10n.AI.aiProvider)
                .font(.subheadline.weight(.medium))
            HStack {
                if model.isConfigured {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text(L10n.AI.configured)
                        .font(.caption)
                } else {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundStyle(.orange)
                    Text(L10n.AI.notConfigured)
                        .font(.caption)
                }
                Spacer()
                Button(L10n.AI.configure) {
                    model.openProviderConfig()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }

    private var personalitySection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(L10n.AI.personality)
                .font(.subheadline.weight(.medium))

            Picker(L10n.AI.personality, selection: Binding(
                get: { model.preferences.selectedPersonalityId },
                set: { model.setPersonality($0) }
            )) {
                ForEach(model.personalityProfiles, id: \.id) { profile in
                    Text(profile.name).tag(profile.id)
                }
            }
            .pickerStyle(.segmented)

            if let profile = model.selectedProfile {
                VStack(alignment: .leading, spacing: 2) {
                    Text(profile.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let phrase = profile.previewPhrases.first {
                        Text("\"\(phrase)\"")
                            .font(.caption)
                            .italic()
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(.top, 2)
            }
        }
    }

    private var initiativeBubbleSection: some View {
        Toggle(L10n.AI.allowInitiativeBubbles, isOn: Binding(
            get: { model.preferences.allowInitiativeBubble },
            set: { model.setAllowInitiativeBubble($0) }
        ))
    }

    private var memoryToggleSection: some View {
        Toggle(L10n.AI.memory, isOn: Binding(
            get: { model.preferences.isMemoryEnabled },
            set: { model.setMemoryEnabled($0) }
        ))
    }

    private var memoryActionsSection: some View {
        HStack(spacing: 12) {
            Button(L10n.AI.viewManageMemory) {
                model.openMemoryManager()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Button(L10n.AI.exportMemory) {
                model.exportMemory()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Button(L10n.AI.clearAllMemory, role: .destructive) {
                model.clearMemory()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    private var privacyNoticeSheet: some View {
        VStack(spacing: 16) {
            Text(L10n.AI.beforeEnablingAI)
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                privacyRow(icon: "text.bubble", text: L10n.AI.privacyProcessing)
                privacyRow(icon: "brain", text: L10n.AI.privacyMemory)
                privacyRow(icon: "xmark.circle", text: L10n.AI.privacyDisable)
                privacyRow(icon: "trash", text: L10n.AI.privacyManage)
                privacyRow(icon: "exclamationmark.triangle", text: L10n.AI.privacyDisclaimer)
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            HStack(spacing: 16) {
                Button(L10n.Common.cancel) {
                    model.showPrivacyNotice = false
                }
                .keyboardShortcut(.cancelAction)

                Button(L10n.AI.iUnderstand) {
                    model.confirmEnableAI()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 380)
    }

    private var providerConfigSheet: some View {
        VStack(spacing: 16) {
            Text(L10n.AI.configureAIProvider)
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                LabeledContent(L10n.AI.protocol_) {
                    Picker("", selection: $model.selectedProtocol) {
                        ForEach(AIProviderProtocol.allCases, id: \.self) { proto in
                            Text(proto == .openai ? L10n.AI.openAI : L10n.AI.anthropic).tag(proto)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 200)
                }

                LabeledContent(L10n.AI.apiEndpoint) {
                    TextField(
                        model.selectedProtocol == .anthropic
                            ? "https://api.anthropic.com"
                            : "https://api.openai.com/v1",
                        text: $model.endpointInput
                    )
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 260)
                }
                LabeledContent(L10n.AI.model) {
                    TextField(
                        model.selectedProtocol == .anthropic ? "claude-sonnet-4-20250514" : "gpt-4o-mini",
                        text: $model.modelInput
                    )
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 160)
                }
                LabeledContent(L10n.AI.apiKey) {
                    SecureField("sk-...", text: $model.apiKeyInput)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 260)
                }
            }

            HStack(spacing: 16) {
                Button(L10n.Common.cancel) {
                    model.showProviderConfig = false
                }
                .keyboardShortcut(.cancelAction)

                Button(L10n.Common.save) {
                    model.saveProviderConfig()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(model.apiKeyInput.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 420)
    }

    private func privacyRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .frame(width: 20)
                .foregroundStyle(.secondary)
            Text(text)
                .font(.callout)
        }
    }
}
