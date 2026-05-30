import AppKit
import Foundation
import DesktopPet

@MainActor
func runUserFeedbackStoreTests() async throws {
    let tests = UserFeedbackStoreTests()
    try tests.recordFeedbackPersistsJSON()
    try tests.feedbackHistoryReturnsSortedEntries()
    try tests.feedbackStatsCountsByType()
    try tests.feedbackStatsEmptyWhenNoFeedback()
    try tests.learnedConstraintsFromStatsRequiresMultipleFeedback()
    try tests.cleanupRemovesOldFeedback()
    try tests.multipleFeedbackTypesForSameAsset()
    try await tests.mediatorRecordFeedbackRecordsToStoreAndDiagnostics()
}

@MainActor
private struct UserFeedbackStoreTests {
    private let fm = FileManager.default

    private func makeTempDir() -> URL {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("user-feedback-tests-\(UUID().uuidString)", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func cleanup(_ dir: URL) {
        try? fm.removeItem(at: dir)
    }

    private func makePNG(at url: URL) throws {
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: 4, pixelsHigh: 4,
            bitsPerSample: 8, samplesPerPixel: 4,
            hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0, bitsPerPixel: 0
        )!
        for y in 0..<4 { for x in 0..<4 { rep.setColor(NSColor.red, atX: x, y: y) } }
        guard let data = rep.representation(using: .png, properties: [:]) else {
            throw PetVisualAssetError.conversionFailed
        }
        try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url)
    }

