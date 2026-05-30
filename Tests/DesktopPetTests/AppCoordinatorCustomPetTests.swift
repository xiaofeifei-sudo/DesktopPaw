import Foundation
import DesktopPet

@MainActor
func runAppCoordinatorCustomPetTests() {
  testCoordinatorRoutesImportPetImageToLibrary()
  testCoordinatorRoutesImportPetPackageToLibrary()
  testCoordinatorRoutesSelectPetToLibrary()
  testCoordinatorRoutesDeletePetToLibrary()
  testCoordinatorRoutesSetSpeechBubbleEnabledToBubble()
  testCoordinatorRoutesSetBubbleFrequencyToBubble()
  testCoordinatorClickedAlsoNotifiesBubble()
  testCoordinatorPetAlsoNotifiesBubble()
  testCoordinatorFeedAlsoNotifiesBubble()
  testCoordinatorTickRoutesToPetCommandsAndBubble()
  testPetLibraryCommanderSelectPetUpdatesPreferencesAndFiresDefinition()
  testPetLibraryCommanderSelectUnknownIdFallsBackToBuiltIn()
  testPetLibraryCommanderImportSuccessAlsoSelectsNewPet()
  testPetLibraryCommanderImportFailureLeavesCurrentPetUnchanged()
  testPetLibraryCommanderPackageImportSuccessAlsoSelectsPackage()
  testPetLibraryCommanderPackageImportFailureLeavesCurrentPetUnchanged()
  testPetLibraryCommanderDeleteCurrentPetFallsBackToBuiltIn()
  testPetLibraryCommanderDeleteNonCurrentPetDoesNotChangeCurrent()
  testPetLibraryCommanderDeleteBuiltInFiresDeleteFailed()
  testBubbleCommanderSetEnabledFalseEmitsNilBubble()
  testBubbleCommanderSetFrequencyForwardsToEngine()
  testBubbleCommanderHandleInteractionEmitsBubbleWhenEngineEmits()
  testBubbleCommanderHandleTickEmitsBubbleWhenEngineEmits()
  testBubbleCommanderHandleTickEmitsNilWhenBubbleExpires()
}

// MARK: - Coordinator routing

@MainActor
private func testCoordinatorRoutesImportPetImageToLibrary() {
  let harness = makeCoordinatorHarness()
  let url = URL(fileURLWithPath: "/tmp/sample.png")
  harness.coordinator.handle(.importPetImage(url, displayName: "Buddy"))
  expect(
    harness.library.actions == [.importPetImage(url, "Buddy")],
    "importPetImage should be forwarded to library"
  )
}

@MainActor
private func testCoordinatorRoutesImportPetPackageToLibrary() {
  let harness = makeCoordinatorHarness()
  let url = URL(fileURLWithPath: "/tmp/Bundle.pet")
  harness.coordinator.handle(.importPetPackage(url))
  expect(
    harness.library.actions == [.importPetPackage(url)],
    "importPetPackage should be forwarded to library"
  )
}

@MainActor
private func testCoordinatorRoutesSelectPetToLibrary() {
  let harness = makeCoordinatorHarness()
  harness.coordinator.handle(.selectPet("custom-1"))
  expect(
    harness.library.actions == [.selectPet("custom-1")],
    "selectPet should be forwarded to library"
  )
}

@MainActor
private func testCoordinatorRoutesDeletePetToLibrary() {
  let harness = makeCoordinatorHarness()
  harness.coordinator.handle(.deletePet("custom-9"))
  expect(
    harness.library.actions == [.deletePet("custom-9")],
    "deletePet should be forwarded to library"
  )
}

@MainActor
private func testCoordinatorRoutesSetSpeechBubbleEnabledToBubble() {
  let harness = makeCoordinatorHarness()
  harness.coordinator.handle(.setSpeechBubbleEnabled(false))
  expect(
    harness.bubble.actions == [.setEnabled(false)],
    "setSpeechBubbleEnabled should be forwarded to bubble"
  )
}

@MainActor
private func testCoordinatorRoutesSetBubbleFrequencyToBubble() {
  let harness = makeCoordinatorHarness()
  harness.coordinator.handle(.setBubbleFrequency(.expressive))
  expect(
    harness.bubble.actions == [.setFrequency(.expressive)],
    "setBubbleFrequency should be forwarded to bubble"
  )
}

