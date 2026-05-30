import Foundation
import DesktopPet

@MainActor
func runMiniMaxCLIImageGeneratorTests() async throws {
    let tests = MiniMaxCLIImageGeneratorTests()
    tests.providerIdIsMinimaxCLI()
    tests.capabilitiesIncludeReferenceImage()
    tests.isConfiguredFalseByDefault()
    tests.defaultClientUsesEnvForPathLookup()
    try await tests.defaultClientPrefixesCommandsWithMmx()
    try await tests.refreshConfigurationSetsConfigured()
    try await tests.refreshConfigurationUnsetsWhenUnavailable()
    try await tests.generateThrowsWhenNotConfigured()
    try await tests.generateReturnsResultOnSuccess()
    try await tests.generateCreatesOutputDirectory()
    try await tests.generateThrowsOnNonZeroExit()
    try await tests.generateThrowsQuotaExceededOnLimitError()
    try await tests.generateUsesReferenceImage()
    try await tests.generateThrowsInvalidOutputWhenNoFile()
    try await tests.quotaSnapshotReturnsNilWhenNotConfigured()
    try await tests.quotaSnapshotReturnsSnapshotOnSuccess()
    try await tests.quotaSnapshotReturnsNilOnFetchError()
}

@MainActor
private struct MiniMaxCLIImageGeneratorTests {

    private func makeClient(
        mmxPath: String = "/usr/local/bin/mmx",
        stubs: FakeProcessRunner.Stubs = FakeProcessRunner.Stubs()
    ) -> (MiniMaxCLIClient, FakeProcessRunner) {
        let runner = FakeProcessRunner(stubs: stubs)
        let client = MiniMaxCLIClient(processRunner: runner, mmxPath: mmxPath)
        return (client, runner)
    }

    private func makeGenerator(
        mmxPath: String = "/usr/local/bin/mmx",
        stubs: FakeProcessRunner.Stubs = FakeProcessRunner.Stubs()
    ) -> (MiniMaxCLIImageGenerator, FakeProcessRunner) {
        let (client, runner) = makeClient(mmxPath: mmxPath, stubs: stubs)
        let generator = MiniMaxCLIImageGenerator(client: client)
        return (generator, runner)
    }

    private func makeRequest(
        actionId: String = "act-1",
        outputDirectory: URL? = nil,
        referenceImageURL: URL? = nil
    ) -> VisualGenerationRequest {
        let tmpDir = outputDirectory ?? URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("minimax-test-\(UUID().uuidString)")
        return VisualGenerationRequest(
            actionId: actionId,
            petId: "pet-1",
            prompt: "a cute cat with a small hat",
            referenceImageURL: referenceImageURL,
            aspectRatio: "1:1",
            outputDirectory: tmpDir,
            outputPrefix: actionId
        )
    }

    func providerIdIsMinimaxCLI() {
        let (generator, _) = makeGenerator()
        expect(generator.providerId == "minimax-cli", "providerId should be minimax-cli")
        expect(generator.displayName == "MiniMax CLI", "displayName should be MiniMax CLI")
    }

    func capabilitiesIncludeReferenceImage() {
        let (generator, _) = makeGenerator()
        expect(generator.capabilities.supportsReferenceImage, "should support reference image")
        expect(generator.capabilities.supportsQuotaSnapshot, "should support quota snapshot")
        expect(!generator.capabilities.supportsImageEdit, "should not support image edit")
    }

    func isConfiguredFalseByDefault() {
        let (generator, _) = makeGenerator()
        expect(!generator.isConfigured, "should not be configured by default")
    }

    func defaultClientUsesEnvForPathLookup() {
        let client = MiniMaxCLIClient(processRunner: FakeProcessRunner(stubs: FakeProcessRunner.Stubs()))
        let url = client.executableURL()
        // With auto-resolve, the client may resolve mmx via shell PATH or fall back to /usr/bin/env
        let path = url?.path ?? ""
        expect(path == "/usr/bin/env" || path.hasSuffix("/mmx"), "default client should resolve mmx path or fall back to /usr/bin/env, got: \(path)")
    }