    func recordFeedbackPersistsJSON() throws {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let store = UserFeedbackStore(baseDirectory: dir)

        let context = FeedbackContext(
            petId: "pet-1",
            promptDigest: "abc123",
            lifecycleState: .applied
        )
        try store.recordFeedback(
            assetId: "asset-1",
            type: .colorWrong,
            context: context
        )

        let feedbackDir = dir
            .appendingPathComponent("pet-1")
            .appendingPathComponent("visual-actions")
            .appendingPathComponent("feedback")
        let files = try fm.contentsOfDirectory(
            at: feedbackDir,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        expect(files.count == 1, "Should create one feedback JSON file")

        let data = try Data(contentsOf: files[0])
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let entry = try decoder.decode(UserFeedbackEntry.self, from: data)
        expect(entry.assetId == "asset-1", "Entry assetId should match")
        expect(entry.type == .colorWrong, "Entry type should match")
        expect(entry.petId == "pet-1", "Entry petId should match")
        expect(entry.context.promptDigest == "abc123", "Entry promptDigest should match")
        expect(entry.context.lifecycleState == .applied, "Entry lifecycleState should match")
    }

    func feedbackHistoryReturnsSortedEntries() throws {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let store = UserFeedbackStore(baseDirectory: dir)

        for type in [PreviewFeedbackType.notLikeOriginal, .styleWrong, .colorWrong] {
            try store.recordFeedback(
                assetId: "asset-\(type.rawValue)",
                type: type,
                context: FeedbackContext(petId: "pet-1", lifecycleState: .discardedByUser)
            )
        }

        let history = store.feedbackHistory(for: "pet-1", limit: 10)
        expect(history.count == 3, "Should return 3 feedback entries")
        expect(history[0].createdAt >= history[1].createdAt, "Should be sorted newest first")

        let limited = store.feedbackHistory(for: "pet-1", limit: 2)
        expect(limited.count == 2, "Should respect limit parameter")

        let empty = store.feedbackHistory(for: "pet-2", limit: 10)
        expect(empty.isEmpty, "Should return empty for unknown pet")
    }

    func feedbackStatsCountsByType() throws {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let store = UserFeedbackStore(baseDirectory: dir)

        try store.recordFeedback(
            assetId: "a1", type: .notLikeOriginal,
            context: FeedbackContext(petId: "pet-1", lifecycleState: .discardedByUser)
        )
        try store.recordFeedback(
            assetId: "a2", type: .notLikeOriginal,
            context: FeedbackContext(petId: "pet-1", lifecycleState: .discardedByUser)
        )
        try store.recordFeedback(
            assetId: "a3", type: .colorWrong,
            context: FeedbackContext(petId: "pet-1", lifecycleState: .applied)
        )
        try store.recordFeedback(
            assetId: "a4", type: .goodDirection,
            context: FeedbackContext(petId: "pet-1", lifecycleState: .applied)
        )

        let stats = store.feedbackStats(for: "pet-1")
        expect(stats.totalCount == 4, "Total count should be 4")
        expect(stats.notLikeOriginalCount == 2, "notLikeOriginal count should be 2")
        expect(stats.colorWrongCount == 1, "colorWrong count should be 1")
        expect(stats.goodDirectionCount == 1, "goodDirection count should be 1")
        expect(stats.styleWrongCount == 0, "styleWrong count should be 0")
        expect(stats.accessoryLostCount == 0, "accessoryLost count should be 0")
    }

    func feedbackStatsEmptyWhenNoFeedback() throws {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let store = UserFeedbackStore(baseDirectory: dir)

        let stats = store.feedbackStats(for: "pet-unknown")
        expect(stats.totalCount == 0, "Should have zero count for no feedback")
    }

    func learnedConstraintsFromStatsRequiresMultipleFeedback() throws {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let store = UserFeedbackStore(baseDirectory: dir)

        let noConstraints = store.learnedConstraintsFromStats(for: "pet-1")
        expect(noConstraints.isEmpty, "Should have no constraints with zero feedback")

        try store.recordFeedback(
            assetId: "a1", type: .colorWrong,
            context: FeedbackContext(petId: "pet-1", lifecycleState: .applied)
        )
        let singleFeedback = store.learnedConstraintsFromStats(for: "pet-1")
        expect(singleFeedback.isEmpty, "Single feedback should not generate constraint")

        try store.recordFeedback(
            assetId: "a2", type: .colorWrong,
            context: FeedbackContext(petId: "pet-1", lifecycleState: .applied)
        )
        let twoFeedback = store.learnedConstraintsFromStats(for: "pet-1")
        expect(twoFeedback.contains("keep-original-colors"), "Two colorWrong feedbacks should generate keep-original-colors constraint")
        expect(!twoFeedback.contains("keep-original-appearance"), "Only colorWrong, no notLikeOriginal constraint yet")

        try store.recordFeedback(
            assetId: "a3", type: .notLikeOriginal,
            context: FeedbackContext(petId: "pet-1", lifecycleState: .discardedByUser)
        )
        try store.recordFeedback(
            assetId: "a4", type: .notLikeOriginal,
            context: FeedbackContext(petId: "pet-1", lifecycleState: .discardedByUser)
        )
        let fullConstraints = store.learnedConstraintsFromStats(for: "pet-1")
        expect(fullConstraints.contains("keep-original-appearance"), "Two notLikeOriginal should generate keep-original-appearance")
        expect(fullConstraints.contains("keep-original-colors"), "Should still have color constraint")
    }

    func cleanupRemovesOldFeedback() throws {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let store = UserFeedbackStore(baseDirectory: dir)

        try store.recordFeedback(
            assetId: "a1", type: .colorWrong,
            context: FeedbackContext(petId: "pet-1", lifecycleState: .applied)
        )

        let historyBefore = store.feedbackHistory(for: "pet-1", limit: 10)
        expect(historyBefore.count == 1, "Should have 1 entry before cleanup")

        try store.cleanup(olderThan: 0)

        let historyAfter = store.feedbackHistory(for: "pet-1", limit: 10)
        expect(historyAfter.isEmpty, "Should have 0 entries after cleanup with 0 days")
    }

    func multipleFeedbackTypesForSameAsset() throws {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let store = UserFeedbackStore(baseDirectory: dir)

        let context = FeedbackContext(petId: "pet-1", lifecycleState: .applied)
        try store.recordFeedback(assetId: "asset-x", type: .notLikeOriginal, context: context)
        try store.recordFeedback(assetId: "asset-x", type: .styleWrong, context: context)

        let history = store.feedbackHistory(for: "pet-1", limit: 10)
        expect(history.count == 2, "Same asset can have multiple feedback entries")
        expect(history.contains { $0.type == .notLikeOriginal }, "Should contain notLikeOriginal")
        expect(history.contains { $0.type == .styleWrong }, "Should contain styleWrong")
    }

    func mediatorRecordFeedbackRecordsToStoreAndDiagnostics() async throws {
        let dir = makeTempDir()
        defer { cleanup(dir) }

        let assetStore = PetVisualAssetStore(baseDirectory: dir)
        let feedbackStore = UserFeedbackStore(baseDirectory: dir)
        let diagnosticsStore = GenerationDiagnosticsStore(baseDirectory: dir)

        var diagRecord = diagnosticsStore.beginRecord(requestId: "req-1", petId: "pet-1")
        diagnosticsStore.recordPrompt(&diagRecord, finalPrompt: "test prompt")
        _ = try diagnosticsStore.finalize(diagRecord)

        let pngURL = dir.appendingPathComponent("test-image.png")
        try makePNG(at: pngURL)

        let asset = PetVisualAsset(
            id: "asset-1",
            petId: "pet-1",
            actionId: "req-1",
            providerId: "test",
            localURL: pngURL,
            promptDigest: "digest-1",
            kind: .ambience,
            renderMode: .replaceWholeImage,
            lifecycleState: .applied,
            generationDiagnosticsId: "req-1"
        )

        let defaultsName = "UserFeedbackMediatorTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: defaultsName) ?? .standard
        defaults.removePersistentDomain(forName: defaultsName)

        let mediator = AIVisualActionMediator(
            coordinator: AIVisualActionCoordinator(
                policy: AIVisualActionPolicy(),
                confirmationController: AIVisualConfirmationController(hasPreviousConfirmation: true),
                quotaStore: AIVisualQuotaStore(userDefaults: defaults)
            ),
            generationService: FeedbackMockGenerationService(baseDirectory: dir),
            assetStore: assetStore,
            stateController: PetVisualStateController(),
            safetyService: AIVisualSafetyService(),
            quotaStore: AIVisualQuotaStore(userDefaults: defaults),
            preferencesStore: AIVisualPreferencesStore(userDefaults: defaults),
            generationDiagnosticsRecorder: diagnosticsStore,
            referenceImageProvider: PetReferenceImageProvider(baseDirectory: dir),
            feedbackStore: feedbackStore
        )

        mediator.recordFeedback(type: PreviewFeedbackType.colorWrong, asset: asset)

        let history = feedbackStore.feedbackHistory(for: "pet-1", limit: 10)
        expect(history.count == 1, "Feedback should be recorded in store")
        expect(history[0].type == .colorWrong, "Feedback type should be colorWrong")
        expect(history[0].assetId == "asset-1", "Feedback should reference correct asset")

        let updatedRecord = try diagnosticsStore.loadRecord(requestId: "req-1")
        expect(updatedRecord.userAction == .feedbackColorWrong, "Diagnostics should record feedback action")
    }
}

private final class FeedbackMockGenerationService: VisualGenerationServicing, @unchecked Sendable {
    private let baseDirectory: URL