@MainActor
private func testCoordinatorClickedAlsoNotifiesBubble() {
  let harness = makeCoordinatorHarness()
  harness.coordinator.handle(.clicked)
  expect(
    harness.petCommands.actions == [.clicked],
    "clicked should still drive the pet engine"
  )
  expect(
    harness.bubble.actions == [.handleInteraction(.clicked)],
    "clicked should also be forwarded to bubble"
  )
}

@MainActor
private func testCoordinatorPetAlsoNotifiesBubble() {
  let harness = makeCoordinatorHarness()
  harness.coordinator.handle(.pet)
  expect(
    harness.petCommands.actions == [.pet],
    "pet should still drive the pet engine"
  )
  expect(
    harness.bubble.actions == [.handleInteraction(.pet)],
    "pet should also be forwarded to bubble"
  )
}

@MainActor
private func testCoordinatorFeedAlsoNotifiesBubble() {
  let harness = makeCoordinatorHarness()
  harness.coordinator.handle(.feed)
  expect(
    harness.petCommands.actions == [.feed],
    "feed should still drive the pet engine"
  )
  expect(
    harness.bubble.actions == [.handleInteraction(.feed)],
    "feed should also be forwarded to bubble"
  )
}

@MainActor
private func testCoordinatorTickRoutesToPetCommandsAndBubble() {
  let harness = makeCoordinatorHarness()
  let date = Date(timeIntervalSince1970: 1_700_000_000)
  harness.coordinator.tick(at: date)
  expect(
    harness.petCommands.tickDates == [date],
    "tick(at:) should forward to pet commands"
  )
  expect(
    harness.bubble.actions == [.handleTick(date)],
    "tick(at:) should forward to bubble"
  )
}

// MARK: - PetLibraryCommander

@MainActor
private func testPetLibraryCommanderSelectPetUpdatesPreferencesAndFiresDefinition() {
  let store = StubLibraryCommandStore()
  let definition = makeStubDefinition(id: "starter-pet")
  store.definitions["starter-pet"] = definition
  let preferences = makeInMemoryPreferencesStore(knownPetIds: ["starter-pet"])
  let commander = PetLibraryCommander(
    store: store,
    importer: StubLibraryImageImporter(),
    manifestWriter: StubLibraryManifestWriter(),
    preferences: preferences
  )
  var observed: PetDefinition?
  commander.onCurrentPetChanged = { observed = $0 }
  commander.selectPet(id: "starter-pet")
  expect(observed?.id == "starter-pet", "onCurrentPetChanged should fire with selected definition")
  expect(preferences.selectedPetId == "starter-pet", "selectedPetId should be persisted")
}

@MainActor
private func testPetLibraryCommanderSelectUnknownIdFallsBackToBuiltIn() {
  let store = StubLibraryCommandStore()
  let builtIn = makeStubDefinition(id: "starter-pet")
  store.definitions["starter-pet"] = builtIn
  let preferences = makeInMemoryPreferencesStore(knownPetIds: ["starter-pet"])
  let commander = PetLibraryCommander(
    store: store,
    importer: StubLibraryImageImporter(),
    manifestWriter: StubLibraryManifestWriter(),
    preferences: preferences
  )
  var observed: PetDefinition?
  commander.onCurrentPetChanged = { observed = $0 }
  commander.selectPet(id: "missing-id")
  expect(
    observed?.id == "starter-pet",
    "Unknown id should fall back to built-in pet definition"
  )
}

@MainActor
private func testPetLibraryCommanderImportSuccessAlsoSelectsNewPet() {
  let store = StubLibraryCommandStore()
  let builtIn = makeStubDefinition(id: "starter-pet")
  let imported = makeStubDefinition(id: "new-pet")
  store.definitions["starter-pet"] = builtIn
  store.definitions["new-pet"] = imported
  let preferences = makeInMemoryPreferencesStore(knownPetIds: ["starter-pet", "new-pet"])
  let importer = StubLibraryImageImporter()
  let writer = StubLibraryManifestWriter()
  let commander = PetLibraryCommander(
    store: store,
    importer: importer,
    manifestWriter: writer,
    preferences: preferences,
    petIdGenerator: { "new-pet" }
  )
  var libraryChangedCount = 0
  var observedDefinition: PetDefinition?
  commander.onLibraryChanged = { libraryChangedCount += 1 }
  commander.onCurrentPetChanged = { observedDefinition = $0 }
  let url = URL(fileURLWithPath: "/tmp/buddy.png")
  commander.importPetImage(at: url, displayName: "Buddy")
  expect(importer.calls.count == 1, "Importer should be called once on success")
  expect(writer.calls.count == 1, "Manifest writer should be called once on success")
  expect(observedDefinition?.id == "new-pet", "Successful import should select the new pet")
  expect(preferences.selectedPetId == "new-pet", "selectedPetId should be persisted to new pet")
  expect(libraryChangedCount >= 1, "Library should be marked changed at least once")
}

