import Foundation
import DesktopPet

@MainActor
func runPetLibraryCommanderPetdexTests() {
  let tests = PetLibraryCommanderPetdexTests()
  tests.petdexImportSuccessSelectsImportedPetAndRefreshesLibrary()
  tests.petdexImportFailureLeavesCurrentPetUnchanged()
  tests.unexpectedPetdexImporterErrorNotifiesUI()
  tests.petdexURLImportDownloadsThenReusesPackageImporter()
  tests.petdexURLImportCleansUpDownloadedArchiveAfterSuccess()
  tests.petdexURLImportCleansUpDownloadedArchiveAfterImportFailure()
  tests.petdexURLDownloadFailureDoesNotSwitchCurrentPet()
}

@MainActor
private struct PetLibraryCommanderPetdexTests {
  func petdexImportSuccessSelectsImportedPetAndRefreshesLibrary() {
    let store = PetdexCommanderStore()
    let builtIn = makePetdexCommanderDefinition(id: "starter-pet")
    let petdex = makePetdexCommanderDefinition(id: "my-cat-v3-large")
    store.definitions["starter-pet"] = builtIn
    store.definitions["my-cat-v3-large"] = petdex

    let preferences = makePetdexCommanderPreferences(knownPetIds: ["starter-pet", "my-cat-v3-large"])
    preferences.selectedPetId = "starter-pet"

    let petdexImporter = PetdexCommanderImporter()
    petdexImporter.definition = petdex
    let commander = PetLibraryCommander(
      store: store,
      importer: PetdexCommanderImageImporter(),
      petdexPackageImporter: petdexImporter,
      manifestWriter: PetdexCommanderManifestWriter(),
      preferences: preferences
    )

    var libraryChangedCount = 0
    var observedDefinition: PetDefinition?
    var observedFailure: PetdexImportError?
    commander.onLibraryChanged = { libraryChangedCount += 1 }
    commander.onCurrentPetChanged = { observedDefinition = $0 }
    commander.onPetdexImportFailed = { observedFailure = $0 }

    let url = URL(fileURLWithPath: "/tmp/my-cat-v3-large.zip")
    commander.importPetdexPackage(at: url)

    expect(petdexImporter.calls.count == 1, "Petdex importer should be called once")
    expect(petdexImporter.calls.first?.archiveURL == url, "Petdex importer should receive selected zip URL")
    expect(petdexImporter.calls.first?.importedPetsDirectoryURL == store.importedPetsDirectoryURL, "Petdex importer should write into App-owned pets directory")
    expect(petdexImporter.calls.first?.builtInPetId == "starter-pet", "Petdex importer should receive built-in id for conflict checks")
    expect(libraryChangedCount == 1, "successful Petdex import should refresh settings library list")
    expect(observedDefinition?.id == "my-cat-v3-large", "successful Petdex import should select the imported pet")
    expect(preferences.selectedPetId == "my-cat-v3-large", "successful Petdex import should persist selected pet id")
    expect(observedFailure == nil, "successful Petdex import should not report failure")
  }

  func petdexImportFailureLeavesCurrentPetUnchanged() {
    let store = PetdexCommanderStore()
    store.definitions["starter-pet"] = makePetdexCommanderDefinition(id: "starter-pet")

    let preferences = makePetdexCommanderPreferences(knownPetIds: ["starter-pet"])
    preferences.selectedPetId = "starter-pet"

    let petdexImporter = PetdexCommanderImporter()
    petdexImporter.error = .missingManifest
    let commander = PetLibraryCommander(
      store: store,
      importer: PetdexCommanderImageImporter(),
      petdexPackageImporter: petdexImporter,
      manifestWriter: PetdexCommanderManifestWriter(),
      preferences: preferences
    )

    var libraryChangedCount = 0
    var observedDefinition: PetDefinition?
    var observedFailure: PetdexImportError?
    commander.onLibraryChanged = { libraryChangedCount += 1 }
    commander.onCurrentPetChanged = { observedDefinition = $0 }
    commander.onPetdexImportFailed = { observedFailure = $0 }

    commander.importPetdexPackage(at: URL(fileURLWithPath: "/tmp/broken.zip"))

    expect(observedFailure == .missingManifest, "Petdex import failure should notify UI with Petdex error")
    expect(observedDefinition == nil, "failed Petdex import should not change current pet definition")
    expect(preferences.selectedPetId == "starter-pet", "failed Petdex import should not change selected pet id")
    expect(libraryChangedCount == 0, "failed Petdex import should not refresh library as changed")
  }

