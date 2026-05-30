import Foundation
import DesktopPet

@MainActor
func runMiniMaxCLIVideoGeneratorTests() async throws {
    let tests = MiniMaxCLIVideoGeneratorTests()
    tests.providerIdIsCorrect()
    tests.isConfiguredFalseByDefault()
    try await tests.refreshConfigurationSetsConfigured()
    try await tests.refreshConfigurationUnsetsWhenUnavailable()
    try await tests.generateThrowsWhenNotConfigured()
    try await tests.generateReturnsResultOnSuccess()
    try await tests.generateUsesFirstFrame()
    try await tests.generateThrowsOnNonZeroExit()
    try await tests.generateThrowsQuotaExceededOnLimitError()
    try await tests.generateThrowsInvalidOutputWhenNoFile()
    try await tests.generateSupportsBothModels()
}

@MainActor
func runVisualVideoExperimentStoreTests() throws {
    let tests = VisualVideoExperimentStoreTests()
    tests.experimentDisabledByDefault()
    tests.setExperimentEnabled()
    tests.canGenerateWithinLimit()
    tests.canGenerateExceedsLimit()
    tests.recordAndRetrieve()
    tests.recordsFilteredByDate()
    tests.summaryAggregatesCorrectly()
    tests.clearAllRemovesRecords()
}

@MainActor
private struct MiniMaxCLIVideoGeneratorTests {

    private func makeGenerator(
        mmxPath: String = "/usr/local/bin/mmx",
        stubs: FakeVideoProcessRunner.Stubs = FakeVideoProcessRunner.Stubs()
    ) -> (MiniMaxCLIVideoGenerator, FakeVideoProcessRunner) {
        let runner = FakeVideoProcessRunner(stubs: stubs)
        let client = MiniMaxCLIClient(processRunner: runner, mmxPath: mmxPath)
        let generator = MiniMaxCLIVideoGenerator(client: client, processRunner: runner)
        return (generator, runner)
    }

    private func makeRequest(
        experimentId: String = "exp-1",
        model: HailuoModel = .fast,
        firstFrameImageURL: URL? = nil,
        outputDirectory: URL? = nil
    ) -> VisualVideoGenerationRequest {
        let tmpDir = outputDirectory ?? URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("video-test-\(UUID().uuidString)")
        return VisualVideoGenerationRequest(
            experimentId: experimentId,
            petId: "pet-1",
            prompt: "pet waving hello",
            model: model,
            firstFrameImageURL: firstFrameImageURL,
            outputDirectory: tmpDir
        )
    }

    func providerIdIsCorrect() {
        let (generator, _) = makeGenerator()
        expect(generator.providerId == "minimax-cli-video", "providerId should be minimax-cli-video")
        expect(generator.displayName == "MiniMax CLI Video (Hailuo)", "displayName should match")
    }

    func isConfiguredFalseByDefault() {
        let (generator, _) = makeGenerator()
        expect(!generator.isConfigured, "should not be configured by default")
    }

    func refreshConfigurationSetsConfigured() async throws {
        var stubs = FakeVideoProcessRunner.Stubs()
        stubs.stubHelp = SubprocessResult(stdout: "mmx 1.0.7", stderr: "", exitCode: 0)
        stubs.stubAuthStatus = SubprocessResult(
            stdout: """
            {"method": "api-key", "source": "config.json", "key": "sk-c...UNVU"}
            """,
            stderr: "",
            exitCode: 0
        )
        let (generator, _) = makeGenerator(stubs: stubs)
        await generator.refreshConfiguration()
        expect(generator.isConfigured, "should be configured after refresh")
    }

    func refreshConfigurationUnsetsWhenUnavailable() async {
        var stubs = FakeVideoProcessRunner.Stubs()
        stubs.stubHelp = SubprocessResult(stdout: "", stderr: "not found", exitCode: 1)
        let (generator, _) = makeGenerator(stubs: stubs)
        await generator.refreshConfiguration()
        expect(!generator.isConfigured, "should not be configured when mmx unavailable")
    }

    func generateThrowsWhenNotConfigured() async {
        let (generator, _) = makeGenerator()
        let request = makeRequest()
        do {
            _ = try await generator.generateVideo(request)
            fail("should throw notConfigured")
        } catch let error as VisualGenerationError {
            if case .notConfigured(let id) = error {
                expect(id == "minimax-cli-video", "should identify provider")
            } else {
                fail("expected notConfigured, got \(error)")
            }
        } catch {
            fail("unexpected error type: \(error)")
        }
    }

