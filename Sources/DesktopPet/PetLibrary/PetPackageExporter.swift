import Foundation

public struct PetPackageExportResult: Equatable, Sendable {
    public let exportURL: URL
    public let totalBytes: Int64
    public let packCount: Int
}

public protocol PetPackageExporting {
    func exportPet(
        id: String,
        from importedPetsDirectoryURL: URL,
        to destinationURL: URL
    ) throws -> PetPackageExportResult
}

public final class PetPackageExporter: PetPackageExporting {
    public static let maximumSingleImageBytes: Int64 = 10 * 1024 * 1024 // 10MB
    public static let maximumTotalPackBytes: Int64 = 50 * 1024 * 1024   // 50MB

    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func exportPet(
        id: String,
        from importedPetsDirectoryURL: URL,
        to destinationURL: URL
    ) throws -> PetPackageExportResult {
        let sourceFolder = importedPetsDirectoryURL.appendingPathComponent(id, isDirectory: true)
        guard fileManager.fileExists(atPath: sourceFolder.path) else {
            throw PetLibraryError.petNotFound
        }

        let manifestURL = sourceFolder.appendingPathComponent("manifest.json")
        guard fileManager.fileExists(atPath: manifestURL.path) else {
            throw PetLibraryError.missingManifest
        }

        let exportFolder = destinationURL.appendingPathComponent("\(id).pet", isDirectory: true)

        if fileManager.fileExists(atPath: exportFolder.path) {
            try fileManager.removeItem(at: exportFolder)
        }

        try fileManager.createDirectory(at: exportFolder, withIntermediateDirectories: true)

        do {
            try copyDirectoryContents(from: sourceFolder, to: exportFolder, excluding: [".tmp-*"])
        } catch {
            try? fileManager.removeItem(at: exportFolder)
            throw error
        }

        let packsDir = exportFolder.appendingPathComponent("action-packs")
        var totalBytes: Int64 = 0
        var packCount = 0

        if fileManager.fileExists(atPath: packsDir.path) {
            let result = try validateAndMeasurePacks(in: packsDir)
            totalBytes = result.totalBytes
            packCount = result.packCount
        }

        return PetPackageExportResult(
            exportURL: exportFolder,
            totalBytes: totalBytes,
            packCount: packCount
        )
    }

    private func copyDirectoryContents(from source: URL, to destination: URL, excluding patterns: [String]) throws {
        let contents = try fileManager.contentsOfDirectory(
            at: source,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )

        for item in contents {
            let name = item.lastPathComponent
            if shouldExclude(name, patterns: patterns) { continue }

            let destItem = destination.appendingPathComponent(name)
            try fileManager.copyItem(at: item, to: destItem)
        }
    }

    private func shouldExclude(_ name: String, patterns: [String]) -> Bool {
        for pattern in patterns {
            if pattern.hasPrefix("."), name.hasPrefix(".") { return true }
            if pattern.contains("*") {
                let prefix = pattern.replacingOccurrences(of: "*", with: "")
                if name.hasPrefix(prefix) { return true }
            }
        }
        return false
    }

    private func validateAndMeasurePacks(in packsDir: URL) throws -> (totalBytes: Int64, packCount: Int) {
        let packDirs = try fileManager.contentsOfDirectory(
            at: packsDir,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ).filter { url in
            (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
        }

        var totalBytes: Int64 = 0
        var packCount = 0

        for packDir in packDirs {
            let packBytes = try measureDirectory(packDir)
            if packBytes > Self.maximumTotalPackBytes {
                throw PetLibraryError.invalidPackage
            }
            totalBytes += packBytes
            packCount += 1

            try validateImageSizes(in: packDir)
        }

        if totalBytes > Self.maximumTotalPackBytes {
            throw PetLibraryError.invalidPackage
        }

        return (totalBytes, packCount)
    }

    private func measureDirectory(_ url: URL) throws -> Int64 {
        let contents = try fileManager.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        )
        var total: Int64 = 0
        for file in contents {
            let size = try file.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            total += Int64(size)
        }
        return total
    }

    private func validateImageSizes(in packDir: URL) throws {
        let imageExtensions: Set<String> = ["png", "jpg", "jpeg"]
        let contents = try fileManager.contentsOfDirectory(
            at: packDir,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        )

        for file in contents {
            let ext = file.pathExtension.lowercased()
            guard imageExtensions.contains(ext) else { continue }
            let size = try file.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            if Int64(size) > Self.maximumSingleImageBytes {
                throw PetLibraryError.invalidPackage
            }
        }
    }
}
