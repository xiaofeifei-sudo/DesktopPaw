import SwiftUI

@MainActor
public final class InteractiveBubbleSettingsViewModel: ObservableObject {
    public static let minIntervalMinuteRange: ClosedRange<Double> = 5...60
    public static let maxIntervalMinuteRange: ClosedRange<Double> = 10...120
    public static let optionWaitSecondRange: ClosedRange<Double> = 10...30

    @Published public private(set) var isEnabled: Bool
    @Published public private(set) var activityLevel: ActivityLevel
    @Published public private(set) var isAdvancedMode: Bool
    @Published public private(set) var minIntervalMinutes: Double
    @Published public private(set) var maxIntervalMinutes: Double
    @Published public private(set) var optionWaitDurationSeconds: Double
    @Published public private(set) var silentPeriodStartDate: Date
    @Published public private(set) var silentPeriodEndDate: Date
    @Published public private(set) var isAIConfigured: Bool

    public var onOpenAISettings: (() -> Void)?

    private let settings: any InteractiveBubbleSettingsProviding
    private let calendar: Calendar

    public init(
        settings: any InteractiveBubbleSettingsProviding,
        isAIConfigured: Bool,
        calendar: Calendar = .current
    ) {
        self.settings = settings
        self.calendar = calendar
        self.isEnabled = settings.isEnabled
        self.activityLevel = settings.activityLevel
        self.isAdvancedMode = settings.isAdvancedMode
        self.minIntervalMinutes = settings.minInterval / 60
        self.maxIntervalMinutes = settings.maxInterval / 60
        self.optionWaitDurationSeconds = settings.optionWaitDuration
        self.silentPeriodStartDate = Self.date(from: settings.silentPeriodStart, calendar: calendar)
        self.silentPeriodEndDate = Self.date(from: settings.silentPeriodEnd, calendar: calendar)
        self.isAIConfigured = isAIConfigured
    }

    public var shouldShowAIGuidance: Bool {
        !isAIConfigured
    }

    public var isActivityLevelControlDisabled: Bool {
        !isEnabled || isAdvancedMode
    }

    public var maxIntervalLowerBoundMinutes: Double {
        max(Self.maxIntervalMinuteRange.lowerBound, minIntervalMinutes)
    }

    public var advancedSettingsButtonTitle: String {
        isAdvancedMode ? L10n.SmartBubble.hideAdvancedSettings : L10n.SmartBubble.advancedSettings
    }

    public var silentPeriodStartHour: Int {
        calendar.component(.hour, from: silentPeriodStartDate)
    }

    public var silentPeriodStartMinute: Int {
        calendar.component(.minute, from: silentPeriodStartDate)
    }

    public var silentPeriodEndHour: Int {
        calendar.component(.hour, from: silentPeriodEndDate)
    }

    public var silentPeriodEndMinute: Int {
        calendar.component(.minute, from: silentPeriodEndDate)
    }

    public func setEnabled(_ enabled: Bool) {
        guard isEnabled != enabled else { return }
        isEnabled = enabled
        settings.isEnabled = enabled
    }

    public func setActivityLevel(_ level: ActivityLevel) {
        guard !isAdvancedMode else { return }
        guard activityLevel != level else { return }
        activityLevel = level
        settings.activityLevel = level
        syncIntervalDisplayFromSettings()
    }

    public func setAdvancedModeExpanded(_ expanded: Bool) {
        guard isAdvancedMode != expanded else { return }

        if expanded {
            settings.enterAdvancedMode()
        } else {
            settings.exitAdvancedMode()
        }
        syncFromSettings()
    }

    public func setMinIntervalMinutes(_ minutes: Double) {
        let clampedMinutes = Self.clamp(minutes, to: Self.minIntervalMinuteRange)
        let seconds = clampedMinutes * 60
        settings.minInterval = seconds
        if settings.maxInterval < seconds {
            settings.maxInterval = seconds
        }
        syncIntervalDisplayFromSettings()
    }

    public func setMaxIntervalMinutes(_ minutes: Double) {
        let clampedMinutes = Self.clamp(
            minutes,
            to: maxIntervalLowerBoundMinutes...Self.maxIntervalMinuteRange.upperBound
        )
        settings.maxInterval = clampedMinutes * 60
        syncIntervalDisplayFromSettings()
    }

    public func setOptionWaitDurationSeconds(_ seconds: Double) {
        let clampedSeconds = Self.clamp(seconds, to: Self.optionWaitSecondRange)
        settings.optionWaitDuration = clampedSeconds
        optionWaitDurationSeconds = settings.optionWaitDuration
    }

    public func setSilentPeriodStart(_ date: Date) {
        silentPeriodStartDate = date
        settings.silentPeriodStart = Self.components(from: date, calendar: calendar)
    }

    public func setSilentPeriodEnd(_ date: Date) {
        silentPeriodEndDate = date
        settings.silentPeriodEnd = Self.components(from: date, calendar: calendar)
    }

    public func updateAIConfigured(_ configured: Bool) {
        isAIConfigured = configured
    }

    public func openAISettings() {
        onOpenAISettings?()
    }

