import Foundation

@MainActor
public final class PetLibraryViewModel: ObservableObject {
  public typealias ImageSelector = @MainActor () -> URL?

  @Published public private(set) var items: [PetLibraryItem] = []
  @Published public private(set) var currentPetId: String?
  @Published public private(set) var errorMessage: String?

  public var onImportPetImage: ((URL, String) -> Void)?
  public var onImportPetPackage: ((URL) -> Void)?
  public var onSelectPet: ((String) -> Void)?
  public var onDeletePet: ((String) -> Void)?

  private let store: PetLibraryStoring
  private let selectedPetIdProvider: @MainActor () -> String
  private let imageSelector: ImageSelector

  public init(
    store: PetLibraryStoring,
    selectedPetIdProvider: @escaping @MainActor () -> String,
    imageSelector: @escaping ImageSelector = { nil }
  ) {
    self.store = store
    self.selectedPetIdProvider = selectedPetIdProvider
    self.imageSelector = imageSelector
  }

  public func reload() {
    do {
      items = try store.listPets()
      currentPetId = selectedPetIdProvider()
    } catch {
      items = []
      errorMessage = (error as? LocalizedError)?.errorDescription
        ?? "Failed to load pet library."
    }
  }

  public func importImage() {
    guard let url = imageSelector() else { return }
    let displayName = url.deletingPathExtension().lastPathComponent
    errorMessage = nil
    onImportPetImage?(url, displayName)
  }

  public func importPackage(at url: URL) {
    errorMessage = nil
    onImportPetPackage?(url)
  }

  public func selectPet(id: String) {
    errorMessage = nil
    onSelectPet?(id)
  }

  public func deletePet(id: String) {
    guard let item = items.first(where: { $0.id == id }) else { return }
    guard item.isImported else { return }
    errorMessage = nil
    onDeletePet?(id)
  }

  public func presentImportError(_ error: PetLibraryError) {
    errorMessage = error.errorDescription
  }
}
