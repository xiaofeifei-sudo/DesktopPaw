import AppKit
import DesktopPet
import Foundation
import ImageIO

@MainActor
func runPetdexValidation() {
    validateValidPetdexZipImport()
    validatePetdexManifestSpritesheetFallbackImport()
    validateInvalidPetdexPackages()
    validatePetdexURLImports()
    validatePetdexURLFailureAndCancellation()
    validatePetdexLibraryReleaseActions()
    validatePetdexGenericFallbackRelease()
    validatePetdexUserFacingErrors()
    print("DesktopPetPetdexValidation passed")
}

@MainActor
private func validateValidPetdexZipImport() {
    let scratch = PetdexValidationScratch(name: "DesktopPetPetdexValidation")
    defer { scratch.cleanUp() }

    let archiveURL = scratch.writeZip(
        name: "my-cat-v3-large.zip",
        entries: validPetdexEntries() + [
            .stored(name: "script.sh", data: Data("#!/bin/sh\necho should-not-run\n".utf8))
        ]
    )

    let supportRoot = scratch.root.appendingPathComponent("Support", isDirectory: true)
    let store = PetLibraryStore(rootDirectory: supportRoot)
    let preferences = makePreferences(name: "DesktopPetPetdexValidation", store: store)
    preferences.selectedPetId = store.builtInPetId

    let commander = PetLibraryCommander(
        store: store,
        importer: PetImageImporter(),
        petdexPackageImporter: PetdexPackageImporter(),
        manifestWriter: PetLibraryManifestWriter(),
        preferences: preferences
    )

    var libraryChangedCount = 0
    var selectedDefinitions: [PetDefinition] = []
    var importErrors: [PetdexImportError] = []
    commander.onLibraryChanged = { libraryChangedCount += 1 }
    commander.onCurrentPetChanged = { selectedDefinitions.append($0) }
    commander.onPetdexImportFailed = { importErrors.append($0) }

    commander.importPetdexPackage(at: archiveURL)

    expect(importErrors.isEmpty, "valid Petdex zip should import without errors")
    expect(libraryChangedCount == 1, "valid Petdex import should refresh library once")
    expect(preferences.selectedPetId == "my-cat-v3-large", "valid Petdex import should select imported pet")
    expect(selectedDefinitions.last?.id == "my-cat-v3-large", "valid Petdex import should publish selected definition")

    let importedFolder = store.importedPetsDirectoryURL.appendingPathComponent("my-cat-v3-large", isDirectory: true)
    expect(FileManager.default.fileExists(atPath: importedFolder.appendingPathComponent("manifest.json").path), "Petdex import should write internal manifest")
    expect(FileManager.default.fileExists(atPath: importedFolder.appendingPathComponent("spritesheet.png").path), "Petdex import should write converted spritesheet")
    expect(FileManager.default.fileExists(atPath: importedFolder.appendingPathComponent("preview.png").path), "Petdex import should write preview")
    expect(FileManager.default.fileExists(atPath: importedFolder.appendingPathComponent(PetdexSourceMetadata.fileName).path), "Petdex import should write source sidecar")
    expect(!FileManager.default.fileExists(atPath: importedFolder.appendingPathComponent("script.sh").path), "Petdex import should not copy zip scripts")

    let items = tryOrFail(try store.listPets(), "pet library should list imported Petdex pet")
    expect(
        items.contains(where: { $0.id == "my-cat-v3-large" && $0.displayName == "Beibei" && $0.source == .petdex }),
        "imported Petdex pet should be listed with manifest metadata and petdex source"
    )

    let definition = tryOrFail(try store.loadDefinition(id: "my-cat-v3-large"), "imported Petdex definition should load")
    expect(definition.assetKind == .spriteSheet, "Petdex import should produce spriteSheet internal definition")
    expect(definition.catalog.actions.count == 9, "Petdex import should include one generic action per row")
    expect(definition.catalog.actions.allSatisfy { $0.role == nil }, "Petdex import should not force rows into legacy roles")
    expect(definition.catalog.actions.map(\.id.rawValue) == (1...9).map { "action_\($0)" }, "Petdex row actions should preserve row order")
    validatePetdexAnimationAcceptance(definition, context: "local zip import")
    validatePNGHasAlpha(
        at: importedFolder.appendingPathComponent("spritesheet.png"),
        "converted Petdex spritesheet should retain transparent background support"
    )
    validatePNGHasAlpha(
        at: importedFolder.appendingPathComponent("preview.png"),
        "Petdex preview should retain transparent background support"
    )

    do {
        try FileManager.default.removeItem(at: archiveURL)
    } catch {
        fail("could not remove original Petdex zip: \(error)")
    }

    let reloaded = tryOrFail(try store.loadDefinition(id: "my-cat-v3-large"), "imported Petdex pet should load after source zip deletion")
    expect(reloaded.id == "my-cat-v3-large", "source zip deletion should not affect imported Petdex pet")
    expect(reloaded.catalog.actions.count == 9, "reloaded my-cat-v3-large equivalent should preserve generic row actions")
}