  func unexpectedPetdexImporterErrorNotifiesUI() {
    let store = PetdexCommanderStore()
    store.definitions["starter-pet"] = makePetdexCommanderDefinition(id: "starter-pet")

    let preferences = makePetdexCommanderPreferences(knownPetIds: ["starter-pet"])
    preferences.selectedPetId = "starter-pet"

    let petdexImporter = PetdexCommanderImporter()
    petdexImporter.unexpectedError = NSError(domain: "PetLibraryCommanderPetdexTests", code: 1)
    let commander = PetLibraryCommander(
      store: store,
      importer: PetdexCommanderImageImporter(),
      petdexPackageImporter: petdexImporter,
      manifestWriter: PetdexCommanderManifestWriter(),
      preferences: preferences
    )

    var observedFailure: PetdexImportError?
    commander.onPetdexImportFailed = { observedFailure = $0 }

    commander.importPetdexPackage(at: URL(fileURLWithPath: "/tmp/unexpected.zip"))

    expect(observedFailure == .invalidArchive, "unexpected Petdex importer errors should become a user-facing Petdex failure")
    expect(preferences.selectedPetId == "starter-pet", "unexpected Petdex errors should not change selected pet id")
  }

  func petdexURLImportDownloadsThenReusesPackageImporter() {
    let store = PetdexCommanderStore()
    let builtIn = makePetdexCommanderDefinition(id: "starter-pet")
    let petdex = makePetdexCommanderDefinition(id: "my-cat-v3-large")
    store.definitions["starter-pet"] = builtIn
    store.definitions["my-cat-v3-large"] = petdex

    let preferences = makePetdexCommanderPreferences(knownPetIds: ["starter-pet", "my-cat-v3-large"])
    preferences.selectedPetId = "starter-pet"

    let input = "https://petdex.crafter.run/zh/pets/my-cat-v3-large"
    let request = PetdexDownloadRequest(
      sourceURL: URL(string: input)!,
      kind: .page,
      suggestedFileName: "my-cat-v3-large.zip"
    )
    let downloadedArchiveURL = URL(fileURLWithPath: "/tmp/my-cat-v3-large.zip")
    let resolver = PetdexCommanderURLResolver(request: request)
    let downloader = PetdexCommanderDownloader(downloadedArchiveURL: downloadedArchiveURL)
    let petdexImporter = PetdexCommanderImporter()
    petdexImporter.definition = petdex
    let commander = PetLibraryCommander(
      store: store,
      importer: PetdexCommanderImageImporter(),
      petdexPackageImporter: petdexImporter,
      petdexURLResolver: resolver,
      petdexDownloader: downloader,
      manifestWriter: PetdexCommanderManifestWriter(),
      preferences: preferences
    )

    var libraryChangedCount = 0
    var observedDefinition: PetDefinition?
    var successCount = 0
    var observedPhases: [PetdexURLImportPhase] = []
    commander.onLibraryChanged = { libraryChangedCount += 1 }
    commander.onCurrentPetChanged = { observedDefinition = $0 }
    commander.onPetdexURLImportSucceeded = { successCount += 1 }
    commander.onPetdexURLImportPhaseChanged = { observedPhases.append($0) }

    commander.importPetdexURL(input)
    waitForMainActorTask {
      observedDefinition?.id == "my-cat-v3-large"
    }

    expect(resolver.inputs == [input], "Petdex URL import should resolve the user input")
    expect(downloader.requests == [request], "Petdex URL import should download the resolved request")
    expect(petdexImporter.calls.first?.archiveURL == downloadedArchiveURL, "Petdex URL import should reuse Phase 1 package importer with downloaded zip")
    expect(libraryChangedCount == 1, "Petdex URL import should refresh library after import")
    expect(successCount == 1, "Petdex URL import should report URL-specific success")
    expect(observedPhases == [.downloading, .importing], "Petdex URL import should report downloading then importing")
    expect(preferences.selectedPetId == "my-cat-v3-large", "Petdex URL import should select imported pet")
  }

