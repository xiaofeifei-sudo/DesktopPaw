import Foundation

/// Petdex URL 导入的阶段
public enum PetdexURLImportPhase: Equatable, Sendable {
    /// 正在下载
    case downloading
    /// 正在导入
    case importing
}

/// 宠物图库指挥官
///
/// 统一管理宠物的导入/选择/删除/动作包等操作，是 PetLibraryCommanding 协议的默认实现。
/// 支持以下导入方式：
/// - 图片导入：单张图片自动生成精灵图
/// - .pet 包导入
/// - Petdex 压缩包导入
/// - Petdex URL 在线下载导入（异步，可取消）
///
/// 同时管理动作包的保存、删除、启用/禁用。
@MainActor
public final class PetLibraryCommander: PetLibraryCommanding {
    // MARK: - 依赖

    private let store: PetLibraryStoring
    private let importer: PetImageImporting
    private let packageImporter: PetPackageImporting
    private let petdexPackageImporter: PetdexPackageImporting
    private let petdexURLResolver: PetdexURLResolving
    private let petdexDownloader: PetdexDownloading
    private let manifestWriter: PetLibraryManifestWriting
    private let preferences: PreferencesStore
    private let petIdGenerator: () -> String
    private let fileManager: FileManager
    private let actionPackWriter: ActionPackWriting
    private let actionPackStore: ActionPackStoring
    private let actionPackOverrideStore: ActionPackOverrideStoring

    /// Petdex URL 导入的异步任务（可取消）
    private var petdexURLImportTask: Task<Void, Never>?
    /// 当前 Petdex 导入的唯一标识（用于取消时比对）
    private var petdexURLImportID: UUID?

    // MARK: - 回调

    public var onLibraryChanged: (() -> Void)?
    public var onCurrentPetChanged: ((PetDefinition) -> Void)?
    public var onImportFailed: ((PetLibraryError) -> Void)?
    public var onPetdexImportFailed: ((PetdexImportError) -> Void)?
    public var onPetdexURLImportPhaseChanged: ((PetdexURLImportPhase) -> Void)?
    public var onPetdexURLImportSucceeded: (() -> Void)?
    public var onPetdexURLImportFailed: ((PetdexImportError) -> Void)?
    public var onPetdexURLImportCancelled: (() -> Void)?
    public var onDeleteFailed: ((PetLibraryError) -> Void)?

    // MARK: - 初始化

    public init(
        store: PetLibraryStoring,
        importer: PetImageImporting,
        packageImporter: PetPackageImporting = PetPackageImporter(),
        petdexPackageImporter: PetdexPackageImporting = PetdexPackageImporter(),
        petdexURLResolver: PetdexURLResolving = PetdexURLResolver(),
        petdexDownloader: PetdexDownloading = PetdexDownloader(),
        manifestWriter: PetLibraryManifestWriting,
        preferences: PreferencesStore,
        petIdGenerator: @escaping () -> String = { UUID().uuidString },
        fileManager: FileManager = .default,
        actionPackWriter: ActionPackWriting? = nil,
        actionPackStore: ActionPackStoring? = nil,
        actionPackOverrideStore: ActionPackOverrideStoring? = nil
    ) {
        self.store = store
        self.importer = importer
        self.packageImporter = packageImporter
        self.petdexPackageImporter = petdexPackageImporter
        self.petdexURLResolver = petdexURLResolver
        self.petdexDownloader = petdexDownloader
        self.manifestWriter = manifestWriter
        self.preferences = preferences
        self.petIdGenerator = petIdGenerator
        self.fileManager = fileManager
        self.actionPackWriter = actionPackWriter ?? FileActionPackWriter(fileManager: fileManager)
        self.actionPackStore = actionPackStore ?? FileActionPackStore(fileManager: fileManager)
        self.actionPackOverrideStore = actionPackOverrideStore ?? FileActionPackOverrideStore(
            petsDirectoryURL: store.importedPetsDirectoryURL,
            fileManager: fileManager
        )
    }

    // MARK: - 图片导入

