import Foundation

@MainActor
public final class PetImportViewModel: ObservableObject {
  public typealias ImageSelector = @MainActor () -> URL?
  public typealias PackageSelector = @MainActor () -> URL?
  public typealias PetdexPackageSelector = @MainActor () -> URL?

  public enum State: Equatable {
    case idle
    case inFlight(URL, displayName: String)
    case failed(String)
  }

  @Published public private(set) var state: State = .idle

  public var onImportRequested: ((URL, String) -> Void)?
  public var onPackageImportRequested: ((URL) -> Void)?
  public var onPetdexPackageImportRequested: ((URL) -> Void)?

  private let imageSelector: ImageSelector
  private let packageSelector: PackageSelector
  private let petdexPackageSelector: PetdexPackageSelector

  public init(
    imageSelector: @escaping ImageSelector = { nil },
    packageSelector: @escaping PackageSelector = { nil },
    petdexPackageSelector: @escaping PetdexPackageSelector = { nil }
  ) {
    self.imageSelector = imageSelector
    self.packageSelector = packageSelector
    self.petdexPackageSelector = petdexPackageSelector
  }

  public convenience init(
    imageSelecting: PetImageSelecting,
    packageSelecting: PetPackageSelecting? = nil,
    petdexPackageSelecting: PetdexPackageSelecting? = PetdexPackageOpenPanel()
  ) {
    self.init(
      imageSelector: { imageSelecting.selectImage() },
      packageSelector: { packageSelecting?.selectPackage() },
      petdexPackageSelector: { petdexPackageSelecting?.selectPetdexPackage() }
    )
  }

  public func requestImport() {
    requestImageImport()
  }

  public func requestImageImport() {
    guard let url = imageSelector() else {
      if case .failed = state {
        state = .idle
      }
      return
    }
    let displayName = url.deletingPathExtension().lastPathComponent
    state = .inFlight(url, displayName: displayName)
    onImportRequested?(url, displayName)
  }

  public func requestPackageImport() {
    guard let url = packageSelector() else {
      if case .failed = state {
        state = .idle
      }
      return
    }
    let displayName = url.deletingPathExtension().lastPathComponent
    state = .inFlight(url, displayName: displayName)
    onPackageImportRequested?(url)
  }

  public func requestPetdexPackageImport() {
    guard let url = petdexPackageSelector() else {
      if case .failed = state {
        state = .idle
      }
      return
    }
    let displayName = url.deletingPathExtension().lastPathComponent
    state = .inFlight(url, displayName: displayName)
    onPetdexPackageImportRequested?(url)
  }

  public func reportImportSucceeded() {
    state = .idle
  }

  public func reportImportFailed(_ error: PetLibraryError) {
    state = .failed(error.errorDescription ?? "Import failed.")
  }

  public func reportPetdexImportFailed(_ error: PetdexImportError) {
    state = .failed(error.errorDescription ?? "Petdex import failed.")
  }
}