  func petdexURLImportCleansUpDownloadedArchiveAfterSuccess() {
    let store = PetdexCommanderStore()
    let builtIn = makePetdexCommanderDefinition(id: "starter-pet")
    let petdex = makePetdexCommanderDefinition(id: "my-cat-v3-large")
    store.definitions["starter-pet"] = builtIn
    store.definitions["my-cat-v3-large"] = petdex

    let preferences = makePetdexCommanderPreferences(knownPetIds: ["starter-pet", "my-cat-v3-large"])
    preferences.selectedPetId = "starter-pet"

    let input = "https://petdex.crafter.run/zh/pets/my-cat-v3-large"
    let request = PetdexDownloadRequest(
      sourceURL: URL(string: input)!,
      kind: .page,
      suggestedFileName: "my-cat-v3-large.zip"
    )
    let downloadedArchiveURL = makePetdexCommanderDownloadedArchive(fileName: "my-cat-v3-large.zip")
    let downloadDirectoryURL = downloadedArchiveURL.deletingLastPathComponent()
    let resolver = PetdexCommanderURLResolver(request: request)
    let downloader = PetdexCommanderDownloader(downloadedArchiveURL: downloadedArchiveURL)
    let petdexImporter = PetdexCommanderImporter()
    petdexImporter.definition = petdex
    let commander = PetLibraryCommander(
      store: store,
      importer: PetdexCommanderImageImporter(),
      petdexPackageImporter: petdexImporter,
      petdexURLResolver: resolver,
      petdexDownloader: downloader,
      manifestWriter: PetdexCommanderManifestWriter(),
      preferences: preferences
    )

    var successCount = 0
    commander.onPetdexURLImportSucceeded = { successCount += 1 }

    commander.importPetdexURL(input)
    waitForMainActorTask {
      successCount == 1 && !FileManager.default.fileExists(atPath: downloadDirectoryURL.path)
    }

    expect(petdexImporter.calls.first?.archiveURL == downloadedArchiveURL, "Petdex importer should receive the downloaded archive before cleanup")
    expect(!FileManager.default.fileExists(atPath: downloadDirectoryURL.path), "successful URL import should remove temporary Petdex download directory")
  }

  func petdexURLImportCleansUpDownloadedArchiveAfterImportFailure() {
    let store = PetdexCommanderStore()
    store.definitions["starter-pet"] = makePetdexCommanderDefinition(id: "starter-pet")

    let preferences = makePetdexCommanderPreferences(knownPetIds: ["starter-pet"])
    preferences.selectedPetId = "starter-pet"

    let input = "https://petdex.crafter.run/zh/pets/broken-cat"
    let request = PetdexDownloadRequest(
      sourceURL: URL(string: input)!,
      kind: .page,
      suggestedFileName: "broken-cat.zip"
    )
    let downloadedArchiveURL = makePetdexCommanderDownloadedArchive(fileName: "broken-cat.zip")
    let downloadDirectoryURL = downloadedArchiveURL.deletingLastPathComponent()
    let resolver = PetdexCommanderURLResolver(request: request)
    let downloader = PetdexCommanderDownloader(downloadedArchiveURL: downloadedArchiveURL)
    let petdexImporter = PetdexCommanderImporter()
    petdexImporter.error = .missingManifest
    let commander = PetLibraryCommander(
      store: store,
      importer: PetdexCommanderImageImporter(),
      petdexPackageImporter: petdexImporter,
      petdexURLResolver: resolver,
      petdexDownloader: downloader,
      manifestWriter: PetdexCommanderManifestWriter(),
      preferences: preferences
    )

    var observedURLFailure: PetdexImportError?
    commander.onPetdexURLImportFailed = { observedURLFailure = $0 }

    commander.importPetdexURL(input)
    waitForMainActorTask {
      observedURLFailure == .missingManifest && !FileManager.default.fileExists(atPath: downloadDirectoryURL.path)
    }

    expect(petdexImporter.calls.first?.archiveURL == downloadedArchiveURL, "failed Petdex import should still receive the downloaded archive")
    expect(!FileManager.default.fileExists(atPath: downloadDirectoryURL.path), "failed URL import should remove temporary Petdex download directory")
    expect(preferences.selectedPetId == "starter-pet", "failed Petdex URL import should leave selected pet unchanged")
  }

