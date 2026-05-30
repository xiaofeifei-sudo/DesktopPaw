import Foundation

public struct ActionPack: Equatable, Sendable {
    public let manifest: ContentPackManifest
    public let actions: [Action]

    public static func load(from packURL: URL, manifest: ContentPackManifest) throws -> ActionPack {
        let candidates = [
            packURL.appendingPathComponent("content/actions.json"),
            packURL.appendingPathComponent("content/actions/actions.json")
        ]
        guard let url = candidates.first(where: { FileManager.default.fileExists(atPath: $0.path) }) else {
            throw CocoaError(.fileNoSuchFile)
        }
        let data = try Data(contentsOf: url)
        let actions = try JSONDecoder().decode([Action].self, from: data)
        return ActionPack(manifest: manifest, actions: actions)
    }
}
