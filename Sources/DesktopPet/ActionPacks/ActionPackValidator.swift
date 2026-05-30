import CoreGraphics
import Foundation
import ImageIO

// MARK: - Validated Action Pack

public struct ValidatedActionPack: Equatable, Sendable {
    public let manifest: ActionPackManifest
    public let packURL: URL
    public let warnings: [ActionPackWarning]

    public init(
        manifest: ActionPackManifest,
        packURL: URL,
        warnings: [ActionPackWarning] = []
    ) {
        self.manifest = manifest
        self.packURL = packURL
        self.warnings = warnings
    }
}

// MARK: - Image Metadata

public struct ActionPackImageMetadata: Equatable, Sendable {
    public let width: Int
    public let height: Int

    public init(width: Int, height: Int) {
        self.width = width
        self.height = height
    }
}

// MARK: - Image Metadata Reader Protocol

public protocol ActionPackImageMetadataReading: Sendable {
    func metadata(for imageURL: URL) throws -> ActionPackImageMetadata
}

// MARK: - Default Image Metadata Reader

public struct DefaultActionPackImageMetadataReader: ActionPackImageMetadataReading {
    public init() {}

    public func metadata(for imageURL: URL) throws -> ActionPackImageMetadata {
        guard let source = CGImageSourceCreateWithURL(imageURL as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int,
              width > 0, height > 0
        else {
            throw ActionPackError.resourceUnreadable(
                packId: "", resourceId: "", path: imageURL.lastPathComponent
            )
        }
        return ActionPackImageMetadata(width: width, height: height)
    }
}

// MARK: - Validator Protocol

public protocol ActionPackValidating: Sendable {
    func validate(
        manifest: ActionPackManifest,
        packURL: URL,
        directoryName: String,
        baseFrameSize: CGSizeCodable,
        existingActionIds: Set<ActionId>
    ) throws -> ValidatedActionPack
}

// MARK: - Default Validator

public final class DefaultActionPackValidator: ActionPackValidating, @unchecked Sendable {
    private let imageMetadataReader: ActionPackImageMetadataReading
    private let fileManager: FileManager

    public init(
        imageMetadataReader: ActionPackImageMetadataReading = DefaultActionPackImageMetadataReader(),
        fileManager: FileManager = .default
    ) {
        self.imageMetadataReader = imageMetadataReader
        self.fileManager = fileManager
    }

    public func validate(
        manifest: ActionPackManifest,
        packURL: URL,
        directoryName: String,
        baseFrameSize: CGSizeCodable,
        existingActionIds: Set<ActionId>
    ) throws -> ValidatedActionPack {
        var warnings: [ActionPackWarning] = []

        guard manifest.schemaVersion == ActionPackManifest.supportedSchemaVersion else {
            throw ActionPackError.unsupportedSchemaVersion(manifest.schemaVersion)
        }

        guard manifest.id == directoryName else {
            throw ActionPackError.invalidPackId(
                "Pack id '\(manifest.id)' does not match directory name '\(directoryName)'"
            )
        }

        guard !manifest.resources.isEmpty else {
            throw ActionPackError.invalidPackId("Pack must contain at least one resource")
        }

        guard !manifest.actions.isEmpty else {
            throw ActionPackError.invalidPackId("Pack must contain at least one action")
        }

        try validateIdSafety(manifest)
        try validateResourcePaths(manifest, packURL: packURL)
        try validateResources(manifest, packURL: packURL, baseFrameSize: baseFrameSize)
        try validateNoDuplicateResourceIds(manifest)
        try validateActions(manifest, baseFrameSize: baseFrameSize, existingActionIds: existingActionIds, warnings: &warnings)

        return ValidatedActionPack(manifest: manifest, packURL: packURL, warnings: warnings)
    }

    // MARK: - ID Safety

    private func validateIdSafety(_ manifest: ActionPackManifest) throws {
        for resource in manifest.resources {
            guard ActionStringValidator.isValid(resource.id) else {
                throw ActionPackError.invalidResourceId(resource.id)
            }
        }
        for action in manifest.actions {
            guard ActionStringValidator.isValid(action.id.rawValue) else {
                throw ActionPackError.invalidActionId(action.id.rawValue)
            }
        }
    }

    // MARK: - Resource Path Safety

    private func validateResourcePaths(_ manifest: ActionPackManifest, packURL: URL) throws {
        for resource in manifest.resources {
            try validateResourcePath(resource.path, packId: manifest.id)
        }
    }