    /// 从图片文件导入新宠物
    /// 流程：复制图片 → 生成 manifest → 写入图库 → 切换为当前宠物
    public func importPetImage(at url: URL, displayName: String) {
        let petId = petIdGenerator()
        let folderURL = store.importedPetsDirectoryURL.appendingPathComponent(petId, isDirectory: true)
        let shouldCleanUpFailedFolder = !fileManager.fileExists(atPath: folderURL.path)

        // Step 1: 导入图片
        let imported: ImportedPetImage
        do {
            imported = try importer.importImage(from: url, to: folderURL, displayName: displayName)
        } catch let error as PetLibraryError {
            reportImportFailure(error, displayName: displayName, sourceURL: url, folderURL: folderURL, shouldCleanUpFolder: shouldCleanUpFailedFolder)
            return
        } catch {
            reportImportFailure(.unreadableImage, displayName: displayName, sourceURL: url, folderURL: folderURL, shouldCleanUpFolder: shouldCleanUpFailedFolder, underlyingError: error)
            return
        }

        // Step 2: 写入 manifest
        do {
            try manifestWriter.writeSingleImageManifest(petId: petId, displayName: displayName, image: imported, to: folderURL)
        } catch let error as PetLibraryError {
            reportImportFailure(error, displayName: displayName, sourceURL: url, folderURL: folderURL, shouldCleanUpFolder: shouldCleanUpFailedFolder)
            return
        } catch {
            reportImportFailure(.cannotWriteManifest, displayName: displayName, sourceURL: url, folderURL: folderURL, shouldCleanUpFolder: shouldCleanUpFailedFolder, underlyingError: error)
            return
        }

        // Step 3: 通知并切换
        onLibraryChanged?()
        selectPet(id: petId)
    }

    // MARK: - 包导入

    /// 导入 .pet 包
    public func importPetPackage(at url: URL) {
        let definition: PetDefinition
        do {
            definition = try packageImporter.importPackage(from: url, to: store.importedPetsDirectoryURL, builtInPetId: store.builtInPetId)
        } catch let error as PetLibraryError {
            reportPackageImportFailure(error, sourceURL: url)
            return
        } catch {
            reportPackageImportFailure(.invalidPackage, sourceURL: url, underlyingError: error)
            return
        }

        onLibraryChanged?()
        selectPet(id: definition.id)
    }

    /// 导入 Petdex 压缩包
    public func importPetdexPackage(at url: URL) {
        let definition: PetDefinition
        do {
            definition = try importPetdexPackageDefinition(at: url)
        } catch let error as PetdexImportError {
            reportPetdexImportFailure(error, sourceURL: url)
            return
        } catch {
            reportPetdexImportFailure(.invalidArchive, sourceURL: url, underlyingError: error)
            return
        }

        publishImportedPet(definition)
    }

    // MARK: - Petdex URL 导入（异步）

    /// 从 Petdex URL 异步下载并导入
    public func importPetdexURL(_ input: String) {
        petdexURLImportTask?.cancel()

        let importID = UUID()
        petdexURLImportID = importID
        onPetdexURLImportPhaseChanged?(.downloading)

        petdexURLImportTask = Task { [weak self] in
            await self?.importPetdexURLInBackground(input, importID: importID)
        }
    }

    /// 取消正在进行的 Petdex URL 导入
    public func cancelPetdexURLImport() {
        guard petdexURLImportTask != nil else { return }

        petdexURLImportID = nil
        petdexURLImportTask?.cancel()
        petdexURLImportTask = nil
        onPetdexURLImportCancelled?()
    }

