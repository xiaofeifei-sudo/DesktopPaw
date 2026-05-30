@preconcurrency import AppKit
import Foundation

@MainActor
public final class PreferencesStore: PetWindowFrameStoring {
    public static let defaultPetId = "cat"
    public static let defaultPetScale = 1.0
    public static let defaultMood = 0.8
    public static let defaultHunger = 0.2
    public static let defaultEnergy = 0.8
    public static let petScaleRange = 0.5...2.0

    private let userDefaults: UserDefaults
    private let knownPetIdsProvider: () -> Set<String>
    private let screenGeometryProvider: () -> ScreenGeometry
    private let frameSizeProvider: () -> CGSize
    private let now: () -> Date

    public init(
        userDefaults: UserDefaults = .standard,
        knownPetIdsProvider: @escaping () -> Set<String> = { [PreferencesStore.defaultPetId] },
        screenGeometryProvider: @escaping () -> ScreenGeometry = { ScreenGeometry.current() },
        frameSizeProvider: @escaping () -> CGSize = { CGSize(width: 128, height: 128) },
        now: @escaping () -> Date = { Date() }
    ) {
        self.userDefaults = userDefaults
        self.knownPetIdsProvider = knownPetIdsProvider
        self.screenGeometryProvider = screenGeometryProvider
        self.frameSizeProvider = frameSizeProvider
        self.now = now
    }

    public convenience init(
        userDefaults: UserDefaults = .standard,
        knownPetIds: Set<String>,
        screenGeometryProvider: @escaping () -> ScreenGeometry = { ScreenGeometry.current() },
        frameSizeProvider: @escaping () -> CGSize = { CGSize(width: 128, height: 128) },
        now: @escaping () -> Date = { Date() }
    ) {
        self.init(
            userDefaults: userDefaults,
            knownPetIdsProvider: { knownPetIds },
            screenGeometryProvider: screenGeometryProvider,
            frameSizeProvider: frameSizeProvider,
            now: now
        )
    }

    public var isPetVisible: Bool {
        get {
            guard userDefaults.object(forKey: PreferenceKeys.isPetVisible) != nil else {
                return true
            }

            return userDefaults.bool(forKey: PreferenceKeys.isPetVisible)
        }
        set {
            userDefaults.set(newValue, forKey: PreferenceKeys.isPetVisible)
        }
    }

    public var petScale: Double {
        get {
            normalizedDouble(
                forKey: PreferenceKeys.petScale,
                defaultValue: Self.defaultPetScale,
                range: Self.petScaleRange
            )
        }
        set {
            userDefaults.set(clamp(newValue, to: Self.petScaleRange), forKey: PreferenceKeys.petScale)
        }
    }

    public var isRandomWalkingEnabled: Bool {
        get {
            guard userDefaults.object(forKey: PreferenceKeys.isRandomWalkingEnabled) != nil else {
                return true
            }

            return userDefaults.bool(forKey: PreferenceKeys.isRandomWalkingEnabled)
        }
        set {
            userDefaults.set(newValue, forKey: PreferenceKeys.isRandomWalkingEnabled)
        }
    }

    public var isSoundEnabled: Bool {
        get {
            guard userDefaults.object(forKey: PreferenceKeys.isSoundEnabled) != nil else {
                return true
            }

            return userDefaults.bool(forKey: PreferenceKeys.isSoundEnabled)
        }
        set {
            userDefaults.set(newValue, forKey: PreferenceKeys.isSoundEnabled)
        }
    }

    public var selectedPetId: String {
        get {
            let stored = userDefaults.string(forKey: PreferenceKeys.selectedPetId) ?? Self.defaultPetId
            let knownIds = knownPetIdsProvider()
            guard knownIds.contains(stored) else {
                DesktopPetLog.preferences.warning("Unknown selected pet id \(stored, privacy: .public); falling back to \(Self.defaultPetId, privacy: .public).")
                userDefaults.set(Self.defaultPetId, forKey: PreferenceKeys.selectedPetId)
                return Self.defaultPetId
            }

            return stored
        }
        set {
            let knownIds = knownPetIdsProvider()
            let value = knownIds.contains(newValue) ? newValue : Self.defaultPetId
            userDefaults.set(value, forKey: PreferenceKeys.selectedPetId)
        }
    }

    public var isSpeechBubbleEnabled: Bool {
        get {
            guard userDefaults.object(forKey: PreferenceKeys.isSpeechBubbleEnabled) != nil else {
                return true
            }

            return userDefaults.bool(forKey: PreferenceKeys.isSpeechBubbleEnabled)
        }
        set {
            userDefaults.set(newValue, forKey: PreferenceKeys.isSpeechBubbleEnabled)
        }
    }