@MainActor
private func testPetLibraryCommanderImportFailureLeavesCurrentPetUnchanged() {
  let store = StubLibraryCommandStore()
  let builtIn = makeStubDefinition(id: "starter-pet")
  store.definitions["starter-pet"] = builtIn
  let preferences = makeInMemoryPreferencesStore(knownPetIds: ["starter-pet"])
  preferences.selectedPetId = "starter-pet"
  let importer = StubLibraryImageImporter()
  importer.error = .unreadableImage
  let writer = StubLibraryManifestWriter()
  let commander = PetLibraryCommander(
    store: store,
    importer: importer,
    manifestWriter: writer,
    preferences: preferences,
    petIdGenerator: { "would-be-new" }
  )
  var observedFailure: PetLibraryError?
  var observedDefinition: PetDefinition?
  commander.onImportFailed = { observedFailure = $0 }
  commander.onCurrentPetChanged = { observedDefinition = $0 }
  commander.importPetImage(at: URL(fileURLWithPath: "/tmp/x.png"), displayName: "X")
  expect(observedFailure == .unreadableImage, "Import failure should fire onImportFailed")
  expect(observedDefinition == nil, "Import failure should not change current pet")
  expect(preferences.selectedPetId == "starter-pet", "selectedPetId should remain unchanged on failure")
  expect(writer.calls.isEmpty, "Manifest writer should not run if importer fails")
}

@MainActor
private func testPetLibraryCommanderPackageImportSuccessAlsoSelectsPackage() {
  let store = StubLibraryCommandStore()
  let builtIn = makeStubDefinition(id: "starter-pet")
  let packaged = makeStubDefinition(id: "package-pet")
  store.definitions["starter-pet"] = builtIn
  store.definitions["package-pet"] = packaged
  let preferences = makeInMemoryPreferencesStore(knownPetIds: ["starter-pet", "package-pet"])
  preferences.selectedPetId = "starter-pet"
  let packageImporter = StubPackageImporter()
  packageImporter.definition = packaged
  let commander = PetLibraryCommander(
    store: store,
    importer: StubLibraryImageImporter(),
    packageImporter: packageImporter,
    manifestWriter: StubLibraryManifestWriter(),
    preferences: preferences
  )
  var libraryChangedCount = 0
  var observedDefinition: PetDefinition?
  commander.onLibraryChanged = { libraryChangedCount += 1 }
  commander.onCurrentPetChanged = { observedDefinition = $0 }
  let url = URL(fileURLWithPath: "/tmp/Bundle.pet")
  commander.importPetPackage(at: url)
  expect(packageImporter.calls.count == 1, "Package importer should be called once")
  expect(observedDefinition?.id == "package-pet", "Successful package import should select the package pet")
  expect(preferences.selectedPetId == "package-pet", "selectedPetId should persist imported package")
  expect(libraryChangedCount == 1, "Package import should mark library changed once")
}

@MainActor
private func testPetLibraryCommanderPackageImportFailureLeavesCurrentPetUnchanged() {
  let store = StubLibraryCommandStore()
  store.definitions["starter-pet"] = makeStubDefinition(id: "starter-pet")
  let preferences = makeInMemoryPreferencesStore(knownPetIds: ["starter-pet"])
  preferences.selectedPetId = "starter-pet"
  let packageImporter = StubPackageImporter()
  packageImporter.error = .invalidPackage
  let commander = PetLibraryCommander(
    store: store,
    importer: StubLibraryImageImporter(),
    packageImporter: packageImporter,
    manifestWriter: StubLibraryManifestWriter(),
    preferences: preferences
  )
  var observedFailure: PetLibraryError?
  var observedDefinition: PetDefinition?
  commander.onImportFailed = { observedFailure = $0 }
  commander.onCurrentPetChanged = { observedDefinition = $0 }
  commander.importPetPackage(at: URL(fileURLWithPath: "/tmp/Broken.pet"))
  expect(observedFailure == .invalidPackage, "Package import failure should fire onImportFailed")
  expect(observedDefinition == nil, "Package import failure should not change current pet")
  expect(preferences.selectedPetId == "starter-pet", "selectedPetId should remain unchanged")
}

