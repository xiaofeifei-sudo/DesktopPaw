import Foundation
import DesktopPet

@MainActor
func runAppCoordinatorPetdexTests() {
  let tests = AppCoordinatorPetdexTests()
  tests.importPetdexPackageCommandRoutesToLibrary()
  tests.importPetdexURLCommandRoutesToLibrary()
  tests.cancelPetdexURLImportCommandRoutesToLibrary()
}

@MainActor
private struct AppCoordinatorPetdexTests {
  func importPetdexPackageCommandRoutesToLibrary() {
    let library = AppCoordinatorPetdexLibrarySpy()
    let coordinator = AppCoordinator(
      petWindow: AppCoordinatorPetdexWindowSpy(),
      petCommands: AppCoordinatorPetdexCommandSpy(),
      settingsWindow: AppCoordinatorPetdexSettingsSpy(),
      launchAtLogin: AppCoordinatorPetdexLaunchSpy(),
      application: AppCoordinatorPetdexApplicationSpy(),
      library: library
    )
    let url = URL(fileURLWithPath: "/tmp/my-cat-v3-large.zip")

    coordinator.handle(.importPetdexPackage(url))

    expect(library.actions == [.importPetdexPackage(url)], ".importPetdexPackage should route to PetLibraryCommanding")
  }

  func importPetdexURLCommandRoutesToLibrary() {
    let library = AppCoordinatorPetdexLibrarySpy()
    let coordinator = AppCoordinator(
      petWindow: AppCoordinatorPetdexWindowSpy(),
      petCommands: AppCoordinatorPetdexCommandSpy(),
      settingsWindow: AppCoordinatorPetdexSettingsSpy(),
      launchAtLogin: AppCoordinatorPetdexLaunchSpy(),
      application: AppCoordinatorPetdexApplicationSpy(),
      library: library
    )
    let input = "https://petdex.crafter.run/zh/pets/my-cat-v3-large"

    coordinator.handle(.importPetdexURL(input))

    expect(library.actions == [.importPetdexURL(input)], ".importPetdexURL should route to PetLibraryCommanding")
  }

  func cancelPetdexURLImportCommandRoutesToLibrary() {
    let library = AppCoordinatorPetdexLibrarySpy()
    let coordinator = AppCoordinator(
      petWindow: AppCoordinatorPetdexWindowSpy(),
      petCommands: AppCoordinatorPetdexCommandSpy(),
      settingsWindow: AppCoordinatorPetdexSettingsSpy(),
      launchAtLogin: AppCoordinatorPetdexLaunchSpy(),
      application: AppCoordinatorPetdexApplicationSpy(),
      library: library
    )

    coordinator.handle(.cancelPetdexURLImport)

    expect(library.actions == [.cancelPetdexURLImport], ".cancelPetdexURLImport should route to PetLibraryCommanding")
  }
}

@MainActor
private final class AppCoordinatorPetdexWindowSpy: PetWindowControlling {
  var isPetVisible = true
  func showPet() {}
  func hidePet() {}
  func resetPosition() {}
  func saveStateBeforeQuit() {}
}

@MainActor
private final class AppCoordinatorPetdexCommandSpy: PetCommandHandling {
  var isSleeping = false
  var runtimeState = PetRuntimeState.defaultState()
  var catalog = PetActionCatalog(petId: "petdex-spy-pet", actions: [], warnings: [])
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
private final class AppCoordinatorPetdexSettingsSpy: SettingsWindowControlling {
  func showSettings() {}
}

@MainActor
private final class AppCoordinatorPetdexLaunchSpy: LaunchAtLoginControlling {
  var isLaunchAtLoginEnabled = false
  func setLaunchAtLoginEnabled(_ enabled: Bool) {}
}

@MainActor
private final class AppCoordinatorPetdexApplicationSpy: ApplicationTerminating {
  func terminate() {}
}

@MainActor
private final class AppCoordinatorPetdexLibrarySpy: PetLibraryCommanding {
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
