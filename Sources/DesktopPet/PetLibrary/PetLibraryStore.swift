import Foundation

public protocol PetLibraryStoring {
    var builtInPetId: String { get }
    var importedPetsDirectoryURL: URL { get }

    func listPets() throws -> [PetLibraryItem]
    func loadDefinition(id: String) throws -> PetDefinition
    func deleteImportedPet(id: String) throws
}

public final class PetLibraryStore: PetLibraryStoring {
    public static let defaultBuiltInPetId = "starter-pet"
    public static let petsDirectoryName = "Pets"
    public static let manifestFileName = "manifest.json"
    public static let imageFileName = "image.png"
    public static let previewFileName = "preview.png"

    public let builtInPetId: String

    private let builtInProvider: BuiltInPetDefinitionProvider
    private let fileManager: FileManager
    private let rootDirectory: URL
    private let decoder: JSONDecoder
    private let actionOverrideStore: PetActionOverrideStoring
    private let actionPackStore: ActionPackStoring
    private let actionPackOverrideStore: ActionPackOverrideStoring
    private let catalogComposer: ActionPackCatalogComposing

    public var importedPetsDirectoryURL: URL {
        rootDirectory.appendingPathComponent(Self.petsDirectoryName, isDirectory: true)
    }

    public init(
        rootDirectory: URL? = nil,
        builtInProvider: BuiltInPetDefinitionProvider = BuiltInPetDefinitionProvider(),
        builtInPetId: String = PetLibraryStore.defaultBuiltInPetId,
        fileManager: FileManager = .default,
        decoder: JSONDecoder = JSONDecoder(),
        actionOverrideStore: PetActionOverrideStoring? = nil,
        actionPackStore: ActionPackStoring? = nil,
        actionPackOverrideStore: ActionPackOverrideStoring? = nil,
        catalogComposer: ActionPackCatalogComposing? = nil
    ) {
        let resolvedRootDirectory = rootDirectory ?? Self.defaultRootDirectory(fileManager: fileManager)
        let resolvedPetsDirectory = resolvedRootDirectory.appendingPathComponent(Self.petsDirectoryName, isDirectory: true)
        self.builtInProvider = builtInProvider
        self.fileManager = fileManager
        self.builtInPetId = builtInPetId
        self.rootDirectory = resolvedRootDirectory
        self.decoder = decoder
        self.actionOverrideStore = actionOverrideStore ?? PetActionOverrideStore(
            petsDirectoryURL: resolvedPetsDirectory,
            fileManager: fileManager,
            decoder: decoder
        )
        self.actionPackStore = actionPackStore ?? FileActionPackStore(fileManager: fileManager)
        self.actionPackOverrideStore = actionPackOverrideStore ?? FileActionPackOverrideStore(
            petsDirectoryURL: resolvedPetsDirectory,
            fileManager: fileManager
        )
        self.catalogComposer = catalogComposer ?? DefaultActionPackCatalogComposer()
    }

    public func listPets() throws -> [PetLibraryItem] {
        try ensureImportedPetsDirectoryExists()

        var items: [PetLibraryItem] = []
        if let builtIn = try? loadBuiltInItem() {
            items.append(builtIn)
        }

        items.append(contentsOf: scanImportedPets())
        return items
    }