    func generateReturnsResultOnSuccess() async throws {
        let tmpDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("video-test-success-\(UUID().uuidString)")

        var stubs = FakeVideoProcessRunner.Stubs()
        stubs.stubHelp = SubprocessResult(stdout: "mmx 1.0.7", stderr: "", exitCode: 0)
        stubs.stubAuthStatus = SubprocessResult(
            stdout: """
            {"method": "api-key", "source": "config.json", "key": "sk-c...UNVU"}
            """,
            stderr: "",
            exitCode: 0
        )
        stubs.stubVideoGenerate = { _ in
            SubprocessResult(stdout: "generated", stderr: "", exitCode: 0)
        }

        let (generator, _) = makeGenerator(stubs: stubs)
        await generator.refreshConfiguration()

        let request = makeRequest(outputDirectory: tmpDir)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        let expectedFile = tmpDir.appendingPathComponent("exp-1.mp4")
        try Data("fake-video".utf8).write(to: expectedFile)

        let result = try await generator.generateVideo(request)
        expect(result.experimentId == "exp-1", "should return correct experimentId")
        expect(result.model == .fast, "should return correct model")
        expect(result.videoURL == expectedFile, "should locate output video")
        expect(result.durationSeconds > 0, "should record elapsed time")

        try? FileManager.default.removeItem(at: tmpDir)
    }

    func generateUsesFirstFrame() async throws {
        let tmpDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("video-test-firstframe-\(UUID().uuidString)")
        let firstFrame = tmpDir.appendingPathComponent("reference.png")

        var stubs = FakeVideoProcessRunner.Stubs()
        stubs.stubHelp = SubprocessResult(stdout: "mmx 1.0.7", stderr: "", exitCode: 0)
        stubs.stubAuthStatus = SubprocessResult(
            stdout: """
            {"method": "api-key", "source": "config.json", "key": "sk-c...UNVU"}
            """,
            stderr: "",
            exitCode: 0
        )
        stubs.stubVideoGenerate = { _ in
            SubprocessResult(stdout: "generated", stderr: "", exitCode: 0)
        }

        let (generator, runner) = makeGenerator(stubs: stubs)
        await generator.refreshConfiguration()

        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        try Data().write(to: firstFrame)
        let outputFile = tmpDir.appendingPathComponent("exp-1.mp4")
        try Data("fake-video".utf8).write(to: outputFile)

        let request = makeRequest(firstFrameImageURL: firstFrame, outputDirectory: tmpDir)
        _ = try await generator.generateVideo(request)

        let lastArgs = runner.lastArguments ?? []
        let hasFirstFrame = lastArgs.contains("--first-frame")
        expect(hasFirstFrame, "should pass --first-frame argument")

        try? FileManager.default.removeItem(at: tmpDir)
    }

    func generateThrowsOnNonZeroExit() async throws {
        var stubs = FakeVideoProcessRunner.Stubs()
        stubs.stubHelp = SubprocessResult(stdout: "mmx 1.0.7", stderr: "", exitCode: 0)
        stubs.stubAuthStatus = SubprocessResult(
            stdout: """
            {"method": "api-key", "source": "config.json", "key": "sk-c...UNVU"}
            """,
            stderr: "",
            exitCode: 0
        )
        stubs.stubVideoGenerate = { _ in
            SubprocessResult(stdout: "", stderr: "generation error", exitCode: 1)
        }

        let (generator, _) = makeGenerator(stubs: stubs)
        await generator.refreshConfiguration()

        let request = makeRequest()
        do {
            _ = try await generator.generateVideo(request)
            fail("should throw invalidOutput")
        } catch let error as VisualGenerationError {
            if case .invalidOutput(let id, _) = error {
                expect(id == "minimax-cli-video", "should identify provider")
            } else {
                fail("expected invalidOutput, got \(error)")
            }
        } catch {
            fail("unexpected error type: \(error)")
        }
    }

    func generateThrowsQuotaExceededOnLimitError() async throws {
        var stubs = FakeVideoProcessRunner.Stubs()
        stubs.stubHelp = SubprocessResult(stdout: "mmx 1.0.7", stderr: "", exitCode: 0)
        stubs.stubAuthStatus = SubprocessResult(
            stdout: """
            {"method": "api-key", "source": "config.json", "key": "sk-c...UNVU"}
            """,
            stderr: "",
            exitCode: 0
        )
        stubs.stubVideoGenerate = { _ in
            SubprocessResult(stdout: "", stderr: "quota limit exceeded", exitCode: 1)
        }

        let (generator, _) = makeGenerator(stubs: stubs)
        await generator.refreshConfiguration()

        let request = makeRequest()
        do {
            _ = try await generator.generateVideo(request)
            fail("should throw quotaExceeded")
        } catch let error as VisualGenerationError {
            if case .quotaExceeded(let id) = error {
                expect(id == "minimax-cli-video", "should identify provider")
            } else {
                fail("expected quotaExceeded, got \(error)")
            }
        } catch {
            fail("unexpected error type: \(error)")
        }
    }

