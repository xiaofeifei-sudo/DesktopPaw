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
                Text(L10n.AIVisual.title)
                    .font(.headline)
                Text(L10n.AIVisual.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if model.isEnabled {
                Button(L10n.AIVisual.disable) {
                    model.disable()
                }
                .buttonStyle(.bordered)
            } else {
                Button(L10n.AIVisual.enable) {
                    model.requestEnable()
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private var providerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L10n.AIVisual.imageProvider)
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
                    Button(L10n.AIVisual.reconfigure) {
                        model.openProviderConfig()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }

            if !model.providerInfos.isEmpty {
                Picker(L10n.AIVisual.provider, selection: Binding(
                    get: { model.currentProviderId ?? "" },
                    set: { id in
                        if !id.isEmpty { model.selectProvider(id) }
                    }
                )) {
                    ForEach(model.providerInfos, id: \.providerId) { info in
                        HStack {
                            Text(info.displayName)
                            if !info.isConfigured {
                                Text(L10n.AIVisual.notConfiguredShort)
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
                Text(L10n.AIVisual.notConfigured)
                    .font(.caption)
            }

            if !model.providerInfos.isEmpty {
                Picker(L10n.AIVisual.provider, selection: Binding(
                    get: { model.currentProviderId ?? "" },
                    set: { id in
                        if !id.isEmpty { model.selectProvider(id) }
                    }
                )) {
                    ForEach(model.providerInfos, id: \.providerId) { info in
                        HStack {
                            Text(info.displayName)
                            if !info.isConfigured {
                                Text(L10n.AIVisual.notConfiguredShort)
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
            Text(L10n.AIVisual.providerRequiresAPIKey)
                .font(.caption)
                .foregroundStyle(.secondary)
            Button(L10n.AIVisual.configure) {
                model.openProviderConfig()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
    }

    private var mmxSetupGuide: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(L10n.AIVisual.setupGuide)
                .font(.caption.weight(.medium))
            guidanceRow(icon: "arrow.down.circle", text: L10n.AIVisual.installGuide)
            guidanceRow(icon: "person.badge.key", text: L10n.AIVisual.loginGuide)
            guidanceRow(icon: "arrow.clockwise", text: L10n.AIVisual.refreshGuide)
        }
        .padding(8)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private var mmxPathRow: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
                TextField(L10n.AIVisual.mmxPathPlaceholder, text: $model.mmxPath, prompt: Text(model.detectedMMXPathPlaceholder))
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
                        Text(L10n.AIVisual.checkStatus)
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
            Text(L10n.AIVisual.dailyUsage)
                .font(.subheadline.weight(.medium))
            HStack(spacing: 16) {
                LabeledContent(L10n.AIVisual.today, value: model.dailyUsedText)
                    .font(.caption)
                LabeledContent(L10n.AIVisual.remaining, value: model.dailyRemainingText)
                    .font(.caption)
            }
            LabeledContent(L10n.AIVisual.thisMonth, value: model.monthlyUsedText)
                .font(.caption)
        }
    }

    private var frequencySection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(L10n.AIVisual.autonomousFrequency)
                .font(.subheadline.weight(.medium))
            Picker(L10n.AIVisual.autonomousFrequency, selection: Binding(
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
            Text(L10n.AIVisual.changeDuration)
                .font(.subheadline.weight(.medium))
            Picker(L10n.AIVisual.changeDuration, selection: Binding(
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
            Text(L10n.AIVisual.changeIntensity)
                .font(.subheadline.weight(.medium))
            Picker(L10n.AIVisual.changeIntensity, selection: Binding(
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
            Text(L10n.AIVisual.consistencyPreference)
                .font(.subheadline.weight(.medium))

            Picker(L10n.AIVisual.consistencyPreference, selection: Binding(
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
                Text(L10n.AIVisual.visualNotes)
                    .font(.caption.weight(.medium))
                TextField(
                    L10n.AIVisual.visualNotesPlaceholder,
                    text: Binding(
                        get: { model.petVisualNotes },
                        set: { model.setPetVisualNotes($0) }
                    )
                )
                .textFieldStyle(.roundedBorder)
                Text(L10n.AIVisual.visualNotesHint)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var manualGenerationSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.AIVisual.manualGeneration)
                    .font(.subheadline.weight(.medium))
                Text(L10n.AIVisual.manualGenerationHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                model.requestManualGeneration()
            } label: {
                Label(L10n.AIVisual.generateNow, systemImage: "sparkles")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
    }

    private var restoreSection: some View {
        HStack {
            if model.hasActiveOverlay {
                Button(L10n.AIVisual.restoreOriginalLook, role: .destructive) {
                    model.restoreVisual()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            } else {
                Text(L10n.AIVisual.noActiveChange)
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
            Text(L10n.AIVisual.beforeEnabling)
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                noticeRow(icon: "paintbrush", text: L10n.AIVisual.noticeVisual)
                noticeRow(icon: "hourglass", text: L10n.AIVisual.noticeDelay)
                noticeRow(icon: "xmark.circle", text: L10n.AIVisual.noticeFail)
                noticeRow(icon: "number.circle", text: L10n.AIVisual.noticeQuota)
                noticeRow(icon: "arrow.uturn.backward", text: L10n.AIVisual.noticeRevert)
                noticeRow(icon: "hand.raised", text: L10n.AIVisual.noticePrivacy)
                noticeRow(icon: "eye.slash", text: L10n.AIVisual.noticeDisable)
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            HStack(spacing: 16) {
                Button(L10n.Common.cancel) {
                    model.showEnableNotice = false
                }
                .keyboardShortcut(.cancelAction)

                Button(L10n.AIVisual.iUnderstandEnable) {
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
                Text(L10n.AIVisual.historyFavorites)
                    .font(.subheadline.weight(.medium))
                Text(L10n.AIVisual.viewHistoryHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(L10n.AIVisual.viewHistory) {
                model.showHistory = true
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    private var frequencyDescription: String {
        switch model.preferences.autonomousFrequency {
        case .off: return L10n.AIVisual.frequencyOffHint
        case .low: return L10n.AIVisual.frequencyLowHint
        case .medium: return L10n.AIVisual.frequencyMediumHint
        }
    }

    private var providerConfigSheet: some View {
        VStack(spacing: 16) {
            Text("Configure \(model.selectedProviderDisplayName)")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                if model.requiresAPIKey {
                    LabeledContent(L10n.AIVisual.apiKey) {
                        SecureField("sk-...", text: $model.apiKeyInput)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 260)
                    }
                }

                if model.requiresTencentCredentials {
                    LabeledContent(L10n.AIVisual.secretId) {
                        SecureField("SecretId", text: $model.secretIdInput)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 260)
                    }
                    LabeledContent(L10n.AIVisual.secretKey) {
                        SecureField("SecretKey", text: $model.secretKeyInput)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 260)
                    }
                }

                if model.requiresBaseURL {
                    LabeledContent(L10n.AIVisual.baseURL) {
                        TextField("https://api.openai.com", text: $model.baseURLInput)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 260)
                    }
                }

                if model.requiresModel {
                    LabeledContent(L10n.AIVisual.model) {
                        TextField("model name", text: $model.modelInput)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 200)
                    }
                }

                if model.requiresRegion {
                    LabeledContent(L10n.AIVisual.region) {
                        TextField("region", text: $model.regionInput)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 160)
                    }
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
