import Foundation

public protocol PetLibraryManifestWriting {
    func writeSingleImageManifest(
        petId: String,
        displayName: String,
        image: ImportedPetImage,
        to folderURL: URL
    ) throws
}

public final class PetLibraryManifestWriter: PetLibraryManifestWriting {
    public static let manifestFileName = "manifest.json"
    public static let manifestSchemaVersion = 2
    public static let defaultDescription = "Imported single image pet."
    public static let defaultFrameDurationMs = 1000
    public static let defaultScale: Double = 1.0

    private let fileManager: FileManager
    private let encoder: JSONEncoder

    public init(
        fileManager: FileManager = .default,
        encoder: JSONEncoder = PetLibraryManifestWriter.makeDefaultEncoder()
    ) {
        self.fileManager = fileManager
        self.encoder = encoder
    }

    public func writeSingleImageManifest(
        petId: String,
        displayName: String,
        image: ImportedPetImage,
        to folderURL: URL
    ) throws {
        let manifest = makeManifest(petId: petId, displayName: displayName, image: image)
        let data: Data
        do {
            data = try encoder.encode(manifest)
        } catch {
            DesktopPetLog.petLibrary.error(
                "Failed to encode manifest for \(petId, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
            cleanUp(folderURL)
            throw PetLibraryError.cannotWriteManifest
        }

        let manifestURL = folderURL.appendingPathComponent(Self.manifestFileName)
        do {
            try data.write(to: manifestURL, options: [.atomic])
        } catch {
            DesktopPetLog.petLibrary.error(
                "Failed to write manifest at \(manifestURL.path, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
            cleanUp(folderURL)
            throw PetLibraryError.cannotWriteManifest
        }
    }

    public static func makeDefaultEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    private func makeManifest(
        petId: String,
        displayName: String,
        image: ImportedPetImage
    ) -> PetPackageManifest {
        PetPackageManifest(
            schemaVersion: Self.manifestSchemaVersion,
            id: petId,
            displayName: displayName,
            description: Self.defaultDescription,
            asset: image.imageFileName,
            preview: image.previewFileName,
            frameSize: image.pixelSize,
            spritesheet: nil,
            defaultScale: Self.defaultScale,
            animations: Self.defaultAnimations(),
            assetKind: .singleImage,
            motionProfile: MotionProfileDefaults.singleImageDefault(),
            bubbleProfile: BubbleProfileDefaults.defaultProfile()
        )
    }

    private static func defaultAnimations() -> [PetState: ManifestAnimationClip] {
        let originFrame = SpriteFrame(column: 0, row: 0)
        var clips: [PetState: ManifestAnimationClip] = [:]
        for state in PetState.allCases {
            clips[state] = ManifestAnimationClip(
                frames: [originFrame],
                frameDurationMs: defaultFrameDurationMs,
                loop: loopBehavior(for: state),
                nextState: nextState(for: state)
            )
        }
        return clips
    }

    private static func loopBehavior(for state: PetState) -> Bool {
        switch state {
        case .idle, .walking, .sleeping, .dragging:
            return true
        case .happy, .eating, .jumping:
            return false
        }
    }

    private static func nextState(for state: PetState) -> PetState? {
        switch state {
        case .happy, .eating, .jumping:
            return .idle
        case .idle, .walking, .sleeping, .dragging:
            return nil
        }
    }

    private func cleanUp(_ folderURL: URL) {
        guard fileManager.fileExists(atPath: folderURL.path) else { return }
        do {
            try fileManager.removeItem(at: folderURL)
        } catch {
            DesktopPetLog.petLibrary.warning(
                "Failed to remove half-written pet folder at \(folderURL.path, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
        }
    }
}