    public func loadDefinition(id: String) throws -> PetDefinition {
        let baseDefinition: PetDefinition
        let petFolderURL: URL?

        if id == builtInPetId {
            baseDefinition = try builtInProvider.loadBuiltInPet()
            petFolderURL = nil
        } else {
            try ensureImportedPetsDirectoryExists()
            let folder = importedPetsDirectoryURL.appendingPathComponent(id, isDirectory: true)
            let manifestURL = folder.appendingPathComponent(Self.manifestFileName)

            guard fileManager.fileExists(atPath: manifestURL.path) else {
                DesktopPetLog.petLibrary.warning("Imported pet \(id, privacy: .public) not found; falling back to built-in pet.")
                return try builtInProvider.loadBuiltInPet()
            }

            do {
                let data = try Data(contentsOf: manifestURL)
                let manifest = try decoder.decode(PetPackageManifest.self, from: data)
                let overrides = try actionOverrideStore.load(petId: id)
                let loadManifest = normalizeLegacyPetdexManifestIfNeeded(
                    manifest,
                    in: folder,
                    hasOverrides: overrides != nil
                )
                baseDefinition = try loadManifest.petDefinition(overrides: overrides)
                petFolderURL = folder
            } catch let error as ActionCatalogError {
                DesktopPetLog.petLibrary.error("Action catalog build failed for imported pet \(id, privacy: .public): \(Self.describe(error), privacy: .public). Falling back to built-in pet.")
                return try builtInProvider.loadBuiltInPet()
            } catch let error as PetAssetError {
                DesktopPetLog.petLibrary.error("Pet asset validation failed for imported pet \(id, privacy: .public): \(error.localizedDescription, privacy: .public). Falling back to built-in pet.")
                return try builtInProvider.loadBuiltInPet()
            } catch {
                DesktopPetLog.petLibrary.error("Failed to load imported pet \(id, privacy: .public): \(error.localizedDescription, privacy: .public). Falling back to built-in pet.")
                return try builtInProvider.loadBuiltInPet()
            }
        }

        let withOverrides = applyOverridesIfPresent(to: baseDefinition, petId: id)

        guard let folderURL = petFolderURL else {
            return withOverrides
        }

        return composeActionPacks(
            definition: withOverrides,
            petId: id,
            folderURL: folderURL
        )
    }

    private func applyOverridesIfPresent(to definition: PetDefinition, petId: String) -> PetDefinition {
        do {
            guard let overrides = try actionOverrideStore.load(petId: petId) else {
                return definition
            }
            let input = PetActionCatalogBuildInput(
                petId: definition.id,
                schemaVersion: 2,
                legacyAnimations: nil,
                actions: definition.catalog.actions,
                spritesheet: definition.spritesheet
            )
            let catalog = try DefaultPetActionCatalogBuilder().build(input: input, overrides: overrides)
            return try PetDefinition(
                id: definition.id,
                displayName: definition.displayName,
                description: definition.description,
                assetName: definition.assetName,
                previewAssetName: definition.previewAssetName,
                frameSize: definition.frameSize,
                spritesheet: definition.spritesheet,
                defaultScale: definition.defaultScale,
                catalog: catalog,
                assetKind: definition.assetKind,
                motionProfile: definition.motionProfile,
                bubbleProfile: definition.bubbleProfile
            ).validated()
        } catch {
            DesktopPetLog.petLibrary.warning("Failed to apply action overrides for pet \(petId, privacy: .public): \(error.localizedDescription, privacy: .public).")
            return definition
        }
    }

    private func composeActionPacks(
        definition: PetDefinition,
        petId: String,
        folderURL: URL
    ) -> PetDefinition {
        do {
            let loadResult = try actionPackStore.loadPacks(
                in: folderURL,
                baseFrameSize: definition.frameSize,
                existingActionIds: Set(definition.catalog.actions.map { $0.id })
            )

            for warning in loadResult.warnings {
                DesktopPetLog.petLibrary.warning(
                    "Action pack warning for pet \(petId, privacy: .public): \(warning.detail, privacy: .public)"
                )
            }

            let packOverrides = actionPackOverrideStore.load(petId: petId)

            return try catalogComposer.compose(
                baseDefinition: definition,
                packs: loadResult.packs,
                overrides: packOverrides
            )
        } catch {
            DesktopPetLog.petLibrary.warning(
                "Failed to compose action packs for pet \(petId, privacy: .public): \(error.localizedDescription, privacy: .public). Using base definition."
            )
            return definition
        }
    }

