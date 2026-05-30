import Foundation
import DesktopPet

@MainActor
func runCustomPetErrorHandlingTests() {
    let tests = CustomPetErrorHandlingTests()
    tests.petLibraryErrorMapsToImportDeleteAndManifestTypes()
    tests.importFailureDoesNotChangeCurrentPetAndCleansPartialFolder()
    tests.manifestFailureDoesNotSelectNewPet()
    tests.corruptManifestIsSkippedWithoutThrowing()
    tests.missingBubblePhraseProducesNoBubble()
}

@MainActor
private struct CustomPetErrorHandlingTests {
    func petLibraryErrorMapsToImportDeleteAndManifestTypes() {
        expect(
            PetLibraryError.unsupportedImageType.imageImportError == .unsupportedImageType,
            "unsupported image should map to import error type"
        )
        expect(
            PetLibraryError.cannotWriteImage.imageImportError == .cannotWriteImage,
            "image write failures should map to import error type"
        )
        expect(
            PetLibraryError.cannotDeleteBuiltInPet.deletionError == .cannotDeleteBuiltInPet,
            "built-in delete should map to deletion error type"
        )
        expect(
            PetLibraryError.cannotDeletePet.deletionError == .cannotDeletePet,
            "filesystem delete failure should map to deletion error type"
        )
        expect(
            PetLibraryError.cannotWriteManifest.manifestError == .cannotWriteManifest,
            "manifest write failure should map to manifest error type"
        )
        expect(
            PetLibraryError.corruptManifest.manifestError == .corruptManifest,
            "corrupt manifest should map to manifest error type"
        )
        expect(
            PetLibraryError.petNotFound.imageImportError == nil,
            "petNotFound should not be reported as an image import error"
        )
    }

    func importFailureDoesNotChangeCurrentPetAndCleansPartialFolder() {
        let scratch = ErrorHandlingScratch()
        defer { scratch.cleanUp() }

        let store = ErrorHandlingStore(importedPetsDirectoryURL: scratch.root)
        store.definitions["starter-pet"] = makeErrorHandlingDefinition(id: "starter-pet")
        let preferences = makeErrorHandlingPreferences(knownPetIds: ["starter-pet"])
        preferences.selectedPetId = "starter-pet"

        let importer = ErrorHandlingImporter()
        importer.error = .cannotWriteImage
        importer.createPartialFolderBeforeFailure = true
        let writer = ErrorHandlingManifestWriter()
        let commander = PetLibraryCommander(
            store: store,
            importer: importer,
            manifestWriter: writer,
            preferences: preferences,
            petIdGenerator: { "failed-pet" }
        )

        var importError: PetLibraryError?
        var selectedDefinition: PetDefinition?
        commander.onImportFailed = { importError = $0 }
        commander.onCurrentPetChanged = { selectedDefinition = $0 }

        commander.importPetImage(at: URL(fileURLWithPath: "/tmp/broken.png"), displayName: "Broken")

        let failedFolder = scratch.root.appendingPathComponent("failed-pet", isDirectory: true)
        expect(importError == .cannotWriteImage, "image import failure should surface exact error")
        expect(selectedDefinition == nil, "failed import should not select a new pet")
        expect(preferences.selectedPetId == "starter-pet", "failed import should leave current pet unchanged")
        expect(writer.calls.isEmpty, "manifest writer should not run after importer failure")
        expect(!FileManager.default.fileExists(atPath: failedFolder.path), "partial import folder should be cleaned")
    }

    func manifestFailureDoesNotSelectNewPet() {
        let scratch = ErrorHandlingScratch()
        defer { scratch.cleanUp() }

        let store = ErrorHandlingStore(importedPetsDirectoryURL: scratch.root)
        store.definitions["starter-pet"] = makeErrorHandlingDefinition(id: "starter-pet")
        store.definitions["new-pet"] = makeErrorHandlingDefinition(id: "new-pet")
        let preferences = makeErrorHandlingPreferences(knownPetIds: ["starter-pet", "new-pet"])
        preferences.selectedPetId = "starter-pet"

        let importer = ErrorHandlingImporter()
        let writer = ErrorHandlingManifestWriter()
        writer.error = .cannotWriteManifest
        let commander = PetLibraryCommander(
            store: store,
            importer: importer,
            manifestWriter: writer,
            preferences: preferences,
            petIdGenerator: { "new-pet" }
        )

        var importError: PetLibraryError?
        var libraryChanged = false
        var selectedDefinition: PetDefinition?
        commander.onImportFailed = { importError = $0 }
        commander.onLibraryChanged = { libraryChanged = true }
        commander.onCurrentPetChanged = { selectedDefinition = $0 }

        commander.importPetImage(at: URL(fileURLWithPath: "/tmp/cat.png"), displayName: "Cat")

        expect(importError == .cannotWriteManifest, "manifest failure should surface manifest error")
        expect(libraryChanged == false, "manifest failure should not report library changed")
        expect(selectedDefinition == nil, "manifest failure should not select the new pet")
        expect(preferences.selectedPetId == "starter-pet", "manifest failure should leave current pet unchanged")
    }

    func corruptManifestIsSkippedWithoutThrowing() {
        let scratch = ErrorHandlingScratch()
        defer { scratch.cleanUp() }

        let store = PetLibraryStore(rootDirectory: scratch.root)
        let badFolder = store.importedPetsDirectoryURL.appendingPathComponent("bad-pet", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: badFolder, withIntermediateDirectories: true)
            try Data("{ not json".utf8).write(to: badFolder.appendingPathComponent(PetLibraryStore.manifestFileName))
        } catch {
            fail("failed to seed corrupt manifest: \(error)")
        }