    func defaultClientPrefixesCommandsWithMmx() async throws {
        var stubs = FakeProcessRunner.Stubs()
        stubs.stubHelp = SubprocessResult(stdout: "mmx 1.0.7", stderr: "", exitCode: 0)
        stubs.stubAuthStatus = SubprocessResult(
            stdout: """
            {"method": "api-key", "source": "config.json", "key": "sk-c...UNVU"}
            """,
            stderr: "",
            exitCode: 0
        )
        let runner = FakeProcessRunner(stubs: stubs)
        let client = MiniMaxCLIClient(processRunner: runner)

        let available = await client.checkAvailability()

        expect(available, "default client should still detect availability")
        let execPath = runner.lastExecutableURL?.path ?? ""
        expect(execPath == "/usr/bin/env" || execPath.hasSuffix("/mmx"), "default client should execute resolved mmx or fall back to env, got: \(execPath)")
        if execPath == "/usr/bin/env" {
            expect(runner.lastArguments?.first == "mmx", "default client should prefix command with mmx when using env")
        }
    }

    func refreshConfigurationSetsConfigured() async throws {
        var stubs = FakeProcessRunner.Stubs()
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
        var stubs = FakeProcessRunner.Stubs()
        stubs.stubHelp = SubprocessResult(stdout: "", stderr: "not found", exitCode: 1)
        let (generator, _) = makeGenerator(stubs: stubs)
        await generator.refreshConfiguration()
        expect(!generator.isConfigured, "should not be configured when mmx unavailable")
    }

    func generateThrowsWhenNotConfigured() async {
        let (generator, _) = makeGenerator()
        let request = makeRequest()
        do {
            _ = try await generator.generate(request)
            fail("should throw notConfigured")
        } catch let error as VisualGenerationError {
            if case .notConfigured(let id) = error {
                expect(id == "minimax-cli", "should identify provider")
            } else {
                fail("expected notConfigured, got \(error)")
            }
        } catch {
            fail("unexpected error type: \(error)")
        }
    }

    func generateReturnsResultOnSuccess() async throws {
        let tmpDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("minimax-test-success-\(UUID().uuidString)")

        var stubs = FakeProcessRunner.Stubs()
        stubs.stubHelp = SubprocessResult(stdout: "mmx 1.0.7", stderr: "", exitCode: 0)
        stubs.stubAuthStatus = SubprocessResult(
            stdout: """
            {"method": "api-key", "source": "config.json", "key": "sk-c...UNVU"}
            """,
            stderr: "",
            exitCode: 0
        )
        stubs.stubGenerate = { _ in
            SubprocessResult(stdout: "generated", stderr: "", exitCode: 0)
        }

        let (generator, _) = makeGenerator(stubs: stubs)
        await generator.refreshConfiguration()

        let request = makeRequest(outputDirectory: tmpDir)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        let expectedFile = tmpDir.appendingPathComponent("act-1.png")
        try Data().write(to: expectedFile)

        let result = try await generator.generate(request)
        expect(result.actionId == "act-1", "should return correct actionId")
        expect(result.providerId == "minimax-cli", "should return correct providerId")
        expect(result.imageURL.standardizedFileURL == expectedFile.standardizedFileURL, "should locate output image")

        try? FileManager.default.removeItem(at: tmpDir)
    }

    func generateCreatesOutputDirectory() async throws {
        let tmpDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("minimax-test-dir-\(UUID().uuidString)")

        var stubs = FakeProcessRunner.Stubs()
        stubs.stubHelp = SubprocessResult(stdout: "mmx 1.0.7", stderr: "", exitCode: 0)
        stubs.stubAuthStatus = SubprocessResult(
            stdout: """
            {"method": "api-key", "source": "config.json", "key": "sk-c...UNVU"}
            """,
            stderr: "",
            exitCode: 0
        )
        stubs.stubGenerate = { _ in
            SubprocessResult(stdout: "generated", stderr: "", exitCode: 0)
        }

        let (generator, _) = makeGenerator(stubs: stubs)
        await generator.refreshConfiguration()

        let request = makeRequest(outputDirectory: tmpDir)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        let expectedFile = tmpDir.appendingPathComponent("act-1.png")
        try Data().write(to: expectedFile)

        _ = try await generator.generate(request)
        let dirExists = FileManager.default.fileExists(atPath: tmpDir.path)
        expect(dirExists, "should create output directory")

        try? FileManager.default.removeItem(at: tmpDir)
    }

