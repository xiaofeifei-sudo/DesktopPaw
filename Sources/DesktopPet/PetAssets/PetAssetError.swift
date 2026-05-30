import Foundation

public enum PetAssetError: Error, Equatable, LocalizedError {
    case invalidSpriteSheetLayout
    case emptyAnimation(PetState)
    case frameOutOfBounds(state: PetState, frame: SpriteFrame)
    case missingRequiredAnimation(PetState)
    case manifestNotFound(URL)
    case invalidPackageExtension
    case invalidPackageStructure(String)
    case singleImagePackageUnsupported
    case unsafePackageResourceName(String)
    case missingPackageResource(String)
    case unreadablePackageResource(String)
    case packageLoadingReservedForFutureVersion

    public var errorDescription: String? {
        switch self {
        case .invalidSpriteSheetLayout:
            "Spritesheet rows and columns must be greater than zero."
        case .emptyAnimation(let state):
            "Animation \(state.rawValue) must include at least one frame."
        case .frameOutOfBounds(let state, let frame):
            "Animation \(state.rawValue) frame is out of bounds: \(frame)."
        case .missingRequiredAnimation(let state):
            "Required animation \(state.rawValue) is missing."
        case .manifestNotFound(let url):
            "Manifest not found at \(url.path)."
        case .invalidPackageExtension:
            "Pet packages must be .pet folders."
        case .invalidPackageStructure(let reason):
            "Invalid pet package structure: \(reason)"
        case .singleImagePackageUnsupported:
            "Single-image pets must be imported with Import Image."
        case .unsafePackageResourceName(let name):
            "Package resource must be a top-level file: \(name)."
        case .missingPackageResource(let name):
            "Package resource is missing: \(name)."
        case .unreadablePackageResource(let name):
            "Package resource could not be read as an image: \(name)."
        case .packageLoadingReservedForFutureVersion:
            "External pet package loading is reserved for a future version."
        }
    }
}
