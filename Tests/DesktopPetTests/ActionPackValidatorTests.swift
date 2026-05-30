import Foundation
import DesktopPet

func runActionPackValidatorTests() {
    let tests = ActionPackValidatorTests()
    tests.validPackPasses()
    tests.packIdMismatchRejected()
    tests.unsupportedSchemaVersionRejected()
    tests.pathTraversalRejected()
    tests.pathWithSlashRejected()
    tests.pathWithBackslashRejected()
    tests.pathWithDotDotRejected()
    tests.unsupportedImageFormatRejected()
    tests.imageSizeMismatchRejected()
    tests.frameSizeMismatchRejected()
    tests.frameOutOfBoundsRejected()
    tests.emptyFramesRejected()
    tests.invalidFrameDurationRejected()
    tests.duplicateResourceIdRejected()
    tests.actionIdConflictGeneratesWarning()
    tests.missingResourceFileRejected()
    tests.frameWithAssetIdPasses()
    tests.multipleWarningsForMultipleConflicts()
}

// MARK: - Mock Image Metadata Reader

private struct MockImageMetadataReader: ActionPackImageMetadataReading {
    let metadataMap: [String: ActionPackImageMetadata]

    func metadata(for imageURL: URL) throws -> ActionPackImageMetadata {
        let filename = imageURL.lastPathComponent
        guard let metadata = metadataMap[filename] else {
            throw ActionPackError.resourceUnreadable(packId: "", resourceId: "", path: filename)
        }
        return metadata
    }
}

// MARK: - Test Helpers

private let standardFrameSize = CGSizeCodable(width: 256, height: 256)

private func makeResource(
    id: String = "test_sheet",
    path: String = "spritesheet.png",
    columns: Int = 4,
    rows: Int = 1,
    frameSize: CGSizeCodable = standardFrameSize
) -> ActionPackResource {
    ActionPackResource(
        id: id,
        kind: .gridImage,
        path: path,
        frameSize: frameSize,
        grid: SpriteSheetLayout(columns: columns, rows: rows)
    )
}

private func makeManifest(
    id: String = "test_pack",
    resources: [ActionPackResource]? = nil,
    actions: [Action]? = nil
) -> ActionPackManifest {
    let res = resources ?? [makeResource()]
    let acts = actions ?? [
        Action(
            id: ActionId(rawValue: "test_pack_wave")!,
            displayName: "Wave",
            role: nil,
            assetId: "test_sheet",
            frames: [
                SpriteFrame(column: 0, row: 0),
                SpriteFrame(column: 1, row: 0),
                SpriteFrame(column: 2, row: 0),
                SpriteFrame(column: 3, row: 0)
            ],
            frameDurationMs: 120,
            loop: false,
            nextActionId: ActionId(rawValue: "idle_default")
        )
    ]
    return ActionPackManifest(
        schemaVersion: 1,
        id: id,
        displayName: "Test Pack",
        createdAt: Date(),
        resources: res,
        actions: acts
    )
}

// MARK: - Tests

private struct ActionPackValidatorTests {

    func validPackPasses() {
        let tmpDir = createTempPackDir()
        defer { cleanupTempDir(tmpDir) }

        let reader = MockImageMetadataReader(metadataMap: [
            "spritesheet.png": ActionPackImageMetadata(width: 1024, height: 256)
        ])
        let validator = DefaultActionPackValidator(imageMetadataReader: reader)
        let manifest = makeManifest()

        do {
            let result = try validator.validate(
                manifest: manifest,
                packURL: tmpDir,
                directoryName: "test_pack",
                baseFrameSize: standardFrameSize,
                existingActionIds: []
            )
            expect(result.manifest.id == "test_pack", "manifest id should match")
            expect(result.warnings.isEmpty, "valid pack should have no warnings")
        } catch {
            fail("valid pack should pass validation; got \(error)")
        }
    }

    func packIdMismatchRejected() {
        let tmpDir = createTempPackDir()
        defer { cleanupTempDir(tmpDir) }

        let reader = MockImageMetadataReader(metadataMap: [
            "spritesheet.png": ActionPackImageMetadata(width: 1024, height: 256)
        ])
        let validator = DefaultActionPackValidator(imageMetadataReader: reader)
        let manifest = makeManifest(id: "different_id")

        do {
            _ = try validator.validate(
                manifest: manifest,
                packURL: tmpDir,
                directoryName: "test_pack",
                baseFrameSize: standardFrameSize,
                existingActionIds: []
            )
            fail("pack id mismatch should be rejected")
        } catch let error as ActionPackError {
            if case .invalidPackId = error {
                // expected
            } else {
                fail("expected invalidPackId, got \(error)")
            }
        } catch {
            fail("expected ActionPackError, got \(error)")
        }
    }