private func validatePetdexManifestSpritesheetFallbackImport() {
    let scratch = PetdexValidationScratch(name: "DesktopPetPetdexFallbackValidation")
    defer { scratch.cleanUp() }

    let archiveURL = scratch.writeZip(
        name: "omegamon-compatible.zip",
        entries: [
            .stored(
                name: "pet.json",
                data: validManifestData(
                    id: "omegamon",
                    displayName: "Omegamon",
                    spritesheetPath: "spritesheet.webp"
                )
            ),
            .stored(name: "spritesheet.png", data: makePNGData(width: 16, height: 18))
        ]
    )
    let importedPetsDirectoryURL = scratch.root.appendingPathComponent("Imported", isDirectory: true)

    do {
        let definition = try PetdexPackageImporter().importPackage(
            at: archiveURL,
            to: importedPetsDirectoryURL,
            builtInPetId: "builtin-pet"
        )
        expect(definition.id == "omegamon", "Petdex fallback import should preserve manifest pet id")
        expect(definition.assetName == "spritesheet.png", "Petdex fallback import should reference the converted spritesheet")
        expect(definition.assetKind == .spriteSheet, "Petdex fallback import should produce a spriteSheet definition")
        expect(
            FileManager.default.fileExists(
                atPath: importedPetsDirectoryURL
                    .appendingPathComponent("omegamon", isDirectory: true)
                    .appendingPathComponent("spritesheet.png")
                    .path
            ),
            "Petdex fallback import should write converted PNG output"
        )
    } catch {
        fail("Petdex zip should import when manifest WebP has same-basename PNG fallback: \(error)")
    }
}

@MainActor
private func validatePetdexLibraryReleaseActions() {
    let scratch = PetdexValidationScratch(name: "DesktopPetPetdexReleaseActions")
    defer { scratch.cleanUp() }

    let firstArchiveURL = scratch.writeZip(
        name: "my-cat-v3-large.zip",
        entries: validPetdexEntries(id: "my-cat-v3-large", displayName: "Beibei")
    )
    let secondArchiveURL = scratch.writeZip(
        name: "desk-dog.zip",
        entries: validPetdexEntries(id: "desk-dog", displayName: "Desk Dog")
    )
    let supportRoot = scratch.root.appendingPathComponent("Support", isDirectory: true)
    let store = PetLibraryStore(rootDirectory: supportRoot)
    let preferences = makePreferences(name: "DesktopPetPetdexReleaseActions", store: store)
    preferences.selectedPetId = store.builtInPetId

    let commander = PetLibraryCommander(
        store: store,
        importer: PetImageImporter(),
        petdexPackageImporter: PetdexPackageImporter(),
        manifestWriter: PetLibraryManifestWriter(),
        preferences: preferences
    )

    var libraryChangedCount = 0
    var selectedDefinitions: [PetDefinition] = []
    var importErrors: [PetdexImportError] = []
    var deleteErrors: [PetLibraryError] = []
    commander.onLibraryChanged = { libraryChangedCount += 1 }
    commander.onCurrentPetChanged = { selectedDefinitions.append($0) }
    commander.onPetdexImportFailed = { importErrors.append($0) }
    commander.onDeleteFailed = { deleteErrors.append($0) }

    commander.importPetdexPackage(at: firstArchiveURL)
    commander.importPetdexPackage(at: secondArchiveURL)

    expect(importErrors.isEmpty, "multiple Petdex packages should import without errors")
    expect(libraryChangedCount == 2, "each Petdex import should refresh the library")
    expect(preferences.selectedPetId == "desk-dog", "latest Petdex import should become the selected pet")
    expect(Array(selectedDefinitions.map(\.id).suffix(2)) == ["my-cat-v3-large", "desk-dog"], "Petdex imports should publish selected definitions")

    let importedItems = tryOrFail(try store.listPets(), "pet library should list multiple imported Petdex pets")
    expect(
        importedItems.contains(where: { $0.id == "my-cat-v3-large" && $0.displayName == "Beibei" && $0.source == .petdex }),
        "first Petdex pet should remain listed with metadata"
    )
    expect(
        importedItems.contains(where: { $0.id == "desk-dog" && $0.displayName == "Desk Dog" && $0.source == .petdex }),
        "second Petdex pet should coexist with the first"
    )

    commander.deletePet(id: "desk-dog")

    expect(deleteErrors.isEmpty, "deleting a Petdex pet should not report errors")
    expect(libraryChangedCount == 3, "deleting a Petdex pet should refresh the library")
    expect(preferences.selectedPetId == store.builtInPetId, "deleting the selected Petdex pet should fall back to built-in pet")
    expect(selectedDefinitions.last?.id == store.builtInPetId, "delete fallback should publish built-in definition")

    let remainingItems = tryOrFail(try store.listPets(), "pet library should list remaining pets after Petdex delete")
    expect(!remainingItems.contains(where: { $0.id == "desk-dog" }), "deleted Petdex pet should be removed from the list")
    expect(
        remainingItems.contains(where: { $0.id == "my-cat-v3-large" && $0.source == .petdex }),
        "deleting one Petdex pet should leave other imported Petdex pets intact"
    )
}