    private func syncFromSettings() {
        isEnabled = settings.isEnabled
        activityLevel = settings.activityLevel
        isAdvancedMode = settings.isAdvancedMode
        syncIntervalDisplayFromSettings()
        optionWaitDurationSeconds = settings.optionWaitDuration
        silentPeriodStartDate = Self.date(from: settings.silentPeriodStart, calendar: calendar)
        silentPeriodEndDate = Self.date(from: settings.silentPeriodEnd, calendar: calendar)
    }

    private func syncIntervalDisplayFromSettings() {
        minIntervalMinutes = settings.minInterval / 60
        maxIntervalMinutes = settings.maxInterval / 60
    }

    private static func clamp(_ value: Double, to range: ClosedRange<Double>) -> Double {
        min(max(value, range.lowerBound), range.upperBound)
    }

    private static func date(from components: DateComponents, calendar: Calendar) -> Date {
        calendar.date(from: DateComponents(
            calendar: calendar,
            hour: components.hour ?? 0,
            minute: components.minute ?? 0
        )) ?? Date()
    }

    private static func components(from date: Date, calendar: Calendar) -> DateComponents {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        return DateComponents(hour: components.hour ?? 0, minute: components.minute ?? 0)
    }
}

@MainActor
public struct InteractiveBubbleSettingsView: View {
    @ObservedObject private var model: InteractiveBubbleSettingsViewModel

    public init(model: InteractiveBubbleSettingsViewModel) {
        self.model = model
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            basicSettings

            Button {
                model.setAdvancedModeExpanded(!model.isAdvancedMode)
            } label: {
                Label(
                    model.advancedSettingsButtonTitle,
                    systemImage: model.isAdvancedMode ? "chevron.up.circle" : "slider.horizontal.3"
                )
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(!model.isEnabled)

            if model.isAdvancedMode {
                advancedSettings
            }

            if model.shouldShowAIGuidance {
                aiGuidance
            }
        }
    }

    private var basicSettings: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(
                L10n.SmartBubble.enableSmartBubbles,
                isOn: Binding(
                    get: { model.isEnabled },
                    set: { model.setEnabled($0) }
                )
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.SmartBubble.activity)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Picker(
                    L10n.SmartBubble.activity,
                    selection: Binding(
                        get: { model.activityLevel },
                        set: { model.setActivityLevel($0) }
                    )
                ) {
                    ForEach(ActivityLevel.allCases, id: \.self) { level in
                        Text(label(for: level)).tag(level)
                    }
                }
                .pickerStyle(.segmented)
                .disabled(model.isActivityLevelControlDisabled)
            }
        }
    }

    private var advancedSettings: some View {
        VStack(alignment: .leading, spacing: 10) {
            intervalSlider(
                title: L10n.SmartBubble.minInterval,
                valueText: "\(Int(model.minIntervalMinutes)) min",
                value: Binding(
                    get: { model.minIntervalMinutes },
                    set: { model.setMinIntervalMinutes($0) }
                ),
                range: InteractiveBubbleSettingsViewModel.minIntervalMinuteRange,
                step: 5
            )

            intervalSlider(
                title: L10n.SmartBubble.maxInterval,
                valueText: "\(Int(model.maxIntervalMinutes)) min",
                value: Binding(
                    get: { model.maxIntervalMinutes },
                    set: { model.setMaxIntervalMinutes($0) }
                ),
                range: model.maxIntervalLowerBoundMinutes...InteractiveBubbleSettingsViewModel.maxIntervalMinuteRange.upperBound,
                step: 5
            )

            intervalSlider(
                title: L10n.SmartBubble.optionWait,
                valueText: "\(Int(model.optionWaitDurationSeconds)) sec",
                value: Binding(
                    get: { model.optionWaitDurationSeconds },
                    set: { model.setOptionWaitDurationSeconds($0) }
                ),
                range: InteractiveBubbleSettingsViewModel.optionWaitSecondRange,
                step: 1
            )

            HStack {
                Text(L10n.SmartBubble.silentPeriod)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 96, alignment: .leading)

                DatePicker(
                    "",
                    selection: Binding(
                        get: { model.silentPeriodStartDate },
                        set: { model.setSilentPeriodStart($0) }
                    ),
                    displayedComponents: .hourAndMinute
                )
                .labelsHidden()

                Text(L10n.SmartBubble.to)
                    .foregroundStyle(.secondary)

                DatePicker(
                    "",
                    selection: Binding(
                        get: { model.silentPeriodEndDate },
                        set: { model.setSilentPeriodEnd($0) }
                    ),
                    displayedComponents: .hourAndMinute
                )
                .labelsHidden()
            }
        }
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func intervalSlider(
        title: String,
        valueText: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double
    ) -> some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 96, alignment: .leading)

            Slider(value: value, in: range, step: step)

            Text(valueText)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 52, alignment: .trailing)
        }
    }

    private var aiGuidance: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 6) {
                Text(L10n.SmartBubble.aiGuidance)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button(L10n.SmartBubble.openAISettings) {
                    model.openAISettings()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(10)
        .background(Color.orange.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func label(for level: ActivityLevel) -> String {
        switch level {
        case .low: return L10n.SmartBubble.activityLow
        case .medium: return L10n.SmartBubble.activityMedium
        case .high: return L10n.SmartBubble.activityHigh
        }
    }
}
