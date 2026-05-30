import Foundation
import DesktopPet

func runPetdexArchiveReaderTests() {
    let tests = PetdexArchiveReaderTests()
    tests.validZipReadsManifestAndSpritesheet()
    tests.deflatedZipReadsManifestAndSpritesheet()
    tests.manifestWebPFallsBackToPNGWithSameBaseName()
    tests.missingManifestFails()
    tests.missingSpritesheetFails()
    tests.unsafeEntryPathFails()
    tests.directoryEntryAsResourceFails()
    tests.oversizedEntryFails()
    tests.extraFilesAreIgnored()
}

private struct PetdexArchiveReaderTests {
    func validZipReadsManifestAndSpritesheet() {
        let fixture = ZipFixture()
        defer { fixture.cleanUp() }

        let manifest = validManifest()
        let spritesheet = Data("WEBP-DATA".utf8)
        let url = fixture.writeZip(entries: [
            .stored(name: "pet.json", data: manifest),
            .stored(name: "spritesheet.webp", data: spritesheet)
        ])

        do {
            let archive = try PetdexArchiveReader().readPackage(at: url)
            expect(archive.manifestData == manifest, "archive reader should return pet.json data")
            expect(archive.spritesheetData == spritesheet, "archive reader should return spritesheet data")
            expect(archive.spritesheetFileName == "spritesheet.webp", "archive reader should preserve spritesheet file name")
        } catch {
            fail("valid Petdex zip should read successfully: \(error)")
        }
    }

