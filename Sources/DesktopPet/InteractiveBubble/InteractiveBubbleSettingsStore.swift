import Foundation

@MainActor
public final class InteractiveBubbleSettingsStore: InteractiveBubbleSettingsProviding, @unchecked Sendable {
    private let defaults: UserDefaults

    private static let enabledKey = "interactiveBubbleEnabled"
    private static let activityLevelKey = "interactiveBubbleActivityLevel"
    private static let minIntervalKey = "interactiveBubbleMinInterval"
    private static let maxIntervalKey = "interactiveBubbleMaxInterval"
    private static let optionWaitKey = "interactiveBubbleOptionWait"
    private static let silentStartKey = "interactiveBubbleSilentStart"
    private static let silentEndKey = "interactiveBubbleSilentEnd"
    private static let advancedModeKey = "interactiveBubbleAdvancedMode"

    private static let defaultMinInterval: TimeInterval = 600
    private static let defaultMaxInterval: TimeInterval = 3600
    private static let defaultOptionWaitDuration: TimeInterval = 15
    private static let defaultSilentStart = DateComponents(hour: 0, minute: 0)
    private static let defaultSilentEnd = DateComponents(hour: 9, minute: 0)

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var isEnabled: Bool {
        get { defaults.object(forKey: Self.enabledKey) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Self.enabledKey) }
    }

    public var activityLevel: ActivityLevel {
        get {
            guard let raw = defaults.string(forKey: Self.activityLevelKey),
                  let level = ActivityLevel(rawValue: raw) else {
                return .medium
            }
            return level
        }
        set {
            defaults.set(newValue.rawValue, forKey: Self.activityLevelKey)
            if !isAdvancedMode {
                setStoredIntervalRange(newValue.intervalRange)
            }
        }
    }

    public var minInterval: TimeInterval {
        get {
            if isAdvancedMode {
                return storedMinInterval
            }
            return activityLevel.intervalRange.lowerBound
        }
        set {
            let interval = max(0, newValue)
            defaults.set(interval, forKey: Self.minIntervalKey)
            if storedMaxInterval < interval {
                defaults.set(interval, forKey: Self.maxIntervalKey)
            }
        }
    }

    public var maxInterval: TimeInterval {
        get {
            if isAdvancedMode {
                return max(storedMaxInterval, storedMinInterval)
            }
            return activityLevel.intervalRange.upperBound
        }
        set {
            defaults.set(max(newValue, storedMinInterval), forKey: Self.maxIntervalKey)
        }
    }

    public var optionWaitDuration: TimeInterval {
        get { defaults.object(forKey: Self.optionWaitKey) as? TimeInterval ?? Self.defaultOptionWaitDuration }
        set { defaults.set(newValue, forKey: Self.optionWaitKey) }
    }

    public var silentPeriodStart: DateComponents {
        get { loadDateComponents(forKey: Self.silentStartKey) ?? Self.defaultSilentStart }
        set { saveDateComponents(newValue, forKey: Self.silentStartKey) }
    }

    public var silentPeriodEnd: DateComponents {
        get { loadDateComponents(forKey: Self.silentEndKey) ?? Self.defaultSilentEnd }
        set { saveDateComponents(newValue, forKey: Self.silentEndKey) }
    }

    public var isAdvancedMode: Bool {
        get { defaults.object(forKey: Self.advancedModeKey) as? Bool ?? false }
        set { defaults.set(newValue, forKey: Self.advancedModeKey) }
    }

    public func enterAdvancedMode() {
        setStoredIntervalRange(activityLevel.intervalRange)
        isAdvancedMode = true
    }

    public func exitAdvancedMode() {
        activityLevel = nearestActivityLevel(for: storedMinInterval...storedMaxInterval)
        isAdvancedMode = false
        setStoredIntervalRange(activityLevel.intervalRange)
    }

    private var storedMinInterval: TimeInterval {
        defaults.object(forKey: Self.minIntervalKey) as? TimeInterval ?? Self.defaultMinInterval
    }

    private var storedMaxInterval: TimeInterval {
        defaults.object(forKey: Self.maxIntervalKey) as? TimeInterval ?? Self.defaultMaxInterval
    }

    private func setStoredIntervalRange(_ range: ClosedRange<TimeInterval>) {
        defaults.set(range.lowerBound, forKey: Self.minIntervalKey)
        defaults.set(range.upperBound, forKey: Self.maxIntervalKey)
    }

    private func nearestActivityLevel(for range: ClosedRange<TimeInterval>) -> ActivityLevel {
        let center = (range.lowerBound + range.upperBound) / 2
        return ActivityLevel.allCases.min { lhs, rhs in
            abs(center - midpoint(of: lhs.intervalRange)) < abs(center - midpoint(of: rhs.intervalRange))
        } ?? .medium
    }

    private func midpoint(of range: ClosedRange<TimeInterval>) -> TimeInterval {
        (range.lowerBound + range.upperBound) / 2
    }

    private func loadDateComponents(forKey key: String) -> DateComponents? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(DateComponents.self, from: data)
    }

    private func saveDateComponents(_ components: DateComponents, forKey key: String) {
        guard let data = try? JSONEncoder().encode(components) else { return }
        defaults.set(data, forKey: key)
    }
}