private func validatePetdexUserFacingErrors() {
    let errors: [PetdexImportError] = [
        .notZipFile,
        .missingManifest,
        .missingSpritesheet("spritesheet.png"),
        .manifestDecodingFailed,
        .unreadableImage("spritesheet.png"),
        .invalidSpritesheetLayout("image dimensions 10x10 are not divisible by 8x9"),
        .downloadFailed("network unavailable"),
        .downloadCancelled,
        .unsupportedPetdexURL("https://example.com/pet.zip"),
        .petAlreadyExists("my-cat-v3-large")
    ]

    for error in errors {
        let description = error.errorDescription ?? ""
        expect(!description.isEmpty, "\(error) should expose a user-facing error message")
        expect(description.count <= 180, "\(error) error message should stay concise")
        expect(!description.localizedCaseInsensitiveContains("Optional("), "\(error) error message should not leak debug formatting")
    }
}

private func validatePetdexGenericFallbackRelease() {
    let scratch = PetdexValidationScratch(name: "DesktopPetPetdexReleaseFallback")
    defer { scratch.cleanUp() }

    let archiveURL = scratch.writeZip(
        name: "one-row-petdex.zip",
        entries: [
            .stored(name: "pet.json", data: validManifestData(id: "one-row-petdex", displayName: "One Row")),
            .stored(name: "spritesheet.png", data: makePNGData(width: 16, height: 2))
        ]
    )
    let importedPetsDirectoryURL = scratch.root.appendingPathComponent("Imported", isDirectory: true)
    let importer = PetdexPackageImporter(
        mappingProvider: DefaultPetdexAnimationMappingProvider(columns: 8, rows: 1),
        imageConvention: PetdexSpriteSheetConvention(columns: 8, rows: 1)
    )

    let definition = tryOrFail(
        try importer.importPackage(
            at: archiveURL,
            to: importedPetsDirectoryURL,
            builtInPetId: "builtin-pet"
        ),
        "one-row Petdex package should import with release fallback coverage"
    )

    guard let action = definition.catalog.actions.first,
          let idleClip = definition.animation(for: .idle),
          let walkingClip = definition.animation(for: .walking) else {
        fail("one-row Petdex package should expose a generic default action")
    }
    expect(definition.catalog.actions.count == 1, "one-row Petdex package should keep one generic action")
    expect(action.id.rawValue == "action_1", "one-row Petdex action should use generic row id")
    expect(action.role == nil, "one-row Petdex action should not synthesize a legacy role")
    expect(action.frames == rowFrames(row: 0, columns: 8), "one-row Petdex action should use row 0 frames")
    expect(definition.catalog.actions(for: .dragging).isEmpty, "one-row Petdex package should not synthesize dragging")
    expect(walkingClip.frames == idleClip.frames, "one-row Petdex package should resolve missing walking through the default action fallback")
    expect(!petdexWarningsFileExists(id: "one-row-petdex", petsRoot: importedPetsDirectoryURL), "one-row generic Petdex package should not persist role fallback warnings")
}

