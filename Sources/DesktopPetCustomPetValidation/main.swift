import AppKit
import DesktopPet
import Foundation

@MainActor
func runCustomPetValidation() {
    validateImageImportSwitchingAndDeleteFallback()
    validatePackageImportFlow()
    validateSingleImageRendererFallback()
    validateMotionProfile()
    validateBubbleEngine()
    print("DesktopPetCustomPetValidation passed")
}

@MainActor
private func validatePackageImportFlow() {
    let scratch = ScratchDirectory(name: "DesktopPetPackageValidation")
    defer { scratch.cleanUp() }

    let packageURL = scratch.root.appendingPathComponent("PackagePet.pet", isDirectory: true)
    do {
        try FileManager.default.createDirectory(at: packageURL, withIntermediateDirectories: true)
        try Data(packageManifestJSON(id: "package-pet").utf8).write(to: packageURL.appendingPathComponent("manifest.json"))
        try writePNGData(width: 256, height: 896).write(to: packageURL.appendingPathComponent("spritesheet.png"))
        try writePNGData(width: 128, height: 128).write(to: packageURL.appendingPathComponent("preview.png"))
        try Data("#!/bin/sh\necho ignored\n".utf8).write(to: packageURL.appendingPathComponent("unused-script.sh"))
    } catch {
        fail("could not seed package validation fixture: \(error)")
    }

    let supportRoot = scratch.root.appendingPathComponent("Support", isDirectory: true)
    let store = PetLibraryStore(rootDirectory: supportRoot)
    let suiteName = "DesktopPetPackageValidation-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName) ?? .standard
    defaults.removePersistentDomain(forName: suiteName)
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let preferences = PreferencesStore(
        userDefaults: defaults,
        knownPetIdsProvider: {
            let items = (try? store.listPets()) ?? []
            return Set(items.map(\.id))
        }
    )
    preferences.selectedPetId = store.builtInPetId

    let commander = PetLibraryCommander(
        store: store,
        importer: PetImageImporter(),
        packageImporter: PetPackageImporter(),
        manifestWriter: PetLibraryManifestWriter(),
        preferences: preferences
    )

    var selectedDefinitions: [PetDefinition] = []
    var importErrors: [PetLibraryError] = []
    commander.onCurrentPetChanged = { selectedDefinitions.append($0) }
    commander.onImportFailed = { importErrors.append($0) }

    commander.importPetPackage(at: packageURL)

    expect(importErrors.isEmpty, "valid package import should not report errors")
    expect(preferences.selectedPetId == "package-pet", "package import should select imported package")
    expect(selectedDefinitions.last?.id == "package-pet", "package import should publish package definition")

    let importedFolder = store.importedPetsDirectoryURL.appendingPathComponent("package-pet", isDirectory: true)
    expect(FileManager.default.fileExists(atPath: importedFolder.appendingPathComponent("manifest.json").path), "package import should copy manifest")
    expect(FileManager.default.fileExists(atPath: importedFolder.appendingPathComponent("spritesheet.png").path), "package import should copy spritesheet")
    expect(FileManager.default.fileExists(atPath: importedFolder.appendingPathComponent("preview.png").path), "package import should copy preview")
    expect(!FileManager.default.fileExists(atPath: importedFolder.appendingPathComponent("unused-script.sh").path), "package import should ignore package scripts")

    let items = tryOrFail(try store.listPets(), "pet library should list package pet")
    expect(items.contains(where: { $0.id == "package-pet" && $0.source == .package }), "imported package should be listed as package")
}

