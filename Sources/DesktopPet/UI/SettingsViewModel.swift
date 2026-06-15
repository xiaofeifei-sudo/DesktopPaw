import Foundation

@MainActor
public final class SettingsViewModel: ObservableObject {
    public static let customPetPackageFolder = "~/Library/Application Support/DesktopPet/Pets"
    public static let customPetPackageFormat = "manifest.json + spritesheet.png + preview.png"

    @Published public private(set) var isPetVisible: Bool
    @Published public private(set) var petScale: Double
    @Published public private(set) var isRandomWalkingEnabled: Bool
    @Published public private(set) var isSoundEnabled: Bool
    @Published public private(set) var isLaunchAtLoginEnabled: Bool
    @Published public private(set) var isSpeechBubbleEnabled: Bool
    @Published public private(set) var bubbleFrequency: BubbleFrequency
    @Published public private(set) var runtimeState: PetRuntimeState

    public var onPetVisibilityChanged: ((Bool) -> Void)?
    public var onScaleChanged: ((Double) -> Void)?
    public var onRandomWalkingChanged: ((Bool) -> Void)?
    public var onSoundChanged: ((Bool) -> Void)?
    public var onLaunchAtLoginChanged: ((Bool) -> Void)?
    public var onSpeechBubbleEnabledChanged: ((Bool) -> Void)?
    public var onBubbleFrequencyChanged: ((BubbleFrequency) -> Void)?
    public var onResetPosition: (() -> Void)?

    public init(
        isPetVisible: Bool = true,
        petScale: Double = PreferencesStore.defaultPetScale,
        isRandomWalkingEnabled: Bool = true,
        isSoundEnabled: Bool = true,
        isLaunchAtLoginEnabled: Bool = false,
        isSpeechBubbleEnabled: Bool = true,
        bubbleFrequency: BubbleFrequency = .default,
        runtimeState: PetRuntimeState = .defaultState()
    ) {
        self.isPetVisible = isPetVisible
        self.petScale = Self.clampScale(petScale)
        self.isRandomWalkingEnabled = isRandomWalkingEnabled
        self.isSoundEnabled = isSoundEnabled
        self.isLaunchAtLoginEnabled = isLaunchAtLoginEnabled
        self.isSpeechBubbleEnabled = isSpeechBubbleEnabled
        self.bubbleFrequency = bubbleFrequency
        self.runtimeState = runtimeState
    }

    public var petStatusText: String {
        if runtimeState.energy < 0.25 {
            return "Tired"
        }

        if runtimeState.hunger > 0.75 {
            return "Hungry"
        }

        if runtimeState.mood >= 0.7 {
            return L10n.localize(cn: "开心", en: "Happy")
        }

        if runtimeState.mood < 0.35 {
            return L10n.localize(cn: "安静", en: "Quiet")
        }

        return L10n.localize(cn: "平静", en: "Calm")
    }

    public func setPetVisible(_ isVisible: Bool) {
        guard isPetVisible != isVisible else {
            return
        }

        isPetVisible = isVisible
        onPetVisibilityChanged?(isVisible)
    }

    public func setPetScale(_ scale: Double) {
        let scale = Self.clampScale(scale)
        guard petScale != scale else {
            return
        }

        petScale = scale
        onScaleChanged?(scale)
    }

    public func setRandomWalkingEnabled(_ enabled: Bool) {
        guard isRandomWalkingEnabled != enabled else {
            return
        }

        isRandomWalkingEnabled = enabled
        onRandomWalkingChanged?(enabled)
    }

    public func setSoundEnabled(_ enabled: Bool) {
        guard isSoundEnabled != enabled else {
            return
        }

        isSoundEnabled = enabled
        onSoundChanged?(enabled)
    }

    public func setLaunchAtLoginEnabled(_ enabled: Bool) {
        guard isLaunchAtLoginEnabled != enabled else {
            return
        }

        isLaunchAtLoginEnabled = enabled
        onLaunchAtLoginChanged?(enabled)
    }

    public func setSpeechBubbleEnabled(_ enabled: Bool) {
        guard isSpeechBubbleEnabled != enabled else {
            return
        }

        isSpeechBubbleEnabled = enabled
        onSpeechBubbleEnabledChanged?(enabled)
    }

    public func setBubbleFrequency(_ frequency: BubbleFrequency) {
        guard bubbleFrequency != frequency else {
            return
        }

        bubbleFrequency = frequency
        onBubbleFrequencyChanged?(frequency)
    }

    public func resetPosition() {
        onResetPosition?()
    }

    public func updatePetVisibility(_ isVisible: Bool) {
        isPetVisible = isVisible
    }

    public func updateLaunchAtLogin(_ enabled: Bool) {
        isLaunchAtLoginEnabled = enabled
    }

    public func updateSpeechBubbleEnabled(_ enabled: Bool) {
        isSpeechBubbleEnabled = enabled
    }

    public func updateBubbleFrequency(_ frequency: BubbleFrequency) {
        bubbleFrequency = frequency
    }

    public func updateRuntimeState(_ state: PetRuntimeState) {
        runtimeState = state
        petScale = Self.clampScale(state.scale)
    }

    private static func clampScale(_ scale: Double) -> Double {
        min(max(scale, PreferencesStore.petScaleRange.lowerBound), PreferencesStore.petScaleRange.upperBound)
    }
}
