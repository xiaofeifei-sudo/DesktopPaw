import Foundation

public struct PetdexImportFailureLog: Equatable, Sendable {
    public let stage: String
    public let sourceFileName: String
    public let reason: String
    public let underlyingReason: String?

    public init(
        stage: String,
        sourceFileName: String,
        reason: String,
        underlyingReason: String? = nil
    ) {
        self.stage = stage
        self.sourceFileName = sourceFileName
        self.reason = reason
        self.underlyingReason = underlyingReason
    }

    public var message: String {
        var value = "Petdex import failed during \(stage) for \(sourceFileName): \(reason)"
        if let underlyingReason, !underlyingReason.isEmpty {
            value += " (\(underlyingReason))"
        }
        return value
    }
}

public enum PetdexImportError: Error, Equatable, LocalizedError, Sendable {
    case notZipFile
    case invalidArchive
    case archiveTooLarge(maximumBytes: Int)
    case missingManifest
    case missingSpritesheet(String)
    case unsafeArchiveEntry(String)
    case unsafeSpritesheetPath(String)
    case directoryEntryUsedAsResource(String)
    case entryTooLarge(name: String, maximumBytes: Int)
    case manifestDecodingFailed
    case missingManifestField(String)
    case invalidManifestField(field: String, reason: String)
    case unreadableImage(String)
    case unsupportedImageFormat(String)
    case imageTooLarge(maximumPixels: Int)
    case invalidImageDimensions
    case invalidSpritesheetLayout(String)
    case writeFailed(String)
    case downloadFailed(String)
    case downloadCancelled
    case downloadTooLarge(maximumBytes: Int)
    case unsupportedPetdexURL(String)
    case petAlreadyExists(String)

    public var errorDescription: String? {
        switch self {
        case .notZipFile:
            "Choose a Petdex .zip package."
        case .invalidArchive:
            "The Petdex package could not be read."
        case let .archiveTooLarge(maximumBytes):
            "The Petdex package is too large. Maximum size is \(maximumBytes) bytes."
        case .missingManifest:
            "The Petdex package is missing pet.json."
        case let .missingSpritesheet(name):
            "The Petdex package is missing the spritesheet file: \(name)."
        case let .unsafeArchiveEntry(name):
            "The Petdex package contains an unsafe file path: \(name)."
        case let .unsafeSpritesheetPath(path):
            "The Petdex spritesheet path is not safe: \(path)."
        case let .directoryEntryUsedAsResource(name):
            "The Petdex package points to a directory instead of a file: \(name)."
        case let .entryTooLarge(name, maximumBytes):
            "The Petdex package file \(name) is too large. Maximum size is \(maximumBytes) bytes."
        case .manifestDecodingFailed:
            "The Petdex pet.json file could not be parsed."
        case let .missingManifestField(field):
            "The Petdex pet.json file is missing the required field: \(field)."
        case let .invalidManifestField(field, reason):
            "The Petdex pet.json field \(field) is invalid: \(reason)."
        case let .unreadableImage(name):
            "The Petdex spritesheet could not be read as an image: \(name)."
        case let .unsupportedImageFormat(name):
            "The Petdex spritesheet format is not supported: \(name)."
        case let .imageTooLarge(maximumPixels):
            "The Petdex spritesheet is too large. Maximum size is \(maximumPixels) pixels."
        case .invalidImageDimensions:
            "The Petdex spritesheet has invalid image dimensions."
        case let .invalidSpritesheetLayout(reason):
            "The Petdex spritesheet layout is not supported: \(reason)."
        case let .writeFailed(path):
            "The Petdex pet could not be written to the library: \(path)."
        case let .downloadFailed(reason):
            "The Petdex package could not be downloaded: \(reason)."
        case .downloadCancelled:
            "The Petdex download was cancelled."
        case let .downloadTooLarge(maximumBytes):
            "The Petdex download is too large. Maximum size is \(maximumBytes) bytes."
        case .unsupportedPetdexURL:
            "Enter a Petdex URL from petdex.crafter.run."
        case let .petAlreadyExists(id):
            "A pet with this Petdex id already exists: \(id)."
        }
    }

    public var failureStage: String {
        switch self {
        case .notZipFile,
             .invalidArchive,
             .archiveTooLarge,
             .missingManifest,
             .missingSpritesheet,
             .unsafeArchiveEntry,
             .unsafeSpritesheetPath,
             .directoryEntryUsedAsResource,
             .entryTooLarge:
            "archive"
        case .manifestDecodingFailed,
             .missingManifestField,
             .invalidManifestField:
            "manifest"
        case .unreadableImage,
             .unsupportedImageFormat,
             .imageTooLarge,
             .invalidImageDimensions,
             .invalidSpritesheetLayout:
            "image"
        case .writeFailed,
             .petAlreadyExists:
            "write"
        case .downloadFailed,
             .downloadCancelled,
             .downloadTooLarge,
             .unsupportedPetdexURL:
            "download"
        }
    }

    public func failureLog(
        sourceURL: URL,
        underlyingErrorDescription: String? = nil
    ) -> PetdexImportFailureLog {
        PetdexImportFailureLog(
            stage: failureStage,
            sourceFileName: sourceURL.lastPathComponent,
            reason: errorDescription ?? "Unknown Petdex import error.",
            underlyingReason: underlyingErrorDescription
        )
    }
}