@MainActor
private func validateImageImportSwitchingAndDeleteFallback() {
    let scratch = ScratchDirectory(name: "DesktopPetCustomPetValidation")
    defer { scratch.cleanUp() }

    let supportRoot = scratch.root.appendingPathComponent("Support", isDirectory: true)
    let store = PetLibraryStore(rootDirectory: supportRoot)
    let sourceURL = scratch.root.appendingPathComponent("validation-pet.png")
    writePNG(to: sourceURL, width: 160, height: 96, hasAlpha: true)

    let suiteName = "DesktopPetCustomPetValidation-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName) ?? .standard
    defaults.removePersistentDomain(forName: suiteName)
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let preferences = PreferencesStore(
        userDefaults: defaults,
        knownPetIdsProvider: {
            let items = (try? store.listPets()) ?? []
            return Set(items.map(\.id))
        },
        screenGeometryProvider: {
            ScreenGeometry(visibleFrames: [CGRect(x: 0, y: 0, width: 1_440, height: 900)])
        },
        frameSizeProvider: {
            CGSize(width: 128, height: 128)
        },
        now: {
            Date(timeIntervalSince1970: 1_700_000_000)
        }
    )

    let petId = "validation-pet"
    let commander = PetLibraryCommander(
        store: store,
        importer: PetImageImporter(),
        manifestWriter: PetLibraryManifestWriter(),
        preferences: preferences,
        petIdGenerator: { petId }
    )

    var libraryChangedCount = 0
    var selectedDefinitions: [PetDefinition] = []
    var importErrors: [PetLibraryError] = []
    commander.onLibraryChanged = { libraryChangedCount += 1 }
    commander.onCurrentPetChanged = { selectedDefinitions.append($0) }
    commander.onImportFailed = { importErrors.append($0) }

    commander.importPetImage(at: sourceURL, displayName: "Validation Pet")

    expect(importErrors.isEmpty, "image import flow should not report errors")
    expect(libraryChangedCount == 1, "successful image import should publish one library change")
    expect(preferences.selectedPetId == petId, "successful image import should select the imported pet")
    expect(selectedDefinitions.last?.id == petId, "selected definition should be the imported pet")

    let petFolder = store.importedPetsDirectoryURL.appendingPathComponent(petId, isDirectory: true)
    expect(FileManager.default.fileExists(atPath: petFolder.path), "import should create pet folder")
    expect(
        FileManager.default.fileExists(atPath: petFolder.appendingPathComponent(PetLibraryStore.manifestFileName).path),
        "import should create manifest.json"
    )
    expect(
        FileManager.default.fileExists(atPath: petFolder.appendingPathComponent(PetImageImporter.imageFileName).path),
        "import should create image.png"
    )
    expect(
        FileManager.default.fileExists(atPath: petFolder.appendingPathComponent(PetImageImporter.previewFileName).path),
        "import should create preview.png"
    )

    let items = tryOrFail(try store.listPets(), "pet library should list imported pet")
    expect(items.contains(where: { $0.id == store.builtInPetId && $0.source == .builtIn }), "built-in pet should remain listed")
    expect(items.contains(where: { $0.id == petId && $0.source == .importedImage }), "imported image pet should be listed")

    let importedDefinition = tryOrFail(try store.loadDefinition(id: petId), "imported definition should load")
    expect(importedDefinition.assetKind == .singleImage, "imported image should load as singleImage")
    expect(importedDefinition.motionProfile?.stateMotions.count == PetState.allCases.count, "imported pet should have full motion profile")
    expect(importedDefinition.bubbleProfile != nil, "imported pet should have bubble profile")

    commander.selectPet(id: store.builtInPetId)
    expect(preferences.selectedPetId == store.builtInPetId, "selectPet should switch back to built-in pet")
    expect(selectedDefinitions.last?.id == store.builtInPetId, "built-in definition should be published after switch")

    commander.selectPet(id: petId)
    expect(preferences.selectedPetId == petId, "selectPet should switch to imported pet")
    expect(selectedDefinitions.last?.id == petId, "imported definition should be published after switch")

    commander.deletePet(id: petId)
    expect(!FileManager.default.fileExists(atPath: petFolder.path), "delete should remove imported pet folder")
    expect(preferences.selectedPetId == store.builtInPetId, "deleting current imported pet should fall back to built-in")
    expect(selectedDefinitions.last?.id == store.builtInPetId, "delete fallback should publish built-in definition")
}

