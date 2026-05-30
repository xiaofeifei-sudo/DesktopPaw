import Compression
import Foundation

public protocol PetdexArchiveReading {
    func readPackage(at archiveURL: URL) throws -> PetdexArchive
}

public struct PetdexArchive: Equatable, Sendable {
    public let manifestData: Data
    public let spritesheetData: Data
    public let spritesheetFileName: String

    public init(
        manifestData: Data,
        spritesheetData: Data,
        spritesheetFileName: String
    ) {
        self.manifestData = manifestData
        self.spritesheetData = spritesheetData
        self.spritesheetFileName = spritesheetFileName
    }
}

public final class PetdexArchiveReader: PetdexArchiveReading {
    public static let defaultMaximumArchiveBytes = 50 * 1024 * 1024
    public static let defaultMaximumEntryBytes = 20 * 1024 * 1024

    private let fileManager: FileManager
    private let maximumArchiveBytes: Int
    private let maximumEntryBytes: Int
    private let decoder: JSONDecoder

    public init(
        fileManager: FileManager = .default,
        maximumArchiveBytes: Int = PetdexArchiveReader.defaultMaximumArchiveBytes,
        maximumEntryBytes: Int = PetdexArchiveReader.defaultMaximumEntryBytes,
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.fileManager = fileManager
        self.maximumArchiveBytes = maximumArchiveBytes
        self.maximumEntryBytes = maximumEntryBytes
        self.decoder = decoder
    }

    public func readPackage(at archiveURL: URL) throws -> PetdexArchive {
        guard archiveURL.pathExtension.lowercased() == "zip" else {
            throw PetdexImportError.notZipFile
        }

        if let size = try? fileManager.attributesOfItem(atPath: archiveURL.path)[.size] as? NSNumber,
           size.intValue > maximumArchiveBytes {
            throw PetdexImportError.archiveTooLarge(maximumBytes: maximumArchiveBytes)
        }

        let data: Data
        do {
            data = try Data(contentsOf: archiveURL, options: [.mappedIfSafe])
        } catch {
            throw PetdexImportError.invalidArchive
        }

        guard data.count <= maximumArchiveBytes else {
            throw PetdexImportError.archiveTooLarge(maximumBytes: maximumArchiveBytes)
        }

        let zip = try ZipArchive(data: data, maximumEntryBytes: maximumEntryBytes)
        let manifestData = try zip.extractResource(named: "pet.json")
        let spritesheetFileName = try spritesheetPath(in: manifestData)
        try Self.validateTopLevelResourceFileName(spritesheetFileName)
        let resolvedSpriteSheet = try zip.extractSpritesheet(named: spritesheetFileName)

        return PetdexArchive(
            manifestData: manifestData,
            spritesheetData: resolvedSpriteSheet.data,
            spritesheetFileName: resolvedSpriteSheet.fileName
        )
    }

    private func spritesheetPath(in manifestData: Data) throws -> String {
        do {
            return try decoder.decode(PetdexArchiveManifestReference.self, from: manifestData).spritesheetPath
        } catch DecodingError.keyNotFound {
            throw PetdexImportError.missingManifestField("spritesheetPath")
        } catch {
            throw PetdexImportError.manifestDecodingFailed
        }
    }

    private static func validateTopLevelResourceFileName(_ name: String) throws {
        guard !name.isEmpty else {
            throw PetdexImportError.unsafeSpritesheetPath(name)
        }

        if name == "." || name == ".." ||
            name.contains("/") ||
            name.contains("\\") {
            throw PetdexImportError.unsafeSpritesheetPath(name)
        }
    }
}

private struct PetdexArchiveManifestReference: Decodable {
    let spritesheetPath: String
}

private struct ZipArchive {
    private static let compatibleSpritesheetExtensions = ["webp", "png"]

    private let data: Data
    private let entriesByName: [String: ZipEntry]

    init(data: Data, maximumEntryBytes: Int) throws {
        self.data = data
        let centralDirectory = try ZipArchive.centralDirectory(in: data)
        var entries: [String: ZipEntry] = [:]
        var offset = centralDirectory.offset

        for _ in 0..<centralDirectory.entryCount {
            let entry = try ZipEntry(data: data, offset: offset)
            try ZipArchive.validateEntry(entry, maximumEntryBytes: maximumEntryBytes)
            entries[entry.name] = entry
            offset = try entry.nextOffset()
        }

        self.entriesByName = entries
    }

    func extractResource(named name: String) throws -> Data {
        if let directoryEntry = entriesByName[name + "/"], directoryEntry.isDirectory {
            throw PetdexImportError.directoryEntryUsedAsResource(name)
        }

        guard let entry = entriesByName[name] else {
            if name == "pet.json" {
                throw PetdexImportError.missingManifest
            }
            throw PetdexImportError.missingSpritesheet(name)
        }

        guard !entry.isDirectory else {
            throw PetdexImportError.directoryEntryUsedAsResource(name)
        }

        return try entry.extract(from: data)
    }