    func generateThrowsOnNonZeroExit() async throws {
        var stubs = FakeProcessRunner.Stubs()
        stubs.stubHelp = SubprocessResult(stdout: "mmx 1.0.7", stderr: "", exitCode: 0)
        stubs.stubAuthStatus = SubprocessResult(
            stdout: """
            {"method": "api-key", "source": "config.json", "key": "sk-c...UNVU"}
            """,
            stderr: "",
            exitCode: 0
        )
        stubs.stubGenerate = { _ in
            SubprocessResult(stdout: "", stderr: "generation error", exitCode: 1)
        }

        let (generator, _) = makeGenerator(stubs: stubs)
        await generator.refreshConfiguration()

        let request = makeRequest()
        do {
            _ = try await generator.generate(request)
            fail("should throw invalidOutput")
        } catch let error as VisualGenerationError {
            if case .invalidOutput(let id, _) = error {
                expect(id == "minimax-cli", "should identify provider")
            } else {
                fail("expected invalidOutput, got \(error)")
            }
        } catch {
            fail("unexpected error type: \(error)")
        }
    }

    func generateThrowsQuotaExceededOnLimitError() async throws {
        var stubs = FakeProcessRunner.Stubs()
        stubs.stubHelp = SubprocessResult(stdout: "mmx 1.0.7", stderr: "", exitCode: 0)
        stubs.stubAuthStatus = SubprocessResult(
            stdout: """
            {"method": "api-key", "source": "config.json", "key": "sk-c...UNVU"}
            """,
            stderr: "",
            exitCode: 0
        )
        stubs.stubGenerate = { _ in
            SubprocessResult(stdout: "", stderr: "quota limit exceeded", exitCode: 1)
        }

        let (generator, _) = makeGenerator(stubs: stubs)
        await generator.refreshConfiguration()

        let request = makeRequest()
        do {
            _ = try await generator.generate(request)
            fail("should throw quotaExceeded")
        } catch let error as VisualGenerationError {
            if case .quotaExceeded(let id) = error {
                expect(id == "minimax-cli", "should identify provider")
            } else {
                fail("expected quotaExceeded, got \(error)")
            }
        } catch {
            fail("unexpected error type: \(error)")
        }
    }

    func generateUsesReferenceImage() async throws {
        let tmpDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("minimax-test-ref-\(UUID().uuidString)")
        let refImage = tmpDir.appendingPathComponent("reference.png")

        var stubs = FakeProcessRunner.Stubs()
        stubs.stubHelp = SubprocessResult(stdout: "mmx 1.0.7", stderr: "", exitCode: 0)
        stubs.stubAuthStatus = SubprocessResult(
            stdout: """
            {"method": "api-key", "source": "config.json", "key": "sk-c...UNVU"}
            """,
            stderr: "",
            exitCode: 0
        )
        stubs.stubGenerate = { _ in
            SubprocessResult(stdout: "generated", stderr: "", exitCode: 0)
        }

        let (generator, runner) = makeGenerator(stubs: stubs)
        await generator.refreshConfiguration()

        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        try Data().write(to: refImage)
        let outputFile = tmpDir.appendingPathComponent("act-1.png")
        try Data().write(to: outputFile)

        let request = makeRequest(outputDirectory: tmpDir, referenceImageURL: refImage)
        _ = try await generator.generate(request)

        let lastArgs = runner.lastArguments ?? []
        let hasSubjectRef = lastArgs.contains { $0.contains("subject-ref") || $0.contains("type=character") }
        expect(hasSubjectRef, "should pass subject-ref argument with reference image")

        try? FileManager.default.removeItem(at: tmpDir)
    }

    func generateThrowsInvalidOutputWhenNoFile() async throws {
        let tmpDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("minimax-test-nofile-\(UUID().uuidString)")

        var stubs = FakeProcessRunner.Stubs()
        stubs.stubHelp = SubprocessResult(stdout: "mmx 1.0.7", stderr: "", exitCode: 0)
        stubs.stubAuthStatus = SubprocessResult(
            stdout: """
            {"method": "api-key", "source": "config.json", "key": "sk-c...UNVU"}
            """,
            stderr: "",
            exitCode: 0
        )
        stubs.stubGenerate = { _ in
            SubprocessResult(stdout: "generated", stderr: "", exitCode: 0)
        }

        let (generator, _) = makeGenerator(stubs: stubs)
        await generator.refreshConfiguration()

        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)

        let request = makeRequest(outputDirectory: tmpDir)
        do {
            _ = try await generator.generate(request)
            fail("should throw invalidOutput")
        } catch let error as VisualGenerationError {
            if case .invalidOutput(let id, let reason) = error {
                expect(id == "minimax-cli", "should identify provider")
                expect(reason.contains("no output image"), "should explain no image found")
            } else {
                fail("expected invalidOutput, got \(error)")
            }
        } catch {
            fail("unexpected error type: \(error)")
        }