    /// 后台异步导入流程：解析 URL → 下载 → 导入
    private func importPetdexURLInBackground(_ input: String, importID: UUID) async {
        // 解析 Petdex URL
        let request: PetdexDownloadRequest
        do {
            request = try petdexURLResolver.resolve(input)
        } catch let error as PetdexImportError {
            reportPetdexURLImportFailure(error, sourceURL: URL(fileURLWithPath: input), importID: importID)
            return
        } catch {
            reportPetdexURLImportFailure(.unsupportedPetdexURL(input), sourceURL: URL(fileURLWithPath: input), importID: importID, underlyingError: error)
            return
        }

        guard isActivePetdexURLImport(importID) else { return }

        // 下载
        let archiveURL: URL
        do {
            archiveURL = try await petdexDownloader.download(request)
        } catch PetdexImportError.downloadCancelled {
            reportPetdexURLImportCancelled(importID: importID)
            return
        } catch let error as PetdexImportError {
            reportPetdexURLImportFailure(error, sourceURL: request.sourceURL, importID: importID)
            return
        } catch {
            reportPetdexURLImportFailure(.downloadFailed(error.localizedDescription), sourceURL: request.sourceURL, importID: importID, underlyingError: error)
            return
        }

        // 清理临时下载文件
        defer { cleanUpDownloadedPetdexArchive(at: archiveURL) }

        guard isActivePetdexURLImport(importID) else { return }

        onPetdexURLImportPhaseChanged?(.importing)

        // 导入
        let definition: PetDefinition
        do {
            definition = try importPetdexPackageDefinition(at: archiveURL)
        } catch let error as PetdexImportError {
            reportPetdexURLImportFailure(error, sourceURL: archiveURL, importID: importID)
            return
        } catch {
            reportPetdexURLImportFailure(.invalidArchive, sourceURL: archiveURL, importID: importID, underlyingError: error)
            return
        }

        guard isActivePetdexURLImport(importID) else { return }

        publishImportedPet(definition)
        onPetdexURLImportSucceeded?()
        finishPetdexURLImport(importID: importID)
    }

    // MARK: - 宠物选择与删除

    /// 切换当前宠物
    public func selectPet(id: String) {
        do {
            let definition = try store.loadDefinition(id: id)
            preferences.selectedPetId = definition.id
            onCurrentPetChanged?(definition)
        } catch {
            DesktopPetLog.petLibrary.error("Failed to select pet \(id, privacy: .public): \(error.localizedDescription, privacy: .public)")
            onImportFailed?(.petNotFound)
        }
    }

    /// 删除宠物（若删除的是当前宠物，则切回内置宠物）
    public func deletePet(id: String) {
        let wasCurrent = preferences.selectedPetId == id
        do {
            try store.deleteImportedPet(id: id)
        } catch let error as PetLibraryError {
            DesktopPetLog.petLibrary.error("Failed to delete pet \(id, privacy: .public): \(error.localizedDescription, privacy: .public)")
            onDeleteFailed?(error)
            return
        } catch {
            DesktopPetLog.petLibrary.error("Failed to delete pet \(id, privacy: .public): \(error.localizedDescription, privacy: .public)")
            onDeleteFailed?(.petNotFound)
            return
        }

        onLibraryChanged?()
        if wasCurrent {
            selectPet(id: store.builtInPetId)
        }
    }

    // MARK: - 动作包管理