    private static func describe(_ error: ActionCatalogError) -> String {
        switch error {
        case .missingRequiredRole(let role):
            return "missingRequiredRole(\(role.rawValue))"
        case .duplicateActionId(let actionId):
            return "duplicateActionId(\(actionId.rawValue))"
        case .unsupportedSchemaVersion(let version):
            return "unsupportedSchemaVersion(\(version))"
        case .invalidActionId(let value):
            return "invalidActionId(\(value))"
        case .invalidActionTag(let value):
            return "invalidActionTag(\(value))"
        case .tooManyTagsOnAction(let actionId, let count, let limit):
            return "tooManyTagsOnAction(\(actionId.rawValue), count: \(count), limit: \(limit))"
        case .tooManyTagsInPackage(let count, let limit):
            return "tooManyTagsInPackage(count: \(count), limit: \(limit))"
        case .nextActionIdNotFound(let actionId):
            return "nextActionIdNotFound(\(actionId.rawValue))"
        case .frameOutOfBounds(let actionId, let frame):
            return "frameOutOfBounds(\(actionId.rawValue), frame: \(frame))"
        }
    }

    public func deleteImportedPet(id: String) throws {
        guard id != builtInPetId else {
            throw PetLibraryError.cannotDeleteBuiltInPet
        }

        try ensureImportedPetsDirectoryExists()

        let folder = importedPetsDirectoryURL.appendingPathComponent(id, isDirectory: true)
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: folder.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw PetLibraryError.petNotFound
        }