    func generateThrowsInvalidOutputWhenNoFile() async throws {
        let tmpDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("video-test-nofile-\(UUID().uuidString)")

        var stubs = FakeVideoProcessRunner.Stubs()
        stubs.stubHelp = SubprocessResult(stdout: "mmx 1.0.7", stderr: "", exitCode: 0)
        stubs.stubAuthStatus = SubprocessResult(
            stdout: """
            {"method": "api-key", "source": "config.json", "key": "sk-c...UNVU"}
            """,
            stderr: "",
            exitCode: 0
        )
        stubs.stubVideoGenerate = { _ in
            SubprocessResult(stdout: "generated", stderr: "", exitCode: 0)
        }

        let (generator, _) = makeGenerator(stubs: stubs)
        await generator.refreshConfiguration()

        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)

        let request = makeRequest(outputDirectory: tmpDir)
        do {
            _ = try await generator.generateVideo(request)
            fail("should throw invalidOutput")
        } catch let error as VisualGenerationError {
            if case .invalidOutput(let id, let reason) = error {
                expect(id == "minimax-cli-video", "should identify provider")
                expect(reason.contains("not found"), "should explain file not found")
            } else {
                fail("expected invalidOutput, got \(error)")
            }
        } catch {
            fail("unexpected error type: \(error)")
        }

        try? FileManager.default.removeItem(at: tmpDir)
    }

    func generateSupportsBothModels() async throws {
        let tmpDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("video-test-models-\(UUID().uuidString)")

        var stubs = FakeVideoProcessRunner.Stubs()
        stubs.stubHelp = SubprocessResult(stdout: "mmx 1.0.7", stderr: "", exitCode: 0)
        stubs.stubAuthStatus = SubprocessResult(
            stdout: """
            {"method": "api-key", "source": "config.json", "key": "sk-c...UNVU"}
            """,
            stderr: "",
            exitCode: 0
        )
        stubs.stubVideoGenerate = { _ in
            SubprocessResult(stdout: "generated", stderr: "", exitCode: 0)
        }

        let (generator, runner) = makeGenerator(stubs: stubs)
        await generator.refreshConfiguration()

        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)

        for model in HailuoModel.allCases {
            let expId = "exp-\(model.rawValue)"
            let outputFile = tmpDir.appendingPathComponent("\(expId).mp4")
            try Data("fake-video".utf8).write(to: outputFile)

            let request = makeRequest(experimentId: expId, model: model, outputDirectory: tmpDir)
            let result = try await generator.generateVideo(request)
            expect(result.model == model, "should return correct model \(model.rawValue)")

            let lastArgs = runner.lastArguments ?? []
            let hasModel = lastArgs.contains(model.rawValue)
            expect(hasModel, "should pass model \(model.rawValue) to CLI")
        }

        try? FileManager.default.removeItem(at: tmpDir)
    }
}

@MainActor
private struct VisualVideoExperimentStoreTests {

    private let suiteName = "test.visual-video-experiment"

    private func makeStore() -> VisualVideoExperimentStore {
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return VisualVideoExperimentStore(userDefaults: defaults)
    }

    func experimentDisabledByDefault() {
        let store = makeStore()
        expect(!store.isExperimentEnabled, "experiment should be disabled by default")
    }

    func setExperimentEnabled() {
        let store = makeStore()
        store.setExperimentEnabled(true)
        expect(store.isExperimentEnabled, "should be enabled after setting")
        store.setExperimentEnabled(false)
        expect(!store.isExperimentEnabled, "should be disabled after unsetting")
    }

    func canGenerateWithinLimit() {
        let store = makeStore()
        let now = Date()
        expect(store.canGenerate(model: .fast, on: now), "should allow when under limit")

        try? store.record(VisualVideoExperimentRecord(
            petId: "pet-1",
            model: .fast,
            promptDigest: "abc",
            usedFirstFrame: false,
            result: .succeeded
        ))
        expect(store.canGenerate(model: .fast, on: now), "should allow at limit")

        try? store.record(VisualVideoExperimentRecord(
            petId: "pet-1",
            model: .fast,
            promptDigest: "def",
            usedFirstFrame: false,
            result: .succeeded
        ))
        expect(!store.canGenerate(model: .fast, on: now), "should deny when over limit")
        expect(store.canGenerate(model: .standard, on: now), "different model should have separate limit")
    }