    func unsupportedSchemaVersionRejected() {
        let tmpDir = createTempPackDir()
        defer { cleanupTempDir(tmpDir) }

        let reader = MockImageMetadataReader(metadataMap: [:])
        let validator = DefaultActionPackValidator(imageMetadataReader: reader)
        let manifest = ActionPackManifest(
            schemaVersion: 99,
            id: "test_pack",
            displayName: "Future",
            createdAt: Date(),
            resources: [makeResource()],
            actions: [makeManifest().actions[0]]
        )

        do {
            _ = try validator.validate(
                manifest: manifest,
                packURL: tmpDir,
                directoryName: "test_pack",
                baseFrameSize: standardFrameSize,
                existingActionIds: []
            )
            fail("unsupported schema version should be rejected")
        } catch let error as ActionPackError {
            if case .unsupportedSchemaVersion(99) = error {
                // expected
            } else {
                fail("expected unsupportedSchemaVersion(99), got \(error)")
            }
        } catch {
            fail("expected ActionPackError, got \(error)")
        }
    }

    func pathTraversalRejected() {
        let tmpDir = createTempPackDir()
        defer { cleanupTempDir(tmpDir) }

        let reader = MockImageMetadataReader(metadataMap: [:])
        let validator = DefaultActionPackValidator(imageMetadataReader: reader)
        let manifest = makeManifest(resources: [makeResource(path: "../secret.png")])

        do {
            _ = try validator.validate(
                manifest: manifest,
                packURL: tmpDir,
                directoryName: "test_pack",
                baseFrameSize: standardFrameSize,
                existingActionIds: []
            )
            fail("path traversal should be rejected")
        } catch let error as ActionPackError {
            if case .invalidResourcePath = error {
                // expected
            } else {
                fail("expected invalidResourcePath, got \(error)")
            }
        } catch {
            fail("expected ActionPackError, got \(error)")
        }
    }

    func pathWithSlashRejected() {
        let tmpDir = createTempPackDir()
        defer { cleanupTempDir(tmpDir) }

        let reader = MockImageMetadataReader(metadataMap: [:])
        let validator = DefaultActionPackValidator(imageMetadataReader: reader)
        let manifest = makeManifest(resources: [makeResource(path: "sub/image.png")])

        do {
            _ = try validator.validate(
                manifest: manifest,
                packURL: tmpDir,
                directoryName: "test_pack",
                baseFrameSize: standardFrameSize,
                existingActionIds: []
            )
            fail("path with slash should be rejected")
        } catch is ActionPackError {
            // expected
        } catch {
            fail("expected ActionPackError, got \(error)")
        }
    }

    func pathWithBackslashRejected() {
        let tmpDir = createTempPackDir()
        defer { cleanupTempDir(tmpDir) }

        let reader = MockImageMetadataReader(metadataMap: [:])
        let validator = DefaultActionPackValidator(imageMetadataReader: reader)
        let manifest = makeManifest(resources: [makeResource(path: "sub\\image.png")])

        do {
            _ = try validator.validate(
                manifest: manifest,
                packURL: tmpDir,
                directoryName: "test_pack",
                baseFrameSize: standardFrameSize,
                existingActionIds: []
            )
            fail("path with backslash should be rejected")
        } catch is ActionPackError {
            // expected
        } catch {
            fail("expected ActionPackError, got \(error)")
        }
    }

    func pathWithDotDotRejected() {
        let tmpDir = createTempPackDir()
        defer { cleanupTempDir(tmpDir) }

        let reader = MockImageMetadataReader(metadataMap: [:])
        let validator = DefaultActionPackValidator(imageMetadataReader: reader)
        let manifest = makeManifest(resources: [makeResource(path: "..hidden.png")])

        do {
            _ = try validator.validate(
                manifest: manifest,
                packURL: tmpDir,
                directoryName: "test_pack",
                baseFrameSize: standardFrameSize,
                existingActionIds: []
            )
            fail("path starting with dot should be rejected")
        } catch is ActionPackError {
            // expected
        } catch {
            fail("expected ActionPackError, got \(error)")
        }
    }

