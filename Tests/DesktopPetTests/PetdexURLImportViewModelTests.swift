import Foundation
import DesktopPet

@MainActor
func runPetdexURLImportViewModelTests() {
  let tests = PetdexURLImportViewModelTests()
  tests.emptyURLShowsInlineFailure()
  tests.requestImportDispatchesTrimmedURLAndShowsDownloading()
  tests.reportImportingShowsImportingState()
  tests.failureExposesPetdexErrorDescription()
  tests.cancelInFlightDispatchesCancelAndShowsCancelled()
  tests.lateFailureAfterCancelIsIgnored()
  tests.successShowsImportedState()
}

@MainActor
private struct PetdexURLImportViewModelTests {
  func emptyURLShowsInlineFailure() {
    let model = PetdexURLImportViewModel(input: "  ")
    var requestedInputs: [String] = []
    model.onImportRequested = { requestedInputs.append($0) }

    model.requestImport()

    expect(model.state == .failed(PetdexURLImportViewModel.emptyURLErrorMessage), "empty URL should show inline failure")
    expect(model.statusMessage == PetdexURLImportViewModel.emptyURLErrorMessage, "empty URL failure should be the status message")
    expect(requestedInputs.isEmpty, "empty URL should not dispatch an import request")
  }

  func requestImportDispatchesTrimmedURLAndShowsDownloading() {
    let input = "https://petdex.crafter.run/zh/pets/my-cat-v3-large"
    let model = PetdexURLImportViewModel(input: "  \(input)  ")
    var requestedInputs: [String] = []
    model.onImportRequested = { requestedInputs.append($0) }

    model.requestImport()

    expect(model.state == .downloading(input), "URL import should enter downloading state")
    expect(model.statusMessage == PetdexURLImportViewModel.downloadingMessage, "downloading state should expose downloading message")
    expect(requestedInputs == [input], "URL import should dispatch trimmed URL")
    expect(model.canSubmit == false, "URL import should not be submitted again while downloading")
  }

  func reportImportingShowsImportingState() {
    let input = "https://petdex.crafter.run/zh/pets/my-cat-v3-large"
    let model = PetdexURLImportViewModel(input: input)
    model.requestImport()

    model.reportPhase(.importing)

    expect(model.state == .importing(input), "download completion should move URL import to importing state")
    expect(model.statusMessage == PetdexURLImportViewModel.importingMessage, "importing state should expose importing message")
  }

  func failureExposesPetdexErrorDescription() {
    let input = "https://petdex.crafter.run/about"
    let model = PetdexURLImportViewModel(input: input)
    model.requestImport()

    model.reportImportFailed(.unsupportedPetdexURL(input))

    expect(
      model.state == .failed(PetdexImportError.unsupportedPetdexURL(input).errorDescription ?? ""),
      "URL failure should expose Petdex localized description"
    )
    expect(model.canSubmit == true, "failed URL import should be retryable")
  }

  func cancelInFlightDispatchesCancelAndShowsCancelled() {
    let model = PetdexURLImportViewModel(input: "https://petdex.crafter.run/zh/pets/my-cat-v3-large")
    var cancelCount = 0
    model.onCancelRequested = { cancelCount += 1 }
    model.requestImport()

    model.cancelImport()

    expect(cancelCount == 1, "cancel should dispatch exactly once while import is in flight")
    expect(model.state == .cancelled, "cancel should move state to cancelled")
    expect(model.statusMessage == PetdexURLImportViewModel.cancelledMessage, "cancelled state should expose cancelled message")
  }

  func lateFailureAfterCancelIsIgnored() {
    let input = "https://petdex.crafter.run/zh/pets/my-cat-v3-large"
    let model = PetdexURLImportViewModel(input: input)
    model.requestImport()
    model.cancelImport()

    model.reportImportFailed(.downloadFailed("late failure"))

    expect(model.state == .cancelled, "late failure after cancel should not replace cancelled state")
  }

  func successShowsImportedState() {
    let input = "https://petdex.crafter.run/zh/pets/my-cat-v3-large"
    let model = PetdexURLImportViewModel(input: input)
    model.requestImport()
    model.reportPhase(.importing)

    model.reportImportSucceeded()

    expect(model.state == .imported(input), "successful URL import should show imported state")
    expect(model.statusMessage == PetdexURLImportViewModel.importedMessage, "successful URL import should expose imported message")
    expect(model.canSubmit == true, "successful URL import should allow another import")
  }
}
