import AppKit
import Foundation
import DesktopPet

@MainActor
func runGenerationDiagnosticsStoreTests() async throws {
    let tests = GenerationDiagnosticsStoreTests()
    try tests.recordLifecyclePersistsLoadablePrivateJSON()
    try tests.imageInfoCapturesReferenceAndOutputMetadata()
    try tests.recentRecordsAndCleanupWorkAcrossPets()
    try await tests.mediatorFinalizesDiagnosticsAfterSuccessfulGeneration()
}

@MainActor
private struct GenerationDiagnosticsStoreTests {
    private let fm = FileManager.default

    private func makeTempDir() -> URL {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("generation-diagnostics-tests-\(UUID().uuidString)", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func cleanup(_ dir: URL) {
        try? fm.removeItem(at: dir)
    }

    private func makePNG(
        at url: URL,
        width: Int = 4,
        height: Int = 4,
        fill: NSColor = NSColor(deviceRed: 1, green: 0.42, blue: 0.7, alpha: 1),
        transparentPixels: Set<String> = []
    ) throws {
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: width,
            pixelsHigh: height,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )!

        for y in 0..<height {
            for x in 0..<width {
                let key = "\(x),\(y)"
                let color = transparentPixels.contains(key)
                    ? NSColor(deviceRed: 0, green: 0, blue: 0, alpha: 0)
                    : fill
                rep.setColor(color, atX: x, y: y)
            }
        }

        guard let data = rep.representation(using: .png, properties: [:]) else {
            throw PetVisualAssetError.conversionFailed
        }
        try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url)
    }

    private func makeReferenceImage() -> NSImage {
        let size = NSSize(width: 8, height: 8)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor(deviceRed: 1, green: 0.42, blue: 0.7, alpha: 1)
            .drawSwatch(in: NSRect(origin: .zero, size: size))
        image.unlockFocus()
        return image
    }

    func recordLifecyclePersistsLoadablePrivateJSON() throws {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let store = GenerationDiagnosticsStore(baseDirectory: dir)

        var record = store.beginRecord(requestId: "request-1", petId: "pet-a")
        store.recordPrompt(&record, finalPrompt: "keep the same pink white 2D sprite")
        store.recordProviderParams(&record, params: ProviderParamsSnapshot(
            providerId: "mock",
            model: nil,
            subjectRefIncluded: true,
            widthRequested: nil,
            heightRequested: nil,
            seed: nil,
            cliVersion: nil,
            cliArgvSummary: nil
        ))
        store.recordUserAction(&record, action: .applied)

        let jsonURL = try store.finalize(record)

        expect(jsonURL.lastPathComponent == "request-1.json", "diagnostics file should use requestId")
        expect(jsonURL.path.contains("pet-a/visual-actions/diagnostics"), "diagnostics should live under pet visual-actions")

        let loaded = try store.loadRecord(requestId: "request-1")
        expect(loaded.requestId == "request-1", "loaded requestId should match")
        expect(loaded.petId == "pet-a", "loaded petId should match")
        expect(loaded.finalPrompt == "keep the same pink white 2D sprite", "prompt should persist")
        expect(loaded.promptDigest != nil, "prompt digest should be recorded")
        expect(loaded.providerParams?.providerId == "mock", "provider params should persist")
        expect(loaded.userAction == .applied, "user action should persist")

        let json = try String(contentsOf: jsonURL, encoding: .utf8)
        expect(!json.contains(dir.path), "diagnostics JSON should not expose the local base directory")
    }

    func imageInfoCapturesReferenceAndOutputMetadata() throws {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let store = GenerationDiagnosticsStore(baseDirectory: dir)

        let referenceURL = dir
            .appendingPathComponent("pet-a")
            .appendingPathComponent("visual-actions")
            .appendingPathComponent("ref")
            .appendingPathComponent("reference.png")
        try makePNG(
            at: referenceURL,
            width: 6,
            height: 4,
            fill: NSColor(deviceRed: 1, green: 0.42, blue: 0.7, alpha: 1)
        )

        let outputURL = dir
            .appendingPathComponent("pet-a")
            .appendingPathComponent("visual-actions")
            .appendingPathComponent("pending")
            .appendingPathComponent("request-2")
            .appendingPathComponent("request-2.png")
        try makePNG(
            at: outputURL,
            width: 4,
            height: 4,
            fill: NSColor(deviceRed: 1, green: 1, blue: 1, alpha: 1),
            transparentPixels: ["0,0", "1,0", "0,1", "1,1"]
        )

        let referenceInfo = try store.referenceImageInfo(for: referenceURL, petId: "pet-a")
        expect(referenceInfo.path == "visual-actions/ref/reference.png", "reference path should be relative")
        expect(referenceInfo.exists == true, "reference should exist")
        expect(referenceInfo.width == 6, "reference width should be captured")
        expect(referenceInfo.height == 4, "reference height should be captured")
        expect(referenceInfo.hasAlpha == true, "reference alpha should be captured")
        expect(referenceInfo.fileSizeBytes > 0, "reference file size should be captured")
        expect(!referenceInfo.digest.isEmpty, "reference digest should be captured")

        let outputInfo = try store.outputImageInfo(for: outputURL)
        expect(outputInfo.width == 4, "output width should be captured")
        expect(outputInfo.height == 4, "output height should be captured")
        expect(outputInfo.hasAlpha == true, "output alpha should be captured")
        expect(outputInfo.fileSizeBytes > 0, "output file size should be captured")
        expect(outputInfo.visibleAreaRatio == 0.75, "visible area ratio should ignore transparent pixels")
        expect(outputInfo.dominantColors.contains("#FFFFFF"), "dominant colors should include white")
        expect(outputInfo.backgroundColor == "#FFFFFF", "background color should be detected from visible edges")
    }

