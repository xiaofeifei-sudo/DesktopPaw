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
                Text("AI Companion")
                    .font(.headline)
                Text("AI features are off by default. Enable to chat with your pet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if model.isAIEnabled {
                Button("Disable AI", role: .destructive) {
                    model.disableAI()
                }
                .buttonStyle(.bordered)
            } else {
                Button("Enable AI") {
                    model.requestEnableAI()
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private var providerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("AI Provider")
                .font(.subheadline.weight(.medium))
            HStack {
                if model.isConfigured {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Configured")
                        .font(.caption)
                } else {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundStyle(.orange)
                    Text("Not configured — set up API key to start chatting")
                        .font(.caption)
                }
                Spacer()
                Button("Configure") {
                    model.openProviderConfig()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }

    private var personalitySection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Personality")
                .font(.subheadline.weight(.medium))

            Picker("Personality", selection: Binding(
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
        Toggle("Allow AI initiative bubbles", isOn: Binding(
            get: { model.preferences.allowInitiativeBubble },
            set: { model.setAllowInitiativeBubble($0) }
        ))
    }

    private var memoryToggleSection: some View {
        Toggle("Memory", isOn: Binding(
            get: { model.preferences.isMemoryEnabled },
            set: { model.setMemoryEnabled($0) }
        ))
    }

    private var memoryActionsSection: some View {
        HStack(spacing: 12) {
            Button("View & Manage Memory") {
                model.openMemoryManager()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Button("Export Memory") {
                model.exportMemory()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Button("Clear All Memory", role: .destructive) {
                model.clearMemory()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    private var privacyNoticeSheet: some View {
        VStack(spacing: 16) {
            Text("Before Enabling AI")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                privacyRow(icon: "text.bubble", text: "AI will process the text messages you send to your pet.")
                privacyRow(icon: "brain", text: "AI may use memory to remember your preferences and nicknames (if enabled).")
                privacyRow(icon: "xmark.circle", text: "You can disable AI at any time from this settings page.")
                privacyRow(icon: "trash", text: "You can view, edit, and clear all AI memory at any time.")
                privacyRow(icon: "exclamationmark.triangle", text: "AI cannot replace professional medical, legal, or financial advice.")
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            HStack(spacing: 16) {
                Button("Cancel") {
                    model.showPrivacyNotice = false
                }
                .keyboardShortcut(.cancelAction)

                Button("I Understand, Enable AI") {
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
            Text("Configure AI Provider")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                LabeledContent("Protocol") {
                    Picker("", selection: $model.selectedProtocol) {
                        ForEach(AIProviderProtocol.allCases, id: \.self) { proto in
                            Text(proto == .openai ? "OpenAI" : "Anthropic").tag(proto)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 200)
                }

                LabeledContent("API Endpoint") {
                    TextField(
                        model.selectedProtocol == .anthropic
                            ? "https://api.anthropic.com"
                            : "https://api.openai.com/v1",
                        text: $model.endpointInput
                    )
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 260)
                }
                LabeledContent("Model") {
                    TextField(
                        model.selectedProtocol == .anthropic ? "claude-sonnet-4-20250514" : "gpt-4o-mini",
                        text: $model.modelInput
                    )
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 160)
                }
                LabeledContent("API Key") {
                    SecureField("sk-...", text: $model.apiKeyInput)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 260)
                }
            }

            HStack(spacing: 16) {
                Button("Cancel") {
                    model.showProviderConfig = false
                }
                .keyboardShortcut(.cancelAction)

                Button("Save") {
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
