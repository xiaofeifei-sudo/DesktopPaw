import Foundation

public enum PetImageImportError: Error, Equatable, LocalizedError {
    case unsupportedImageType
    case unreadableImage
    case imageTooLarge
    case cannotCreatePetDirectory
    case cannotWriteImage

    public init?(_ error: PetLibraryError) {
        switch error {
        case .unsupportedImageType:
            self = .unsupportedImageType
        case .unreadableImage:
            self = .unreadableImage
        case .imageTooLarge:
            self = .imageTooLarge
        case .cannotCreatePetDirectory:
            self = .cannotCreatePetDirectory
        case .cannotWriteImage:
            self = .cannotWriteImage
        case .cannotWriteManifest,
             .unsupportedPackage,
             .invalidPackage,
             .missingPackageResource,
             .petAlreadyExists,
             .cannotDeleteBuiltInPet,
             .cannotDeletePet,
             .petNotFound,
             .missingManifest,
             .corruptManifest:
            return nil
        }
    }

    public var libraryError: PetLibraryError {
        switch self {
        case .unsupportedImageType:
            return .unsupportedImageType
        case .unreadableImage:
            return .unreadableImage
        case .imageTooLarge:
            return .imageTooLarge
        case .cannotCreatePetDirectory:
            return .cannotCreatePetDirectory
        case .cannotWriteImage:
            return .cannotWriteImage
        }
    }

    public var errorDescription: String? {
        libraryError.errorDescription
    }
}

public enum PetDeletionError: Error, Equatable, LocalizedError {
    case cannotDeleteBuiltInPet
    case cannotDeletePet
    case petNotFound

    public init?(_ error: PetLibraryError) {
        switch error {
        case .cannotDeleteBuiltInPet:
            self = .cannotDeleteBuiltInPet
        case .cannotDeletePet:
            self = .cannotDeletePet
        case .petNotFound:
            self = .petNotFound
        case .unsupportedImageType,
             .unreadableImage,
             .imageTooLarge,
             .cannotCreatePetDirectory,
             .cannotWriteImage,
             .cannotWriteManifest,
             .unsupportedPackage,
             .invalidPackage,
             .missingPackageResource,
             .petAlreadyExists,
             .missingManifest,
             .corruptManifest:
            return nil
        }
    }

    public var libraryError: PetLibraryError {
        switch self {
        case .cannotDeleteBuiltInPet:
            return .cannotDeleteBuiltInPet
        case .cannotDeletePet:
            return .cannotDeletePet
        case .petNotFound:
            return .petNotFound
        }
    }

    public var errorDescription: String? {
        libraryError.errorDescription
    }
}

public enum PetManifestError: Error, Equatable, LocalizedError {
    case cannotWriteManifest
    case missingManifest
    case corruptManifest

    public init?(_ error: PetLibraryError) {
        switch error {
        case .cannotWriteManifest:
            self = .cannotWriteManifest
        case .missingManifest:
            self = .missingManifest
        case .corruptManifest:
            self = .corruptManifest
        case .unsupportedImageType,
             .unreadableImage,
             .imageTooLarge,
             .cannotCreatePetDirectory,
             .cannotWriteImage,
             .cannotDeleteBuiltInPet,
             .cannotDeletePet,
             .unsupportedPackage,
             .invalidPackage,
             .missingPackageResource,
             .petAlreadyExists,
             .petNotFound:
            return nil
        }
    }

    public var libraryError: PetLibraryError {
        switch self {
        case .cannotWriteManifest:
            return .cannotWriteManifest
        case .missingManifest:
            return .missingManifest
        case .corruptManifest:
            return .corruptManifest
        }
    }

    public var errorDescription: String? {
        libraryError.errorDescription
    }
}

public enum PetLibraryError: Error, Equatable, LocalizedError {
    case unsupportedImageType
    case unreadableImage
    case imageTooLarge
    case cannotCreatePetDirectory
    case cannotWriteImage
    case cannotWriteManifest
    case unsupportedPackage
    case invalidPackage
    case missingPackageResource
    case petAlreadyExists
    case cannotDeleteBuiltInPet
    case cannotDeletePet
    case petNotFound
    case missingManifest
    case corruptManifest

    public var imageImportError: PetImageImportError? {
        PetImageImportError(self)
    }

    public var deletionError: PetDeletionError? {
        PetDeletionError(self)
    }

    public var manifestError: PetManifestError? {
        PetManifestError(self)
    }

    public var errorDescription: String? {
        switch self {
        case .unsupportedImageType:
            "The selected file is not a supported image format."
        case .unreadableImage:
            "The selected image could not be read."
        case .imageTooLarge:
            "The selected image is too large."
        case .cannotCreatePetDirectory:
            "Could not create the pet directory in Application Support."
        case .cannotWriteImage:
            "Could not write the pet image."
        case .cannotWriteManifest:
            "Could not write the pet manifest."
        case .unsupportedPackage:
            "The selected folder is not a supported pet package."
        case .invalidPackage:
            "The selected pet package is invalid."
        case .missingPackageResource:
            "The selected pet package is missing a required resource."
        case .petAlreadyExists:
            "A pet with this package id already exists."
        case .cannotDeleteBuiltInPet:
            "Built-in pets cannot be deleted."
        case .cannotDeletePet:
            "Could not delete the imported pet."
        case .petNotFound:
            "The requested pet could not be found."
        case .missingManifest:
            "The pet manifest is missing."
        case .corruptManifest:
            "The pet manifest could not be read."
        }
    }
}