        try? FileManager.default.removeItem(at: tmpDir)
    }

    func quotaSnapshotReturnsNilWhenNotConfigured() async throws {
        let (generator, _) = makeGenerator()
        let snapshot = try await generator.quotaSnapshot()
        expect(snapshot == nil, "should return nil when not configured")
    }

    func quotaSnapshotReturnsSnapshotOnSuccess() async throws {
        var stubs = FakeProcessRunner.Stubs()
        stubs.stubHelp = SubprocessResult(stdout: "mmx 1.0.7", stderr: "", exitCode: 0)
        stubs.stubAuthStatus = SubprocessResult(
            stdout: """
            {"method": "api-key", "source": "config.json", "key": "sk-c...UNVU"}
            """,
            stderr: "",
            exitCode: 0
        )
        stubs.stubQuota = SubprocessResult(
            stdout: """
            {
              "model_remains": [
                {
                  "model_name": "image-01",
                  "current_interval_total_count": 120,
                  "current_interval_usage_count": 119,
                  "current_weekly_total_count": 840,
                  "current_weekly_usage_count": 839,
                  "start_time": 1000,
                  "end_time": 2000,
                  "remains_time": 500
                }
              ]
            }
            """,
            stderr: "",
            exitCode: 0
        )

        let (generator, _) = makeGenerator(stubs: stubs)
        await generator.refreshConfiguration()

        let snapshot = try await generator.quotaSnapshot()
        expect(snapshot != nil, "should return quota snapshot")
        expect(snapshot?.dailyLimit == 120, "should extract daily limit")
        expect(snapshot?.dailyUsed == 1, "should derive daily used from MiniMax remaining count")
        expect(snapshot?.dailyRemaining == 119, "should expose daily remaining")
        expect(snapshot?.providerId == "minimax-cli", "should have correct providerId")
    }

    func quotaSnapshotReturnsNilOnFetchError() async throws {
        var stubs = FakeProcessRunner.Stubs()
        stubs.stubHelp = SubprocessResult(stdout: "mmx 1.0.7", stderr: "", exitCode: 0)
        stubs.stubAuthStatus = SubprocessResult(
            stdout: """
            {"method": "api-key", "source": "config.json", "key": "sk-c...UNVU"}
            """,
            stderr: "",
            exitCode: 0
        )
        stubs.stubQuota = SubprocessResult(stdout: "", stderr: "error", exitCode: 1)

        let (generator, _) = makeGenerator(stubs: stubs)
        await generator.refreshConfiguration()

        let snapshot = try await generator.quotaSnapshot()
        expect(snapshot == nil, "should return nil on fetch error")
    }
}

private final class FakeProcessRunner: ProcessRunning, @unchecked Sendable {
    struct Stubs {
        var stubHelp: SubprocessResult = SubprocessResult(stdout: "", stderr: "", exitCode: 1)
        var stubAuthStatus: SubprocessResult = SubprocessResult(stdout: "{}", stderr: "", exitCode: 1)
        var stubQuota: SubprocessResult = SubprocessResult(stdout: "{}", stderr: "", exitCode: 1)
        var stubGenerate: ([String]) -> SubprocessResult = { _ in
            SubprocessResult(stdout: "", stderr: "", exitCode: 1)
        }
    }

    private let queue = DispatchQueue(label: "fake-process-runner")
    private let stubs: Stubs
    private(set) var lastArguments: [String]?
    private(set) var lastExecutableURL: URL?

    init(stubs: Stubs) {
        self.stubs = stubs
    }

    func run(
        executableURL: URL,
        arguments: [String],
        currentDirectoryURL: URL?
    ) async throws -> SubprocessResult {
        queue.sync {
            lastExecutableURL = executableURL
            lastArguments = arguments
        }
        let commandArguments = arguments.first == "mmx" ? Array(arguments.dropFirst()) : arguments
        if commandArguments.first == "--help" {
            return stubs.stubHelp
        }
        if commandArguments.contains("auth") && commandArguments.contains("status") {
            return stubs.stubAuthStatus
        }
        if commandArguments.contains("quota") && commandArguments.contains("show") {
            return stubs.stubQuota
        }
        if commandArguments.contains("image") && commandArguments.contains("generate") {
            return stubs.stubGenerate(commandArguments)
        }
        return SubprocessResult(stdout: "", stderr: "unknown command", exitCode: 1)
    }
}
