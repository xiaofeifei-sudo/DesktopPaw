import Foundation

public final class BuiltInPetDefinitionProvider {
    private let decoder: JSONDecoder

    public init(decoder: JSONDecoder = JSONDecoder()) {
        self.decoder = decoder
    }

    public func loadBuiltInPet() throws -> PetDefinition {
        guard let manifestURL = DesktopPetResources.url(named: "manifest", extension: "json") else {
            throw PetAssetError.invalidPackageStructure("Built-in pet manifest.json not found in bundle.")
        }

        let data = try Data(contentsOf: manifestURL)
        let manifest = try decoder.decode(PetPackageManifest.self, from: data)
        return try manifest.petDefinition().validated()
    }

    public func bundledResourceExists(named name: String, extension fileExtension: String = "png") -> Bool {
        DesktopPetResources.url(named: name, extension: fileExtension) != nil
    }

    public func bundledResourceURL(named name: String, extension fileExtension: String = "png") -> URL? {
        DesktopPetResources.url(named: name, extension: fileExtension)
    }
}
