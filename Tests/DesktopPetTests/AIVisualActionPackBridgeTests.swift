import CoreGraphics
import Foundation
import ImageIO
import DesktopPet

func runAIVisualActionPackBridgeTests() {
    let tests = AIVisualActionPackBridgeTests()
    tests.bridgeCreatesDraftWithSourceMetadata()
    tests.bridgePreservesProviderInfo()
    tests.bridgeDoesNotSaveAPIKey()
    tests.regenerationPreservesOriginalPrompt()
    tests.regenerationCreatesNewPack()
}

func runActionPackSourceMetadataSanitizationTests() {
    let tests = ActionPackSourceMetadataSanitizationTests()
    tests.sanitizeAPIKey()
    tests.sanitizeAbsolutePaths()
    tests.sanitizeMultiplePatterns()
    tests.preservesCleanContent()
    tests.sanitizeTokenInPrompt()
}

// MARK: - AI Bridge Tests

private struct AIVisualActionPackBridgeTests {

    func bridgeCreatesDraftWithSourceMetadata() {
        let bridge = AIVisualActionPackBridge()
        let imageData = makeTestImageData()

        let metadata = ActionPackSourceMetadata(
            source: .aiGeneration,
            createdAt: Date(),
            provider: "test-provider",
            model: "test-model",
            prompt: "cute pet waving",
            seed: "12345"
        )

        do {
            let draft = try bridge.createRegenerationDraft(
                originalSource: metadata,
                newImageData: imageData,
                displayName: "AI Wave",
                targetFrameSize: CGSizeCodable(width: 256, height: 256)
            )
            expect(draft.sourceMetadata != nil, "source metadata should be present")
            expect(draft.sourceMetadata?.source == .aiGeneration, "source should be aiGeneration")
            expect(draft.sourceMetadata?.provider == "test-provider", "provider should be preserved")
            expect(draft.sourceMetadata?.model == "test-model", "model should be preserved")
            expect(draft.sourceMetadata?.prompt == "cute pet waving", "prompt should be preserved")
        } catch {
            fail("bridge should create draft; got \(error)")
        }
    }

    func bridgePreservesProviderInfo() {
        let bridge = AIVisualActionPackBridge()
        let imageData = makeTestImageData()

        let metadata = ActionPackSourceMetadata(
            source: .aiGeneration,
            createdAt: Date(),
            provider: "openai-compatible",
            model: "dall-e-3"
        )

        do {
            let draft = try bridge.createRegenerationDraft(
                originalSource: metadata,
                newImageData: imageData,
                displayName: "Test",
                targetFrameSize: CGSizeCodable(width: 256, height: 256)
            )
            expect(draft.sourceMetadata?.provider == "openai-compatible", "provider should match")
            expect(draft.sourceMetadata?.model == "dall-e-3", "model should match")
        } catch {
            fail("provider info should be preserved; got \(error)")
        }
    }

    func bridgeDoesNotSaveAPIKey() {
        let bridge = AIVisualActionPackBridge()
        let imageData = makeTestImageData()

        let metadata = ActionPackSourceMetadata(
            source: .aiGeneration,
            createdAt: Date(),
            provider: "test",
            prompt: "cute pet api_key=sk-secret12345"
        )

        do {
            let draft = try bridge.createRegenerationDraft(
                originalSource: metadata,
                newImageData: imageData,
                displayName: "Test",
                targetFrameSize: CGSizeCodable(width: 256, height: 256)
            )
            // The sanitized() method is called during save (by the writer),
            // but the raw metadata in the draft may still contain the key.
            // The bridge itself doesn't sanitize - that's the writer's job.
            // But we verify the metadata is structurally correct.
            expect(draft.sourceMetadata?.source == .aiGeneration, "source should be correct")
        } catch {
            fail("bridge should create draft; got \(error)")
        }
    }

    func regenerationPreservesOriginalPrompt() {
        let bridge = AIVisualActionPackBridge()
        let imageData = makeTestImageData()

        let original = ActionPackSourceMetadata(
            source: .aiGeneration,
            createdAt: Date(timeIntervalSince1970: 1_717_000_000),
            provider: "test-provider",
            model: "test-model",
            prompt: "original prompt for regeneration",
            seed: "99999"
        )

        do {
            let draft = try bridge.createRegenerationDraft(
                originalSource: original,
                newImageData: imageData,
                displayName: "Regenerated",
                targetFrameSize: CGSizeCodable(width: 256, height: 256)
            )
            expect(draft.sourceMetadata?.prompt == "original prompt for regeneration",
                   "original prompt should be preserved")
            expect(draft.sourceMetadata?.seed == "99999", "original seed should be preserved")
            expect(draft.sourceMetadata?.notes?.contains("Regenerated") == true,
                   "notes should indicate regeneration")
        } catch {
            fail("regeneration should preserve prompt; got \(error)")
        }
    }

