import Foundation

public enum AIVisualAutonomousFrequency: String, Codable, Sendable, CaseIterable {
    case off
    case low
    case medium

    public var displayName: String {
        switch self {
        case .off: "Off"
        case .low: "Low"
        case .medium: "Medium"
        }
    }

    public var minimumIntervalSeconds: TimeInterval? {
        switch self {
        case .off: nil
        case .low: 1800
        case .medium: 600
        }
    }
}

public enum AIVisualDurationPreset: String, Codable, Sendable, CaseIterable {
    case short
    case medium
    case long

    public var displayName: String {
        switch self {
        case .short: "Short"
        case .medium: "Medium"
        case .long: "Long"
        }
    }

    public var durationSeconds: TimeInterval {
        switch self {
        case .short: 60
        case .medium: 180
        case .long: 300
        }
    }
}

public enum AIVisualIntensity: String, Codable, Sendable, CaseIterable {
    case light
    case moderate
    case pronounced

    public var displayName: String {
        switch self {
        case .light: "Light"
        case .moderate: "Moderate"
        case .pronounced: "Pronounced"
        }
    }
}

public struct AIVisualPreferences: Codable, Equatable, Sendable {
    public var isEnabled: Bool
    public var autonomousFrequency: AIVisualAutonomousFrequency
    public var durationPreset: AIVisualDurationPreset
    public var intensity: AIVisualIntensity
    public var selectedProviderId: String?
    public var mmxPath: String?
    public var isHistoryEnabled: Bool

    public init(
        isEnabled: Bool = false,
        autonomousFrequency: AIVisualAutonomousFrequency = .low,
        durationPreset: AIVisualDurationPreset = .short,
        intensity: AIVisualIntensity = .light,
        selectedProviderId: String? = nil,
        mmxPath: String? = nil,
        isHistoryEnabled: Bool = true
    ) {
        self.isEnabled = isEnabled
        self.autonomousFrequency = autonomousFrequency
        self.durationPreset = durationPreset
        self.intensity = intensity
        self.selectedProviderId = selectedProviderId
        self.mmxPath = mmxPath
        self.isHistoryEnabled = isHistoryEnabled
    }
}
