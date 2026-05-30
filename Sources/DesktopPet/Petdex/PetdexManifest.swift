import Foundation

public struct PetdexManifest: Codable, Equatable, Sendable {
    public let id: String
    public let displayName: String
    public let description: String
    public let spritesheetPath: String

    public init(
        id: String,
        displayName: String,
        description: String,
        spritesheetPath: String
    ) {
        self.id = id
        self.displayName = displayName
        self.description = description
        self.spritesheetPath = spritesheetPath
    }
}
