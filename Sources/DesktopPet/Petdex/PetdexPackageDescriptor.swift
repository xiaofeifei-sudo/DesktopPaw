import Foundation

public struct PetdexPackageDescriptor: Equatable, Sendable {
    public let manifest: PetdexManifest
    public let spritesheetEntryName: String
    public let sourceArchiveURL: URL

    public init(
        manifest: PetdexManifest,
        spritesheetEntryName: String,
        sourceArchiveURL: URL
    ) {
        self.manifest = manifest
        self.spritesheetEntryName = spritesheetEntryName
        self.sourceArchiveURL = sourceArchiveURL
    }
}