        do {
            try fileManager.removeItem(at: folder)
        } catch {
            DesktopPetLog.petLibrary.error("Failed to delete imported pet \(id, privacy: .public): \(error.localizedDescription, privacy: .public).")
            throw PetLibraryError.cannotDeletePet
        }
    }

    private func ensureImportedPetsDirectoryExists() throws {
        var isDirectory: ObjCBool = false
        if fileManager.fileExists(atPath: importedPetsDirectoryURL.path, isDirectory: &isDirectory) {
            if isDirectory.boolValue {
                return
            }
        }

        do {
            try fileManager.createDirectory(
                at: importedPetsDirectoryURL,
                withIntermediateDirectories: true,
                attributes: nil
            )
        } catch {
            DesktopPetLog.petLibrary.error("Failed to create imported pets directory at \(self.importedPetsDirectoryURL.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
            throw PetLibraryError.cannotCreatePetDirectory
        }
    }

    private func loadBuiltInItem() throws -> PetLibraryItem {
        let definition = try builtInProvider.loadBuiltInPet()
        return PetLibraryItem(
            id: definition.id,
            displayName: definition.displayName,
            source: .builtIn,
            folderURL: nil,
            previewURL: definition.previewAssetName.flatMap { name in
                builtInProvider.bundledResourceURL(named: name)
            },
            createdAt: Date(timeIntervalSince1970: 0)
        )
    }

    private func scanImportedPets() -> [PetLibraryItem] {
        guard let entries = try? fileManager.contentsOfDirectory(
            at: importedPetsDirectoryURL,
            includingPropertiesForKeys: [.creationDateKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var items: [PetLibraryItem] = []
        for entry in entries {
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: entry.path, isDirectory: &isDirectory),
                  isDirectory.boolValue else {
                continue
            }

            if let item = importedItem(at: entry) {
                items.append(item)
            }
        }
        return items.sorted(by: { $0.createdAt < $1.createdAt })
    }

    private func importedItem(at folder: URL) -> PetLibraryItem? {
        let manifestURL = folder.appendingPathComponent(Self.manifestFileName)
        guard fileManager.fileExists(atPath: manifestURL.path) else {
            DesktopPetLog.petLibrary.warning("Skipping imported pet folder without manifest: \(folder.lastPathComponent, privacy: .public)")
            return nil
        }

        do {
            let data = try Data(contentsOf: manifestURL)
            let manifest = try decoder.decode(PetPackageManifest.self, from: data)

            let createdAt: Date
            if let attributes = try? fileManager.attributesOfItem(atPath: folder.path),
               let creationDate = attributes[.creationDate] as? Date {
                createdAt = creationDate
            } else {
                createdAt = Date()
            }

            let previewURL: URL? = manifest.preview.map { folder.appendingPathComponent($0) }
            let source = importedSource(for: manifest, in: folder)

            return PetLibraryItem(
                id: manifest.id,
                displayName: manifest.displayName,
                source: source,
                folderURL: folder,
                previewURL: previewURL,
                createdAt: createdAt
            )
        } catch {
            DesktopPetLog.petLibrary.warning("Skipping imported pet \(folder.lastPathComponent, privacy: .public) due to manifest error: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    private func importedSource(for manifest: PetPackageManifest, in folder: URL) -> PetSource {
        let sidecarURL = folder.appendingPathComponent(PetdexSourceMetadata.fileName)
        guard fileManager.fileExists(atPath: sidecarURL.path) else {
            return defaultImportedSource(for: manifest)
        }

        do {
            let data = try Data(contentsOf: sidecarURL)
            let metadata = try decoder.decode(PetdexSourceMetadata.self, from: data)
            guard metadata.source == .petdex else {
                DesktopPetLog.petLibrary.warning("Petdex source sidecar for \(folder.lastPathComponent, privacy: .public) has invalid source \(metadata.source.rawValue, privacy: .public); treating it as an imported package.")
                return .package
            }
            return .petdex
        } catch {
            DesktopPetLog.petLibrary.warning("Could not read Petdex source sidecar for \(folder.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public). Treating it as an imported package.")
            return .package
        }
    }

    private func defaultImportedSource(for manifest: PetPackageManifest) -> PetSource {
        manifest.assetKind == .singleImage ? .importedImage : .package
    }

    private func normalizeLegacyPetdexManifestIfNeeded(
        _ manifest: PetPackageManifest,
        in folder: URL,
        hasOverrides: Bool
    ) -> PetPackageManifest {
        guard !hasOverrides,
              manifest.assetKind == .spriteSheet,
              let spritesheet = manifest.spritesheet,
              importedSource(for: manifest, in: folder) == .petdex,
              manifest.actions.contains(where: { $0.role != nil }) else {
            return manifest
        }

        let actions = genericPetdexRowActions(from: manifest.actions, spritesheet: spritesheet)
        guard !actions.isEmpty else {
            return manifest
        }

        return PetPackageManifest(
            schemaVersion: 2,
            id: manifest.id,
            displayName: manifest.displayName,
            description: manifest.description,
            asset: manifest.asset,
            preview: manifest.preview,
            frameSize: manifest.frameSize,
            spritesheet: spritesheet,
            defaultScale: manifest.defaultScale,
            actions: actions,
            assetKind: manifest.assetKind,
            motionProfile: manifest.motionProfile,
            bubbleProfile: manifest.bubbleProfile
        )
    }

    private func genericPetdexRowActions(
        from sourceActions: [Action],
        spritesheet: SpriteSheetLayout
    ) -> [Action] {
        guard spritesheet.columns > 0, spritesheet.rows > 0 else {
            return []
        }

        return (0..<spritesheet.rows).compactMap { row in
            guard let actionId = ActionId(rawValue: "action_\(row + 1)") else {
                return nil
            }
            let existingFrames = sourceActions
                .first { action in action.frames.contains { $0.row == row } }?
                .frames
                .filter { $0.row == row && $0.column >= 0 && $0.column < spritesheet.columns }
            let frames: [SpriteFrame]
            if let existingFrames, !existingFrames.isEmpty {
                frames = existingFrames
            } else {
                frames = (0..<spritesheet.columns).map { SpriteFrame(column: $0, row: row) }
            }
            let isDefault = row == 0

            return Action(
                id: actionId,
                displayName: "Action \(row + 1)",
                role: nil,
                tags: [],
                frames: frames,
                frameDurationMs: isDefault
                    ? DefaultPetdexAnimationMappingProvider.loopingFrameDurationMs
                    : DefaultPetdexAnimationMappingProvider.oneShotFrameDurationMs,
                loop: isDefault,
                nextActionId: nil
            )
        }
    }

    private static func defaultRootDirectory(fileManager: FileManager) -> URL {
        if let url = try? fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        ) {
            return url.appendingPathComponent("DesktopPet", isDirectory: true)
        }

        let home = fileManager.homeDirectoryForCurrentUser
        return home.appendingPathComponent("Library/Application Support/DesktopPet", isDirectory: true)
    }
}
