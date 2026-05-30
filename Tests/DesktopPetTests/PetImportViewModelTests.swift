import Foundation
import DesktopPet

@MainActor
func runPetImportViewModelTests() {
  let tests = PetImportViewModelTests()
  tests.defaultStateIsIdle()
  tests.cancelKeepsStateIdle()
  tests.successDispatchesCallbackAndMovesToInFlight()
  tests.reportImportSucceededReturnsToIdle()
  tests.reportImportFailedExposesLocalizedDescription()
  tests.requestImportClearsPreviousFailure()
  tests.displayNameDefaultsToFileNameWithoutExtension()
  tests.packageImportDispatchesPackageCallback()
  tests.packageCancelLeavesStateIdle()
}

@MainActor
private struct PetImportViewModelTests {
  func defaultStateIsIdle() {
    let model = PetImportViewModel(imageSelector: { nil })
    expect(model.state == .idle, "default import state should be idle")
  }

  func cancelKeepsStateIdle() {
    let model = PetImportViewModel(imageSelector: { nil })
    model.requestImport()
    expect(model.state == .idle, "cancelled selector should leave state idle")
  }

  func successDispatchesCallbackAndMovesToInFlight() {
    let url = URL(fileURLWithPath: "/tmp/My Pet.jpg")
    let model = PetImportViewModel(imageSelector: { url })
    var observed: [(URL, String)] = []
    model.onImportRequested = { observed.append(($0, $1)) }
    model.requestImport()

    if case let .inFlight(reportedURL, displayName) = model.state {
      expect(reportedURL == url, "in-flight state should hold selected URL")
      expect(displayName == "My Pet", "in-flight state should hold display name")
    } else {
      fail("requestImport with URL should move state to inFlight, got \(model.state)")
    }
    expect(observed.count == 1, "onImportRequested should fire exactly once on success")
  }

  func reportImportSucceededReturnsToIdle() {
    let url = URL(fileURLWithPath: "/tmp/My Pet.jpg")
    let model = PetImportViewModel(imageSelector: { url })
    model.requestImport()
    model.reportImportSucceeded()
    expect(model.state == .idle, "successful import should reset state to idle")
  }

  func reportImportFailedExposesLocalizedDescription() {
    let url = URL(fileURLWithPath: "/tmp/My Pet.jpg")
    let model = PetImportViewModel(imageSelector: { url })
    model.requestImport()
    model.reportImportFailed(.unsupportedImageType)
    if case let .failed(message) = model.state {
      expect(
        message == PetLibraryError.unsupportedImageType.errorDescription,
        "failed state should surface localized description"
      )
    } else {
      fail("reportImportFailed should move state to failed, got \(model.state)")
    }
  }

  func requestImportClearsPreviousFailure() {
    let url = URL(fileURLWithPath: "/tmp/Cat.png")
    let model = PetImportViewModel(imageSelector: { url })
    model.requestImport()
    model.reportImportFailed(.unsupportedImageType)
    model.requestImport()
    if case .inFlight = model.state {
      // expected
    } else {
      fail("retrying after failure should move state back to inFlight, got \(model.state)")
    }
  }

  func displayNameDefaultsToFileNameWithoutExtension() {
    let url = URL(fileURLWithPath: "/tmp/Sleepy Bunny.PNG")
    let model = PetImportViewModel(imageSelector: { url })
    var observedName: String?
    model.onImportRequested = { _, name in observedName = name }
    model.requestImport()
    expect(observedName == "Sleepy Bunny", "display name should match filename minus extension")
  }

  func packageImportDispatchesPackageCallback() {
    let url = URL(fileURLWithPath: "/tmp/Pack.pet")
    let model = PetImportViewModel(imageSelector: { nil }, packageSelector: { url })
    var observed: [URL] = []
    model.onPackageImportRequested = { observed.append($0) }
    model.requestPackageImport()

    if case let .inFlight(reportedURL, displayName) = model.state {
      expect(reportedURL == url, "package in-flight state should hold selected URL")
      expect(displayName == "Pack", "package display name should derive from folder name")
    } else {
      fail("requestPackageImport with URL should move state to inFlight, got \(model.state)")
    }
    expect(observed == [url], "package import callback should receive selected URL")
  }

  func packageCancelLeavesStateIdle() {
    let model = PetImportViewModel(imageSelector: { nil }, packageSelector: { nil })
    model.requestPackageImport()
    expect(model.state == .idle, "cancelled package selector should leave state idle")
  }
}
