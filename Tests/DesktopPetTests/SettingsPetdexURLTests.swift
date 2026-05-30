import Foundation
import DesktopPet

@MainActor
func runSettingsPetdexURLTests() {
  let tests = SettingsPetdexURLTests()
  tests.petdexURLImportLabelsAreUserFacing()
  tests.petdexURLImportLabelsDoNotExposeManifestDetails()
  tests.petdexURLImportViewModelCanDispatchSettingsCommand()
  tests.petdexURLCancelCanDispatchSettingsCommand()
}

@MainActor
private struct SettingsPetdexURLTests {
  func petdexURLImportLabelsAreUserFacing() {
    expect(
      PetLibraryView.importPetdexURLButtonTitle == "Import from Petdex URL",
      "settings should expose a Petdex URL import entry"
    )
    expect(
      PetLibraryView.cancelPetdexURLButtonTitle == "Cancel",
      "settings should expose a Petdex URL cancel action"
    )
    expect(
      PetLibraryView.petdexURLPlaceholder.localizedCaseInsensitiveContains("petdex.crafter.run"),
      "URL field should hint at the supported Petdex host"
    )
  }

  func petdexURLImportLabelsDoNotExposeManifestDetails() {
    let labels = [
      PetLibraryView.importPetdexURLButtonTitle,
      PetLibraryView.cancelPetdexURLButtonTitle,
      PetLibraryView.petdexURLPlaceholder,
      PetdexURLImportViewModel.downloadingMessage,
      PetdexURLImportViewModel.importingMessage,
      PetdexURLImportViewModel.importedMessage,
      PetdexURLImportViewModel.cancelledMessage
    ]
    expect(
      labels.allSatisfy { !$0.localizedCaseInsensitiveContains("manifest") },
      "settings Petdex URL labels should not expose internal manifest details"
    )
  }

  func petdexURLImportViewModelCanDispatchSettingsCommand() {
    let input = "https://petdex.crafter.run/zh/pets/my-cat-v3-large"
    let model = PetdexURLImportViewModel(input: input)
    var commands: [AppCommand] = []
    model.onImportRequested = { commands.append(.importPetdexURL($0)) }

    model.requestImport()

    expect(commands == [.importPetdexURL(input)], "URL import model should dispatch AppCommand.importPetdexURL")
  }

  func petdexURLCancelCanDispatchSettingsCommand() {
    let model = PetdexURLImportViewModel(input: "https://petdex.crafter.run/zh/pets/my-cat-v3-large")
    var commands: [AppCommand] = []
    model.onCancelRequested = { commands.append(.cancelPetdexURLImport) }
    model.requestImport()

    model.cancelImport()

    expect(commands == [.cancelPetdexURLImport], "URL import model should dispatch AppCommand.cancelPetdexURLImport")
  }
}