        do {
            let items = try store.listPets()
            expect(items.contains(where: { $0.id == store.builtInPetId }), "built-in pet should still be listed")
            expect(!items.contains(where: { $0.id == "bad-pet" }), "corrupt manifest should be skipped")
        } catch {
            fail("corrupt manifest should not make listPets throw: \(error)")
        }
    }

    func missingBubblePhraseProducesNoBubble() {
        let profile = BubbleProfile(
            phrases: [:],
            minimumIntervalSeconds: 0,
            displayDurationSeconds: 3
        )
        let engine = BubbleEngine(
            profile: profile,
            phraseProvider: DefaultBubblePhraseProvider(profile: profile)
        )

        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let eventBubble = engine.handle(event: .clicked, state: .defaultState(at: now), at: now)

        var state = PetRuntimeState.defaultState(at: now.addingTimeInterval(-300))
        state.currentState = .walking
        let tickBubble = engine.tick(state: state, at: now)

        expect(eventBubble == nil, "missing interaction phrase should not emit a bubble")
        expect(tickBubble == nil, "missing ambient phrase should not emit a bubble")
        expect(engine.currentBubble == nil, "missing phrase fallback should leave current bubble nil")
    }
}

private final class ErrorHandlingScratch {
    let root: URL

    init() {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("CustomPetErrorHandlingTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    func cleanUp() {
        try? FileManager.default.removeItem(at: root)
    }
}

private final class ErrorHandlingStore: PetLibraryStoring, @unchecked Sendable {
    let builtInPetId = "starter-pet"
    let importedPetsDirectoryURL: URL
    var definitions: [String: PetDefinition] = [:]

    init(importedPetsDirectoryURL: URL) {
        self.importedPetsDirectoryURL = importedPetsDirectoryURL
    }

    func listPets() throws -> [PetLibraryItem] {
        definitions.values.map { definition in
            PetLibraryItem(
                id: definition.id,
                displayName: definition.displayName,
                source: definition.id == builtInPetId ? .builtIn : .importedImage,
                folderURL: definition.id == builtInPetId ? nil : importedPetsDirectoryURL.appendingPathComponent(definition.id),
                previewURL: nil,
                createdAt: Date(timeIntervalSince1970: 0)
            )
        }
    }

    func loadDefinition(id: String) throws -> PetDefinition {
        if let definition = definitions[id] {
            return definition
        }
        if let builtIn = definitions[builtInPetId] {
            return builtIn
        }
        throw PetLibraryError.petNotFound
    }

    func deleteImportedPet(id: String) throws {}
}

private final class ErrorHandlingImporter: PetImageImporting, @unchecked Sendable {
    var error: PetLibraryError?
    var createPartialFolderBeforeFailure = false

    func importImage(
        from sourceURL: URL,
        to destinationFolder: URL,
        displayName: String
    ) throws -> ImportedPetImage {
        if createPartialFolderBeforeFailure {
            try FileManager.default.createDirectory(at: destinationFolder, withIntermediateDirectories: true)
            try Data("partial".utf8).write(to: destinationFolder.appendingPathComponent(PetImageImporter.imageFileName))
        }
        if let error {
            throw error
        }
        try FileManager.default.createDirectory(at: destinationFolder, withIntermediateDirectories: true)
        return ImportedPetImage(
            imageFileName: PetImageImporter.imageFileName,
            previewFileName: PetImageImporter.previewFileName,
            pixelSize: CGSizeCodable(width: 128, height: 128),
            hasAlpha: true
        )
    }
}

private final class ErrorHandlingManifestWriter: PetLibraryManifestWriting, @unchecked Sendable {
    private(set) var calls: [String] = []
    var error: PetLibraryError?

    func writeSingleImageManifest(
        petId: String,
        displayName: String,
        image: ImportedPetImage,
        to folderURL: URL
    ) throws {
        calls.append(petId)
        if let error {
            throw error
        }
    }
}

@MainActor
private func makeErrorHandlingPreferences(knownPetIds: Set<String>) -> PreferencesStore {
    let suiteName = "CustomPetErrorHandlingTests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)
    return PreferencesStore(userDefaults: defaults, knownPetIds: knownPetIds)
}

private func makeErrorHandlingDefinition(id: String) -> PetDefinition {
    let frame = SpriteFrame(column: 0, row: 0)
    let animations = Dictionary(uniqueKeysWithValues: PetState.allCases.map { state in
        (
            state,
            AnimationClip(
                state: state,
                frames: [frame],
                frameDurationMs: 200,
                loop: true,
                nextState: nil
            )
        )
    })
    return PetDefinition(
        id: id,
        displayName: id,
        description: "Test \(id)",
        assetName: PetDefinition.placeholderAssetName,
        previewAssetName: PetDefinition.placeholderAssetName,
        frameSize: CGSizeCodable(width: 128, height: 128),
        spritesheet: SpriteSheetLayout(columns: 1, rows: 1),
        defaultScale: 1.0,
        animations: animations,
        assetKind: .singleImage,
        motionProfile: MotionProfileDefaults.singleImageDefault(),
        bubbleProfile: BubbleProfileDefaults.defaultProfile()
    )
}