    func recentRecordsAndCleanupWorkAcrossPets() throws {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let store = GenerationDiagnosticsStore(baseDirectory: dir)

        var older = store.beginRecord(requestId: "old", petId: "pet-a")
        older.createdAt = Date().addingTimeInterval(-40 * 24 * 60 * 60)
        _ = try store.finalize(older)

        var newer = store.beginRecord(requestId: "new", petId: "pet-b")
        newer.createdAt = Date()
        _ = try store.finalize(newer)

        let recent = store.recentRecords(limit: 2)
        expect(recent.map(\.requestId) == ["new", "old"], "recent records should be newest first across pets")

        try store.cleanup(olderThan: 30)
        let remaining = try store.loadRecord(requestId: "new")
        expect(remaining.requestId == "new", "new record should remain after cleanup")
        do {
            _ = try store.loadRecord(requestId: "old")
            fail("old record should be removed by cleanup")
        } catch GenerationDiagnosticsError.recordNotFound {
            // expected
        } catch {
            fail("unexpected cleanup error: \(error)")
        }
    }

    func mediatorFinalizesDiagnosticsAfterSuccessfulGeneration() async throws {
        let dir = makeTempDir()
        defer { cleanup(dir) }

        let defaultsName = "GenerationDiagnosticsMediatorTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: defaultsName) ?? .standard
        defaults.removePersistentDomain(forName: defaultsName)

        let preferencesStore = AIVisualPreferencesStore(userDefaults: defaults)
        preferencesStore.savePreferences(AIVisualPreferences(isEnabled: true, durationPreset: .short))
        let quotaStore = AIVisualQuotaStore(userDefaults: defaults)
        let coordinator = AIVisualActionCoordinator(
            policy: AIVisualActionPolicy(),
            confirmationController: AIVisualConfirmationController(hasPreviousConfirmation: true),
            quotaStore: quotaStore
        )
        let generationService = RecordingGenerationService()
        let diagnosticsStore = GenerationDiagnosticsStore(baseDirectory: dir)

        let mediator = AIVisualActionMediator(
            coordinator: coordinator,
            generationService: generationService,
            assetStore: PetVisualAssetStore(baseDirectory: dir),
            stateController: PetVisualStateController(),
            safetyService: AIVisualSafetyService(),
            quotaStore: quotaStore,
            preferencesStore: preferencesStore,
            visualPreferenceStore: PetVisualPreferenceStore(userDefaults: defaults),
            generationDiagnosticsRecorder: diagnosticsStore,
            referenceImageProvider: PetReferenceImageProvider(baseDirectory: dir),
            getReferenceImage: { makeReferenceImage() },
            hasActiveOverlayProvider: { false }
        )

        var changedDescription: String?
        mediator.onVisualChanged = { changedDescription = $0 }

        mediator.requestManualGeneration(petId: "pet-a", petName: "Mimi")
        try await waitUntil {
            changedDescription != nil
        }

        let records = diagnosticsStore.recentRecords(limit: 1)
        guard let record = records.first else {
            fail("mediator should finalize a diagnostics record")
        }

        expect(record.petId == "pet-a", "diagnostics record should use current pet")
        expect(record.finalPrompt?.contains("gentle ambient variation") == true || record.finalPrompt?.contains("ambient") == true, "record should include final prompt")
        expect(record.providerParams?.providerId == "recording-provider", "record should include provider id")
        expect(record.providerParams?.subjectRefIncluded == true, "record should capture subject reference inclusion")
        expect(record.referenceImage?.path == "visual-actions/ref/reference.png", "record should include private reference path")
        expect(record.outputImage?.width == 4, "record should include output width")
        expect(record.outputImage?.dominantColors.contains("#FF0000") == true, "record should include output dominant colors")
        expect(record.generationDurationSeconds != nil, "record should include duration")
        expect(record.errorMessage == nil, "successful generation should not record an error")
    }

    private func waitUntil(
        timeout: TimeInterval = 1,
        condition: @escaping () -> Bool
    ) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() && Date() < deadline {
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        expect(condition(), "timed out waiting for async condition")
    }
}

private final class RecordingGenerationService: VisualGenerationServicing, @unchecked Sendable {
    func generate(_ request: VisualGenerationRequest) async throws -> VisualGenerationResult {
        let outputURL = request.outputDirectory.appendingPathComponent("\(request.outputPrefix).png")
        try makeRedPNG(at: outputURL)
        return VisualGenerationResult(
            actionId: request.actionId,
            imageURL: outputURL,
            providerId: "recording-provider"
        )
    }

    func quotaSnapshot() async throws -> VisualProviderQuotaSnapshot? {
        nil
    }

    func currentProviderId() -> String? {
        "recording-provider"
    }

    func availableProviders() -> [ProviderInfo] {
        []
    }

    func selectProvider(_ providerId: String) -> Bool {
        providerId == "recording-provider"
    }

    func currentCapabilities() -> VisualGenerationCapabilities? {
        .full
    }

    private func makeRedPNG(at url: URL) throws {
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: 4,
            pixelsHigh: 4,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )!
        for y in 0..<4 {
            for x in 0..<4 {
                rep.setColor(NSColor(deviceRed: 1, green: 0, blue: 0, alpha: 1), atX: x, y: y)
            }
        }
        guard let data = rep.representation(using: .png, properties: [:]) else {
            throw PetVisualAssetError.conversionFailed
        }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url)
    }
}
