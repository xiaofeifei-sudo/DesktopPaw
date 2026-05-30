import Foundation
import DesktopPet

@MainActor
func runPetImportViewModelPetdexTests() {
  let tests = PetImportViewModelPetdexTests()
  tests.petdexImportDispatchesCallbackAndMovesToInFlight()
  tests.petdexCancelLeavesStateIdle()
  tests.petdexCancelClearsPreviousFailure()
  tests.petdexFailureExposesLocalizedDescription()
  tests.convenienceInitializerInjectsPetdexSelectingProtocol()
}

@MainActor
private struct PetImportViewModelPetdexTests {
  func petdexImportDispatchesCallbackAndMovesToInFlight() {
    let url = URL(fileURLWithPath: "/tmp/my-cat-v3-large.zip")
    let model = PetImportViewModel(
      imageSelector: { nil },
      packageSelector: { nil },
      petdexPackageSelector: { url }
    )
    var observed: [URL] = []
    model.onPetdexPackageImportRequested = { observed.append($0) }

    model.requestPetdexPackageImport()

    if case let .inFlight(reportedURL, displayName) = model.state {
      expect(reportedURL == url, "Petdex in-flight state should hold selected zip URL")
      expect(displayName == "my-cat-v3-large", "Petdex display name should derive from zip filename")
    } else {
      fail("requestPetdexPackageImport with URL should move state to inFlight, got \(model.state)")
    }
    expect(observed == [url], "Petdex import callback should receive selected zip URL")
  }

  func petdexCancelLeavesStateIdle() {
    let model = PetImportViewModel(
      imageSelector: { nil },
      packageSelector: { nil },
      petdexPackageSelector: { nil }
    )
    model.requestPetdexPackageImport()
    expect(model.state == .idle, "cancelled Petdex selection should leave state idle")
  }

  func petdexCancelClearsPreviousFailure() {
    let model = PetImportViewModel(
      imageSelector: { nil },
      packageSelector: { nil },
      petdexPackageSelector: { nil }
    )
    model.reportPetdexImportFailed(.missingManifest)
    model.requestPetdexPackageImport()
    expect(model.state == .idle, "cancelled Petdex selection should clear a previous failure")
  }

  func petdexFailureExposesLocalizedDescription() {
    let model = PetImportViewModel(
      imageSelector: { nil },
      packageSelector: { nil },
      petdexPackageSelector: { nil }
    )
    model.reportPetdexImportFailed(.missingManifest)
    if case let .failed(message) = model.state {
      expect(
        message == PetdexImportError.missingManifest.errorDescription,
        "Petdex failed state should surface localized description"
      )
    } else {
      fail("reportPetdexImportFailed should move state to failed, got \(model.state)")
    }
  }

  func convenienceInitializerInjectsPetdexSelectingProtocol() {
    let url = URL(fileURLWithPath: "/tmp/Beibei.zip")
    let imageStub = PetdexImportImageSelectorStub(result: nil)
    let packageStub = PetdexImportPackageSelectorStub(result: nil)
    let petdexStub = PetdexImportPetdexSelectorStub(result: url)
    let model = PetImportViewModel(
      imageSelecting: imageStub,
      packageSelecting: packageStub,
      petdexPackageSelecting: petdexStub
    )
    var observed: [URL] = []
    model.onPetdexPackageImportRequested = { observed.append($0) }

    model.requestPetdexPackageImport()

    expect(observed == [url], "view model should call injected Petdex selector")
    expect(petdexStub.callCount == 1, "Petdex selector should be invoked once")
    expect(imageStub.callCount == 0, "image selector should not be used for Petdex import")
    expect(packageStub.callCount == 0, "package selector should not be used for Petdex import")
  }
}

@MainActor
private final class PetdexImportImageSelectorStub: PetImageSelecting {
  private let result: URL?
  private(set) var callCount = 0

  init(result: URL?) {
    self.result = result
  }

  func selectImage() -> URL? {
    callCount += 1
    return result
  }
}

@MainActor
private final class PetdexImportPackageSelectorStub: PetPackageSelecting {
  private let result: URL?
  private(set) var callCount = 0

  init(result: URL?) {
    self.result = result
  }

  func selectPackage() -> URL? {
    callCount += 1
    return result
  }
}

@MainActor
private final class PetdexImportPetdexSelectorStub: PetdexPackageSelecting {
  private let result: URL?
  private(set) var callCount = 0

  init(result: URL?) {
    self.result = result
  }

  func selectPetdexPackage() -> URL? {
    callCount += 1
    return result
  }
}