@MainActor
private func validateSingleImageRendererFallback() {
    let preview = NSImage(size: CGSize(width: 8, height: 8))
    let placeholder = NSImage(size: CGSize(width: 4, height: 4))
    let renderer = SingleImageRenderer(
        definition: makeSingleImageDefinition(id: "renderer-fallback"),
        imageLoader: { name in
            switch name {
            case "image.png":
                return nil
            case "preview.png":
                return preview
            case PetDefinition.placeholderAssetName:
                return placeholder
            default:
                return nil
            }
        }
    )

    expect(renderer.image(for: .idle, frame: nil) === preview, "single image renderer should fall back to preview")
    expect(renderer.image(for: .happy, frame: SpriteFrame(column: 9, row: 9)) === preview, "single image renderer should ignore frame")
}

private func validateMotionProfile() {
    let profile = MotionProfileDefaults.singleImageDefault()
    expect(profile.stateMotions.count == PetState.allCases.count, "single image default profile should cover all pet states")
    for state in PetState.allCases {
        expect(profile.motion(for: state).kind != .none, "motion profile should define visible intent for \(state.rawValue)")
    }

    let provider = DefaultPetMotionProvider()
    let happy = provider.motionValue(for: .happy, profile: profile, elapsed: 0.24, reducedMotion: false)
    expect(happy != .identity, "happy motion should produce a transform")
    let jumping = provider.motionValue(for: .jumping, profile: profile, elapsed: 0.21, reducedMotion: false)
    expect(jumping.offset.height != 0, "jumping motion should lift the rendered image")
    let dragging = provider.motionValue(for: .dragging, profile: profile, elapsed: 0.12, reducedMotion: false)
    expect(dragging == .identity, "dragging should suppress autonomous render motion")
    let reduced = provider.motionValue(for: .happy, profile: profile, elapsed: 0.24, reducedMotion: true)
    expect(reduced == .identity, "reduced motion should suppress continuous transforms")
}

@MainActor
private func validateBubbleEngine() {
    let profile = BubbleProfileDefaults.defaultProfile()
    let phraseProvider = DefaultBubblePhraseProvider(profile: profile, selector: { $0.first })
    let engine = BubbleEngine(profile: profile, phraseProvider: phraseProvider)

    let now = Date(timeIntervalSince1970: 1_700_000_000)
    let clicked = engine.handle(event: .clicked, state: .defaultState(at: now), at: now)
    expect(clicked?.priority == .interaction, "clicked event should produce interaction bubble")
    expect(engine.currentBubble == clicked, "bubble engine should keep the current bubble")

    engine.isEnabled = false
    expect(engine.currentBubble == nil, "disabling bubbles should clear current bubble")

    let stateEngine = BubbleEngine(profile: profile, phraseProvider: phraseProvider)
    var hungryState = PetRuntimeState.defaultState(at: now)
    hungryState.hunger = 0.9
    let hungry = stateEngine.tick(state: hungryState, at: now.addingTimeInterval(1))
    expect(hungry?.priority == .state, "high hunger should produce state-priority bubble")

    let quietProfile = BubbleProfile(phrases: [:], minimumIntervalSeconds: 0, displayDurationSeconds: 3)
    let quietEngine = BubbleEngine(
        profile: quietProfile,
        phraseProvider: DefaultBubblePhraseProvider(profile: quietProfile)
    )
    let missingPhrase = quietEngine.handle(event: .clicked, state: .defaultState(at: now), at: now)
    expect(missingPhrase == nil, "missing bubble phrase should quietly produce no bubble")
}

