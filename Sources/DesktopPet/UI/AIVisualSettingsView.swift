import SwiftUI

@MainActor
public struct AIVisualSettingsView: View {
    @ObservedObject private var model: AIVisualSettingsViewModel

    public init(model: AIVisualSettingsViewModel) {
        self.model = model
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            toggleSection
            if model.isEnabled {
                Divider()
                providerSection
                Divider()
                usageSection
                Divider()
                frequencySection
                Divider()
                durationSection
                Divider()
                intensitySection
                Divider()
                consistencySection
                Divider()
                manualGenerationSection
                Divider()
                restoreSection
                Divider()
                historySection
            }

            if let message = model.feedbackMessage {
                Divider()
                feedbackSection(message)
            }

            Spacer(minLength: 0)
        }
        .sheet(isPresented: $model.showEnableNotice) {
            enableNoticeSheet
        }
        .sheet(isPresented: $model.showProviderConfig) {
            providerConfigSheet
        }
        .sheet(isPresented: $model.showHistory) {
            if let historyModel = model.historyModel {
                AIVisualHistoryView(model: historyModel)
                    .frame(width: 380, height: 480)
            }
        }
        .onAppear {
            model.refreshUsage()
            Task { await model.refreshProviderQuota() }
        }
    }

    private var toggleSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("AI Visual Expression")
                    .font(.headline)
                Text("Let AI create temporary visual changes for your pet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if model.isEnabled {
                Button("Disable") {
                    model.disable()
                }
                .buttonStyle(.bordered)
            } else {
                Button("Enable") {
                    model.requestEnable()
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private var providerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Image Provider")
                .font(.subheadline.weight(.medium))

            if model.isProviderConfigured {
                configuredProviderContent
            } else {
                unconfiguredProviderContent
            }
        }
    }

    private var configuredProviderContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text(model.selectedProviderDisplayName)
                    .font(.caption)
                Spacer()
                if !model.isCLIProvider {
                    Button("Reconfigure") {
                        model.openProviderConfig()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }

            if !model.providerInfos.isEmpty {
                Picker("Provider", selection: Binding(
                    get: { model.currentProviderId ?? "" },
                    set: { id in
                        if !id.isEmpty { model.selectProvider(id) }
                    }
                )) {
                    ForEach(model.providerInfos, id: \.providerId) { info in
                        HStack {
                            Text(info.displayName)
                            if !info.isConfigured {
                                Text("(not configured)")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .tag(info.providerId)
                    }
                }
            }

            if model.isCLIProvider {
                mmxPathRow
            }

            if let quotaText = model.providerQuotaText {
                Text(quotaText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var unconfiguredProviderContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(.orange)
                Text("Not configured")
                    .font(.caption)
            }

            if !model.providerInfos.isEmpty {
                Picker("Provider", selection: Binding(
                    get: { model.currentProviderId ?? "" },
                    set: { id in
                        if !id.isEmpty { model.selectProvider(id) }
                    }
                )) {
                    ForEach(model.providerInfos, id: \.providerId) { info in
                        HStack {
                            Text(info.displayName)
                            if !info.isConfigured {
                                Text("(not configured)")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .tag(info.providerId)
                    }
                }
            }

            if model.isCLIProvider {
                mmxPathRow
                mmxSetupGuide
            } else {
                apiProviderUnconfiguredGuide
            }
        }
    }

    private var apiProviderUnconfiguredGuide: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("This provider requires an API key to generate images.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button("Configure") {
                model.openProviderConfig()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
    }

    private var mmxSetupGuide: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Setup Guide")
                .font(.caption.weight(.medium))
            guidanceRow(icon: "arrow.down.circle", text: "Install: `brew install minimax/tap/mmx` or download from minimax.ai")
            guidanceRow(icon: "person.badge.key", text: "Log in: run `mmx auth login` in your command line")
            guidanceRow(icon: "arrow.clockwise", text: "Click \"Check Status\" after installing or logging in")
        }
        .padding(8)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private var mmxPathRow: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
                TextField("mmx path (optional)", text: $model.mmxPath, prompt: Text(model.detectedMMXPathPlaceholder))
                    .textFieldStyle(.roundedBorder)
                    .font(.caption)
                    .onSubmit { model.commitMmxPath() }
                Button {
                    model.commitMmxPath()
                    Task { await model.refreshProviderStatus() }
                } label: {
                    if model.isRefreshingProvider {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text("Check Status")
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(model.isRefreshingProvider)
            }
            if model.detectedMMXPathPlaceholder != "/usr/local/bin/mmx" {
                Text("Auto-detected: \(model.detectedMMXPathPlaceholder)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func guidanceRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 4) {
            Image(systemName: icon)
                .frame(width: 14)
                .foregroundStyle(.secondary)
                .font(.caption2)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var usageSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Daily Usage")
                .font(.subheadline.weight(.medium))
            HStack(spacing: 16) {
                LabeledContent("Today", value: model.dailyUsedText)
                    .font(.caption)
                LabeledContent("Remaining", value: model.dailyRemainingText)
                    .font(.caption)
            }
            LabeledContent("This Month", value: model.monthlyUsedText)
                .font(.caption)
        }
    }

    private var frequencySection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Autonomous Frequency")
                .font(.subheadline.weight(.medium))
            Picker("Frequency", selection: Binding(
                get: { model.preferences.autonomousFrequency },
                set: { model.setAutonomousFrequency($0) }
            )) {
                ForEach(AIVisualAutonomousFrequency.allCases, id: \.self) { freq in
                    Text(freq.displayName).tag(freq)
                }
            }
            .pickerStyle(.segmented)

            Text(frequencyDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var durationSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Change Duration")
                .font(.subheadline.weight(.medium))
            Picker("Duration", selection: Binding(
                get: { model.preferences.durationPreset },
                set: { model.setDurationPreset($0) }
            )) {
                ForEach(AIVisualDurationPreset.allCases, id: \.self) { preset in
                    Text("\(preset.displayName) (\(Int(preset.durationSeconds))s)").tag(preset)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var intensitySection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Change Intensity")
                .font(.subheadline.weight(.medium))
            Picker("Intensity", selection: Binding(
                get: { model.preferences.intensity },
                set: { model.setIntensity($0) }
            )) {
                ForEach(AIVisualIntensity.allCases, id: \.self) { level in
                    Text(level.displayName).tag(level)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var consistencySection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("一致性偏好")
                .font(.subheadline.weight(.medium))

            Picker("一致性偏好", selection: Binding(
                get: { model.consistencyPreference },
                set: { model.setConsistencyPreference($0) }
            )) {
                ForEach(ConsistencyPreference.allCases, id: \.self) { preference in
                    Text(preference.displayName).tag(preference)
                }
            }
            .pickerStyle(.segmented)

            Text(model.consistencyPreferenceDescription)
                .font(.caption)
                .foregroundStyle(.secondary)

            if let notice = model.creativePreferenceNotice {
                HStack(alignment: .top, spacing: 4) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                    Text(notice)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("形象备注")
                    .font(.caption.weight(.medium))
                TextField(
                    "粉白色小狐狸，2D 插画风，不要 3D",
                    text: Binding(
                        get: { model.petVisualNotes },
                        set: { model.setPetVisualNotes($0) }
                    )
                )
                .textFieldStyle(.roundedBorder)
                Text("可选；会用于下一次生成。")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var manualGenerationSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Manual Generation")
                    .font(.subheadline.weight(.medium))
                Text("Create a fresh visual change now.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                model.requestManualGeneration()
            } label: {
                Label("Generate Now", systemImage: "sparkles")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
    }

    private var restoreSection: some View {
        HStack {
            if model.hasActiveOverlay {
                Button("Restore Original Look", role: .destructive) {
                    model.restoreVisual()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            } else {
                Text("No active visual change")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func feedbackSection(_ message: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "info.circle")
                .foregroundStyle(.secondary)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                model.clearFeedback()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption2)
            }
            .buttonStyle(.plain)
        }
    }

    private var enableNoticeSheet: some View {
        VStack(spacing: 16) {
            Text("Before Enabling AI Visual Expression")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                noticeRow(icon: "paintbrush", text: "AI may create temporary visual changes based on your conversation.")
                noticeRow(icon: "hourglass", text: "Changes may take a few seconds to generate. You can continue chatting while waiting.")
                noticeRow(icon: "xmark.circle", text: "Changes may fail. If so, your pet stays the same and a brief message is shown.")
                noticeRow(icon: "number.circle", text: "Changes count toward a daily quota. You can see remaining uses in settings.")
                noticeRow(icon: "arrow.uturn.backward", text: "All changes are temporary and auto-revert. You can also restore immediately.")
                noticeRow(icon: "hand.raised", text: "This feature does not read your screen, camera, microphone, or other apps.")
                noticeRow(icon: "eye.slash", text: "You can disable this feature at any time from this settings page.")
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            HStack(spacing: 16) {
                Button("Cancel") {
                    model.showEnableNotice = false
                }
                .keyboardShortcut(.cancelAction)

                Button("I Understand, Enable") {
                    model.confirmEnable()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 400)
    }

    private func noticeRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .frame(width: 20)
                .foregroundStyle(.secondary)
            Text(text)
                .font(.callout)
        }
    }

    private var historySection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("History & Favorites")
                    .font(.subheadline.weight(.medium))
                Text("View and manage visual change history")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("View History") {
                model.showHistory = true
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    private var frequencyDescription: String {
        switch model.preferences.autonomousFrequency {
        case .off: "AI will not create visual changes on its own."
        case .low: "AI may suggest visual changes occasionally (at least 30 min apart)."
        case .medium: "AI may suggest visual changes more often (at least 10 min apart)."
        }
    }

    private var providerConfigSheet: some View {
        VStack(spacing: 16) {
            Text("Configure \(model.selectedProviderDisplayName)")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                if model.requiresAPIKey {
                    LabeledContent("API Key") {
                        SecureField("sk-...", text: $model.apiKeyInput)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 260)
                    }
                }

                if model.requiresTencentCredentials {
                    LabeledContent("Secret ID") {
                        SecureField("SecretId", text: $model.secretIdInput)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 260)
                    }
                    LabeledContent("Secret Key") {
                        SecureField("SecretKey", text: $model.secretKeyInput)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 260)
                    }
                }

                if model.requiresBaseURL {
                    LabeledContent("Base URL") {
                        TextField("https://api.openai.com", text: $model.baseURLInput)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 260)
                    }
                }

                if model.requiresModel {
                    LabeledContent("Model") {
                        TextField("model name", text: $model.modelInput)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 200)
                    }
                }

                if model.requiresRegion {
                    LabeledContent("Region") {
                        TextField("region", text: $model.regionInput)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 160)
                    }
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
                .disabled(!providerConfigSaveEnabled)
            }
        }
        .padding(24)
        .frame(width: 440)
    }

    private var providerConfigSaveEnabled: Bool {
        if model.requiresAPIKey && model.apiKeyInput.isEmpty { return false }
        if model.requiresTencentCredentials && (model.secretIdInput.isEmpty || model.secretKeyInput.isEmpty) { return false }
        return true
    }
}