    public var bubbleFrequency: BubbleFrequency {
        get {
            guard let raw = userDefaults.string(forKey: PreferenceKeys.bubbleFrequency) else {
                return .default
            }
            guard let value = BubbleFrequency(rawValue: raw) else {
                DesktopPetLog.preferences.warning("Invalid bubble frequency \(raw, privacy: .public); falling back to \(BubbleFrequency.default.rawValue, privacy: .public).")
                userDefaults.set(BubbleFrequency.default.rawValue, forKey: PreferenceKeys.bubbleFrequency)
                return .default
            }
            return value
        }
        set {
            userDefaults.set(newValue.rawValue, forKey: PreferenceKeys.bubbleFrequency)
        }
    }

    public var mood: Double {
        get {
            normalizedDouble(forKey: PreferenceKeys.mood, defaultValue: Self.defaultMood, range: 0...1)
        }
        set {
            userDefaults.set(MoodModel.clamp01(newValue), forKey: PreferenceKeys.mood)
        }
    }

    public var hunger: Double {
        get {
            normalizedDouble(forKey: PreferenceKeys.hunger, defaultValue: Self.defaultHunger, range: 0...1)
        }
        set {
            userDefaults.set(MoodModel.clamp01(newValue), forKey: PreferenceKeys.hunger)
        }
    }

    public var energy: Double {
        get {
            normalizedDouble(forKey: PreferenceKeys.energy, defaultValue: Self.defaultEnergy, range: 0...1)
        }
        set {
            userDefaults.set(MoodModel.clamp01(newValue), forKey: PreferenceKeys.energy)
        }
    }

    public var lastInteractionAt: Date {
        get {
            guard let date = userDefaults.object(forKey: PreferenceKeys.lastInteractionAt) as? Date else {
                let defaultDate = now()
                userDefaults.set(defaultDate, forKey: PreferenceKeys.lastInteractionAt)
                return defaultDate
            }

            return date
        }
        set {
            userDefaults.set(newValue, forKey: PreferenceKeys.lastInteractionAt)
        }
    }

    public func loadRuntimeState() -> PetRuntimeState {
        PetRuntimeState(
            currentState: .idle,
            mood: mood,
            hunger: hunger,
            energy: energy,
            lastInteractionAt: lastInteractionAt,
            isDragging: false,
            scale: petScale
        )
    }

    public func saveRuntimeState(_ state: PetRuntimeState) {
        petScale = state.scale
        mood = state.mood
        hunger = state.hunger
        energy = state.energy
        lastInteractionAt = state.lastInteractionAt
    }

    public func loadPetWindowFrame() -> CGRect? {
        rawPetWindowFrame()
    }

    public func savePetWindowFrame(_ frame: CGRect) {
        userDefaults.set(NSStringFromRect(frame), forKey: PreferenceKeys.petWindowFrame)
    }

    public func resolvedPetWindowFrame() -> CGRect {
        let geometry = screenGeometryProvider()
        let frameSize = frameSizeProvider()

        guard let frame = rawPetWindowFrame(), geometry.isFrameVisible(frame) else {
            let defaultFrame = geometry.defaultPetFrame(frameSize: frameSize)
            DesktopPetLog.preferences.warning("Saved pet window frame is unavailable or off-screen; using default frame.")
            savePetWindowFrame(defaultFrame)
            return defaultFrame
        }

        let clampedFrame = geometry.clamp(frame: frame)
        if clampedFrame != frame {
            DesktopPetLog.preferences.info("Saved pet window frame was clamped into visible screen bounds.")
            savePetWindowFrame(clampedFrame)
        }
        return clampedFrame
    }

    private func rawPetWindowFrame() -> CGRect? {
        guard let value = userDefaults.string(forKey: PreferenceKeys.petWindowFrame) else {
            return nil
        }

        let frame = NSRectFromString(value)
        return frame.isEmpty ? nil : frame
    }

    private func normalizedDouble(
        forKey key: String,
        defaultValue: Double,
        range: ClosedRange<Double>
    ) -> Double {
        guard userDefaults.object(forKey: key) != nil else {
            return defaultValue
        }

        let value = userDefaults.double(forKey: key)
        let normalized = clamp(value, to: range)
        if normalized != value {
            DesktopPetLog.preferences.warning("Preference \(key, privacy: .public) was out of range and has been clamped.")
            userDefaults.set(normalized, forKey: key)
        }
        return normalized
    }

    private func clamp(_ value: Double, to range: ClosedRange<Double>) -> Double {
        min(max(value, range.lowerBound), range.upperBound)
    }
}