private func makeSingleImageDefinition(id: String) -> PetDefinition {
    let animations = Dictionary(uniqueKeysWithValues: PetState.allCases.map { state in
        (
            state,
            AnimationClip(
                state: state,
                frames: [SpriteFrame(column: 0, row: 0)],
                frameDurationMs: 1_000,
                loop: true
            )
        )
    })

    return PetDefinition(
        id: id,
        displayName: id,
        description: "Validation single image pet",
        assetName: "image.png",
        previewAssetName: "preview.png",
        frameSize: CGSizeCodable(width: 128, height: 128),
        spritesheet: nil,
        defaultScale: 1.0,
        animations: animations,
        assetKind: .singleImage,
        motionProfile: MotionProfileDefaults.singleImageDefault(),
        bubbleProfile: BubbleProfileDefaults.defaultProfile()
    )
}

private final class ScratchDirectory {
    let root: URL

    init(name: String) {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(name)-\(UUID().uuidString)", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        } catch {
            fail("could not create scratch directory: \(error)")
        }
    }

    func cleanUp() {
        try? FileManager.default.removeItem(at: root)
    }
}

private func writePNG(to url: URL, width: Int, height: Int, hasAlpha: Bool) {
    do {
        try writePNGData(width: width, height: height, hasAlpha: hasAlpha).write(to: url, options: [.atomic])
    } catch {
        fail("could not write validation png: \(error)")
    }
}

private func writePNGData(width: Int, height: Int, hasAlpha: Bool = false) throws -> Data {
    let bitmapInfo = hasAlpha
        ? CGImageAlphaInfo.premultipliedLast.rawValue
        : CGImageAlphaInfo.noneSkipLast.rawValue
    guard let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: bitmapInfo
    ) else {
        fail("could not create validation image context")
    }

    context.setFillColor(CGColor(red: 0.15, green: 0.45, blue: 0.95, alpha: hasAlpha ? 0.75 : 1.0))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))

    guard let image = context.makeImage() else {
        fail("could not create validation image")
    }
    let rep = NSBitmapImageRep(cgImage: image)
    guard let data = rep.representation(using: .png, properties: [:]) else {
        fail("could not encode validation png")
    }
    return data
}

private func packageManifestJSON(id: String) -> String {
    """
    {
      "schemaVersion": 2,
      "id": "\(id)",
      "displayName": "Package Pet",
      "description": "package validation pet",
      "asset": "spritesheet.png",
      "preview": "preview.png",
      "assetKind": "spriteSheet",
      "frameSize": { "width": 128, "height": 128 },
      "spritesheet": { "columns": 2, "rows": 7 },
      "defaultScale": 1.0,
      "animations": {
        "idle": { "frames": [{ "column": 0, "row": 0 }, { "column": 1, "row": 0 }], "frameDurationMs": 160, "loop": true },
        "walking": { "frames": [{ "column": 0, "row": 1 }, { "column": 1, "row": 1 }], "frameDurationMs": 140, "loop": true },
        "sleeping": { "frames": [{ "column": 0, "row": 2 }], "frameDurationMs": 300, "loop": true },
        "happy": { "frames": [{ "column": 0, "row": 3 }], "frameDurationMs": 120, "loop": false, "nextState": "idle" },
        "eating": { "frames": [{ "column": 0, "row": 4 }], "frameDurationMs": 120, "loop": false, "nextState": "idle" },
        "jumping": { "frames": [{ "column": 0, "row": 5 }], "frameDurationMs": 110, "loop": false, "nextState": "idle" },
        "dragging": { "frames": [{ "column": 0, "row": 6 }], "frameDurationMs": 160, "loop": true }
      }
    }
    """
}

private func tryOrFail<T>(_ expression: @autoclosure () throws -> T, _ message: String) -> T {
    do {
        return try expression()
    } catch {
        fail("\(message): \(error)")
    }
}

private func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        fail(message)
    }
}

private func fail(_ message: String) -> Never {
    fputs("DesktopPetCustomPetValidation failed: \(message)\n", stderr)
    Foundation.exit(1)
}

runCustomPetValidation()
