import Foundation
import DesktopPet

@MainActor
func runPetdexErrorHandlingTests() {
  let tests = PetdexErrorHandlingTests()
  tests.petdexErrorsExposeUserFacingDescriptions()
  tests.importViewModelSurfacesPetdexErrorInline()
  tests.petdexImportFailuresDoNotRefreshLibraryOrSwitchCurrentPet()
}

@MainActor
private struct PetdexErrorHandlingTests {
  func petdexErrorsExposeUserFacingDescriptions() {
    let errors: [PetdexImportError] = [
      .notZipFile,
      .missingManifest,
      .manifestDecodingFailed,
      .unreadableImage("spritesheet.webp"),
      .writeFailed("/tmp/Pets/my-cat-v3-large"),
      .petAlreadyExists("my-cat-v3-large")
    ]

    for error in errors {
      let description = error.errorDescription ?? ""
      expect(!description.isEmpty, "\(error) should expose a user-facing description")
      expect(!description.contains("PetdexImportError"), "\(error) should not expose Swift type details")
      expect(!description.contains("manifest.json"), "\(error) should not expose internal manifest file details")
    }
  }

  func importViewModelSurfacesPetdexErrorInline() {
    let model = PetImportViewModel(
      imageSelector: { nil },
      packageSelector: { nil },
      petdexPackageSelector: { nil }
    )

    model.reportPetdexImportFailed(.unreadableImage("spritesheet.webp"))

    if case let .failed(message) = model.state {
      expect(
        message == PetdexImportError.unreadableImage("spritesheet.webp").errorDescription,
        "Petdex inline error should use the Petdex user-facing message"
      )
    } else {
      fail("Petdex failure should move import view model to failed state, got \(model.state)")
    }
  }

  func petdexImportFailuresDoNotRefreshLibraryOrSwitchCurrentPet() {
    let errors: [PetdexImportError] = [
      .invalidArchive,
      .manifestDecodingFailed,
      .unreadableImage("spritesheet.webp"),
      .writeFailed("/tmp/Pets/my-cat-v3-large")
    ]

    for error in errors {
      let store = PetdexErrorStore()
      store.definitions["starter-pet"] = makePetdexErrorDefinition(id: "starter-pet")
      let preferences = makePetdexErrorPreferences(knownPetIds: ["starter-pet"])
      preferences.selectedPetId = "starter-pet"

      let importer = PetdexErrorImporter()
      importer.error = error
      let commander = PetLibraryCommander(
        store: store,
        importer: PetdexErrorImageImporter(),
        petdexPackageImporter: importer,
        manifestWriter: PetdexErrorManifestWriter(),
        preferences: preferences
      )

      var libraryChanged = false
      var selectedDefinition: PetDefinition?
      var reportedError: PetdexImportError?
      commander.onLibraryChanged = { libraryChanged = true }
      commander.onCurrentPetChanged = { selectedDefinition = $0 }
      commander.onPetdexImportFailed = { reportedError = $0 }

      commander.importPetdexPackage(at: URL(fileURLWithPath: "/tmp/broken.zip"))

      expect(reportedError == error, "Petdex failure should report exact error \(error)")
      expect(libraryChanged == false, "Petdex failure \(error) should not mark library changed")
      expect(selectedDefinition == nil, "Petdex failure \(error) should not publish a new current pet")
      expect(preferences.selectedPetId == "starter-pet", "Petdex failure \(error) should leave selectedPetId unchanged")
    }
  }
}

private final class PetdexErrorStore: PetLibraryStoring, @unchecked Sendable {
  let builtInPetId = "starter-pet"
  let importedPetsDirectoryURL = URL(fileURLWithPath: "/tmp/desktop-pet-tests-petdex-errors", isDirectory: true)
  var definitions: [String: PetDefinition] = [:]

  func listPets() throws -> [PetLibraryItem] {
    []
  }

  func loadDefinition(id: String) throws -> PetDefinition {
    if let definition = definitions[id] {
      return definition
    }
    throw PetLibraryError.petNotFound
  }

  func deleteImportedPet(id: String) throws {}
}

private final class PetdexErrorImporter: PetdexPackageImporting, @unchecked Sendable {
  var error: PetdexImportError?

  func importPackage(
    at archiveURL: URL,
    to importedPetsDirectoryURL: URL,
    builtInPetId: String
  ) throws -> PetDefinition {
    if let error {
      throw error
    }
    return makePetdexErrorDefinition(id: "imported-pet")
  }
}

private final class PetdexErrorImageImporter: PetImageImporting, @unchecked Sendable {
  func importImage(
    from sourceURL: URL,
    to destinationFolder: URL,
    displayName: String
  ) throws -> ImportedPetImage {
    throw PetLibraryError.unreadableImage
  }
}

private final class PetdexErrorManifestWriter: PetLibraryManifestWriting, @unchecked Sendable {
  func writeSingleImageManifest(
    petId: String,
    displayName: String,
    image: ImportedPetImage,
    to folderURL: URL
  ) throws {}
}

@MainActor
private func makePetdexErrorPreferences(knownPetIds: Set<String>) -> PreferencesStore {
  let suiteName = "PetdexErrorHandlingTests-\(UUID().uuidString)"
  let defaults = UserDefaults(suiteName: suiteName)!
  defaults.removePersistentDomain(forName: suiteName)
  return PreferencesStore(userDefaults: defaults, knownPetIds: knownPetIds)
}

private func makePetdexErrorDefinition(id: String) -> PetDefinition {
  var animations: [PetState: AnimationClip] = [:]
  for state in PetState.allCases {
    animations[state] = AnimationClip(
      state: state,
      frames: [SpriteFrame(column: 0, row: 0)],
      frameDurationMs: 160,
      loop: true
    )
  }

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
    assetKind: .spriteSheet
  )
}