  func petdexURLDownloadFailureDoesNotSwitchCurrentPet() {
    let store = PetdexCommanderStore()
    store.definitions["starter-pet"] = makePetdexCommanderDefinition(id: "starter-pet")

    let preferences = makePetdexCommanderPreferences(knownPetIds: ["starter-pet"])
    preferences.selectedPetId = "starter-pet"

    let input = "https://petdex.crafter.run/zh/pets/missing-cat"
    let request = PetdexDownloadRequest(
      sourceURL: URL(string: input)!,
      kind: .page,
      suggestedFileName: "missing-cat.zip"
    )
    let resolver = PetdexCommanderURLResolver(request: request)
    let downloader = PetdexCommanderDownloader(downloadedArchiveURL: URL(fileURLWithPath: "/tmp/missing-cat.zip"))
    downloader.error = .downloadFailed("offline")
    let petdexImporter = PetdexCommanderImporter()
    let commander = PetLibraryCommander(
      store: store,
      importer: PetdexCommanderImageImporter(),
      petdexPackageImporter: petdexImporter,
      petdexURLResolver: resolver,
      petdexDownloader: downloader,
      manifestWriter: PetdexCommanderManifestWriter(),
      preferences: preferences
    )

    var libraryChangedCount = 0
    var observedDefinition: PetDefinition?
    var observedURLFailure: PetdexImportError?
    var observedPackageFailure: PetdexImportError?
    commander.onLibraryChanged = { libraryChangedCount += 1 }
    commander.onCurrentPetChanged = { observedDefinition = $0 }
    commander.onPetdexURLImportFailed = { observedURLFailure = $0 }
    commander.onPetdexImportFailed = { observedPackageFailure = $0 }

    commander.importPetdexURL(input)
    waitForMainActorTask {
      observedURLFailure != nil
    }

    expect(observedURLFailure == .downloadFailed("offline"), "Petdex URL download failure should notify URL import UI")
    expect(observedPackageFailure == nil, "Petdex URL download failure should not be reported as a zip import failure")
    expect(petdexImporter.calls.isEmpty, "failed Petdex URL download should not call package importer")
    expect(observedDefinition == nil, "failed Petdex URL download should not publish a new current pet")
    expect(preferences.selectedPetId == "starter-pet", "failed Petdex URL download should leave selected pet unchanged")
    expect(libraryChangedCount == 0, "failed Petdex URL download should not refresh library as changed")
  }
}

private func makePetdexCommanderDownloadedArchive(fileName: String) -> URL {
  let directoryURL = FileManager.default.temporaryDirectory
    .appendingPathComponent("\(PetdexDownloader.temporaryDownloadDirectoryPrefix)\(UUID().uuidString)", isDirectory: true)
  let archiveURL = directoryURL.appendingPathComponent(fileName)
  do {
    try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    try Data("PK-temp-petdex-archive".utf8).write(to: archiveURL)
  } catch {
    fail("could not create temporary Petdex archive fixture: \(error)")
  }
  return archiveURL
}