@MainActor
private func validateInvalidPetdexPackages() {
    validatePetdexFailure(
        name: "missing-manifest",
        expectedError: .missingManifest,
        entries: [
            .stored(name: "spritesheet.png", data: makePNGData(width: 16, height: 18))
        ]
    )

    validatePetdexFailure(
        name: "missing-spritesheet",
        expectedError: .missingSpritesheet("spritesheet.png"),
        entries: [
            .stored(name: "pet.json", data: validManifestData())
        ]
    )

    validatePetdexFailure(
        name: "invalid-image",
        expectedError: .unreadableImage("spritesheet.png"),
        entries: [
            .stored(name: "pet.json", data: validManifestData()),
            .stored(name: "spritesheet.png", data: Data("not an image".utf8))
        ]
    )
}

@MainActor
private func validatePetdexFailure(
    name: String,
    expectedError: PetdexImportError,
    entries: [PetdexValidationZipEntry]
) {
    let scratch = PetdexValidationScratch(name: "DesktopPetPetdexValidation-\(name)")
    defer { scratch.cleanUp() }

    let archiveURL = scratch.writeZip(name: "\(name).zip", entries: entries)
    let supportRoot = scratch.root.appendingPathComponent("Support", isDirectory: true)
    let store = PetLibraryStore(rootDirectory: supportRoot)
    let preferences = makePreferences(name: "DesktopPetPetdexValidation-\(name)", store: store)
    preferences.selectedPetId = store.builtInPetId

    let commander = PetLibraryCommander(
        store: store,
        importer: PetImageImporter(),
        petdexPackageImporter: PetdexPackageImporter(),
        manifestWriter: PetLibraryManifestWriter(),
        preferences: preferences
    )

    var libraryChanged = false
    var selectedDefinition: PetDefinition?
    var reportedErrors: [PetdexImportError] = []
    commander.onLibraryChanged = { libraryChanged = true }
    commander.onCurrentPetChanged = { selectedDefinition = $0 }
    commander.onPetdexImportFailed = { reportedErrors.append($0) }

    commander.importPetdexPackage(at: archiveURL)

    expect(reportedErrors == [expectedError], "\(name) should report expected Petdex error")
    expect(libraryChanged == false, "\(name) should not mark library changed")
    expect(selectedDefinition == nil, "\(name) should not publish a selected definition")
    expect(preferences.selectedPetId == store.builtInPetId, "\(name) should leave selected pet unchanged")
}

@MainActor
private func validatePetdexURLImports() {
    validatePetdexURLImportSuccess(
        name: "page-url",
        input: "https://petdex.crafter.run/zh/pets/my-cat-v3-large",
        requestKind: .page
    )
    validatePetdexURLImportSuccess(
        name: "download-url",
        input: "https://petdex.crafter.run/downloads/my-cat-v3-large.zip",
        requestKind: .archive
    )
}

