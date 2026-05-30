import Foundation
import DesktopPet

func runPetdexManifestParserTests() {
    let tests = PetdexManifestParserTests()
    tests.currentPetdexManifestCanDecode()
    tests.parserParsesCurrentPetdexManifest()
    tests.unknownManifestFieldsDoNotFailDecode()
    tests.parserAllowsUnknownManifestFields()
    tests.missingRequiredManifestFieldFailsDecode()
    tests.parserReportsMissingId()
    tests.parserReportsEmptyId()
    tests.parserFallsBackToIdForMissingDisplayName()
    tests.parserFallsBackToIdForEmptyDisplayName()
    tests.parserAllowsEmptyDescription()
    tests.parserReportsMissingDescription()
    tests.parserReportsEmptySpritesheetPath()
    tests.parserRejectsUnsafeSpritesheetPath()
    tests.parserReportsMalformedJSON()
    tests.petdexSourceMetadataDecodesSidecarFormat()
    tests.petdexErrorsExposeReadableDescriptions()
}

private struct PetdexManifestParserTests {
    func currentPetdexManifestCanDecode() {
        let manifest: PetdexManifest
        do {
            manifest = try JSONDecoder().decode(PetdexManifest.self, from: validManifestData)
        } catch {
            fail("expected Petdex manifest to decode: \(error)")
        }

        expect(manifest.id == "my-cat-v3-large", "manifest id should decode")
        expect(manifest.displayName == "Beibei", "manifest displayName should decode")
        expect(manifest.description == "A Petdex cat package.", "manifest description should decode")
        expect(manifest.spritesheetPath == "spritesheet.webp", "manifest spritesheetPath should decode")
    }

    func parserParsesCurrentPetdexManifest() {
        let manifest: PetdexManifest
        do {
            manifest = try PetdexManifestParser().parse(validManifestData)
        } catch {
            fail("expected parser to parse current Petdex manifest: \(error)")
        }

        expect(manifest.id == "my-cat-v3-large", "parser should preserve id")
        expect(manifest.displayName == "Beibei", "parser should preserve displayName")
        expect(manifest.description == "A Petdex cat package.", "parser should preserve description")
        expect(manifest.spritesheetPath == "spritesheet.webp", "parser should preserve spritesheetPath")
    }

    func unknownManifestFieldsDoNotFailDecode() {
        let json = """
        {
          "id": "my-cat-v3-large",
          "displayName": "Beibei",
          "description": "A Petdex cat package.",
          "spritesheetPath": "spritesheet.webp",
          "author": "petdex",
          "animations": { "idle": [] }
        }
        """

        do {
            let manifest = try JSONDecoder().decode(PetdexManifest.self, from: Data(json.utf8))
            expect(manifest.id == "my-cat-v3-large", "unknown fields should be ignored")
        } catch {
            fail("unknown Petdex manifest fields should not fail decoding: \(error)")
        }
    }

    func parserAllowsUnknownManifestFields() {
        let json = """
        {
          "id": "my-cat-v3-large",
          "displayName": "Beibei",
          "description": "A Petdex cat package.",
          "spritesheetPath": "spritesheet.webp",
          "petdexVersion": 3,
          "homepage": "https://petdex.example/pets/my-cat-v3-large"
        }
        """

        do {
            let manifest = try PetdexManifestParser().parse(Data(json.utf8))
            expect(manifest.id == "my-cat-v3-large", "parser should ignore unknown fields")
        } catch {
            fail("parser should allow unknown Petdex manifest fields: \(error)")
        }
    }

    func missingRequiredManifestFieldFailsDecode() {
        let json = """
        {
          "id": "my-cat-v3-large",
          "displayName": "Beibei",
          "description": "A Petdex cat package."
        }
        """

        do {
            _ = try JSONDecoder().decode(PetdexManifest.self, from: Data(json.utf8))
            fail("missing spritesheetPath should fail decoding")
        } catch DecodingError.keyNotFound(let key, _) {
            expect(key.stringValue == "spritesheetPath", "missing field error should name spritesheetPath")
        } catch {
            fail("missing required field should be reported as keyNotFound, got \(error)")
        }
    }

    func parserReportsMissingId() {
        let json = """
        {
          "displayName": "Beibei",
          "description": "A Petdex cat package.",
          "spritesheetPath": "spritesheet.webp"
        }
        """

        expectPetdexError(.missingManifestField("id")) {
            _ = try PetdexManifestParser().parse(Data(json.utf8))
        }
    }

    func parserReportsEmptyId() {
        let json = """
        {
          "id": "   ",
          "displayName": "Beibei",
          "description": "A Petdex cat package.",
          "spritesheetPath": "spritesheet.webp"
        }
        """

        expectPetdexError(.invalidManifestField(field: "id", reason: "must not be empty")) {
            _ = try PetdexManifestParser().parse(Data(json.utf8))
        }
    }

