import AppKit
import Foundation

public enum DesktopPetApplication {
    @MainActor
    public static func run() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        application.run()

        withExtendedLifetime(delegate) {}
    }

    public static func validateLaunchConfiguration() throws {
        let provider = BuiltInPetDefinitionProvider()
        let definition = try provider.loadBuiltInPet()
        let previewExists = definition.previewAssetName.map {
            provider.bundledResourceExists(named: $0)
        } ?? true

        guard provider.bundledResourceExists(named: definition.assetName),
              previewExists,
              provider.bundledResourceExists(named: PetDefinition.placeholderAssetName)
        else {
            throw DesktopPetLaunchValidationError.missingBundledResources
        }
    }
}

public enum DesktopPetLaunchValidationError: Error, Equatable {
    case missingBundledResources
}