@MainActor
private func validatePetdexURLImportSuccess(
    name: String,
    input: String,
    requestKind: PetdexDownloadRequest.Kind
) {
    let scratch = PetdexValidationScratch(name: "DesktopPetPetdexURLValidation-\(name)")
    defer { scratch.cleanUp() }

    let archiveURL = scratch.writeZip(name: "my-cat-v3-large.zip", entries: validPetdexEntries())
    let supportRoot = scratch.root.appendingPathComponent("Support", isDirectory: true)
    let store = PetLibraryStore(rootDirectory: supportRoot)
    let preferences = makePreferences(name: "DesktopPetPetdexURLValidation-\(name)", store: store)
    preferences.selectedPetId = store.builtInPetId

    let request = PetdexDownloadRequest(
        sourceURL: URL(string: input) ?? URL(fileURLWithPath: input),
        kind: requestKind,
        suggestedFileName: "my-cat-v3-large.zip"
    )
    let resolver = PetdexValidationURLResolver(request: request)
    let downloader = PetdexValidationImmediateDownloader(result: .success(archiveURL))
    let commander = PetLibraryCommander(
        store: store,
        importer: PetImageImporter(),
        petdexPackageImporter: PetdexPackageImporter(),
        petdexURLResolver: resolver,
        petdexDownloader: downloader,
        manifestWriter: PetLibraryManifestWriter(),
        preferences: preferences
    )

    var phases: [PetdexURLImportPhase] = []
    var successCount = 0
    var libraryChangedCount = 0
    var selectedDefinitions: [PetDefinition] = []
    var urlErrors: [PetdexImportError] = []
    commander.onPetdexURLImportPhaseChanged = { phases.append($0) }
    commander.onPetdexURLImportSucceeded = { successCount += 1 }
    commander.onLibraryChanged = { libraryChangedCount += 1 }
    commander.onCurrentPetChanged = { selectedDefinitions.append($0) }
    commander.onPetdexURLImportFailed = { urlErrors.append($0) }

    commander.importPetdexURL(input)
    waitUntil("\(name) URL import should complete") {
        successCount == 1
    }

    expect(resolver.inputs == [input], "\(name) should resolve the user-entered URL")
    expect(downloader.requests == [request], "\(name) should download the resolved request")
    expect(phases == [.downloading, .importing], "\(name) should report downloading then importing")
    expect(urlErrors.isEmpty, "\(name) should not report URL import errors")
    expect(libraryChangedCount == 1, "\(name) should refresh library once")
    expect(preferences.selectedPetId == "my-cat-v3-large", "\(name) should select imported pet")
    expect(selectedDefinitions.last?.id == "my-cat-v3-large", "\(name) should publish imported definition")

    let items = tryOrFail(try store.listPets(), "\(name) should list imported Petdex URL pet")
    expect(
        items.contains(where: { $0.id == "my-cat-v3-large" && $0.displayName == "Beibei" && $0.source == .petdex }),
        "\(name) should list URL-imported pet with Petdex metadata"
    )

    let definition = tryOrFail(try store.loadDefinition(id: "my-cat-v3-large"), "\(name) should load URL-imported definition")
    expect(definition.catalog.actions.count == 9, "\(name) should keep all generic Petdex row actions")
    expect(definition.catalog.actions.allSatisfy { $0.role == nil }, "\(name) should keep URL-imported Petdex actions role-less")
}

@MainActor
private func validatePetdexURLFailureAndCancellation() {
    validatePetdexURLDownloadFailure()
    validatePetdexURLDownloadCancellation()
}

@MainActor
private func validatePetdexURLDownloadFailure() {
    let scratch = PetdexValidationScratch(name: "DesktopPetPetdexURLValidation-failure")
    defer { scratch.cleanUp() }

    let supportRoot = scratch.root.appendingPathComponent("Support", isDirectory: true)
    let store = PetLibraryStore(rootDirectory: supportRoot)
    let preferences = makePreferences(name: "DesktopPetPetdexURLValidation-failure", store: store)
    preferences.selectedPetId = store.builtInPetId

    let input = "https://petdex.crafter.run/zh/pets/missing-cat"
    let request = PetdexDownloadRequest(
        sourceURL: URL(string: input) ?? URL(fileURLWithPath: input),
        kind: .page,
        suggestedFileName: "missing-cat.zip"
    )
    let resolver = PetdexValidationURLResolver(request: request)
    let downloader = PetdexValidationImmediateDownloader(result: .failure(.downloadFailed("network unavailable")))
    let commander = PetLibraryCommander(
        store: store,
        importer: PetImageImporter(),
        petdexPackageImporter: PetdexPackageImporter(),
        petdexURLResolver: resolver,
        petdexDownloader: downloader,
        manifestWriter: PetLibraryManifestWriter(),
        preferences: preferences
    )

    var libraryChanged = false
    var selectedDefinition: PetDefinition?
    var urlErrors: [PetdexImportError] = []
    var packageErrors: [PetdexImportError] = []
    commander.onLibraryChanged = { libraryChanged = true }
    commander.onCurrentPetChanged = { selectedDefinition = $0 }
    commander.onPetdexURLImportFailed = { urlErrors.append($0) }
    commander.onPetdexImportFailed = { packageErrors.append($0) }

    commander.importPetdexURL(input)
    waitUntil("URL download failure should be reported") {
        !urlErrors.isEmpty
    }

    expect(urlErrors == [.downloadFailed("network unavailable")], "URL download failure should report clear Petdex error")
    expect(packageErrors.isEmpty, "URL download failure should not be reported as local zip import failure")
    expect(libraryChanged == false, "URL download failure should not refresh library")
    expect(selectedDefinition == nil, "URL download failure should not publish selected definition")
    expect(preferences.selectedPetId == store.builtInPetId, "URL download failure should leave current pet unchanged")
}

