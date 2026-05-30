import Foundation
import DesktopPet

@MainActor
func runAppCoordinatorPetdexURLTests() {
  let tests = AppCoordinatorPetdexURLTests()
  tests.importPetdexURLCommandRoutesToLibrary()
  tests.cancelPetdexURLImportCommandRoutesToLibrary()
}

@MainActor
private struct AppCoordinatorPetdexURLTests {
  func importPetdexURLCommandRoutesToLibrary() {
    let library = AppCoordinatorPetdexURLLibrarySpy()
    let coordinator = AppCoordinator(
      petWindow: AppCoordinatorPetdexURLWindowSpy(),
      petCommands: AppCoordinatorPetdexURLCommandSpy(),
      settingsWindow: AppCoordinatorPetdexURLSettingsSpy(),
      launchAtLogin: AppCoordinatorPetdexURLLaunchSpy(),
      application: AppCoordinatorPetdexURLApplicationSpy(),
      library: library
    )
    let input = "https://petdex.crafter.run/zh/pets/my-cat-v3-large"

    coordinator.handle(.importPetdexURL(input))

    expect(library.actions == [.importPetdexURL(input)], ".importPetdexURL should route to PetLibraryCommanding")
  }

  func cancelPetdexURLImportCommandRoutesToLibrary() {
    let library = AppCoordinatorPetdexURLLibrarySpy()
    let coordinator = AppCoordinator(
      petWindow: AppCoordinatorPetdexURLWindowSpy(),
      petCommands: AppCoordinatorPetdexURLCommandSpy(),
      settingsWindow: AppCoordinatorPetdexURLSettingsSpy(),
      launchAtLogin: AppCoordinatorPetdexURLLaunchSpy(),
      application: AppCoordinatorPetdexURLApplicationSpy(),
      library: library
    )

    coordinator.handle(.cancelPetdexURLImport)

    expect(library.actions == [.cancelPetdexURLImport], ".cancelPetdexURLImport should route to PetLibraryCommanding")
  }
}

@MainActor
private final class AppCoordinatorPetdexURLWindowSpy: PetWindowControlling {
  var isPetVisible = true
  func showPet() {}
  func hidePet() {}
  func resetPosition() {}
  func saveStateBeforeQuit() {}
}

@MainActor
private final class AppCoordinatorPetdexURLCommandSpy: PetCommandHandling {
  var isSleeping = false
  var runtimeState = PetRuntimeState.defaultState()
  var catalog = PetActionCatalog(petId: "petdex-url-spy-pet", actions: [], warnings: [])
  func clicked() {}
  func pet() {}
  func feed() {}
  func sleep() {}
  func wake() {}
  func dragStarted() {}
  func dragEnded() {}
  func playAction(_ id: ActionId) {}
  func setScale(_ scale: Double) {}
  func setRandomWalkingEnabled(_ enabled: Bool) {}
  func tick(at date: Date) {}
}

@MainActor
private final class AppCoordinatorPetdexURLSettingsSpy: SettingsWindowControlling {
  func showSettings() {}
}

@MainActor
private final class AppCoordinatorPetdexURLLaunchSpy: LaunchAtLoginControlling {
  var isLaunchAtLoginEnabled = false
  func setLaunchAtLoginEnabled(_ enabled: Bool) {}
}

@MainActor
private final class AppCoordinatorPetdexURLApplicationSpy: ApplicationTerminating {
  func terminate() {}
}

@MainActor
private final class AppCoordinatorPetdexURLLibrarySpy: PetLibraryCommanding {
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

  func importPetPackage(at url: URL) {
    actions.append(.importPetPackage(url))
  }

  func importPetdexPackage(at url: URL) {
    actions.append(.importPetdexPackage(url))
  }

  func importPetdexURL(_ input: String) {
    actions.append(.importPetdexURL(input))
  }

  func cancelPetdexURLImport() {
    actions.append(.cancelPetdexURLImport)
  }

  func selectPet(id: String) {
    actions.append(.selectPet(id))
  }

  func deletePet(id: String) {
    actions.append(.deletePet(id))
  }
}
