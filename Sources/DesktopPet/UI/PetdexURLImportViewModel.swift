import Foundation

@MainActor
public final class PetdexURLImportViewModel: ObservableObject {
  public static let emptyURLErrorMessage = "Enter a Petdex URL."
  public static let downloadingMessage = "Downloading..."
  public static let importingMessage = "Importing..."
  public static let importedMessage = "Imported."
  public static let cancelledMessage = "Cancelled."

  public enum State: Equatable {
    case idle
    case downloading(String)
    case importing(String)
    case imported(String)
    case failed(String)
    case cancelled
  }

  @Published public var input: String
  @Published public private(set) var state: State = .idle

  public var onImportRequested: ((String) -> Void)?
  public var onCancelRequested: (() -> Void)?

  private var activeInput: String?

  public init(input: String = "") {
    self.input = input
  }

  public var isInFlight: Bool {
    switch state {
    case .downloading, .importing:
      return true
    case .idle, .imported, .failed, .cancelled:
      return false
    }
  }

  public var canSubmit: Bool {
    !trimmedInput.isEmpty && !isInFlight
  }

  public var statusMessage: String? {
    switch state {
    case .idle:
      return nil
    case .downloading:
      return Self.downloadingMessage
    case .importing:
      return Self.importingMessage
    case .imported:
      return Self.importedMessage
    case let .failed(message):
      return message
    case .cancelled:
      return Self.cancelledMessage
    }
  }

  public func requestImport() {
    let input = trimmedInput
    guard !input.isEmpty else {
      activeInput = nil
      state = .failed(Self.emptyURLErrorMessage)
      return
    }

    activeInput = input
    state = .downloading(input)
    onImportRequested?(input)
  }

  public func cancelImport() {
    guard isInFlight else {
      return
    }

    activeInput = nil
    onCancelRequested?()
    state = .cancelled
  }

  public func reportPhase(_ phase: PetdexURLImportPhase) {
    guard let activeInput else {
      return
    }

    switch phase {
    case .downloading:
      state = .downloading(activeInput)
    case .importing:
      state = .importing(activeInput)
    }
  }

  public func reportImportSucceeded() {
    guard let activeInput else {
      return
    }

    state = .imported(activeInput)
    self.activeInput = nil
  }

  public func reportImportFailed(_ error: PetdexImportError) {
    guard activeInput != nil else {
      return
    }

    activeInput = nil
    state = .failed(error.errorDescription ?? "Petdex import failed.")
  }

  public func reportImportCancelled() {
    guard activeInput != nil || isInFlight else {
      return
    }

    activeInput = nil
    state = .cancelled
  }

  private var trimmedInput: String {
    input.trimmingCharacters(in: .whitespacesAndNewlines)
  }
}
