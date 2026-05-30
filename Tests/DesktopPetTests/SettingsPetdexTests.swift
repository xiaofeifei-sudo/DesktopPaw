import Foundation
import DesktopPet

@MainActor
func runSettingsPetdexTests() {
  let tests = SettingsPetdexTests()
  tests.petdexImportButtonLabelIsUserFacing()
  tests.petdexSourceLabelIsUserFacing()
  tests.petdexLabelsDoNotExposeManifestDetails()
  tests.petdexItemCanDispatchUsePetSelection()
}

@MainActor
private struct SettingsPetdexTests {
  func petdexImportButtonLabelIsUserFacing() {
    expect(
      PetLibraryView.importPetdexZipButtonTitle == "Import Petdex Zip",
      "settings should expose a Petdex zip import entry"
    )
  }

  func petdexSourceLabelIsUserFacing() {
    expect(PetSource.petdex.displayName == "Petdex", "Petdex source should display as Petdex")
  }

  func petdexLabelsDoNotExposeManifestDetails() {
    let labels = [
      PetLibraryView.importPetdexZipButtonTitle,
      PetSource.petdex.displayName,
      PetLibraryView.importingMessage
    ]
    expect(
      labels.allSatisfy { !$0.localizedCaseInsensitiveContains("manifest") },
      "settings Petdex labels should not expose internal manifest details"
    )
  }

  func petdexItemCanDispatchUsePetSelection() {
    let item = PetLibraryItem(
      id: "my-cat-v3-large",
      displayName: "Beibei",
      source: .petdex,
      folderURL: URL(fileURLWithPath: "/tmp/Pets/my-cat-v3-large", isDirectory: true),
      previewURL: nil,
      createdAt: Date(timeIntervalSince1970: 0)
    )
    let model = PetLibraryViewModel(
      store: SettingsPetdexStubStore(items: [item]),
      selectedPetIdProvider: { "starter-pet" }
    )
    model.reload()

    var selectedIds: [String] = []
    model.onSelectPet = { selectedIds.append($0) }
    model.selectPet(id: item.id)

    expect(selectedIds == [item.id], "Petdex library rows should be usable via Use Pet selection")
  }
}

private final class SettingsPetdexStubStore: PetLibraryStoring, @unchecked Sendable {
  let builtInPetId: String = "starter-pet"
  let importedPetsDirectoryURL: URL = URL(fileURLWithPath: "/tmp/Pets", isDirectory: true)

  private let items: [PetLibraryItem]

  init(items: [PetLibraryItem]) {
    self.items = items
  }

  func listPets() throws -> [PetLibraryItem] {
    items
  }

  func loadDefinition(id: String) throws -> PetDefinition {
    throw PetLibraryError.petNotFound
  }

  func deleteImportedPet(id: String) throws {
    throw PetLibraryError.petNotFound
  }
}