@MainActor
private func validatePetdexURLDownloadCancellation() {
    let scratch = PetdexValidationScratch(name: "DesktopPetPetdexURLValidation-cancel")
    defer { scratch.cleanUp() }

    let supportRoot = scratch.root.appendingPathComponent("Support", isDirectory: true)
    let store = PetLibraryStore(rootDirectory: supportRoot)
    let preferences = makePreferences(name: "DesktopPetPetdexURLValidation-cancel", store: store)
    preferences.selectedPetId = store.builtInPetId

    let input = "https://petdex.crafter.run/zh/pets/my-cat-v3-large"
    let request = PetdexDownloadRequest(
        sourceURL: URL(string: input) ?? URL(fileURLWithPath: input),
        kind: .page,
        suggestedFileName: "my-cat-v3-large.zip"
    )
    let resolver = PetdexValidationURLResolver(request: request)
    let downloader = PetdexValidationSuspendingDownloader()
    let commander = PetLibraryCommander(
        store: store,
        importer: PetImageImporter(),
        petdexPackageImporter: PetdexPackageImporter(),
        petdexURLResolver: resolver,
        petdexDownloader: downloader,
        manifestWriter: PetLibraryManifestWriter(),
        preferences: preferences
    )

    var cancelledCount = 0
    var libraryChanged = false
    var selectedDefinition: PetDefinition?
    var phases: [PetdexURLImportPhase] = []
    commander.onPetdexURLImportCancelled = { cancelledCount += 1 }
    commander.onPetdexURLImportPhaseChanged = { phases.append($0) }
    commander.onLibraryChanged = { libraryChanged = true }
    commander.onCurrentPetChanged = { selectedDefinition = $0 }

    commander.importPetdexURL(input)
    waitUntil("URL download should start before cancellation") {
        downloader.didStart
    }
    commander.cancelPetdexURLImport()
    waitUntil("URL download task should observe cancellation") {
        downloader.didComplete
    }

    expect(downloader.requests == [request], "cancelled URL import should begin one download request")
    expect(cancelledCount == 1, "cancelled URL import should report cancellation once")
    expect(phases == [.downloading], "cancelled URL import should not reach importing phase")
    expect(libraryChanged == false, "cancelled URL import should not refresh library")
    expect(selectedDefinition == nil, "cancelled URL import should not publish selected definition")
    expect(preferences.selectedPetId == store.builtInPetId, "cancelled URL import should leave current pet unchanged")
}

@MainActor
private func makePreferences(name: String, store: PetLibraryStore) -> PreferencesStore {
    let suiteName = "\(name)-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName) ?? .standard
    defaults.removePersistentDomain(forName: suiteName)
    return PreferencesStore(
        userDefaults: defaults,
        knownPetIdsProvider: {
            let items = (try? store.listPets()) ?? []
            return Set(items.map(\.id))
        }
    )
}

private func validPetdexEntries(id: String = "my-cat-v3-large") -> [PetdexValidationZipEntry] {
    [
        .stored(name: "pet.json", data: validManifestData(id: id)),
        .stored(name: "spritesheet.png", data: makePNGData(width: 16, height: 18))
    ]
}

private func validPetdexEntries(
    id: String,
    displayName: String
) -> [PetdexValidationZipEntry] {
    [
        .stored(name: "pet.json", data: validManifestData(id: id, displayName: displayName)),
        .stored(name: "spritesheet.png", data: makePNGData(width: 16, height: 18))
    ]
}

private func validManifestData(
    id: String = "my-cat-v3-large",
    displayName: String = "Beibei",
    spritesheetPath: String = "spritesheet.png"
) -> Data {
    Data(
        """
        {
          "id": "\(id)",
          "displayName": "\(displayName)",
          "description": "A Petdex validation package.",
          "spritesheetPath": "\(spritesheetPath)"
        }
        """.utf8
    )
}

private func makePNGData(width: Int, height: Int) -> Data {
    guard let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        fail("could not create PNG context")
    }

    context.setFillColor(red: 0, green: 0, blue: 0, alpha: 0)
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    context.setFillColor(red: 0.3, green: 0.6, blue: 0.9, alpha: 0.7)
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))

    guard let image = context.makeImage() else {
        fail("could not create PNG image")
    }

    let output = NSMutableData()
    guard let destination = CGImageDestinationCreateWithData(output, "public.png" as CFString, 1, nil) else {
        fail("could not create PNG destination")
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        fail("could not encode PNG")
    }
    return output as Data
}