    func unsupportedImageFormatRejected() {
        let tmpDir = createTempPackDir()
        defer { cleanupTempDir(tmpDir) }

        let reader = MockImageMetadataReader(metadataMap: [:])
        let validator = DefaultActionPackValidator(imageMetadataReader: reader)
        let manifest = makeManifest(resources: [makeResource(path: "image.gif")])

        do {
            _ = try validator.validate(
                manifest: manifest,
                packURL: tmpDir,
                directoryName: "test_pack",
                baseFrameSize: standardFrameSize,
                existingActionIds: []
            )
            fail("unsupported format should be rejected")
        } catch let error as ActionPackError {
            if case .unsupportedImageFormat = error {
                // expected
            } else {
                fail("expected unsupportedImageFormat, got \(error)")
            }
        } catch {
            fail("expected ActionPackError, got \(error)")
        }
    }

    func imageSizeMismatchRejected() {
        let tmpDir = createTempPackDir()
        defer { cleanupTempDir(tmpDir) }

        // Expected: 256 * 4 = 1024 wide, 256 * 1 = 256 tall
        // Actual: 800 x 256 (wrong width)
        let reader = MockImageMetadataReader(metadataMap: [
            "spritesheet.png": ActionPackImageMetadata(width: 800, height: 256)
        ])
        let validator = DefaultActionPackValidator(imageMetadataReader: reader)
        let manifest = makeManifest()

        do {
            _ = try validator.validate(
                manifest: manifest,
                packURL: tmpDir,
                directoryName: "test_pack",
                baseFrameSize: standardFrameSize,
                existingActionIds: []
            )
            fail("image size mismatch should be rejected")
        } catch let error as ActionPackError {
            if case .imageSizeMismatch = error {
                // expected
            } else {
                fail("expected imageSizeMismatch, got \(error)")
            }
        } catch {
            fail("expected ActionPackError, got \(error)")
        }
    }

    func frameSizeMismatchRejected() {
        let tmpDir = createTempPackDir()
        defer { cleanupTempDir(tmpDir) }

        // Pack uses 128x128, pet uses 256x256
        let reader = MockImageMetadataReader(metadataMap: [
            "spritesheet.png": ActionPackImageMetadata(width: 512, height: 128)
        ])
        let validator = DefaultActionPackValidator(imageMetadataReader: reader)
        let manifest = makeManifest(
            resources: [makeResource(frameSize: CGSizeCodable(width: 128, height: 128))]
        )

        do {
            _ = try validator.validate(
                manifest: manifest,
                packURL: tmpDir,
                directoryName: "test_pack",
                baseFrameSize: standardFrameSize,
                existingActionIds: []
            )
            fail("frame size mismatch should be rejected")
        } catch let error as ActionPackError {
            if case .frameSizeMismatch = error {
                // expected
            } else {
                fail("expected frameSizeMismatch, got \(error)")
            }
        } catch {
            fail("expected ActionPackError, got \(error)")
        }
    }

    func frameOutOfBoundsRejected() {
        let tmpDir = createTempPackDir()
        defer { cleanupTempDir(tmpDir) }

        let reader = MockImageMetadataReader(metadataMap: [
            "spritesheet.png": ActionPackImageMetadata(width: 1024, height: 256)
        ])
        let validator = DefaultActionPackValidator(imageMetadataReader: reader)
        let manifest = makeManifest(actions: [
            Action(
                id: ActionId(rawValue: "test_pack_bad")!,
                displayName: "Bad",
                role: nil,
                assetId: "test_sheet",
                frames: [SpriteFrame(column: 5, row: 0)], // only 4 columns
                frameDurationMs: 120,
                loop: false
            )
        ])

        do {
            _ = try validator.validate(
                manifest: manifest,
                packURL: tmpDir,
                directoryName: "test_pack",
                baseFrameSize: standardFrameSize,
                existingActionIds: []
            )
            fail("out of bounds frame should be rejected")
        } catch let error as ActionPackError {
            if case .frameOutOfBounds = error {
                // expected
            } else {
                fail("expected frameOutOfBounds, got \(error)")
            }
        } catch {
            fail("expected ActionPackError, got \(error)")
        }
    }