private final class PetdexCommanderStore: PetLibraryStoring, @unchecked Sendable {
  let builtInPetId: String = "starter-pet"
  let importedPetsDirectoryURL: URL = URL(fileURLWithPath: "/tmp/desktop-pet-tests-petdex-library", isDirectory: true)
  var definitions: [String: PetDefinition] = [:]

  func listPets() throws -> [PetLibraryItem] {
    []
  }

  func loadDefinition(id: String) throws -> PetDefinition {
    if let definition = definitions[id] {
      return definition
    }
    if let fallback = definitions[builtInPetId] {
      return fallback
    }
    throw PetLibraryError.petNotFound
  }

  func deleteImportedPet(id: String) throws {}
}

private final class PetdexCommanderImporter: PetdexPackageImporting, @unchecked Sendable {
  struct Call {
    let archiveURL: URL
    let importedPetsDirectoryURL: URL
    let builtInPetId: String
  }

  private(set) var calls: [Call] = []
  var definition: PetDefinition?
  var error: PetdexImportError?
  var unexpectedError: Error?

  func importPackage(
    at archiveURL: URL,
    to importedPetsDirectoryURL: URL,
    builtInPetId: String
  ) throws -> PetDefinition {
    calls.append(Call(
      archiveURL: archiveURL,
      importedPetsDirectoryURL: importedPetsDirectoryURL,
      builtInPetId: builtInPetId
    ))
    if let error {
      throw error
    }
    if let unexpectedError {
      throw unexpectedError
    }
    if let definition {
      return definition
    }
    throw PetdexImportError.invalidArchive
  }
}

private final class PetdexCommanderURLResolver: PetdexURLResolving, @unchecked Sendable {
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

private final class PetdexCommanderDownloader: PetdexDownloading, @unchecked Sendable {
  private let downloadedArchiveURL: URL
  private(set) var requests: [PetdexDownloadRequest] = []
  var error: PetdexImportError?

  init(downloadedArchiveURL: URL) {
    self.downloadedArchiveURL = downloadedArchiveURL
  }

  func download(_ request: PetdexDownloadRequest) async throws -> URL {
    requests.append(request)
    if let error {
      throw error
    }
    return downloadedArchiveURL
  }
}

private final class PetdexCommanderImageImporter: PetImageImporting, @unchecked Sendable {
  func importImage(
    from sourceURL: URL,
    to destinationFolder: URL,
    displayName: String
  ) throws -> ImportedPetImage {
    throw PetLibraryError.unreadableImage
  }
}

private final class PetdexCommanderManifestWriter: PetLibraryManifestWriting, @unchecked Sendable {
  func writeSingleImageManifest(
    petId: String,
    displayName: String,
    image: ImportedPetImage,
    to folderURL: URL
  ) throws {}
}

@MainActor
private func makePetdexCommanderPreferences(knownPetIds: Set<String>) -> PreferencesStore {
  let suiteName = "PetLibraryCommanderPetdexTests-\(UUID().uuidString)"
  let defaults = UserDefaults(suiteName: suiteName)!
  defaults.removePersistentDomain(forName: suiteName)
  return PreferencesStore(userDefaults: defaults, knownPetIds: knownPetIds)
}

private func makePetdexCommanderDefinition(id: String) -> PetDefinition {
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
    assetKind: .spriteSheet,
    motionProfile: MotionProfileDefaults.singleImageDefault(),
    bubbleProfile: BubbleProfileDefaults.defaultProfile()
  )
}

@MainActor
private func waitForMainActorTask(
  timeout: TimeInterval = 2,
  condition: @escaping () -> Bool
) {
  let deadline = Date().addingTimeInterval(timeout)
  while !condition() && Date() < deadline {
    RunLoop.current.run(until: Date().addingTimeInterval(0.01))
  }
  expect(condition(), "timed out waiting for main actor task")
}