private func validatePetdexAnimationAcceptance(
    _ definition: PetDefinition,
    context: String
) {
    _ = tryOrFail(try definition.validated(), "\(context) definition should pass PetDefinition validation")

    guard let spritesheet = definition.spritesheet else {
        fail("\(context) should include spritesheet layout")
    }

    expect(spritesheet.columns == 8, "\(context) should use the Petdex 8-column convention")
    expect(spritesheet.rows == 9, "\(context) should use the Petdex 9-row convention")

    expect(definition.catalog.actions.count == spritesheet.rows, "\(context) should expose one action per Petdex row")
    for (index, action) in definition.catalog.actions.enumerated() {
        expect(action.id.rawValue == "action_\(index + 1)", "\(context) generic action id should follow row order")
        expect(action.role == nil, "\(context) generic action should not have a legacy role")
        expect(!action.frames.isEmpty, "\(context) \(action.id.rawValue) should have frames")
        expect(action.frames.allSatisfy { $0.row == index }, "\(context) \(action.id.rawValue) should use its Petdex row")
        expect(action.frames.allSatisfy { $0.column >= 0 && $0.column < spritesheet.columns }, "\(context) \(action.id.rawValue) frames should stay within spritesheet columns")
    }
}

private func validatePNGHasAlpha(at url: URL, _ message: String) {
    let data = tryOrFail(try Data(contentsOf: url), "PNG should be readable at \(url.lastPathComponent)")
    guard let imageRep = NSBitmapImageRep(data: data) else {
        fail("PNG should decode as a bitmap at \(url.lastPathComponent)")
    }
    expect(imageRep.hasAlpha, message)
}

private func readPetdexWarnings(id: String, petsRoot: URL) -> [PetdexValidationWarningSidecarEntry] {
    let url = petsRoot
        .appendingPathComponent(id, isDirectory: true)
        .appendingPathComponent(ConvertedPetPackage.importWarningsFileName)
    return tryOrFail(try JSONDecoder().decode([PetdexValidationWarningSidecarEntry].self, from: Data(contentsOf: url)), "Petdex import warnings should decode")
}

private func petdexWarningsFileExists(id: String, petsRoot: URL) -> Bool {
    let url = petsRoot
        .appendingPathComponent(id, isDirectory: true)
        .appendingPathComponent(ConvertedPetPackage.importWarningsFileName)
    return FileManager.default.fileExists(atPath: url.path)
}

private func rowFrames(row: Int, columns: Int) -> [SpriteFrame] {
    (0..<columns).map { SpriteFrame(column: $0, row: row) }
}

private struct PetdexValidationWarningSidecarEntry: Decodable, Equatable {
    let kind: String
    let detail: String
    let role: ActionRole?
    let actionId: ActionId?
}

private struct PetdexValidationZipEntry {
    let name: String
    let data: Data

    static func stored(name: String, data: Data) -> PetdexValidationZipEntry {
        PetdexValidationZipEntry(name: name, data: data)
    }
}

private final class PetdexValidationScratch {
    let root: URL