    func emptyFramesRejected() {
        let tmpDir = createTempPackDir()
        defer { cleanupTempDir(tmpDir) }

        let reader = MockImageMetadataReader(metadataMap: [
            "spritesheet.png": ActionPackImageMetadata(width: 1024, height: 256)
        ])
        let validator = DefaultActionPackValidator(imageMetadataReader: reader)
        let manifest = makeManifest(actions: [
            Action(
                id: ActionId(rawValue: "test_pack_empty")!,
                displayName: "Empty",
                role: nil,
                assetId: "test_sheet",
                frames: [],
                frameDurationMs: 120,
                loop: false
            )
        ])

        do {
            _ = try validator.validate(
                manifest: manifest,
                packURL: tmpDir,
                directoryName: "test_pack",
                baseFrameSize: standardFrameSize,
                existingActionIds: []
            )
            fail("empty frames should be rejected")
        } catch let error as ActionPackError {
            if case .emptyActionFrames = error {
                // expected
            } else {
                fail("expected emptyActionFrames, got \(error)")
            }
        } catch {
            fail("expected ActionPackError, got \(error)")
        }
    }

    func invalidFrameDurationRejected() {
        let tmpDir = createTempPackDir()
        defer { cleanupTempDir(tmpDir) }

        let reader = MockImageMetadataReader(metadataMap: [
            "spritesheet.png": ActionPackImageMetadata(width: 1024, height: 256)
        ])
        let validator = DefaultActionPackValidator(imageMetadataReader: reader)
        let manifest = makeManifest(actions: [
            Action(
                id: ActionId(rawValue: "test_pack_baddur")!,
                displayName: "Bad Duration",
                role: nil,
                assetId: "test_sheet",
                frames: [SpriteFrame(column: 0, row: 0)],
                frameDurationMs: 0,
                loop: false
            )
        ])

        do {
            _ = try validator.validate(
                manifest: manifest,
                packURL: tmpDir,
                directoryName: "test_pack",
                baseFrameSize: standardFrameSize,
                existingActionIds: []
            )
            fail("frameDurationMs <= 0 should be rejected")
        } catch let error as ActionPackError {
            if case .invalidFrameDuration = error {
                // expected
            } else {
                fail("expected invalidFrameDuration, got \(error)")
            }
        } catch {
            fail("expected ActionPackError, got \(error)")
        }
    }

    func duplicateResourceIdRejected() {
        let tmpDir = createTempPackDir()
        defer { cleanupTempDir(tmpDir) }

        let reader = MockImageMetadataReader(metadataMap: [
            "spritesheet.png": ActionPackImageMetadata(width: 1024, height: 256)
        ])
        let validator = DefaultActionPackValidator(imageMetadataReader: reader)
        let manifest = makeManifest(resources: [
            makeResource(id: "dup", path: "spritesheet.png"),
            makeResource(id: "dup", path: "spritesheet.png")
        ])

        do {
            _ = try validator.validate(
                manifest: manifest,
                packURL: tmpDir,
                directoryName: "test_pack",
                baseFrameSize: standardFrameSize,
                existingActionIds: []
            )
            fail("duplicate resource id should be rejected")
        } catch let error as ActionPackError {
            if case .duplicateResourceId = error {
                // expected
            } else {
                fail("expected duplicateResourceId, got \(error)")
            }
        } catch {
            fail("expected ActionPackError, got \(error)")
        }
    }

    func actionIdConflictGeneratesWarning() {
        let tmpDir = createTempPackDir()
        defer { cleanupTempDir(tmpDir) }

        let reader = MockImageMetadataReader(metadataMap: [
            "spritesheet.png": ActionPackImageMetadata(width: 1024, height: 256)
        ])
        let validator = DefaultActionPackValidator(imageMetadataReader: reader)
        let manifest = makeManifest()

        let existingIds: Set<ActionId> = [ActionId(rawValue: "test_pack_wave")!]

        do {
            let result = try validator.validate(
                manifest: manifest,
                packURL: tmpDir,
                directoryName: "test_pack",
                baseFrameSize: standardFrameSize,
                existingActionIds: existingIds
            )
            expect(result.warnings.count == 1, "should have 1 warning for action id conflict")
            expect(result.warnings.first?.kind == .actionIdConflict, "warning kind should be actionIdConflict")
            expect(result.warnings.first?.actionId == "test_pack_wave", "warning should reference conflicting action id")
        } catch {
            fail("action id conflict should generate warning, not error; got \(error)")
        }
    }

