import Foundation

public enum PetSource: String, Codable, Equatable, Sendable {
    case builtIn
    case importedImage
    case package
    case petdex

    public var displayName: String {
        switch self {
        case .builtIn:
            "Built-in"
        case .importedImage:
            "Imported image"
        case .package:
            "Imported package"
        case .petdex:
            "Petdex"
        }
    }
}

public struct PetLibraryItem: Equatable, Sendable {
    public let id: String
    public let displayName: String
    public let source: PetSource
    public let folderURL: URL?
    public let previewURL: URL?
    public let createdAt: Date

    public init(
        id: String,
        displayName: String,
        source: PetSource,
        folderURL: URL?,
        previewURL: URL?,
        createdAt: Date
    ) {
        self.id = id
        self.displayName = displayName
        self.source = source
        self.folderURL = folderURL
        self.previewURL = previewURL
        self.createdAt = createdAt
    }

    public var isImported: Bool {
        source != .builtIn
    }
}