    func deflatedZipReadsManifestAndSpritesheet() {
        let fixture = ZipFixture()
        defer { fixture.cleanUp() }

        let manifest = Data(#"{"id":"cat","displayName":"Cat","description":"","spritesheetPath":"spritesheet.webp"}"#.utf8)
        let spritesheet = Data("WEBP-DATA".utf8)
        let url = fixture.writeZip(entries: [
            .deflated(
                name: "pet.json",
                uncompressedData: manifest,
                rawDeflateHex: "ab56ca4c51b2524a4e2c51d2514ac92c2ec849acf44bcc4d058a3943c4528b938b320b4a32f3f380624081e282a2cc92d4e28cd4d49280c4920ca02092885e796a5281522d00"
            ),
            .deflated(
                name: "spritesheet.webp",
                uncompressedData: spritesheet,
                rawDeflateHex: "0b77750ad075710c710400"
            )
        ])

        do {
            let archive = try PetdexArchiveReader().readPackage(at: url)
            expect(archive.manifestData == manifest, "deflated manifest should decompress")
            expect(archive.spritesheetData == spritesheet, "deflated spritesheet should decompress")
        } catch {
            fail("deflated Petdex zip should read successfully: \(error)")
        }
    }

    func manifestWebPFallsBackToPNGWithSameBaseName() {
        let fixture = ZipFixture()
        defer { fixture.cleanUp() }

        let manifest = Data(#"{"id":"omegamon","displayName":"Omegamon","description":"","spritesheetPath":"spritesheet.webp"}"#.utf8)
        let spritesheet = Data("PNG-DATA".utf8)
        let url = fixture.writeZip(entries: [
            .stored(name: "pet.json", data: manifest),
            .stored(name: "spritesheet.png", data: spritesheet)
        ])

        do {
            let archive = try PetdexArchiveReader().readPackage(at: url)
            expect(archive.manifestData == manifest, "archive reader should preserve manifest data when using PNG fallback")
            expect(archive.spritesheetData == spritesheet, "archive reader should use same-basename PNG fallback when manifest references WebP")
            expect(archive.spritesheetFileName == "spritesheet.png", "archive reader should report the resolved spritesheet file name")
        } catch {
            fail("Petdex zip with same-basename PNG fallback should read successfully: \(error)")
        }
    }

    func missingManifestFails() {
        let fixture = ZipFixture()
        defer { fixture.cleanUp() }

        let url = fixture.writeZip(entries: [
            .stored(name: "spritesheet.webp", data: Data("WEBP-DATA".utf8))
        ])

        expectPetdexError(.missingManifest) {
            _ = try PetdexArchiveReader().readPackage(at: url)
        }
    }

    func missingSpritesheetFails() {
        let fixture = ZipFixture()
        defer { fixture.cleanUp() }

        let url = fixture.writeZip(entries: [
            .stored(name: "pet.json", data: validManifest())
        ])

        expectPetdexError(.missingSpritesheet("spritesheet.webp")) {
            _ = try PetdexArchiveReader().readPackage(at: url)
        }
    }

    func unsafeEntryPathFails() {
        let fixture = ZipFixture()
        defer { fixture.cleanUp() }

        let url = fixture.writeZip(entries: [
            .stored(name: "pet.json", data: validManifest()),
            .stored(name: "spritesheet.webp", data: Data("WEBP-DATA".utf8)),
            .stored(name: "../script.sh", data: Data("#!/bin/sh\n".utf8))
        ])

        expectPetdexError(.unsafeArchiveEntry("../script.sh")) {
            _ = try PetdexArchiveReader().readPackage(at: url)
        }
    }

    func directoryEntryAsResourceFails() {
        let fixture = ZipFixture()
        defer { fixture.cleanUp() }

        let url = fixture.writeZip(entries: [
            .stored(name: "pet.json", data: validManifest()),
            .stored(name: "spritesheet.webp/", data: Data())
        ])

        expectPetdexError(.directoryEntryUsedAsResource("spritesheet.webp")) {
            _ = try PetdexArchiveReader().readPackage(at: url)
        }
    }

    func oversizedEntryFails() {
        let fixture = ZipFixture()
        defer { fixture.cleanUp() }

        let url = fixture.writeZip(entries: [
            .stored(name: "pet.json", data: validManifest()),
            .stored(name: "spritesheet.webp", data: Data("WEBP-DATA".utf8))
        ])

        expectPetdexError(.entryTooLarge(name: "pet.json", maximumBytes: 8)) {
            _ = try PetdexArchiveReader(maximumEntryBytes: 8).readPackage(at: url)
        }
    }

    func extraFilesAreIgnored() {
        let fixture = ZipFixture()
        defer { fixture.cleanUp() }

        let manifest = validManifest()
        let spritesheet = Data("WEBP-DATA".utf8)
        let url = fixture.writeZip(entries: [
            .stored(name: "pet.json", data: manifest),
            .stored(name: "spritesheet.webp", data: spritesheet),
            .stored(name: "script.sh", data: Data("#!/bin/sh\necho should-not-run\n".utf8)),
            .stored(name: "notes.txt", data: Data("ignored".utf8))
        ])

        do {
            let archive = try PetdexArchiveReader().readPackage(at: url)
            expect(archive.manifestData == manifest, "extra files should not affect manifest data")
            expect(archive.spritesheetData == spritesheet, "extra files should not affect spritesheet data")
        } catch {
            fail("safe extra files should be ignored: \(error)")
        }
    }

    private func validManifest() -> Data {
        Data(
            """
            {
              "id": "my-cat-v3-large",
              "displayName": "Beibei",
              "description": "A Petdex cat package.",
              "spritesheetPath": "spritesheet.webp"
            }
            """.utf8
        )
    }

    private func expectPetdexError(
        _ expected: PetdexImportError,
        operation: () throws -> Void
    ) {
        do {
            try operation()
            fail("expected Petdex error \(expected)")
        } catch let error as PetdexImportError {
            expect(error == expected, "expected \(expected), got \(error)")
        } catch {
            fail("expected PetdexImportError \(expected), got \(error)")
        }
    }
}

private struct ZipFixture {
    private let root: URL

    init() {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("DesktopPetZipTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    func cleanUp() {
        try? FileManager.default.removeItem(at: root)
    }

    func writeZip(entries: [ZipTestEntry]) -> URL {
        let url = root.appendingPathComponent("petdex.zip")
        do {
            try makeZipData(entries: entries).write(to: url)
        } catch {
            fail("failed to write zip fixture: \(error)")
        }
        return url
    }

    private func makeZipData(entries: [ZipTestEntry]) -> Data {
        var localData = Data()
        var centralDirectory = Data()

        for entry in entries {
            let localHeaderOffset = localData.count
            let nameData = Data(entry.name.utf8)

            localData.appendUInt32(0x0403_4B50)
            localData.appendUInt16(20)
            localData.appendUInt16(0)
            localData.appendUInt16(entry.compressionMethod)
            localData.appendUInt16(0)
            localData.appendUInt16(0)
            localData.appendUInt32(0)
            localData.appendUInt32(UInt32(entry.compressedData.count))
            localData.appendUInt32(UInt32(entry.uncompressedData.count))
            localData.appendUInt16(UInt16(nameData.count))
            localData.appendUInt16(0)
            localData.append(nameData)
            localData.append(entry.compressedData)

            centralDirectory.appendUInt32(0x0201_4B50)
            centralDirectory.appendUInt16(20)
            centralDirectory.appendUInt16(20)
            centralDirectory.appendUInt16(0)
            centralDirectory.appendUInt16(entry.compressionMethod)
            centralDirectory.appendUInt16(0)
            centralDirectory.appendUInt16(0)
            centralDirectory.appendUInt32(0)
            centralDirectory.appendUInt32(UInt32(entry.compressedData.count))
            centralDirectory.appendUInt32(UInt32(entry.uncompressedData.count))
            centralDirectory.appendUInt16(UInt16(nameData.count))
            centralDirectory.appendUInt16(0)
            centralDirectory.appendUInt16(0)
            centralDirectory.appendUInt16(0)
            centralDirectory.appendUInt16(0)
            centralDirectory.appendUInt32(0)
            centralDirectory.appendUInt32(UInt32(localHeaderOffset))
            centralDirectory.append(nameData)
        }

        let centralDirectoryOffset = localData.count
        localData.append(centralDirectory)
        localData.appendUInt32(0x0605_4B50)
        localData.appendUInt16(0)
        localData.appendUInt16(0)
        localData.appendUInt16(UInt16(entries.count))
        localData.appendUInt16(UInt16(entries.count))
        localData.appendUInt32(UInt32(centralDirectory.count))
        localData.appendUInt32(UInt32(centralDirectoryOffset))
        localData.appendUInt16(0)

        return localData
    }
}

private struct ZipTestEntry {
    let name: String
    let compressionMethod: UInt16
    let compressedData: Data
    let uncompressedData: Data

    static func stored(name: String, data: Data) -> ZipTestEntry {
        ZipTestEntry(
            name: name,
            compressionMethod: 0,
            compressedData: data,
            uncompressedData: data
        )
    }

    static func deflated(
        name: String,
        uncompressedData: Data,
        rawDeflateHex: String
    ) -> ZipTestEntry {
        ZipTestEntry(
            name: name,
            compressionMethod: 8,
            compressedData: Data(hexString: rawDeflateHex),
            uncompressedData: uncompressedData
        )
    }
}

private extension Data {
    init(hexString: String) {
        self.init()
        var index = hexString.startIndex
        while index < hexString.endIndex {
            let nextIndex = hexString.index(index, offsetBy: 2)
            guard let byte = UInt8(hexString[index..<nextIndex], radix: 16) else {
                fail("invalid hex byte in \(hexString)")
            }
            append(byte)
            index = nextIndex
        }
    }

    mutating func appendUInt16(_ value: UInt16) {
        append(UInt8(value & 0x00FF))
        append(UInt8((value >> 8) & 0x00FF))
    }

    mutating func appendUInt32(_ value: UInt32) {
        append(UInt8(value & 0x0000_00FF))
        append(UInt8((value >> 8) & 0x0000_00FF))
        append(UInt8((value >> 16) & 0x0000_00FF))
        append(UInt8((value >> 24) & 0x0000_00FF))
    }
}