@MainActor
private func testPetLibraryCommanderDeleteCurrentPetFallsBackToBuiltIn() {
  let store = StubLibraryCommandStore()
  let builtIn = makeStubDefinition(id: "starter-pet")
  let custom = makeStubDefinition(id: "custom-1")
  store.definitions["starter-pet"] = builtIn
  store.definitions["custom-1"] = custom
  let preferences = makeInMemoryPreferencesStore(knownPetIds: ["starter-pet", "custom-1"])
  preferences.selectedPetId = "custom-1"
  let commander = PetLibraryCommander(
    store: store,
    importer: StubLibraryImageImporter(),
    manifestWriter: StubLibraryManifestWriter(),
    preferences: preferences
  )
  var observedDefinition: PetDefinition?
  commander.onCurrentPetChanged = { observedDefinition = $0 }
  commander.deletePet(id: "custom-1")
  expect(store.deletedIds == ["custom-1"], "store.deleteImportedPet should be called for the target id")
  expect(observedDefinition?.id == "starter-pet", "Deleting current pet should select built-in")
  expect(preferences.selectedPetId == "starter-pet", "Preferences should fall back to built-in")
}

@MainActor
private func testPetLibraryCommanderDeleteNonCurrentPetDoesNotChangeCurrent() {
  let store = StubLibraryCommandStore()
  let builtIn = makeStubDefinition(id: "starter-pet")
  let custom = makeStubDefinition(id: "custom-1")
  store.definitions["starter-pet"] = builtIn
  store.definitions["custom-1"] = custom
  let preferences = makeInMemoryPreferencesStore(knownPetIds: ["starter-pet", "custom-1"])
  preferences.selectedPetId = "starter-pet"
  let commander = PetLibraryCommander(
    store: store,
    importer: StubLibraryImageImporter(),
    manifestWriter: StubLibraryManifestWriter(),
    preferences: preferences
  )
  var observedDefinition: PetDefinition?
  commander.onCurrentPetChanged = { observedDefinition = $0 }
  commander.deletePet(id: "custom-1")
  expect(observedDefinition == nil, "Deleting a non-current pet should not change current pet")
  expect(preferences.selectedPetId == "starter-pet", "selectedPetId should remain unchanged")
}

@MainActor
private func testPetLibraryCommanderDeleteBuiltInFiresDeleteFailed() {
  let store = StubLibraryCommandStore()
  let builtIn = makeStubDefinition(id: "starter-pet")
  store.definitions["starter-pet"] = builtIn
  store.deleteError = .cannotDeleteBuiltInPet
  let preferences = makeInMemoryPreferencesStore(knownPetIds: ["starter-pet"])
  preferences.selectedPetId = "starter-pet"
  let commander = PetLibraryCommander(
    store: store,
    importer: StubLibraryImageImporter(),
    manifestWriter: StubLibraryManifestWriter(),
    preferences: preferences
  )
  var observedFailure: PetLibraryError?
  var observedDefinition: PetDefinition?
  commander.onDeleteFailed = { observedFailure = $0 }
  commander.onCurrentPetChanged = { observedDefinition = $0 }
  commander.deletePet(id: "starter-pet")
  expect(observedFailure == .cannotDeleteBuiltInPet, "Deleting built-in should report error")
  expect(observedDefinition == nil, "Deleting built-in should not change current pet")
  expect(preferences.selectedPetId == "starter-pet", "selectedPetId should remain unchanged")
}

// MARK: - BubbleCommander

@MainActor
private func testBubbleCommanderSetEnabledFalseEmitsNilBubble() {
  let engine = makeBubbleEngine()
  engine.isEnabled = true
  // pre-populate a bubble so it has something to clear
  let now = Date(timeIntervalSince1970: 100)
  let state = makeRuntimeState()
  _ = engine.handle(event: .clicked, state: state, at: now)
  expect(engine.currentBubble != nil, "Engine should hold a current bubble before disabling")
  let commander = BubbleCommander(bubbleEngine: engine)
  var observed: [PetBubble?] = []
  commander.onBubbleChanged = { observed.append($0) }
  commander.setSpeechBubbleEnabled(false)
  expect(engine.isEnabled == false, "Engine isEnabled should be false")
  expect(observed.last == .some(nil), "Disabling bubbles should emit a nil bubble")
}

