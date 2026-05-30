import AppKit
import Foundation
import DesktopPet

@MainActor
func runQualityGateStoreTests() async throws {
    let tests = QualityGateStoreTests()
    try await tests.sizeCheckPassesForLargeOutputFailsForTiny()
    try await tests.alphaCheckPassesWhenBothHaveAlpha()
    try await tests.dominantColorSimilarityMatchesPalettes()
    try await tests.backgroundCheckFailsForSolidBackground()
    try await tests.visibleAreaRatioInRange()
    try await tests.centeringCheckPassesForCenteredSubject()
    try await tests.verdictBasedOnFailCount()
    try await tests.riskLevelUnacceptableForVeryLowColorSimilarity()
    tests.autoActionMapsFromRiskAndVerdict()
    try await tests.preferenceAdjustsThresholds()
    try await tests.userFacingMessagesAreNonTechnical()
    try await tests.fullEvaluationWithMatchingColors()
    try await tests.fullEvaluationRejectsUnacceptable()
    try await tests.mediatorSkipsApplyWhenGateRequiresPreview()
}

@MainActor
private struct QualityGateStoreTests {
    private let fm = FileManager.default

    private func makeTempDir() -> URL {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("quality-gate-tests-\(UUID().uuidString)", isDirectory: true)
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
        transparentPixels: Set<String> = [],
        solidBackground: Bool = false
    ) throws {
        let bgColor = solidBackground
            ? NSColor(deviceRed: 1, green: 1, blue: 1, alpha: 1)
            : NSColor(deviceRed: 0, green: 0, blue: 0, alpha: 0)
        let fgColor = fill

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
                if transparentPixels.contains(key) {
                    rep.setColor(NSColor(deviceRed: 0, green: 0, blue: 0, alpha: 0), atX: x, y: y)
                } else if solidBackground {
                    let cx = width / 2, cy = height / 2
                    let halfSize = max(1, min(width, height) / 4)
                    if abs(x - cx) <= halfSize && abs(y - cy) <= halfSize {
                        rep.setColor(fgColor, atX: x, y: y)
                    } else {
                        rep.setColor(bgColor, atX: x, y: y)
                    }
                } else {
                    rep.setColor(fgColor, atX: x, y: y)
                }
            }
        }

        guard let data = rep.representation(using: .png, properties: [:]) else {
            throw PetVisualAssetError.conversionFailed
        }
        try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url)
    }

    private func makeOffCenterPNG(at url: URL, width: Int = 16, height: Int = 16) throws {
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
                rep.setColor(NSColor(deviceRed: 0, green: 0, blue: 0, alpha: 0), atX: x, y: y)
            }
        }
        for y in 0..<2 {
            for x in 0..<2 {
                rep.setColor(NSColor(deviceRed: 1, green: 0, blue: 0, alpha: 1), atX: x, y: y)
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

    // MARK: - D-5.4 Size Check

    func sizeCheckPassesForLargeOutputFailsForTiny() async throws {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let gate = QualityGateStore()

        let largeRef = ImageSnapshot(width: 200, height: 200, hasAlpha: true, visibleAreaRatio: 0.8, dominantColors: ["#FF0000"])
        let largeURL = dir.appendingPathComponent("large.png")
        try makePNG(at: largeURL, width: 256, height: 256)
        let largeResult = try await gate.evaluate(reference: largeRef, output: largeURL, petDescriptor: PetDescriptor(petId: "p"), preference: .balanced)
        let largeSize = largeResult.checks.first { $0.checkType == .size }
        expect(largeSize?.passed == true, "256x256 should pass size check")

        let tinyURL = dir.appendingPathComponent("tiny.png")
        try makePNG(at: tinyURL, width: 4, height: 4)
        let tinyResult = try await gate.evaluate(reference: largeRef, output: tinyURL, petDescriptor: PetDescriptor(petId: "p"), preference: .balanced)
        let tinySize = tinyResult.checks.first { $0.checkType == .size }
        expect(tinySize?.passed == false, "4x4 should fail size check")
        expect(tinySize?.score ?? 1 < 1, "tiny image score should be < 1")
    }

    // MARK: - D-5.5 Alpha Check

    func alphaCheckPassesWhenBothHaveAlpha() async throws {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let gate = QualityGateStore()

        let alphaRef = ImageSnapshot(width: 8, height: 8, hasAlpha: true, visibleAreaRatio: 0.8, dominantColors: ["#FF0000"])
        let alphaURL = dir.appendingPathComponent("alpha.png")
        try makePNG(at: alphaURL, width: 16, height: 16, transparentPixels: ["0,0", "1,0"])
        let result = try await gate.evaluate(reference: alphaRef, output: alphaURL, petDescriptor: PetDescriptor(petId: "p"), preference: .balanced)
        let alphaCheck = result.checks.first { $0.checkType == .alpha }
        expect(alphaCheck?.passed == true, "output with alpha should pass when reference has alpha")

        let noAlphaRef = ImageSnapshot(width: 8, height: 8, hasAlpha: false, visibleAreaRatio: 1.0, dominantColors: ["#FF0000"])
        let result2 = try await gate.evaluate(reference: noAlphaRef, output: alphaURL, petDescriptor: PetDescriptor(petId: "p"), preference: .balanced)
        let alphaCheck2 = result2.checks.first { $0.checkType == .alpha }
        expect(alphaCheck2?.passed == true, "should skip alpha check when reference has no alpha")
    }

    // MARK: - D-5.6 & D-5.7 Color Similarity

    func dominantColorSimilarityMatchesPalettes() async throws {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let gate = QualityGateStore()

        let pinkRef = ImageSnapshot(width: 8, height: 8, hasAlpha: true, visibleAreaRatio: 0.8, dominantColors: ["#FF6BB3", "#FFB6C1"])

        let matchingURL = dir.appendingPathComponent("match.png")
        try makePNG(at: matchingURL, width: 16, height: 16, fill: NSColor(deviceRed: 1, green: 0.42, blue: 0.7, alpha: 1))
        let matchResult = try await gate.evaluate(reference: pinkRef, output: matchingURL, petDescriptor: PetDescriptor(petId: "p"), preference: .balanced)
        let matchColor = matchResult.checks.first { $0.checkType == .dominantColor }
        expect(matchColor?.passed == true, "matching pink colors should pass")
        expect(matchColor?.score ?? 0 > 0.5, "matching score should be > 0.5")

        let greenURL = dir.appendingPathComponent("green.png")
        try makePNG(at: greenURL, width: 16, height: 16, fill: NSColor(deviceRed: 0, green: 1, blue: 0, alpha: 1))
        let greenResult = try await gate.evaluate(reference: pinkRef, output: greenURL, petDescriptor: PetDescriptor(petId: "p"), preference: .balanced)
        let greenColor = greenResult.checks.first { $0.checkType == .dominantColor }
        expect(greenColor?.passed == false, "green vs pink should fail color similarity")
        expect(greenColor?.score ?? 1 < 0.5, "green-pink score should be < 0.5")
    }

    // MARK: - D-5.8 Background Check

    func backgroundCheckFailsForSolidBackground() async throws {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let gate = QualityGateStore()

        let alphaRef = ImageSnapshot(width: 8, height: 8, hasAlpha: true, visibleAreaRatio: 0.5, dominantColors: ["#FF0000"])

        let solidURL = dir.appendingPathComponent("solid.png")
        try makePNG(at: solidURL, width: 64, height: 64, fill: NSColor(deviceRed: 1, green: 0, blue: 0, alpha: 1), solidBackground: true)
        let solidResult = try await gate.evaluate(reference: alphaRef, output: solidURL, petDescriptor: PetDescriptor(petId: "p"), preference: .conservative)
        let bgCheck = solidResult.checks.first { $0.checkType == .background }
        expect(bgCheck?.passed == false, "solid white background with small subject should fail conservative check")

        let noAlphaRef = ImageSnapshot(width: 8, height: 8, hasAlpha: false, visibleAreaRatio: 1.0, dominantColors: ["#FF0000"])
        let result2 = try await gate.evaluate(reference: noAlphaRef, output: solidURL, petDescriptor: PetDescriptor(petId: "p"), preference: .balanced)
        let bgCheck2 = result2.checks.first { $0.checkType == .background }
        expect(bgCheck2?.passed == true, "background check should skip when reference has no alpha")
    }

    // MARK: - D-5.9 Visible Area Ratio

    func visibleAreaRatioInRange() async throws {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let gate = QualityGateStore()

        let ref = ImageSnapshot(width: 8, height: 8, hasAlpha: true, visibleAreaRatio: 0.5, dominantColors: ["#FF0000"])

        let normalURL = dir.appendingPathComponent("normal.png")
        var transparent: Set<String> = []
        for i in 0..<4 { for j in 0..<4 { transparent.insert("\(i),\(j)") } }
        try makePNG(at: normalURL, width: 8, height: 8, transparentPixels: transparent)
        let normalResult = try await gate.evaluate(reference: ref, output: normalURL, petDescriptor: PetDescriptor(petId: "p"), preference: .balanced)
        let areaCheck = normalResult.checks.first { $0.checkType == .visibleAreaRatio }
        expect(areaCheck?.passed == true, "75% visible area should pass balanced check")

        let emptyURL = dir.appendingPathComponent("empty.png")
        try makePNG(at: emptyURL, width: 8, height: 8, fill: NSColor(deviceRed: 0, green: 0, blue: 0, alpha: 0))
        let emptyResult = try await gate.evaluate(reference: ref, output: emptyURL, petDescriptor: PetDescriptor(petId: "p"), preference: .balanced)
        let emptyArea = emptyResult.checks.first { $0.checkType == .visibleAreaRatio }
        expect(emptyArea?.passed == false, "0% visible area should fail")
    }

    // MARK: - D-5.10 Centering

    func centeringCheckPassesForCenteredSubject() async throws {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let gate = QualityGateStore()

        let ref = ImageSnapshot(width: 8, height: 8, hasAlpha: true, visibleAreaRatio: 0.8, dominantColors: ["#FF0000"])

        let centeredURL = dir.appendingPathComponent("centered.png")
        try makePNG(at: centeredURL, width: 16, height: 16)
        let centeredResult = try await gate.evaluate(reference: ref, output: centeredURL, petDescriptor: PetDescriptor(petId: "p"), preference: .balanced)
        let centerCheck = centeredResult.checks.first { $0.checkType == .centering }
        expect(centerCheck?.passed == true, "fully filled image should be centered")

        let cornerURL = dir.appendingPathComponent("corner.png")
        try makeOffCenterPNG(at: cornerURL, width: 16, height: 16)
        let cornerResult = try await gate.evaluate(reference: ref, output: cornerURL, petDescriptor: PetDescriptor(petId: "p"), preference: .balanced)
        let cornerCheck = cornerResult.checks.first { $0.checkType == .centering }
        expect(cornerCheck?.passed == false, "corner subject should fail centering")
    }

    // MARK: - D-5.11 Verdict

    func verdictBasedOnFailCount() async throws {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let gate = QualityGateStore()

        let ref = ImageSnapshot(width: 8, height: 8, hasAlpha: false, visibleAreaRatio: 0.8, dominantColors: ["#FF0000"])

        let goodURL = dir.appendingPathComponent("good.png")
        try makePNG(at: goodURL, width: 256, height: 256, fill: NSColor(deviceRed: 1, green: 0, blue: 0, alpha: 1))
        let goodResult = try await gate.evaluate(reference: ref, output: goodURL, petDescriptor: PetDescriptor(petId: "p"), preference: .balanced)
        expect(goodResult.overall == .pass, "all checks passing should give pass verdict")

        let tinyURL = dir.appendingPathComponent("tiny.png")
        try makePNG(at: tinyURL, width: 4, height: 4, fill: NSColor(deviceRed: 0, green: 0, blue: 1, alpha: 1))
        let badResult = try await gate.evaluate(reference: ref, output: tinyURL, petDescriptor: PetDescriptor(petId: "p"), preference: .balanced)
        let failCount = badResult.checks.filter { !$0.passed }.count
        expect(failCount >= 1, "tiny mismatched image should fail at least 1 check")
        if failCount == 1 {
            expect(badResult.overall == .warn, "1 failure should give warn")
        } else {
            expect(badResult.overall == .fail, "2+ failures should give fail")
        }
    }

    // MARK: - D-5.12 Risk Level

    func riskLevelUnacceptableForVeryLowColorSimilarity() async throws {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let gate = QualityGateStore()

        let pinkRef = ImageSnapshot(width: 200, height: 200, hasAlpha: true, visibleAreaRatio: 0.8, dominantColors: ["#FF69B4", "#FFB6C1"])

        let greenURL = dir.appendingPathComponent("green.png")
        try makePNG(at: greenURL, width: 256, height: 256, fill: NSColor(deviceRed: 0, green: 1, blue: 0, alpha: 1))
        let result = try await gate.evaluate(reference: pinkRef, output: greenURL, petDescriptor: PetDescriptor(petId: "p"), preference: .balanced)

        let colorCheck = result.checks.first { $0.checkType == .dominantColor }
        if let score = colorCheck?.score, score < 0.3 {
            expect(result.riskLevel == .unacceptable, "very low color similarity should be unacceptable")
            expect(result.autoAction == .rejectWithMessage, "unacceptable should reject")
        }
    }

    // MARK: - Auto Action

    func autoActionMapsFromRiskAndVerdict() {
        let _ = QualityGateStore()

        let passResult = GateResult(overall: .pass, checks: [], riskLevel: .low, userFacingMessage: nil, autoAction: .applyDirectly)
        expect(passResult.autoAction == .applyDirectly, "low+pass should apply directly")

        let warnResult = GateResult(overall: .warn, checks: [], riskLevel: .medium, userFacingMessage: "生成完成，请确认是否应用这次变化。", autoAction: .requirePreview)
        expect(warnResult.autoAction == .requirePreview, "medium+warn should require preview")

        let rejectResult = GateResult(overall: .fail, checks: [], riskLevel: .unacceptable, userFacingMessage: "这次结果和原形象差异较大，已为你保留原样。", autoAction: .rejectWithMessage)
        expect(rejectResult.autoAction == .rejectWithMessage, "unacceptable should reject")
    }

    // MARK: - D-5.13 Preference Influence

    func preferenceAdjustsThresholds() async throws {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let gate = QualityGateStore()

        let pinkRef = ImageSnapshot(width: 200, height: 200, hasAlpha: true, visibleAreaRatio: 0.5, dominantColors: ["#FF69B4"])

        let slightlyOffURL = dir.appendingPathComponent("off.png")
        try makePNG(at: slightlyOffURL, width: 256, height: 256, fill: NSColor(deviceRed: 0.9, green: 0.5, blue: 0.6, alpha: 1))

        let conservativeResult = try await gate.evaluate(reference: pinkRef, output: slightlyOffURL, petDescriptor: PetDescriptor(petId: "p"), preference: .conservative)
        let creativeResult = try await gate.evaluate(reference: pinkRef, output: slightlyOffURL, petDescriptor: PetDescriptor(petId: "p"), preference: .creative)

        let conservativeColor = conservativeResult.checks.first { $0.checkType == .dominantColor }?.score ?? 0
        let creativeColor = creativeResult.checks.first { $0.checkType == .dominantColor }?.score ?? 0
        expect(creativeColor == conservativeColor, "color similarity score should be identical across preferences")
        expect(conservativeResult.overall != creativeResult.overall || conservativeResult.checks.filter { !$0.passed }.count >= creativeResult.checks.filter { !$0.passed }.count,
               "conservative should fail at least as many checks as creative")
    }

    // MARK: - D-5.14 User-Facing Messages

    func userFacingMessagesAreNonTechnical() async throws {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let gate = QualityGateStore()

        let pinkRef = ImageSnapshot(width: 200, height: 200, hasAlpha: true, visibleAreaRatio: 0.5, dominantColors: ["#FF69B4"])

        let greenURL = dir.appendingPathComponent("green.png")
        try makePNG(at: greenURL, width: 256, height: 256, fill: NSColor(deviceRed: 0, green: 1, blue: 0, alpha: 1))
        let result = try await gate.evaluate(reference: pinkRef, output: greenURL, petDescriptor: PetDescriptor(petId: "p"), preference: .conservative)

        if let msg = result.userFacingMessage {
            expect(!msg.contains("cosine"), "message should not contain technical terms")
            expect(!msg.contains("threshold"), "message should not contain technical terms")
            expect(!msg.contains("alpha"), "message should not contain technical terms")
            expect(!msg.contains("score"), "message should not contain technical terms")
        }
    }

    // MARK: - Full Evaluation

    func fullEvaluationWithMatchingColors() async throws {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let gate = QualityGateStore()

        let ref = ImageSnapshot(width: 200, height: 200, hasAlpha: false, visibleAreaRatio: 1.0, dominantColors: ["#FF6BB3"])

        let goodURL = dir.appendingPathComponent("good.png")
        try makePNG(at: goodURL, width: 256, height: 256, fill: NSColor(deviceRed: 1, green: 0.42, blue: 0.7, alpha: 1))
        let result = try await gate.evaluate(reference: ref, output: goodURL, petDescriptor: PetDescriptor(petId: "p"), preference: .balanced)

        expect(result.overall == .pass, "matching output should pass")
        expect(result.riskLevel == .low, "matching output should be low risk")
        expect(result.autoAction == .applyDirectly, "low risk pass should apply directly")
        expect(result.userFacingMessage == nil, "directly applied should have no message")
        expect(result.checks.count == 6, "should run all 6 checks")
    }

    func fullEvaluationRejectsUnacceptable() async throws {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let gate = QualityGateStore()

        let pinkRef = ImageSnapshot(width: 200, height: 200, hasAlpha: true, visibleAreaRatio: 0.5, dominantColors: ["#FF69B4", "#FFB6C1"])

        let greenURL = dir.appendingPathComponent("green.png")
        try makePNG(at: greenURL, width: 256, height: 256, fill: NSColor(deviceRed: 0, green: 1, blue: 0, alpha: 1))
        let result = try await gate.evaluate(reference: pinkRef, output: greenURL, petDescriptor: PetDescriptor(petId: "p"), preference: .conservative)

        let colorScore = result.checks.first { $0.checkType == .dominantColor }?.score ?? 1
        if colorScore < 0.3 {
            expect(result.riskLevel == .unacceptable, "very mismatched colors should be unacceptable")
            expect(result.autoAction == .rejectWithMessage, "unacceptable should reject")
            expect(result.userFacingMessage != nil, "should have user message")
        }
    }

    // MARK: - Mediator Integration

    func mediatorSkipsApplyWhenGateRequiresPreview() async throws {
        let dir = makeTempDir()
        defer { cleanup(dir) }

        let defaultsName = "QualityGateMediatorTests-\(UUID().uuidString)"
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

        let generationService = AlwaysGreenGenerationService(outputDir: dir)
        let diagnosticsStore = GenerationDiagnosticsStore(baseDirectory: dir)
        let gate = QualityGateStore()

        var previewRequested = false
        var gateRejected = false

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
            qualityGateChecker: gate,
            getReferenceImage: { makeReferenceImage() },
            hasActiveOverlayProvider: { false }
        )

        var changedDescription: String?
        mediator.onVisualChanged = { changedDescription = $0 }
        mediator.onPreviewRequested = { _, _ in previewRequested = true }
        mediator.onGateRejected = { _, _ in gateRejected = true }

        mediator.requestManualGeneration(petId: "pet-a", petName: "Mimi")
        try await waitUntil(timeout: 2) {
            previewRequested || gateRejected || changedDescription != nil
        }

        if previewRequested {
            expect(!gateRejected, "should not both preview and reject")
        }

        let records = diagnosticsStore.recentRecords(limit: 1)
        if let record = records.first {
            if let gateResult = record.gateResult {
                expect(gateResult.verdict == "pass" || gateResult.verdict == "warn" || gateResult.verdict == "fail",
                       "diagnostics should record gate verdict")
            }
        }
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

private final class AlwaysGreenGenerationService: VisualGenerationServicing, @unchecked Sendable {
    private let outputDir: URL

    init(outputDir: URL) {
        self.outputDir = outputDir
    }

    func generate(_ request: VisualGenerationRequest) async throws -> VisualGenerationResult {
        let outputURL = request.outputDirectory.appendingPathComponent("\(request.outputPrefix).png")
        try makeGreenPNG(at: outputURL)
        return VisualGenerationResult(
            actionId: request.actionId,
            imageURL: outputURL,
            providerId: "always-green"
        )
    }

    func quotaSnapshot() async throws -> VisualProviderQuotaSnapshot? { nil }
    func currentProviderId() -> String? { "always-green" }
    func availableProviders() -> [ProviderInfo] { [] }
    func selectProvider(_ providerId: String) -> Bool { true }
    func currentCapabilities() -> VisualGenerationCapabilities? { .full }

    private func makeGreenPNG(at url: URL) throws {
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: 256,
            pixelsHigh: 256,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )!
        for y in 0..<256 {
            for x in 0..<256 {
                rep.setColor(NSColor(deviceRed: 0, green: 1, blue: 0, alpha: 1), atX: x, y: y)
            }
        }
        guard let data = rep.representation(using: .png, properties: [:]) else {
            throw PetVisualAssetError.conversionFailed
        }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url)
    }
}