    func missingResourceFileRejected() {
        let tmpDir = createEmptyTempPackDir()
        defer { cleanupTempDir(tmpDir) }

        let reader = MockImageMetadataReader(metadataMap: [:])
        let validator = DefaultActionPackValidator(imageMetadataReader: reader)
        let manifest = makeManifest()

        do {
            _ = try validator.validate(
                manifest: manifest,
                packURL: tmpDir,
                directoryName: "test_pack",
                baseFrameSize: standardFrameSize,
                existingActionIds: []
            )
            fail("missing resource file should be rejected")
        } catch let error as ActionPackError {
            if case .resourceNotFound = error {
                // expected
            } else {
                fail("expected resourceNotFound, got \(error)")
            }
        } catch {
            fail("expected ActionPackError, got \(error)")
        }
    }

    func frameWithAssetIdPasses() {
        let tmpDir = createTempPackDir()
        defer { cleanupTempDir(tmpDir) }

        let reader = MockImageMetadataReader(metadataMap: [
            "spritesheet.png": ActionPackImageMetadata(width: 1024, height: 256)
        ])
        let validator = DefaultActionPackValidator(imageMetadataReader: reader)
        let manifest = makeManifest(actions: [
            Action(
                id: ActionId(rawValue: "test_pack_mixed")!,
                displayName: "Mixed",
                role: nil,
                frames: [
                    SpriteFrame(assetId: "test_sheet", column: 0, row: 0),
                    SpriteFrame(column: 1, row: 0) // uses action default assetId
                ],
                frameDurationMs: 120,
                loop: false
            )
        ])

        do {
            let result = try validator.validate(
                manifest: manifest,
                packURL: tmpDir,
                directoryName: "test_pack",
                baseFrameSize: standardFrameSize,
                existingActionIds: []
            )
            expect(result.manifest.id == "test_pack", "manifest should be returned")
        } catch {
            fail("frame with mixed assetId should pass; got \(error)")
        }
    }

    func multipleWarningsForMultipleConflicts() {
        let tmpDir = createTempPackDir()
        defer { cleanupTempDir(tmpDir) }

        let reader = MockImageMetadataReader(metadataMap: [
            "spritesheet.png": ActionPackImageMetadata(width: 1024, height: 256)
        ])
        let validator = DefaultActionPackValidator(imageMetadataReader: reader)
        let manifest = makeManifest(actions: [
            Action(
                id: ActionId(rawValue: "test_pack_wave")!,
                displayName: "Wave",
                role: nil,
                assetId: "test_sheet",
                frames: [SpriteFrame(column: 0, row: 0)],
                frameDurationMs: 120,
                loop: false
            ),
            Action(
                id: ActionId(rawValue: "test_pack_sit")!,
                displayName: "Sit",
                role: nil,
                assetId: "test_sheet",
                frames: [SpriteFrame(column: 1, row: 0)],
                frameDurationMs: 200,
                loop: true
            )
        ])

        let existingIds: Set<ActionId> = [
            ActionId(rawValue: "test_pack_wave")!,
            ActionId(rawValue: "test_pack_sit")!
        ]

        do {
            let result = try validator.validate(
                manifest: manifest,
                packURL: tmpDir,
                directoryName: "test_pack",
                baseFrameSize: standardFrameSize,
                existingActionIds: existingIds
            )
            expect(result.warnings.count == 2, "should have 2 warnings for 2 conflicts")
        } catch {
            fail("multiple conflicts should generate multiple warnings; got \(error)")
        }
    }
}

// MARK: - Temp Directory Helpers

private func createTempPackDir() -> URL {
    let tmpDir = FileManager.default.temporaryDirectory
        .appendingPathComponent("action-pack-test-\(UUID().uuidString)")
    try! FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)

    // Create a dummy spritesheet.png file so fileExists checks pass
    let dummyFile = tmpDir.appendingPathComponent("spritesheet.png")
    // Write minimal PNG data
    let pngData = Data([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A
    ])
    try! pngData.write(to: dummyFile)

    return tmpDir
}

private func createEmptyTempPackDir() -> URL {
    let tmpDir = FileManager.default.temporaryDirectory
        .appendingPathComponent("action-pack-test-\(UUID().uuidString)")
    try! FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
    return tmpDir
}

private func cleanupTempDir(_ url: URL) {
    try? FileManager.default.removeItem(at: url)
}