    /// 保存动作包草稿
    public func saveActionPackDraft(_ draft: ActionPackDraft, forPetId petId: String) {
        let petFolderURL = store.importedPetsDirectoryURL.appendingPathComponent(petId, isDirectory: true)
        do {
            let definition = try store.loadDefinition(id: petId)
            _ = try actionPackWriter.writeDraft(draft, to: petFolderURL, baseFrameSize: definition.frameSize)
            reloadCurrentPet(petId: petId)
        } catch {
            DesktopPetLog.petLibrary.error("Failed to save action pack for pet \(petId, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }

    /// 删除动作包
    public func deleteActionPack(id packId: String, forPetId petId: String) {
        let petFolderURL = store.importedPetsDirectoryURL.appendingPathComponent(petId, isDirectory: true)
        do {
            try actionPackStore.deletePack(id: packId, in: petFolderURL)
            reloadCurrentPet(petId: petId)
        } catch {
            DesktopPetLog.petLibrary.error("Failed to delete action pack \(packId, privacy: .public) for pet \(petId, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }

    /// 禁用动作包
    public func disableActionPack(id packId: String, forPetId petId: String) {
        var overrides = actionPackOverrideStore.load(petId: petId) ?? ActionPackOverrideSet(petId: petId)
        overrides = overrides.disablingPack(packId)
        do {
            try actionPackOverrideStore.save(overrides, petId: petId)
            reloadCurrentPet(petId: petId)
        } catch {
            DesktopPetLog.petLibrary.error("Failed to disable pack \(packId, privacy: .public) for pet \(petId, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }

    /// 禁用单个动作
    public func disableAction(_ actionId: ActionId, forPetId petId: String) {
        var overrides = actionPackOverrideStore.load(petId: petId) ?? ActionPackOverrideSet(petId: petId)
        overrides = overrides.disablingAction(actionId)
        do {
            try actionPackOverrideStore.save(overrides, petId: petId)
            reloadCurrentPet(petId: petId)
        } catch {
            DesktopPetLog.petLibrary.error("Failed to disable action \(actionId.rawValue, privacy: .public) for pet \(petId, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }

    /// 重新加载当前宠物（仅在修改的是当前宠物时）
    private func reloadCurrentPet(petId: String) {
        guard preferences.selectedPetId == petId else { return }
        selectPet(id: petId)
    }

    // MARK: - 错误处理辅助

    private func reportImportFailure(_ error: PetLibraryError, displayName: String, sourceURL: URL, folderURL: URL, shouldCleanUpFolder: Bool, underlyingError: Error? = nil) {
        if let underlyingError {
            DesktopPetLog.petLibrary.error("Import failed for \(displayName, privacy: .public) from \(sourceURL.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public) (\(underlyingError.localizedDescription, privacy: .public))")
        } else {
            DesktopPetLog.petLibrary.error("Import failed for \(displayName, privacy: .public) from \(sourceURL.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
        if shouldCleanUpFolder { cleanUpFailedImportFolder(folderURL) }
        onImportFailed?(error)
    }

    private func cleanUpFailedImportFolder(_ folderURL: URL) {
        guard fileManager.fileExists(atPath: folderURL.path) else { return }
        do {
            try fileManager.removeItem(at: folderURL)
        } catch {
            DesktopPetLog.petLibrary.warning("Failed to remove failed import folder at \(folderURL.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }

    private func reportPackageImportFailure(_ error: PetLibraryError, sourceURL: URL, underlyingError: Error? = nil) {
        if let underlyingError {
            DesktopPetLog.petLibrary.error("Package import failed from \(sourceURL.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public) (\(underlyingError.localizedDescription, privacy: .public))")
        } else {
            DesktopPetLog.petLibrary.error("Package import failed from \(sourceURL.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
        onImportFailed?(error)
    }

    private func reportPetdexImportFailure(_ error: PetdexImportError, sourceURL: URL, underlyingError: Error? = nil) {
        let log = error.failureLog(sourceURL: sourceURL, underlyingErrorDescription: underlyingError?.localizedDescription)
        DesktopPetLog.petdex.error("\(log.message, privacy: .public)")
        onPetdexImportFailed?(error)
    }

    private func importPetdexPackageDefinition(at url: URL) throws -> PetDefinition {
        try petdexPackageImporter.importPackage(at: url, to: store.importedPetsDirectoryURL, builtInPetId: store.builtInPetId)
    }

    private func cleanUpDownloadedPetdexArchive(at archiveURL: URL) {
        let directoryURL = archiveURL.deletingLastPathComponent()
        guard directoryURL.lastPathComponent.hasPrefix(PetdexDownloader.temporaryDownloadDirectoryPrefix) else { return }
        guard fileManager.fileExists(atPath: directoryURL.path) else { return }
        do {
            try fileManager.removeItem(at: directoryURL)
        } catch {
            DesktopPetLog.petdex.warning("Failed to remove temporary Petdex download at \(directoryURL.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }

    /// 发布新导入的宠物：通知图库变更并切换
    private func publishImportedPet(_ definition: PetDefinition) {
        onLibraryChanged?()
        selectPet(id: definition.id)
    }

    private func isActivePetdexURLImport(_ importID: UUID) -> Bool {
        petdexURLImportID == importID
    }

    private func finishPetdexURLImport(importID: UUID) {
        guard isActivePetdexURLImport(importID) else { return }
        petdexURLImportID = nil
        petdexURLImportTask = nil
    }

    private func reportPetdexURLImportFailure(_ error: PetdexImportError, sourceURL: URL, importID: UUID, underlyingError: Error? = nil) {
        guard isActivePetdexURLImport(importID) else { return }
        finishPetdexURLImport(importID: importID)
        let log = error.failureLog(sourceURL: sourceURL, underlyingErrorDescription: underlyingError?.localizedDescription)
        DesktopPetLog.petdex.error("\(log.message, privacy: .public)")
        onPetdexURLImportFailed?(error)
    }

    private func reportPetdexURLImportCancelled(importID: UUID) {
        guard isActivePetdexURLImport(importID) else { return }
        finishPetdexURLImport(importID: importID)
        onPetdexURLImportCancelled?()
    }
}
