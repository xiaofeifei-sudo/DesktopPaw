@preconcurrency import AppKit
import Foundation

public enum PetSoundEvent: CaseIterable, Equatable {
    case click
    case pet
    case feed

    public var resourceName: String {
        switch self {
        case .click:
            "pet-click"
        case .pet:
            "pet-happy"
        case .feed:
            "pet-feed"
        }
    }
}

@MainActor
public protocol PetSoundPlaying: AnyObject {
    func play(_ event: PetSoundEvent)
}

@MainActor
public final class SilentPetSoundPlayer: PetSoundPlaying {
    public init() {}

    public func play(_ event: PetSoundEvent) {}
}

@MainActor
public final class PetSoundPlayer: PetSoundPlaying {
    public typealias SoundLoader = @MainActor (String) -> NSSound?

    private let isSoundEnabled: () -> Bool
    private let soundLoader: SoundLoader

    public init(
        isSoundEnabled: @escaping () -> Bool,
        soundLoader: @escaping SoundLoader = PetSoundPlayer.loadBundledSound(named:)
    ) {
        self.isSoundEnabled = isSoundEnabled
        self.soundLoader = soundLoader
    }

    public func play(_ event: PetSoundEvent) {
        guard isSoundEnabled() else {
            return
        }

        guard let sound = soundLoader(event.resourceName) else {
            return
        }

        sound.stop()
        sound.currentTime = 0
        sound.play()
    }

    public static func loadBundledSound(named name: String) -> NSSound? {
        for fileExtension in ["wav", "aiff", "mp3"] {
            if let url = Bundle.module.url(forResource: name, withExtension: fileExtension),
               let sound = NSSound(contentsOf: url, byReference: false) {
                return sound
            }
        }

        return nil
    }
}