    func extractSpritesheet(named preferredName: String) throws -> (data: Data, fileName: String) {
        do {
            return (try extractResource(named: preferredName), preferredName)
        } catch PetdexImportError.missingSpritesheet {
            guard let fallbackName = fallbackSpritesheetName(for: preferredName) else {
                throw PetdexImportError.missingSpritesheet(preferredName)
            }
            return (try extractResource(named: fallbackName), fallbackName)
        }
    }

    private func fallbackSpritesheetName(for preferredName: String) -> String? {
        let preferredURL = URL(fileURLWithPath: preferredName)
        let preferredExtension = preferredURL.pathExtension.lowercased()
        guard Self.compatibleSpritesheetExtensions.contains(preferredExtension) else {
            return nil
        }

        let baseName = preferredURL.deletingPathExtension().lastPathComponent
        guard !baseName.isEmpty else {
            return nil
        }

        return Self.compatibleSpritesheetExtensions
            .filter { $0 != preferredExtension }
            .map { "\(baseName).\($0)" }
            .first { candidate in
                guard let entry = entriesByName[candidate] else {
                    return false
                }
                return !entry.isDirectory
            }
    }

    private static func validateEntry(
        _ entry: ZipEntry,
        maximumEntryBytes: Int
    ) throws {
        try validateArchiveEntryName(entry.name)

        guard entry.uncompressedSize <= maximumEntryBytes,
              entry.compressedSize <= maximumEntryBytes else {
            throw PetdexImportError.entryTooLarge(
                name: entry.name,
                maximumBytes: maximumEntryBytes
            )
        }
    }

    private static func validateArchiveEntryName(_ name: String) throws {
        guard !name.isEmpty,
              !name.hasPrefix("/"),
              !name.hasPrefix("\\"),
              !name.contains("\\"),
              !name.contains(":") else {
            throw PetdexImportError.unsafeArchiveEntry(name)
        }

        let components = name.split(separator: "/", omittingEmptySubsequences: false)
        for component in components {
            if component == ".." {
                throw PetdexImportError.unsafeArchiveEntry(name)
            }
        }
    }

    private static func centralDirectory(in data: Data) throws -> ZipCentralDirectory {
        guard data.count >= ZipEndOfCentralDirectory.minimumLength else {
            throw PetdexImportError.invalidArchive
        }

        let minimumOffset = max(0, data.count - ZipEndOfCentralDirectory.maximumSearchLength)
        var offset = data.count - ZipEndOfCentralDirectory.minimumLength
        while offset >= minimumOffset {
            if try data.littleEndianUInt32(at: offset) == ZipEndOfCentralDirectory.signature {
                return try ZipEndOfCentralDirectory(data: data, offset: offset).centralDirectory
            }
            offset -= 1
        }

        throw PetdexImportError.invalidArchive
    }
}

private struct ZipCentralDirectory {
    let offset: Int
    let entryCount: Int
}

private struct ZipEndOfCentralDirectory {
    static let signature: UInt32 = 0x0605_4B50
    static let minimumLength = 22
    static let maximumSearchLength = minimumLength + 65_535

    let centralDirectory: ZipCentralDirectory

    init(data: Data, offset: Int) throws {
        let diskNumber = try data.littleEndianUInt16(at: offset + 4)
        let centralDirectoryDisk = try data.littleEndianUInt16(at: offset + 6)
        let diskEntries = try data.littleEndianUInt16(at: offset + 8)
        let totalEntries = try data.littleEndianUInt16(at: offset + 10)
        let centralDirectoryOffset = try data.littleEndianUInt32(at: offset + 16)

        guard diskNumber == 0,
              centralDirectoryDisk == 0,
              diskEntries == totalEntries,
              centralDirectoryOffset != UInt32.max else {
            throw PetdexImportError.invalidArchive
        }

        self.centralDirectory = ZipCentralDirectory(
            offset: Int(centralDirectoryOffset),
            entryCount: Int(totalEntries)
        )
    }
}

private struct ZipEntry {
    private static let centralDirectorySignature: UInt32 = 0x0201_4B50
    private static let localFileHeaderSignature: UInt32 = 0x0403_4B50
    private static let centralDirectoryHeaderLength = 46
    private static let localFileHeaderLength = 30

    let name: String
    let compressionMethod: UInt16
    let generalPurposeFlags: UInt16
    let compressedSize: Int
    let uncompressedSize: Int
    let centralDirectoryOffset: Int
    let localHeaderOffset: Int
    let fileNameLength: Int
    let extraFieldLength: Int
    let commentLength: Int

    var isDirectory: Bool {
        name.hasSuffix("/")
    }