@MainActor
private func testBubbleCommanderSetFrequencyForwardsToEngine() {
  let engine = makeBubbleEngine()
  let commander = BubbleCommander(bubbleEngine: engine)
  commander.setBubbleFrequency(.expressive)
  expect(engine.frequency == .expressive, "Engine frequency should follow commander setter")
}

@MainActor
private func testBubbleCommanderHandleInteractionEmitsBubbleWhenEngineEmits() {
  let engine = makeBubbleEngine()
  let commander = BubbleCommander(bubbleEngine: engine)
  var observed: [PetBubble?] = []
  commander.onBubbleChanged = { observed.append($0) }
  let date = Date(timeIntervalSince1970: 200)
  commander.handleInteraction(.clicked, state: makeRuntimeState(), at: date)
  expect(observed.count == 1, "Bubble change should fire once")
  expect(observed.last??.priority == .interaction, "Emitted bubble should be interaction priority")
}

@MainActor
private func testBubbleCommanderHandleTickEmitsBubbleWhenEngineEmits() {
  let engine = makeBubbleEngine()
  let commander = BubbleCommander(bubbleEngine: engine)
  var observed: [PetBubble?] = []
  commander.onBubbleChanged = { observed.append($0) }
  let date = Date(timeIntervalSince1970: 300)
  let state = makeRuntimeState(currentState: .happy)
  commander.handleTick(state: state, at: date)
  expect(
    observed.last??.priority == .state,
    "Tick into happy state should emit a state-priority bubble"
  )
}

@MainActor
private func testBubbleCommanderHandleTickEmitsNilWhenBubbleExpires() {
  let engine = makeBubbleEngine()
  let commander = BubbleCommander(bubbleEngine: engine)
  var observed: [PetBubble?] = []
  commander.onBubbleChanged = { observed.append($0) }
  let baseDate = Date(timeIntervalSince1970: 400)
  commander.handleInteraction(.clicked, state: makeRuntimeState(), at: baseDate)
  expect(observed.last??.priority == .interaction, "First emission should be interaction bubble")
  let later = baseDate.addingTimeInterval(10)
  // Use eating state and a recent lastInteractionAt so tick won't emit a fresh ambient.
  let nonTriggeringState = PetRuntimeState(
    currentState: .eating,
    mood: 0.8,
    hunger: 0.2,
    energy: 0.8,
    lastInteractionAt: later,
    isDragging: false,
    scale: 1.0
  )
  commander.handleTick(state: nonTriggeringState, at: later)
  expect(observed.last == .some(nil), "After bubble expires the commander should emit nil")
}

// MARK: - Helpers

@MainActor
private struct CoordinatorHarness {
  let coordinator: AppCoordinator
  let petWindow: SpyCoordinatorPetWindow
  let petCommands: SpyCoordinatorPetCommands
  let settings: SpyCoordinatorSettings
  let launch: SpyCoordinatorLaunch
  let application: SpyCoordinatorApplication
  let library: SpyLibraryCommanding
  let bubble: SpyBubbleCommanding
}

@MainActor
private func makeCoordinatorHarness() -> CoordinatorHarness {
  let petWindow = SpyCoordinatorPetWindow()
  let petCommands = SpyCoordinatorPetCommands()
  let settings = SpyCoordinatorSettings()
  let launch = SpyCoordinatorLaunch()
  let application = SpyCoordinatorApplication()
  let library = SpyLibraryCommanding()
  let bubble = SpyBubbleCommanding()
  let coordinator = AppCoordinator(
    petWindow: petWindow,
    petCommands: petCommands,
    settingsWindow: settings,
    launchAtLogin: launch,
    application: application,
    library: library,
    bubble: bubble
  )
  return CoordinatorHarness(
    coordinator: coordinator,
    petWindow: petWindow,
    petCommands: petCommands,
    settings: settings,
    launch: launch,
    application: application,
    library: library,
    bubble: bubble
  )
}

@MainActor
private final class SpyCoordinatorPetWindow: PetWindowControlling {
  var isPetVisible = true
  func showPet() {}
  func hidePet() {}
  func resetPosition() {}
  func saveStateBeforeQuit() {}
}