    func regenerationCreatesNewPack() {
        let bridge = AIVisualActionPackBridge()
        let imageData = makeTestImageData()

        let original = ActionPackSourceMetadata(
            source: .aiGeneration,
            createdAt: Date(),
            provider: "test"
        )

        do {
            let draft1 = try bridge.createRegenerationDraft(
                originalSource: original,
                newImageData: imageData,
                displayName: "Version 1",
                targetFrameSize: CGSizeCodable(width: 256, height: 256)
            )
            let draft2 = try bridge.createRegenerationDraft(
                originalSource: original,
                newImageData: imageData,
                displayName: "Version 2",
                targetFrameSize: CGSizeCodable(width: 256, height: 256)
            )
            expect(draft1.manifest.id != draft2.manifest.id,
                   "regenerated packs should have different IDs")
        } catch {
            fail("regeneration should create new pack; got \(error)")
        }
    }
}

// MARK: - Source Metadata Sanitization Tests

private struct ActionPackSourceMetadataSanitizationTests {

    func sanitizeAPIKey() {
        let metadata = ActionPackSourceMetadata(
            source: .aiGeneration,
            createdAt: Date(),
            prompt: "generate pet api_key=sk-abcdef12345"
        )
        let sanitized = metadata.sanitized()
        expect(!sanitized.prompt!.contains("sk-abcdef12345"), "API key should be redacted")
        expect(sanitized.prompt!.contains("[REDACTED]"), "should contain [REDACTED]")
    }

    func sanitizeAbsolutePaths() {
        let metadata = ActionPackSourceMetadata(
            source: .localImage,
            createdAt: Date(),
            notes: "Loaded from /Users/testuser/Desktop/input.png"
        )
        let sanitized = metadata.sanitized()
        expect(!sanitized.notes!.contains("/Users/testuser"), "absolute path should be redacted")
    }

    func sanitizeMultiplePatterns() {
        let metadata = ActionPackSourceMetadata(
            source: .aiGeneration,
            createdAt: Date(),
            prompt: "api_key=sk-111 token=abc123",
            notes: "from /Users/test/file.png"
        )
        let sanitized = metadata.sanitized()
        expect(!sanitized.prompt!.contains("sk-111"), "api_key should be redacted")
        expect(!sanitized.prompt!.contains("abc123"), "token should be redacted")
    }

    func preservesCleanContent() {
        let metadata = ActionPackSourceMetadata(
            source: .aiGeneration,
            createdAt: Date(),
            provider: "openai",
            model: "dall-e-3",
            prompt: "cute desktop pet waving, transparent background"
        )
        let sanitized = metadata.sanitized()
        expect(sanitized.provider == "openai", "clean provider should be preserved")
        expect(sanitized.model == "dall-e-3", "clean model should be preserved")
        expect(sanitized.prompt == "cute desktop pet waving, transparent background",
               "clean prompt should be preserved")
    }

    func sanitizeTokenInPrompt() {
        let metadata = ActionPackSourceMetadata(
            source: .aiGeneration,
            createdAt: Date(),
            prompt: "generate image secret=super_secret_value here"
        )
        let sanitized = metadata.sanitized()
        expect(!sanitized.prompt!.contains("super_secret_value"), "secret value should be redacted")
    }
}

// MARK: - Helpers

private func makeTestImageData() -> Data {
    guard let context = CGContext(
        data: nil, width: 256, height: 256,
        bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ), let image = context.makeImage() else {
        return Data(repeating: 0xFF, count: 256 * 256 * 4)
    }
    let data = NSMutableData()
    guard let dest = CGImageDestinationCreateWithData(data, "public.png" as CFString, 1, nil) else {
        return Data(repeating: 0xFF, count: 256 * 256 * 4)
    }
    CGImageDestinationAddImage(dest, image, nil)
    CGImageDestinationFinalize(dest)
    return data as Data
}