    init(data: Data, offset: Int) throws {
        guard try data.littleEndianUInt32(at: offset) == Self.centralDirectorySignature else {
            throw PetdexImportError.invalidArchive
        }

        let flags = try data.littleEndianUInt16(at: offset + 8)
        let method = try data.littleEndianUInt16(at: offset + 10)
        let compressedSize = try data.littleEndianUInt32(at: offset + 20)
        let uncompressedSize = try data.littleEndianUInt32(at: offset + 24)
        let fileNameLength = Int(try data.littleEndianUInt16(at: offset + 28))
        let extraFieldLength = Int(try data.littleEndianUInt16(at: offset + 30))
        let commentLength = Int(try data.littleEndianUInt16(at: offset + 32))
        let localHeaderOffset = try data.littleEndianUInt32(at: offset + 42)

        guard compressedSize != UInt32.max,
              uncompressedSize != UInt32.max,
              localHeaderOffset != UInt32.max else {
            throw PetdexImportError.invalidArchive
        }

        guard flags & 0x0001 == 0 else {
            throw PetdexImportError.invalidArchive
        }

        guard method == 0 || method == 8 else {
            throw PetdexImportError.invalidArchive
        }

        let nameData = try data.subdataChecked(
            in: (offset + Self.centralDirectoryHeaderLength)..<(offset + Self.centralDirectoryHeaderLength + fileNameLength)
        )

        guard let name = String(data: nameData, encoding: .utf8) else {
            throw PetdexImportError.invalidArchive
        }

        self.name = name
        self.compressionMethod = method
        self.generalPurposeFlags = flags
        self.compressedSize = Int(compressedSize)
        self.uncompressedSize = Int(uncompressedSize)
        self.centralDirectoryOffset = offset
        self.localHeaderOffset = Int(localHeaderOffset)
        self.fileNameLength = fileNameLength
        self.extraFieldLength = extraFieldLength
        self.commentLength = commentLength
    }

    func nextOffset() throws -> Int {
        try Int.addingChecked(
            centralDirectoryOffset,
            Self.centralDirectoryHeaderLength,
            fileNameLength,
            extraFieldLength,
            commentLength
        )
    }

    func extract(from data: Data) throws -> Data {
        guard try data.littleEndianUInt32(at: localHeaderOffset) == Self.localFileHeaderSignature else {
            throw PetdexImportError.invalidArchive
        }

        let localFileNameLength = Int(try data.littleEndianUInt16(at: localHeaderOffset + 26))
        let localExtraFieldLength = Int(try data.littleEndianUInt16(at: localHeaderOffset + 28))
        let dataOffset = try Int.addingChecked(
            localHeaderOffset,
            Self.localFileHeaderLength,
            localFileNameLength,
            localExtraFieldLength
        )
        let dataEndOffset = try Int.addingChecked(dataOffset, compressedSize)
        let compressedData = try data.subdataChecked(in: dataOffset..<dataEndOffset)

        switch compressionMethod {
        case 0:
            guard compressedData.count == uncompressedSize else {
                throw PetdexImportError.invalidArchive
            }
            return compressedData
        case 8:
            return try compressedData.inflated(expectedSize: uncompressedSize)
        default:
            throw PetdexImportError.invalidArchive
        }
    }
}

private extension Data {
    func littleEndianUInt16(at offset: Int) throws -> UInt16 {
        guard offset >= 0, offset + 2 <= count else {
            throw PetdexImportError.invalidArchive
        }

        return UInt16(self[offset]) |
            UInt16(self[offset + 1]) << 8
    }

    func littleEndianUInt32(at offset: Int) throws -> UInt32 {
        guard offset >= 0, offset + 4 <= count else {
            throw PetdexImportError.invalidArchive
        }

        return UInt32(self[offset]) |
            UInt32(self[offset + 1]) << 8 |
            UInt32(self[offset + 2]) << 16 |
            UInt32(self[offset + 3]) << 24
    }

    func subdataChecked(in range: Range<Int>) throws -> Data {
        guard range.lowerBound >= 0,
              range.upperBound >= range.lowerBound,
              range.upperBound <= count else {
            throw PetdexImportError.invalidArchive
        }

        return subdata(in: range)
    }

    func inflated(expectedSize: Int) throws -> Data {
        guard expectedSize >= 0 else {
            throw PetdexImportError.invalidArchive
        }
        guard expectedSize > 0 else {
            return Data()
        }

        var output = Data(count: expectedSize)
        let decodedCount = output.withUnsafeMutableBytes { outputBuffer in
            withUnsafeBytes { inputBuffer in
                compression_decode_buffer(
                    outputBuffer.bindMemory(to: UInt8.self).baseAddress!,
                    expectedSize,
                    inputBuffer.bindMemory(to: UInt8.self).baseAddress!,
                    count,
                    nil,
                    COMPRESSION_ZLIB
                )
            }
        }

        guard decodedCount == expectedSize else {
            throw PetdexImportError.invalidArchive
        }

        return output
    }
}

private extension Int {
    static func addingChecked(_ values: Int...) throws -> Int {
        var result = 0
        for value in values {
            guard value >= 0,
                  result <= Int.max - value else {
                throw PetdexImportError.invalidArchive
            }
            result += value
        }
        return result
    }
}
