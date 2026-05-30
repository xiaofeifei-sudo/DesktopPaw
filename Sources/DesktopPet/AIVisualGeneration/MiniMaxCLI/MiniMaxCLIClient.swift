import Foundation

public struct ExecutablePathResolver: Sendable {
    private let environmentPATH: String
    private let homeDirectory: URL

    public init(
        environmentPATH: String = ProcessInfo.processInfo.environment["PATH"] ?? "",
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) {
        self.environmentPATH = environmentPATH
        self.homeDirectory = homeDirectory
    }

    public func resolve(_ executableName: String) -> String? {
        guard !executableName.isEmpty, !executableName.contains("/") else {
            return nil
        }

        for directory in searchDirectories {
            let candidate = directory.appendingPathComponent(executableName)
            if FileManager.default.isExecutableFile(atPath: candidate.path) {
                return candidate.path
            }
        }

        return nil
    }

    public var searchPATH: String {
        searchDirectories.map(\.path).joined(separator: ":")
    }

    private var searchDirectories: [URL] {
        uniqueURLs(
            pathEnvironmentDirectories()
            + homeToolDirectories()
            + nvmNodeVersionDirectories()
            + fixedToolDirectories()
        )
    }

    private func pathEnvironmentDirectories() -> [URL] {
        environmentPATH
            .split(separator: ":", omittingEmptySubsequences: true)
            .map { expandedURL(forPath: String($0)) }
    }

    private func homeToolDirectories() -> [URL] {
        [
            ".local/bin",
            "bin",
            ".npm-global/bin",
            ".yarn/bin",
            ".bun/bin",
            ".volta/bin",
            ".asdf/shims",
            ".nodenv/shims"
        ].map { homeDirectory.appendingPathComponent($0, isDirectory: true) }
    }

    private func nvmNodeVersionDirectories() -> [URL] {
        let versionsDirectory = homeDirectory
            .appendingPathComponent(".nvm", isDirectory: true)
            .appendingPathComponent("versions", isDirectory: true)
            .appendingPathComponent("node", isDirectory: true)
        guard let versions = try? FileManager.default.contentsOfDirectory(
            at: versionsDirectory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return versions.compactMap { versionURL in
            guard isDirectory(versionURL) else { return nil }
            return versionURL.appendingPathComponent("bin", isDirectory: true)
        }
    }

    private func fixedToolDirectories() -> [URL] {
        [
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "/usr/bin",
            "/bin",
            "/usr/sbin",
            "/sbin"
        ].map { URL(fileURLWithPath: $0, isDirectory: true) }
    }

    private func expandedURL(forPath path: String) -> URL {
        if path == "~" {
            return homeDirectory
        }

        if path.hasPrefix("~/") {
            return homeDirectory.appendingPathComponent(String(path.dropFirst(2)), isDirectory: true)
        }

        return URL(fileURLWithPath: path, isDirectory: true)
    }

    private func isDirectory(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
    }

    private func uniqueURLs(_ urls: [URL]) -> [URL] {
        var seen = Set<String>()
        var result: [URL] = []

        for url in urls {
            let standardized = url.standardizedFileURL
            guard seen.insert(standardized.path).inserted else {
                continue
            }
            result.append(standardized)
        }

        return result
    }
}

public final class MiniMaxCLIClient: @unchecked Sendable {
    private let processRunner: ProcessRunning
    private let mmxPath: String?

    public static let defaultTimeout: TimeInterval = 90

    private static let autoResolvedPathLock = NSLock()
    private nonisolated(unsafe) static var _autoResolvedPath: String??

    private static func loadAutoResolvedPath() -> String? {
        autoResolvedPathLock.lock()
        let cached = _autoResolvedPath
        autoResolvedPathLock.unlock()
        if let cached { return cached }

        let final = ExecutablePathResolver().resolve("mmx")
        autoResolvedPathLock.lock()
        _autoResolvedPath = Optional(final)
        autoResolvedPathLock.unlock()
        return final
    }

    public static func detectedMMXPath() -> String? {
        loadAutoResolvedPath()
    }

    public init(processRunner: ProcessRunning, mmxPath: String? = nil) {
        self.processRunner = processRunner
        self.mmxPath = mmxPath
    }

    public func executableURL() -> URL? {
        if let path = effectiveMMXPath {
            return URL(fileURLWithPath: path)
        }
        return URL(fileURLWithPath: "/usr/bin/env")
    }

    public func checkAvailability() async -> Bool {
        guard let url = executableURL() else { return false }
        do {
            let result = try await processRunner.run(
                executableURL: url,
                arguments: mmxArguments(["--help"]),
                currentDirectoryURL: nil
            )
            return result.isSuccess || result.exitCode == 0
        } catch {
            return false
        }
    }

