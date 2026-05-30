import SwiftUI

public struct FeatureInfoSheet: View {
    public let info: FeatureInfo
    @Binding public var isPresented: Bool

    public init(info: FeatureInfo, isPresented: Binding<Bool>) {
        self.info = info
        self._isPresented = isPresented
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(info.title)
                .font(.title2)
                .bold()

            infoLine(label: "Why Needed", text: info.whyNeeded)
            infoLine(label: "What It Accesses", text: info.whatItAccesses)
            infoLine(label: "What It Does NOT Access", text: info.whatItDoesNotAccess)
            infoLine(label: "Data Saved", text: info.dataSaved)
            infoLine(label: "How to Close", text: info.howToClose)
            infoLine(label: "What You Lose", text: info.whatYouLose)

            Spacer()

            HStack {
                Spacer()
                Button("Close") { isPresented = false }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 480, height: 440)
    }

    private func infoLine(label: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .bold()
                .foregroundStyle(.secondary)
            Text(text)
                .font(.caption)
        }
    }
}

@MainActor
public struct AdvancedSettingsView: View {
    @ObservedObject private var model: AdvancedSettingsViewModel

    public init(model: AdvancedSettingsViewModel) {
        self.model = model
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            inputSyncSection
            Divider()
            desktopSpaceSection
            Divider()
            externalStateSection
            Divider()
            contentPackSection
            Spacer(minLength: 0)
        }
        .sheet(isPresented: $model.showInputSyncInfo) {
            FeatureInfoSheet(info: AdvancedSettingsViewModel.inputSyncInfo,
                             isPresented: $model.showInputSyncInfo)
        }
        .sheet(isPresented: $model.showDesktopSpaceInfo) {
            FeatureInfoSheet(info: AdvancedSettingsViewModel.desktopSpaceInfo,
                             isPresented: $model.showDesktopSpaceInfo)
        }
        .sheet(isPresented: $model.showExternalStateInfo) {
            FeatureInfoSheet(info: AdvancedSettingsViewModel.externalStateInfo,
                             isPresented: $model.showExternalStateInfo)
        }
        .sheet(isPresented: $model.showContentPackManager) {
            if let vm = model.contentPackViewModel {
                ContentPackView(model: vm)
                    .frame(width: 480, height: 500)
            }
        }
    }

    private var inputSyncSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            featureHeader(
                title: "Input Sync",
                isOn: Binding(
                    get: { model.preferences.inputSyncConfig.isEnabled },
                    set: { model.onInputSyncEnabledChanged?($0) }
                ),
                infoAction: { model.showInputSyncInfo = true }
            )
            if model.preferences.inputSyncConfig.isEnabled {
                inputSyncSubSettings
            }
        }
    }

    private var inputSyncSubSettings: some View {
        VStack(alignment: .leading, spacing: 6) {
            Picker("Intensity", selection: Binding(
                get: { model.preferences.inputSyncConfig.syncIntensity },
                set: { model.onInputSyncIntensityChanged?($0) }
            )) {
                Text("Subtle").tag(InputSyncIntensity.subtle)
                Text("Moderate").tag(InputSyncIntensity.moderate)
                Text("Expressive").tag(InputSyncIntensity.expressive)
            }
            .pickerStyle(.segmented)

            Toggle("Track Keyboard", isOn: Binding(
                get: { model.preferences.inputSyncConfig.trackKeyboard },
                set: { model.onInputSyncTrackKeyboardChanged?($0) }
            ))
            Toggle("Track Mouse", isOn: Binding(
                get: { model.preferences.inputSyncConfig.trackMouse },
                set: { model.onInputSyncTrackMouseChanged?($0) }
            ))
            Toggle("Respect Quiet Mode", isOn: Binding(
                get: { model.preferences.inputSyncConfig.respectQuietMode },
                set: { model.onInputSyncRespectQuietModeChanged?($0) }
            ))
        }
        .padding(.leading, 12)
    }

    private var desktopSpaceSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            featureHeader(
                title: "Desktop Space",
                isOn: Binding(
                    get: { model.preferences.desktopSpaceEnabled },
                    set: { model.onDesktopSpaceEnabledChanged?($0) }
                ),
                infoAction: { model.showDesktopSpaceInfo = true }
            )
            if model.preferences.desktopSpaceEnabled {
                desktopSpaceSubSettings
            }
        }
    }

    private var desktopSpaceSubSettings: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Edge Threshold: \(Int(model.preferences.desktopSpaceEdgeThreshold))pt")
                    .font(.caption)
                Slider(
                    value: Binding(
                        get: { model.preferences.desktopSpaceEdgeThreshold },
                        set: { model.onDesktopSpaceEdgeThresholdChanged?($0) }
                    ),
                    in: 10...100,
                    step: 5
                )
            }
            Toggle("Lock Pet Position", isOn: Binding(
                get: { model.preferences.isMovementConstrained },
                set: { model.onMovementConstrainedChanged?($0) }
            ))
        }
        .padding(.leading, 12)
    }

    private var externalStateSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            featureHeader(
                title: "External State",
                isOn: Binding(
                    get: { model.preferences.externalStateEnabled },
                    set: { model.onExternalStateEnabledChanged?($0) }
                ),
                infoAction: { model.showExternalStateInfo = true }
            )
            if model.preferences.externalStateEnabled {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Socket Path")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(model.preferences.externalStateSocketPath.isEmpty
                         ? AdvancedPreferences.defaultSocketPath()
                         : model.preferences.externalStateSocketPath)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .padding(.leading, 12)
            }
        }
    }

    private var contentPackSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Content Packs")
                    .font(.headline)
                Spacer()
                Button("Manage") {
                    model.showContentPackManager = true
                }
            }
            Text("Import and manage dialogue, personality, and action packs.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func featureHeader(title: String, isOn: Binding<Bool>, infoAction: @escaping () -> Void) -> some View {
        HStack {
            Text(title)
                .font(.headline)
            Button(action: infoAction) {
                Image(systemName: "info.circle")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            Spacer()
            Toggle("", isOn: isOn)
                .toggleStyle(.switch)
                .labelsHidden()
        }
    }
}