    private func validateResourcePath(_ path: String, packId: String) throws {
        guard !path.isEmpty else {
            throw ActionPackError.invalidResourcePath("Empty resource path")
        }

        let forbidden: [Character] = ["/", "\\", ":"]
        for char in forbidden {
            guard !path.contains(char) else {
                throw ActionPackError.invalidResourcePath(path)
            }
        }

        guard !path.contains("..") else {
            throw ActionPackError.invalidResourcePath(path)
        }

        guard !path.hasPrefix(".") else {
            throw ActionPackError.invalidResourcePath(path)
        }

        let supportedExtensions: Set<String> = ["png", "jpg", "jpeg"]
        let ext = (path as NSString).pathExtension.lowercased()
        guard supportedExtensions.contains(ext) else {
            throw ActionPackError.unsupportedImageFormat(packId: packId, path: path)
        }
    }

    // MARK: - Resource Image Validation

    private func validateResources(
        _ manifest: ActionPackManifest,
        packURL: URL,
        baseFrameSize: CGSizeCodable
    ) throws {
        for resource in manifest.resources {
            let imageURL = packURL.appendingPathComponent(resource.path)

            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: imageURL.path, isDirectory: &isDirectory),
                  !isDirectory.boolValue else {
                throw ActionPackError.resourceNotFound(
                    packId: manifest.id, resourceId: resource.id, path: resource.path
                )
            }

            let metadata: ActionPackImageMetadata
            do {
                metadata = try imageMetadataReader.metadata(for: imageURL)
            } catch {
                throw ActionPackError.resourceUnreadable(
                    packId: manifest.id, resourceId: resource.id, path: resource.path
                )
            }

            guard resource.frameSize.width > 0, resource.frameSize.height > 0,
                  resource.grid.columns > 0, resource.grid.rows > 0 else {
                throw ActionPackError.invalidResourcePath("frameSize and grid must be positive")
            }

            let expectedWidth = Int(resource.frameSize.width) * resource.grid.columns
            let expectedHeight = Int(resource.frameSize.height) * resource.grid.rows

            guard metadata.width == expectedWidth, metadata.height == expectedHeight else {
                throw ActionPackError.imageSizeMismatch(
                    packId: manifest.id,
                    resourceId: resource.id,
                    expected: CGSizeCodable(width: Double(expectedWidth), height: Double(expectedHeight)),
                    actual: CGSizeCodable(width: Double(metadata.width), height: Double(metadata.height))
                )
            }

            guard resource.frameSize.width == baseFrameSize.width,
                  resource.frameSize.height == baseFrameSize.height else {
                throw ActionPackError.frameSizeMismatch(
                    packId: manifest.id,
                    expected: baseFrameSize,
                    actual: resource.frameSize
                )
            }
        }
    }

    // MARK: - Duplicate Resource IDs

    private func validateNoDuplicateResourceIds(_ manifest: ActionPackManifest) throws {
        var seen = Set<String>()
        for resource in manifest.resources {
            guard seen.insert(resource.id).inserted else {
                throw ActionPackError.duplicateResourceId(packId: manifest.id, resourceId: resource.id)
            }
        }
    }

    // MARK: - Action Validation

    private func validateActions(
        _ manifest: ActionPackManifest,
        baseFrameSize: CGSizeCodable,
        existingActionIds: Set<ActionId>,
        warnings: inout [ActionPackWarning]
    ) throws {
        var resourceById = [String: ActionPackResource]()
        for resource in manifest.resources {
            resourceById[resource.id] = resource
        }

        for action in manifest.actions {
            if existingActionIds.contains(action.id) {
                warnings.append(ActionPackWarning(
                    kind: .actionIdConflict,
                    packId: manifest.id,
                    actionId: action.id.rawValue,
                    detail: "Action id '\(action.id.rawValue)' conflicts with existing action"
                ))
                continue
            }

            guard !action.frames.isEmpty else {
                throw ActionPackError.emptyActionFrames(actionId: action.id.rawValue)
            }

            guard action.frameDurationMs > 0 else {
                throw ActionPackError.invalidFrameDuration(
                    actionId: action.id.rawValue, durationMs: action.frameDurationMs
                )
            }

            let defaultAssetId = action.assetId
            for frame in action.frames {
                let resolvedAssetId = frame.assetId ?? defaultAssetId
                if let assetId = resolvedAssetId, let resource = resourceById[assetId] {
                    guard frame.column >= 0, frame.column < resource.grid.columns,
                          frame.row >= 0, frame.row < resource.grid.rows else {
                        throw ActionPackError.frameOutOfBounds(
                            actionId: action.id.rawValue,
                            frame: frame,
                            resource: assetId
                        )
                    }
                }
            }
        }
    }
}