    public func checkAuthStatus() async throws -> MiniMaxAuthStatus {
        guard let url = executableURL() else {
            throw VisualGenerationError.notConfigured(providerId: MiniMaxCLIClient.providerId)
        }
        let result = try await processRunner.run(
            executableURL: url,
            arguments: mmxArguments(["auth", "status", "--output", "json"]),
            currentDirectoryURL: nil
        )
        guard result.isSuccess else {
            return MiniMaxAuthStatus(isAuthenticated: false)
        }
        return MiniMaxCLIQuotaParser.parseAuthStatus(from: result.stdout)
    }

    public func fetchQuotaRaw() async throws -> String {
        guard let url = executableURL() else {
            throw VisualGenerationError.notConfigured(providerId: MiniMaxCLIClient.providerId)
        }
        let result = try await processRunner.run(
            executableURL: url,
            arguments: mmxArguments(["quota", "show", "--output", "json"]),
            currentDirectoryURL: nil
        )
        guard result.isSuccess else {
            throw VisualGenerationError.unknown(
                providerId: MiniMaxCLIClient.providerId,
                underlying: "mmx quota show failed: \(result.stderr)"
            )
        }
        return result.stdout
    }

    public func generateImage(
        prompt: String,
        referenceImagePath: String?,
        outputDirectory: URL,
        outputPrefix: String
    ) async throws -> SubprocessResult {
        guard let url = executableURL() else {
            throw VisualGenerationError.notConfigured(providerId: MiniMaxCLIClient.providerId)
        }

        var arguments = [
            "image", "generate",
            "--prompt", prompt,
            "--aspect-ratio", "1:1",
            "--n", "1",
            "--output", "json",
            "--quiet",
            "--out-dir", outputDirectory.path,
            "--out-prefix", outputPrefix
        ]

        if let refPath = referenceImagePath {
            arguments += ["--subject-ref", "type=character,image=\(refPath)"]
        }

        return try await processRunner.run(
            executableURL: url,
            arguments: mmxArguments(arguments),
            currentDirectoryURL: outputDirectory
        )
    }

    public static let providerId = "minimax-cli"

    private var effectiveMMXPath: String? {
        let configured = mmxPath?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let path = configured, !path.isEmpty { return path }
        return Self.detectedMMXPath()
    }

    private func mmxArguments(_ arguments: [String]) -> [String] {
        effectiveMMXPath == nil ? ["mmx"] + arguments : arguments
    }
}

public final class RealProcessRunner: ProcessRunning, @unchecked Sendable {
    private let timeout: TimeInterval

    public init(timeout: TimeInterval = MiniMaxCLIClient.defaultTimeout) {
        self.timeout = timeout
    }

    public func run(
        executableURL: URL,
        arguments: [String],
        currentDirectoryURL: URL?
    ) async throws -> SubprocessResult {
        let task = Process()
        task.executableURL = executableURL
        task.arguments = arguments
        if let dir = currentDirectoryURL {
            task.currentDirectoryURL = dir
        }

        var environment = ProcessInfo.processInfo.environment
        var pathParts = [String]()
        let resolver = ExecutablePathResolver(environmentPATH: environment["PATH"] ?? "")
        pathParts.append(resolver.searchPATH)
        let execDir = executableURL.deletingLastPathComponent().path
        pathParts.append(execDir)
        pathParts.append(environment["PATH"] ?? "/usr/bin:/bin:/usr/sbin:/sbin")
        environment["PATH"] = Self.uniquePATH(pathParts.joined(separator: ":"))
        task.environment = environment

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        task.standardOutput = stdoutPipe
        task.standardError = stderrPipe

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global().async {
                do {
                    try task.run()
                    task.waitUntilExit()
                } catch {
                    continuation.resume(returning: SubprocessResult(
                        stdout: "",
                        stderr: error.localizedDescription,
                        exitCode: 1
                    ))
                    return
                }

                let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                continuation.resume(returning: SubprocessResult(
                    stdout: String(data: stdoutData, encoding: .utf8) ?? "",
                    stderr: String(data: stderrData, encoding: .utf8) ?? "",
                    exitCode: task.terminationStatus
                ))
            }
        }
    }

    private static func uniquePATH(_ path: String) -> String {
        var seen = Set<String>()
        var result: [String] = []

        for component in path.split(separator: ":", omittingEmptySubsequences: true).map(String.init) {
            guard seen.insert(component).inserted else {
                continue
            }
            result.append(component)
        }

        return result.joined(separator: ":")
    }
}