    init(baseDirectory: URL) {
        self.baseDirectory = baseDirectory
    }

    func generate(_ request: VisualGenerationRequest) async throws -> VisualGenerationResult {
        let outputURL = request.outputDirectory.appendingPathComponent("\(request.outputPrefix).png")
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: 4, pixelsHigh: 4,
            bitsPerSample: 8, samplesPerPixel: 4,
            hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0, bitsPerPixel: 0
        )!
        for y in 0..<4 { for x in 0..<4 { rep.setColor(NSColor.red, atX: x, y: y) } }
        let data = rep.representation(using: .png, properties: [:])!
        try FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: outputURL)
        return VisualGenerationResult(actionId: request.actionId, imageURL: outputURL, providerId: "mock")
    }

    func quotaSnapshot() async throws -> VisualProviderQuotaSnapshot? { nil }
    func currentProviderId() -> String? { "mock" }
    func availableProviders() -> [ProviderInfo] { [] }
    func selectProvider(_ providerId: String) -> Bool { true }
    func currentCapabilities() -> VisualGenerationCapabilities? { .full }
}

private func expect(_ condition: Bool, _ message: String, file: StaticString = #file, line: UInt = #line) {
    if !condition {
        fatalError("[FAIL] \(message) (\(file):\(line))")
    }
}
