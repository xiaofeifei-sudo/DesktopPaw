import Foundation
import DesktopPet

@MainActor
func runPetLibraryViewModelTests() {
  let tests = PetLibraryViewModelTests()
  tests.defaultsAreEmpty()
  tests.reloadPopulatesItemsAndCurrentPetId()
  tests.reloadFailureSetsErrorMessage()
  tests.selectPetFiresCallback()
  tests.deletePetFiresCallbackOnlyForImported()
  tests.deletePetIsNoOpForBuiltIn()
  tests.deletePetIgnoresUnknownId()
  tests.importImageFiresCallbackWhenSelectorReturnsURL()
  tests.importImageDoesNothingWhenSelectorReturnsNil()
  tests.importPackageFiresCallback()
  tests.successfulSelectClearsPreviousError()
  tests.presentImportErrorSetsLocalizedDescription()
}

@MainActor
private struct PetLibraryViewModelTests {
  func defaultsAreEmpty() {
    let model = makeModel(items: [])
    expect(model.items.isEmpty, "default items should be empty before reload")
    expect(model.currentPetId == nil, "default currentPetId should be nil")
    expect(model.errorMessage == nil, "default errorMessage should be nil")
  }

  func reloadPopulatesItemsAndCurrentPetId() {
    let store = StubLibraryStore(
      items: [makeBuiltIn(), makeImported(id: "cat")]
    )
    let model = PetLibraryViewModel(
      store: store,
      selectedPetIdProvider: { "cat" }
    )
    model.reload()
    expect(model.items.count == 2, "reload should populate items from store")
    expect(model.items.first?.id == "starter-pet", "built-in pet should appear first")
    expect(model.currentPetId == "cat", "currentPetId should reflect provider")
  }

  func reloadFailureSetsErrorMessage() {
    let store = StubLibraryStore(error: PetLibraryError.cannotCreatePetDirectory)
    let model = PetLibraryViewModel(store: store, selectedPetIdProvider: { "starter-pet" })
    model.reload()
    expect(model.items.isEmpty, "items should be empty when reload fails")
    expect(model.errorMessage != nil, "reload failure should set errorMessage")
  }

  func selectPetFiresCallback() {
    let model = makeModel(items: [makeImported(id: "cat")])
    var observed: [String] = []
    model.onSelectPet = { observed.append($0) }
    model.selectPet(id: "cat")
    expect(observed == ["cat"], "selectPet should dispatch the requested id")
  }

  func deletePetFiresCallbackOnlyForImported() {
    let model = makeModel(items: [makeBuiltIn(), makeImported(id: "cat")])
    var observed: [String] = []
    model.onDeletePet = { observed.append($0) }
    model.deletePet(id: "cat")
    expect(observed == ["cat"], "deletePet should fire callback for imported pet")
  }

  func deletePetIsNoOpForBuiltIn() {
    let model = makeModel(items: [makeBuiltIn()])
    var fired = false
    model.onDeletePet = { _ in fired = true }
    model.deletePet(id: "starter-pet")
    expect(fired == false, "deletePet should never delete a built-in pet")
  }

  func deletePetIgnoresUnknownId() {
    let model = makeModel(items: [makeImported(id: "cat")])
    var fired = false
    model.onDeletePet = { _ in fired = true }
    model.deletePet(id: "ghost")
    expect(fired == false, "deletePet should ignore ids not in items")
  }

  func importImageFiresCallbackWhenSelectorReturnsURL() {
    let url = URL(fileURLWithPath: "/tmp/Cute Cat.png")
    let model = PetLibraryViewModel(
      store: StubLibraryStore(items: []),
      selectedPetIdProvider: { "starter-pet" },
      imageSelector: { url }
    )
    var observed: [(URL, String)] = []
    model.onImportPetImage = { observed.append(($0, $1)) }
    model.importImage()
    expect(observed.count == 1, "importImage should fire onImportPetImage on success")
    expect(observed.first?.0 == url, "URL passed to callback should match selector")
    expect(observed.first?.1 == "Cute Cat", "displayName should default to file name minus extension")
  }

  func importImageDoesNothingWhenSelectorReturnsNil() {
    let model = PetLibraryViewModel(
      store: StubLibraryStore(items: []),
      selectedPetIdProvider: { "starter-pet" },
      imageSelector: { nil }
    )
    var fired = false
    model.onImportPetImage = { _, _ in fired = true }
    model.importImage()
    expect(fired == false, "cancelled selector should not dispatch import callback")
  }

  func importPackageFiresCallback() {
    let model = makeModel(items: [])
    let url = URL(fileURLWithPath: "/tmp/Pack.pet", isDirectory: true)
    var observed: [URL] = []
    model.onImportPetPackage = { observed.append($0) }
    model.importPackage(at: url)
    expect(observed == [url], "importPackage should dispatch selected package URL")
    expect(model.errorMessage == nil, "importPackage should clear previous error")
  }

  func successfulSelectClearsPreviousError() {
    let model = makeModel(items: [makeImported(id: "cat")])
    model.presentImportError(.unsupportedImageType)
    expect(model.errorMessage != nil, "preconditioned error should be set")
    model.selectPet(id: "cat")
    expect(model.errorMessage == nil, "successful selection should clear previous error")
  }

  func presentImportErrorSetsLocalizedDescription() {
    let model = makeModel(items: [])
    model.presentImportError(.unsupportedImageType)
    expect(
      model.errorMessage == PetLibraryError.unsupportedImageType.errorDescription,
      "presentImportError should expose the error's localized description"
    )
  }

  private func makeModel(items: [PetLibraryItem]) -> PetLibraryViewModel {
    let model = PetLibraryViewModel(
      store: StubLibraryStore(items: items),
      selectedPetIdProvider: { "starter-pet" }
    )
    if !items.isEmpty {
      model.reload()
    }
    return model
  }

  private func makeBuiltIn() -> PetLibraryItem {
    PetLibraryItem(
      id: "starter-pet",
      displayName: "Starter Pet",
      source: .builtIn,
      folderURL: nil,
      previewURL: nil,
      createdAt: Date(timeIntervalSince1970: 0)
    )
  }

  private func makeImported(id: String) -> PetLibraryItem {
    PetLibraryItem(
      id: id,
      displayName: id,
      source: .importedImage,
      folderURL: URL(fileURLWithPath: "/tmp/" + id),
      previewURL: nil,
      createdAt: Date(timeIntervalSince1970: 100)
    )
  }
}

private final class StubLibraryStore: PetLibraryStoring, @unchecked Sendable {
  let builtInPetId: String = "starter-pet"
  let importedPetsDirectoryURL: URL = URL(fileURLWithPath: "/tmp/pets")

  private let items: [PetLibraryItem]
  private let error: Error?

  init(items: [PetLibraryItem] = [], error: Error? = nil) {
    self.items = items
    self.error = error
  }

  func listPets() throws -> [PetLibraryItem] {
    if let error {
      throw error
    }
    return items
  }

  func loadDefinition(id: String) throws -> PetDefinition {
    throw PetLibraryError.petNotFound
  }

  func deleteImportedPet(id: String) throws {
    throw PetLibraryError.petNotFound
  }
}