@MainActor
private final class SpyCoordinatorPetCommands: PetCommandHandling {
  enum Action: Equatable { case clicked, pet, feed, sleep, wake }
  private(set) var actions: [Action] = []
  private(set) var tickDates: [Date] = []
  var isSleeping = false
  var runtimeState = PetRuntimeState.defaultState()
  var catalog = PetActionCatalog(petId: "custom-pet-spy", actions: [], warnings: [])
  func clicked() { actions.append(.clicked) }
  func pet() { actions.append(.pet) }
  func feed() { actions.append(.feed) }
  func sleep() { actions.append(.sleep); isSleeping = true }
  func wake() { actions.append(.wake); isSleeping = false }
  func dragStarted() {}
  func dragEnded() {}
  func playAction(_ id: ActionId) {}
  func setScale(_ scale: Double) {}
  func setRandomWalkingEnabled(_ enabled: Bool) {}
  func tick(at date: Date) { tickDates.append(date) }
}

@MainActor
private final class SpyCoordinatorSettings: SettingsWindowControlling {
  func showSettings() {}
}

@MainActor
private final class SpyCoordinatorLaunch: LaunchAtLoginControlling {
  var isLaunchAtLoginEnabled = false
  func setLaunchAtLoginEnabled(_ enabled: Bool) { isLaunchAtLoginEnabled = enabled }
}

@MainActor
private final class SpyCoordinatorApplication: ApplicationTerminating {
  func terminate() {}
}

@MainActor
private final class SpyLibraryCommanding: PetLibraryCommanding {
  enum Action: Equatable {
    case importPetImage(URL, String)
    case importPetPackage(URL)
    case importPetdexPackage(URL)
    case importPetdexURL(String)
    case cancelPetdexURLImport
    case selectPet(String)
    case deletePet(String)
  }
  private(set) var actions: [Action] = []
  func importPetImage(at url: URL, displayName: String) {
    actions.append(.importPetImage(url, displayName))
  }
  func importPetPackage(at url: URL) { actions.append(.importPetPackage(url)) }
  func importPetdexPackage(at url: URL) { actions.append(.importPetdexPackage(url)) }
  func importPetdexURL(_ input: String) { actions.append(.importPetdexURL(input)) }
  func cancelPetdexURLImport() { actions.append(.cancelPetdexURLImport) }
  func selectPet(id: String) { actions.append(.selectPet(id)) }
  func deletePet(id: String) { actions.append(.deletePet(id)) }
}

@MainActor
private final class SpyBubbleCommanding: BubbleCommanding {
  enum Action: Equatable {
    case setEnabled(Bool)
    case setFrequency(BubbleFrequency)
    case handleInteraction(PetEvent)
    case handleTick(Date)
  }
  private(set) var actions: [Action] = []
  var currentBubble: PetBubble? { nil }
  func setSpeechBubbleEnabled(_ enabled: Bool) { actions.append(.setEnabled(enabled)) }
  func setBubbleFrequency(_ frequency: BubbleFrequency) { actions.append(.setFrequency(frequency)) }
  func handleInteraction(_ event: PetEvent, state: PetRuntimeState, at date: Date) {
    actions.append(.handleInteraction(event))
  }
  func handleTick(state: PetRuntimeState, at date: Date) {
    actions.append(.handleTick(date))
  }
  func handleCompanionInteraction(_ trigger: BubbleTrigger, context: CompanionContext, at date: Date) {}
  func handleCompanionTick(context: CompanionContext, at date: Date) {}
}

// PetLibraryCommander helpers

private final class StubLibraryCommandStore: PetLibraryStoring, @unchecked Sendable {
  let builtInPetId: String = "starter-pet"
  let importedPetsDirectoryURL: URL = URL(fileURLWithPath: "/tmp/desktop-pet-tests-library")
  var definitions: [String: PetDefinition] = [:]
  var deleteError: PetLibraryError?
  private(set) var deletedIds: [String] = []

  func listPets() throws -> [PetLibraryItem] { [] }

  func loadDefinition(id: String) throws -> PetDefinition {
    if let def = definitions[id] {
      return def
    }
    if let fallback = definitions[builtInPetId] {
      return fallback
    }
    throw PetLibraryError.petNotFound
  }

