import Foundation

public protocol ManifestRewriting {
    @discardableResult
    func rewriteV1ManifestToV2(at manifestURL: URL) throws -> Bool
}

public final class ManifestRewriter: ManifestRewriting {
    private let fileManager: FileManager
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    private let legacyAdapter: LegacyAnimationsAdapting

    public init(
        fileManager: FileManager = .default,
        decoder: JSONDecoder = JSONDecoder(),
        encoder: JSONEncoder = ManifestRewriter.makeDefaultEncoder(),
        legacyAdapter: LegacyAnimationsAdapting = LegacyAnimationsAdapter()
    ) {
        self.fileManager = fileManager
        self.decoder = decoder
        self.encoder = encoder
        self.legacyAdapter = legacyAdapter
    }

    @discardableResult
    public func rewriteV1ManifestToV2(at manifestURL: URL) throws -> Bool {
        let data = try Data(contentsOf: manifestURL)
        let manifest = try decoder.decode(PetPackageManifest.self, from: data)
        guard manifest.schemaVersion == 1 || manifest.legacyAnimations != nil else {
            return false
        }
        guard let legacyAnimations = manifest.legacyAnimations else {
            return false
        }

        let upgraded = PetPackageManifest(
            schemaVersion: 2,
            id: manifest.id,
            displayName: manifest.displayName,
            description: manifest.description,
            asset: manifest.asset,
            preview: manifest.preview,
            frameSize: manifest.frameSize,
            spritesheet: manifest.spritesheet,
            defaultScale: manifest.defaultScale,
            actions: sortedActions(from: legacyAnimations),
            assetKind: manifest.assetKind,
            motionProfile: manifest.motionProfile,
            bubbleProfile: manifest.bubbleProfile
        )
        let upgradedData = try encoder.encode(upgraded)
        try replaceManifest(at: manifestURL, with: upgradedData)
        return true
    }

    public static func makeDefaultEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    private func sortedActions(from animations: [PetState: ManifestAnimationClip]) -> [Action] {
        let roleOrder = Dictionary(uniqueKeysWithValues: PetState.allCases.enumerated().map { index, state in
            (ActionRole(legacyState: state), index)
        })
        return legacyAdapter.actions(from: animations).sorted { lhs, rhs in
            let lhsOrder = lhs.role.flatMap { roleOrder[$0] } ?? Int.max
            let rhsOrder = rhs.role.flatMap { roleOrder[$0] } ?? Int.max
            if lhsOrder != rhsOrder {
                return lhsOrder < rhsOrder
            }
            return lhs.id.rawValue < rhs.id.rawValue
        }
    }

    private func replaceManifest(at manifestURL: URL, with data: Data) throws {
        let temporaryURL = manifestURL.deletingLastPathComponent().appendingPathComponent(
            ".\(manifestURL.lastPathComponent).\(UUID().uuidString).tmp",
            isDirectory: false
        )

        do {
            try data.write(to: temporaryURL)
            _ = try fileManager.replaceItemAt(manifestURL, withItemAt: temporaryURL)
        } catch {
            try? fileManager.removeItem(at: temporaryURL)
            throw error
        }
    }
}
