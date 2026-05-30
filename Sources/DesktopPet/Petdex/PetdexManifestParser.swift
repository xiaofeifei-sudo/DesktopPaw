import Foundation

public protocol PetdexManifestParsing {
    func parse(_ data: Data) throws -> PetdexManifest
}

public final class PetdexManifestParser: PetdexManifestParsing {
    private let decoder: JSONDecoder

    public init(decoder: JSONDecoder = JSONDecoder()) {
        self.decoder = decoder
    }

    public func parse(_ data: Data) throws -> PetdexManifest {
        let rawManifest: RawPetdexManifest
        do {
            rawManifest = try decoder.decode(RawPetdexManifest.self, from: data)
        } catch {
            throw PetdexImportError.manifestDecodingFailed
        }

        let id = try requiredTrimmedString(rawManifest.id, field: "id")
        let displayName = normalizedDisplayName(rawManifest.displayName, fallback: id)
        let description = try requiredString(rawManifest.description, field: "description")
        let spritesheetPath = try requiredTrimmedString(rawManifest.spritesheetPath, field: "spritesheetPath")
        try validateSpritesheetPath(spritesheetPath)

        return PetdexManifest(
            id: id,
            displayName: displayName,
            description: description,
            spritesheetPath: spritesheetPath
        )
    }

    private func requiredTrimmedString(_ value: String?, field: String) throws -> String {
        let value = try requiredString(value, field: field).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else {
            throw PetdexImportError.invalidManifestField(field: field, reason: "must not be empty")
        }
        return value
    }

    private func requiredString(_ value: String?, field: String) throws -> String {
        guard let value else {
            throw PetdexImportError.missingManifestField(field)
        }
        return value
    }

    private func normalizedDisplayName(_ value: String?, fallback id: String) -> String {
        let displayName = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return displayName.isEmpty ? id : displayName
    }

    private func validateSpritesheetPath(_ value: String) throws {
        guard value != "." && value != ".." &&
            !value.contains("/") &&
            !value.contains("\\") else {
            throw PetdexImportError.unsafeSpritesheetPath(value)
        }
    }
}

private struct RawPetdexManifest: Decodable {
    let id: String?
    let displayName: String?
    let description: String?
    let spritesheetPath: String?
}