  func deleteImportedPet(id: String) throws {
    if let error = deleteError {
      throw error
    }
    deletedIds.append(id)
  }
}

private final class StubLibraryImageImporter: PetImageImporting, @unchecked Sendable {
  struct Call { let sourceURL: URL; let destinationFolder: URL; let displayName: String }
  private(set) var calls: [Call] = []
  var error: PetLibraryError?

  func importImage(
    from sourceURL: URL,
    to destinationFolder: URL,
    displayName: String
  ) throws -> ImportedPetImage {
    calls.append(Call(sourceURL: sourceURL, destinationFolder: destinationFolder, displayName: displayName))
    if let error {
      throw error
    }
    return ImportedPetImage(
      imageFileName: "image.png",
      previewFileName: "preview.png",
      pixelSize: CGSizeCodable(width: 128, height: 128),
      hasAlpha: true
    )
  }
}

private final class StubLibraryManifestWriter: PetLibraryManifestWriting, @unchecked Sendable {
  struct Call { let petId: String; let displayName: String; let folderURL: URL }
  private(set) var calls: [Call] = []
  var error: PetLibraryError?

  func writeSingleImageManifest(
    petId: String,
    displayName: String,
    image: ImportedPetImage,
    to folderURL: URL
  ) throws {
    calls.append(Call(petId: petId, displayName: displayName, folderURL: folderURL))
    if let error {
      throw error
    }
  }
}

private final class StubPackageImporter: PetPackageImporting, @unchecked Sendable {
  struct Call { let sourceURL: URL; let importedPetsDirectoryURL: URL; let builtInPetId: String }
  private(set) var calls: [Call] = []
  var definition: PetDefinition?
  var error: PetLibraryError?

  func importPackage(
    from sourceURL: URL,
    to importedPetsDirectoryURL: URL,
    builtInPetId: String
  ) throws -> PetDefinition {
    calls.append(Call(sourceURL: sourceURL, importedPetsDirectoryURL: importedPetsDirectoryURL, builtInPetId: builtInPetId))
    if let error {
      throw error
    }
    if let definition {
      return definition
    }
    throw PetLibraryError.invalidPackage
  }
}

@MainActor
private func makeInMemoryPreferencesStore(knownPetIds: Set<String>) -> PreferencesStore {
  let suiteName = "AppCoordinatorCustomPetTests-\(UUID().uuidString)"
  let defaults = UserDefaults(suiteName: suiteName)!
  defaults.removePersistentDomain(forName: suiteName)
  return PreferencesStore(userDefaults: defaults, knownPetIds: knownPetIds)
}

private func makeStubDefinition(id: String) -> PetDefinition {
  let frame = SpriteFrame(column: 0, row: 0)
  var animations: [PetState: AnimationClip] = [:]
  for state in PetState.allCases {
    animations[state] = AnimationClip(
      state: state,
      frames: [frame],
      frameDurationMs: 200,
      loop: true,
      nextState: nil
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
    assetKind: .singleImage,
    motionProfile: MotionProfileDefaults.singleImageDefault(),
    bubbleProfile: BubbleProfileDefaults.defaultProfile()
  )
}

@MainActor
private func makeBubbleEngine() -> BubbleEngine {
  let phrases: [BubbleTrigger: [String]] = [
    .clicked: ["hi"],
    .pet: ["pat"],
    .feed: ["yum"],
    .happy: ["yay"],
    .hungry: ["food"],
    .tired: ["zzz"],
    .idle: ["..."],
    .walking: ["walk"],
    .sleeping: ["zzz"]
  ]
  let profile = BubbleProfile(
    phrases: phrases,
    minimumIntervalSeconds: 0,
    displayDurationSeconds: 4
  )
  let provider = DefaultBubblePhraseProvider(profile: profile, selector: { $0.first })
  var counter: UInt = 0
  return BubbleEngine(
    profile: profile,
    isEnabled: true,
    frequency: .normal,
    phraseProvider: provider,
    idGenerator: {
      counter &+= 1
      return UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, UInt8(counter % 255)))
    }
  )
}

private func makeRuntimeState(currentState: PetState = .idle) -> PetRuntimeState {
  PetRuntimeState(
    currentState: currentState,
    mood: 0.8,
    hunger: 0.2,
    energy: 0.8,
    lastInteractionAt: Date(timeIntervalSince1970: 50),
    isDragging: false,
    scale: 1.0
  )
}