    func parserFallsBackToIdForMissingDisplayName() {
        let json = """
        {
          "id": "my-cat-v3-large",
          "description": "A Petdex cat package.",
          "spritesheetPath": "spritesheet.webp"
        }
        """

        do {
            let manifest = try PetdexManifestParser().parse(Data(json.utf8))
            expect(manifest.displayName == "my-cat-v3-large", "missing displayName should fallback to id")
        } catch {
            fail("missing displayName should not fail parsing: \(error)")
        }
    }

    func parserFallsBackToIdForEmptyDisplayName() {
        let json = """
        {
          "id": "my-cat-v3-large",
          "displayName": " ",
          "description": "A Petdex cat package.",
          "spritesheetPath": "spritesheet.webp"
        }
        """

        do {
            let manifest = try PetdexManifestParser().parse(Data(json.utf8))
            expect(manifest.displayName == "my-cat-v3-large", "empty displayName should fallback to id")
        } catch {
            fail("empty displayName should not fail parsing: \(error)")
        }
    }

    func parserAllowsEmptyDescription() {
        let json = """
        {
          "id": "my-cat-v3-large",
          "displayName": "Beibei",
          "description": "",
          "spritesheetPath": "spritesheet.webp"
        }
        """

        do {
            let manifest = try PetdexManifestParser().parse(Data(json.utf8))
            expect(manifest.description == "", "empty description should be preserved")
        } catch {
            fail("empty description should not fail parsing: \(error)")
        }
    }

    func parserReportsMissingDescription() {
        let json = """
        {
          "id": "my-cat-v3-large",
          "displayName": "Beibei",
          "spritesheetPath": "spritesheet.webp"
        }
        """

        expectPetdexError(.missingManifestField("description")) {
            _ = try PetdexManifestParser().parse(Data(json.utf8))
        }
    }

    func parserReportsEmptySpritesheetPath() {
        let json = """
        {
          "id": "my-cat-v3-large",
          "displayName": "Beibei",
          "description": "A Petdex cat package.",
          "spritesheetPath": " "
        }
        """

        expectPetdexError(.invalidManifestField(field: "spritesheetPath", reason: "must not be empty")) {
            _ = try PetdexManifestParser().parse(Data(json.utf8))
        }
    }

    func parserRejectsUnsafeSpritesheetPath() {
        let unsafePaths = [
            "assets/spritesheet.webp",
            #"assets\spritesheet.webp"#,
            ".",
            ".."
        ]

        for path in unsafePaths {
            let escapedPath = path.replacingOccurrences(of: "\\", with: "\\\\")
            let json = """
            {
              "id": "my-cat-v3-large",
              "displayName": "Beibei",
              "description": "A Petdex cat package.",
              "spritesheetPath": "\(escapedPath)"
            }
            """

            expectPetdexError(.unsafeSpritesheetPath(path)) {
                _ = try PetdexManifestParser().parse(Data(json.utf8))
            }
        }
    }

    func parserReportsMalformedJSON() {
        expectPetdexError(.manifestDecodingFailed) {
            _ = try PetdexManifestParser().parse(Data("{ not valid json".utf8))
        }
    }

    func petdexSourceMetadataDecodesSidecarFormat() {
        let json = """
        {
          "source": "petdex",
          "petdexId": "my-cat-v3-large",
          "originalDisplayName": "Beibei",
          "importedAt": "2026-05-12T00:00:00Z"
        }
        """

        let metadata: PetdexSourceMetadata
        do {
            metadata = try JSONDecoder().decode(PetdexSourceMetadata.self, from: Data(json.utf8))
        } catch {
            fail("Petdex sidecar metadata should decode: \(error)")
        }

        expect(metadata.source == .petdex, "sidecar source should decode as petdex")
        expect(metadata.petdexId == "my-cat-v3-large", "sidecar petdex id should decode")
        expect(metadata.originalDisplayName == "Beibei", "sidecar original display name should decode")

        do {
            let encoded = try JSONEncoder().encode(metadata)
            let encodedString = String(data: encoded, encoding: .utf8) ?? ""
            expect(encodedString.contains("\"source\":\"petdex\""), "sidecar source should encode as petdex")
            expect(encodedString.contains("\"importedAt\":\"2026-05-12T00:00:00Z\""), "sidecar date should encode as ISO-8601")
        } catch {
            fail("Petdex sidecar metadata should encode: \(error)")
        }
    }

    func petdexErrorsExposeReadableDescriptions() {
        let errors: [PetdexImportError] = [
            .missingManifest,
            .missingSpritesheet("spritesheet.webp"),
            .unreadableImage("spritesheet.webp"),
            .invalidSpritesheetLayout("expected 8 x 9"),
            .writeFailed("/tmp/Pets/my-cat-v3-large"),
            .downloadFailed("timed out")
        ]

        for error in errors {
            expect(
                error.errorDescription?.isEmpty == false,
                "Petdex error should expose a readable description: \(error)"
            )
        }
    }

    private var validManifestData: Data {
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