    init(name: String) {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(name)-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    func cleanUp() {
        try? FileManager.default.removeItem(at: root)
    }

    func writeZip(name: String, entries: [PetdexValidationZipEntry]) -> URL {
        let url = root.appendingPathComponent(name)
        do {
            try makeZipData(entries: entries).write(to: url)
        } catch {
            fail("could not write Petdex zip fixture: \(error)")
        }
        return url
    }

    private func makeZipData(entries: [PetdexValidationZipEntry]) -> Data {
        var localData = Data()
        var centralDirectory = Data()

        for entry in entries {
            let localHeaderOffset = localData.count
            let nameData = Data(entry.name.utf8)

            localData.appendPetdexValidationZipUInt32(0x0403_4B50)
            localData.appendPetdexValidationZipUInt16(20)
            localData.appendPetdexValidationZipUInt16(0)
            localData.appendPetdexValidationZipUInt16(0)
            localData.appendPetdexValidationZipUInt16(0)
            localData.appendPetdexValidationZipUInt16(0)
            localData.appendPetdexValidationZipUInt32(0)
            localData.appendPetdexValidationZipUInt32(UInt32(entry.data.count))
            localData.appendPetdexValidationZipUInt32(UInt32(entry.data.count))
            localData.appendPetdexValidationZipUInt16(UInt16(nameData.count))
            localData.appendPetdexValidationZipUInt16(0)
            localData.append(nameData)
            localData.append(entry.data)

            centralDirectory.appendPetdexValidationZipUInt32(0x0201_4B50)
            centralDirectory.appendPetdexValidationZipUInt16(20)
            centralDirectory.appendPetdexValidationZipUInt16(20)
            centralDirectory.appendPetdexValidationZipUInt16(0)
            centralDirectory.appendPetdexValidationZipUInt16(0)
            centralDirectory.appendPetdexValidationZipUInt16(0)
            centralDirectory.appendPetdexValidationZipUInt16(0)
            centralDirectory.appendPetdexValidationZipUInt32(0)
            centralDirectory.appendPetdexValidationZipUInt32(UInt32(entry.data.count))
            centralDirectory.appendPetdexValidationZipUInt32(UInt32(entry.data.count))
            centralDirectory.appendPetdexValidationZipUInt16(UInt16(nameData.count))
            centralDirectory.appendPetdexValidationZipUInt16(0)
            centralDirectory.appendPetdexValidationZipUInt16(0)
            centralDirectory.appendPetdexValidationZipUInt16(0)
            centralDirectory.appendPetdexValidationZipUInt16(0)
            centralDirectory.appendPetdexValidationZipUInt32(0)
            centralDirectory.appendPetdexValidationZipUInt32(UInt32(localHeaderOffset))
            centralDirectory.append(nameData)
        }

        let centralDirectoryOffset = localData.count
        localData.append(centralDirectory)
        localData.appendPetdexValidationZipUInt32(0x0605_4B50)
        localData.appendPetdexValidationZipUInt16(0)
        localData.appendPetdexValidationZipUInt16(0)
        localData.appendPetdexValidationZipUInt16(UInt16(entries.count))
        localData.appendPetdexValidationZipUInt16(UInt16(entries.count))
        localData.appendPetdexValidationZipUInt32(UInt32(centralDirectory.count))
        localData.appendPetdexValidationZipUInt32(UInt32(centralDirectoryOffset))
        localData.appendPetdexValidationZipUInt16(0)

        return localData
    }
}

private final class PetdexValidationURLResolver: PetdexURLResolving, @unchecked Sendable {
    private let request: PetdexDownloadRequest
    private(set) var inputs: [String] = []

    init(request: PetdexDownloadRequest) {
        self.request = request
    }

    func resolve(_ input: String) throws -> PetdexDownloadRequest {
        inputs.append(input)
        return request
    }
}

private final class PetdexValidationImmediateDownloader: PetdexDownloading, @unchecked Sendable {
    private let result: Result<URL, PetdexImportError>
    private(set) var requests: [PetdexDownloadRequest] = []

    init(result: Result<URL, PetdexImportError>) {
        self.result = result
    }

    func download(_ request: PetdexDownloadRequest) async throws -> URL {
        requests.append(request)
        switch result {
        case let .success(url):
            return url
        case let .failure(error):
            throw error
        }
    }
}

private final class PetdexValidationSuspendingDownloader: PetdexDownloading, @unchecked Sendable {
    private(set) var requests: [PetdexDownloadRequest] = []
    private(set) var didStart = false
    private(set) var didComplete = false

    func download(_ request: PetdexDownloadRequest) async throws -> URL {
        requests.append(request)
        didStart = true

        do {
            while true {
                try await Task.sleep(nanoseconds: 10_000_000)
            }
        } catch {
            didComplete = true
            throw PetdexImportError.downloadCancelled
        }
    }
}

private extension Data {
    mutating func appendPetdexValidationZipUInt16(_ value: UInt16) {
        append(UInt8(value & 0x00FF))
        append(UInt8((value >> 8) & 0x00FF))
    }

    mutating func appendPetdexValidationZipUInt32(_ value: UInt32) {
        append(UInt8(value & 0x0000_00FF))
        append(UInt8((value >> 8) & 0x0000_00FF))
        append(UInt8((value >> 16) & 0x0000_00FF))
        append(UInt8((value >> 24) & 0x0000_00FF))
    }
}

@MainActor
private func waitUntil(
    _ message: String,
    timeout: TimeInterval = 2,
    condition: @escaping () -> Bool
) {
    let deadline = Date().addingTimeInterval(timeout)
    while !condition() && Date() < deadline {
        RunLoop.current.run(until: Date().addingTimeInterval(0.01))
    }
    expect(condition(), message)
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
    fputs("DesktopPetPetdexValidation failed: \(message)\n", stderr)
    Foundation.exit(1)
}

runPetdexValidation()