    func canGenerateExceedsLimit() {
        let store = makeStore()
        let now = Date()
        for i in 0..<3 {
            try? store.record(VisualVideoExperimentRecord(
                petId: "pet-1",
                model: .standard,
                promptDigest: "hash-\(i)",
                usedFirstFrame: false,
                result: .succeeded
            ))
        }
        expect(!store.canGenerate(model: .standard, on: now), "should deny over limit")
    }

    func recordAndRetrieve() {
        let store = makeStore()
        let record = VisualVideoExperimentRecord(
            petId: "pet-1",
            model: .fast,
            promptDigest: "abc123",
            usedFirstFrame: true,
            result: .succeeded,
            durationSeconds: 45.0
        )
        try? store.record(record)

        let all = store.allRecords()
        expect(all.count == 1, "should have 1 record")
        expect(all.first?.model == .fast, "should store correct model")
        expect(all.first?.usedFirstFrame == true, "should store firstFrame flag")
        expect(all.first?.durationSeconds == 45.0, "should store duration")
    }

    func recordsFilteredByDate() {
        let store = makeStore()
        let now = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: now)!

        try? store.record(VisualVideoExperimentRecord(
            petId: "pet-1",
            model: .fast,
            promptDigest: "today",
            usedFirstFrame: false,
            result: .succeeded,
            createdAt: now
        ))
        try? store.record(VisualVideoExperimentRecord(
            petId: "pet-1",
            model: .fast,
            promptDigest: "yesterday",
            usedFirstFrame: false,
            result: .succeeded,
            createdAt: yesterday
        ))

        let todayRecords = store.records(on: now)
        expect(todayRecords.count == 1, "only records from the requested day should be returned")
        expect(todayRecords.first?.promptDigest == "today", "today filter should keep today's record")
    }

    func summaryAggregatesCorrectly() {
        let store = makeStore()
        try? store.record(VisualVideoExperimentRecord(
            petId: "pet-1", model: .fast, promptDigest: "a",
            usedFirstFrame: true, result: .succeeded, durationSeconds: 30.0
        ))
        try? store.record(VisualVideoExperimentRecord(
            petId: "pet-1", model: .standard, promptDigest: "b",
            usedFirstFrame: false, result: .failed, durationSeconds: 10.0
        ))
        try? store.record(VisualVideoExperimentRecord(
            petId: "pet-1", model: .fast, promptDigest: "c",
            usedFirstFrame: true, result: .firstFrameConsistent, durationSeconds: 50.0
        ))

        let summary = store.summary()
        expect(summary.totalExperiments == 3, "should count all records")
        expect(summary.successCount == 2, "succeeded + firstFrameConsistent are successes")
        expect(summary.failureCount == 1, "should count failures")
        expect(summary.firstFrameConsistentCount == 1, "should count firstFrameConsistent")
        expect(summary.modelCounts["MiniMax-Hailuo-2.3-Fast"] == 2, "should count fast model")
        expect(summary.modelCounts["MiniMax-Hailuo-2.3"] == 1, "should count standard model")
        expect(summary.averageDurationSeconds == 30.0, "should compute average duration")
    }

    func clearAllRemovesRecords() {
        let store = makeStore()
        try? store.record(VisualVideoExperimentRecord(
            petId: "pet-1", model: .fast, promptDigest: "a",
            usedFirstFrame: false, result: .succeeded
        ))
        expect(store.allRecords().count == 1, "should have 1 record")
        store.clearAll()
        expect(store.allRecords().isEmpty, "should have no records after clear")
    }
}

private final class FakeVideoProcessRunner: ProcessRunning, @unchecked Sendable {
    struct Stubs {
        var stubHelp: SubprocessResult = SubprocessResult(stdout: "", stderr: "", exitCode: 1)
        var stubAuthStatus: SubprocessResult = SubprocessResult(stdout: "{}", stderr: "", exitCode: 1)
        var stubVideoGenerate: ([String]) -> SubprocessResult = { _ in
            SubprocessResult(stdout: "", stderr: "", exitCode: 1)
        }
    }

    private let queue = DispatchQueue(label: "fake-video-process-runner")
    private let stubs: Stubs
    private(set) var lastArguments: [String]?

    init(stubs: Stubs) {
        self.stubs = stubs
    }

    func run(
        executableURL: URL,
        arguments: [String],
        currentDirectoryURL: URL?
    ) async throws -> SubprocessResult {
        queue.sync { lastArguments = arguments }
        if arguments.first == "--help" {
            return stubs.stubHelp
        }
        if arguments.contains("auth") && arguments.contains("status") {
            return stubs.stubAuthStatus
        }
        if arguments.contains("video") && arguments.contains("generate") {
            return stubs.stubVideoGenerate(arguments)
        }
        return SubprocessResult(stdout: "", stderr: "unknown command", exitCode: 1)
    }
}
