import AppKit
import CryptoKit
import Foundation

public protocol GenerationDiagnosticsRecording: Sendable {
    func beginRecord(requestId: String, petId: String) -> GenerationDiagnosticsRecord
    func recordPrompt(_ record: inout GenerationDiagnosticsRecord, finalPrompt: String)
    func recordReferenceImage(_ record: inout GenerationDiagnosticsRecord, info: ReferenceImageInfo)
    func recordProviderParams(_ record: inout GenerationDiagnosticsRecord, params: ProviderParamsSnapshot)
    func recordOutput(_ record: inout GenerationDiagnosticsRecord, info: OutputImageInfo)
    func recordGateResult(_ record: inout GenerationDiagnosticsRecord, result: GenerationDiagnosticsGateResult)
    func recordUserAction(_ record: inout GenerationDiagnosticsRecord, action: DiagnosticsUserAction)
    func finalize(_ record: GenerationDiagnosticsRecord) throws -> URL
    func loadRecord(requestId: String) throws -> GenerationDiagnosticsRecord
    func recentRecords(limit: Int) -> [GenerationDiagnosticsRecord]
    func cleanup(olderThan days: Int) throws
    func referenceImageInfo(for url: URL, petId: String) throws -> ReferenceImageInfo
    func outputImageInfo(for url: URL) throws -> OutputImageInfo
}

public struct GenerationDiagnosticsRecord: Codable, Sendable, Equatable {
    public let requestId: String
    public let petId: String
    public var createdAt: Date

    public var finalPrompt: String?
    public var promptDigest: String?
    public var referenceImage: ReferenceImageInfo?
    public var providerParams: ProviderParamsSnapshot?

    public var outputImage: OutputImageInfo?
    public var gateResult: GenerationDiagnosticsGateResult?
    public var userAction: DiagnosticsUserAction?
    public var appliedAt: Date?

    public var generationDurationSeconds: Double?
    public var errorMessage: String?

    public init(
        requestId: String,
        petId: String,
        createdAt: Date = Date(),
        finalPrompt: String? = nil,
        promptDigest: String? = nil,
        referenceImage: ReferenceImageInfo? = nil,
        providerParams: ProviderParamsSnapshot? = nil,
        outputImage: OutputImageInfo? = nil,
        gateResult: GenerationDiagnosticsGateResult? = nil,
        userAction: DiagnosticsUserAction? = nil,
        appliedAt: Date? = nil,
        generationDurationSeconds: Double? = nil,
        errorMessage: String? = nil
    ) {
        self.requestId = requestId
        self.petId = petId
        self.createdAt = createdAt
        self.finalPrompt = finalPrompt
        self.promptDigest = promptDigest
        self.referenceImage = referenceImage
        self.providerParams = providerParams
        self.outputImage = outputImage
        self.gateResult = gateResult
        self.userAction = userAction
        self.appliedAt = appliedAt
        self.generationDurationSeconds = generationDurationSeconds
        self.errorMessage = errorMessage
    }
}

public struct ReferenceImageInfo: Codable, Sendable, Equatable {
    public let path: String
    public let exists: Bool
    public let width: Int
    public let height: Int
    public let hasAlpha: Bool
    public let fileSizeBytes: Int
    public let digest: String

    public init(
        path: String,
        exists: Bool,
        width: Int,
        height: Int,
        hasAlpha: Bool,
        fileSizeBytes: Int,
        digest: String
    ) {
        self.path = path
        self.exists = exists
        self.width = width
        self.height = height
        self.hasAlpha = hasAlpha
        self.fileSizeBytes = fileSizeBytes
        self.digest = digest
    }
}

public struct OutputImageInfo: Codable, Sendable, Equatable {
    public let width: Int
    public let height: Int
    public let hasAlpha: Bool
    public let fileSizeBytes: Int
    public let dominantColors: [String]
    public let backgroundColor: String?
    public let visibleAreaRatio: Double

    public init(
        width: Int,
        height: Int,
        hasAlpha: Bool,
        fileSizeBytes: Int,
        dominantColors: [String],
        backgroundColor: String?,
        visibleAreaRatio: Double
    ) {
        self.width = width
        self.height = height
        self.hasAlpha = hasAlpha
        self.fileSizeBytes = fileSizeBytes
        self.dominantColors = dominantColors
        self.backgroundColor = backgroundColor
        self.visibleAreaRatio = visibleAreaRatio
    }
}

public struct ProviderParamsSnapshot: Codable, Sendable, Equatable {
    public let providerId: String
    public let model: String?
    public let subjectRefIncluded: Bool
    public let widthRequested: Int?
    public let heightRequested: Int?
    public let seed: Int?
    public let cliVersion: String?
    public let cliArgvSummary: String?

    public init(
        providerId: String,
        model: String? = nil,
        subjectRefIncluded: Bool,
        widthRequested: Int? = nil,
        heightRequested: Int? = nil,
        seed: Int? = nil,
        cliVersion: String? = nil,
        cliArgvSummary: String? = nil
    ) {
        self.providerId = providerId
        self.model = model
        self.subjectRefIncluded = subjectRefIncluded
        self.widthRequested = widthRequested
        self.heightRequested = heightRequested
        self.seed = seed
        self.cliVersion = cliVersion
        self.cliArgvSummary = cliArgvSummary
    }
}

public struct GenerationDiagnosticsGateResult: Codable, Sendable, Equatable {
    public let verdict: String
    public let reason: String?

    public init(verdict: String, reason: String? = nil) {
        self.verdict = verdict
        self.reason = reason
    }
}

public enum DiagnosticsUserAction: String, Codable, Sendable {
    case applied
    case discarded
    case retried
    case feedbackNotLikeOriginal
    case feedbackStyleWrong
    case feedbackColorWrong
    case feedbackAccessoryLost
    case feedbackGoodDirection
}

public enum GenerationDiagnosticsError: Error, Equatable, LocalizedError {
    case imageDataUnavailable(path: String)
    case imageMetadataUnavailable(path: String)
    case recordNotFound(requestId: String)

    public var errorDescription: String? {
        switch self {
        case .imageDataUnavailable(let path):
            return "Image data unavailable: \(path)"
        case .imageMetadataUnavailable(let path):
            return "Image metadata unavailable: \(path)"
        case .recordNotFound(let requestId):
            return "Generation diagnostics record not found: \(requestId)"
        }
    }
}

public final class GenerationDiagnosticsStore: GenerationDiagnosticsRecording, @unchecked Sendable {
    private let baseDirectory: URL
    private let fileManager: FileManager
    private let lock = NSLock()

    public init(
        baseDirectory: URL? = nil,
        fileManager: FileManager = .default
    ) {
        self.baseDirectory = baseDirectory ?? PetVisualAssetStore.defaultBaseDirectory()
        self.fileManager = fileManager
    }

    public func beginRecord(requestId: String, petId: String) -> GenerationDiagnosticsRecord {
        GenerationDiagnosticsRecord(requestId: requestId, petId: petId)
    }

    public func recordPrompt(_ record: inout GenerationDiagnosticsRecord, finalPrompt: String) {
        record.finalPrompt = finalPrompt
        record.promptDigest = PetVisualAssetStore.digestPrompt(finalPrompt)
    }

    public func recordReferenceImage(_ record: inout GenerationDiagnosticsRecord, info: ReferenceImageInfo) {
        record.referenceImage = info
    }

    public func recordProviderParams(_ record: inout GenerationDiagnosticsRecord, params: ProviderParamsSnapshot) {
        record.providerParams = params
    }

    public func recordOutput(_ record: inout GenerationDiagnosticsRecord, info: OutputImageInfo) {
        record.outputImage = info
    }

    public func recordGateResult(_ record: inout GenerationDiagnosticsRecord, result: GenerationDiagnosticsGateResult) {
        record.gateResult = result
    }

    public func recordUserAction(_ record: inout GenerationDiagnosticsRecord, action: DiagnosticsUserAction) {
        record.userAction = action
        if action == .applied {
            record.appliedAt = Date()
        }
    }

    public func finalize(_ record: GenerationDiagnosticsRecord) throws -> URL {
        lock.lock()
        defer { lock.unlock() }

        let url = diagnosticsDirectory(petId: record.petId)
            .appendingPathComponent("\(record.requestId).json")
        try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        var redacted = record
        redacted.errorMessage = redactLocalPaths(redacted.errorMessage)
        if let params = redacted.providerParams {
            redacted.providerParams = ProviderParamsSnapshot(
                providerId: params.providerId,
                model: params.model,
                subjectRefIncluded: params.subjectRefIncluded,
                widthRequested: params.widthRequested,
                heightRequested: params.heightRequested,
                seed: params.seed,
                cliVersion: params.cliVersion,
                cliArgvSummary: redactLocalPaths(params.cliArgvSummary)
            )
        }
        let data = try encoder.encode(redacted)
        try data.write(to: url, options: [.atomic])
        return url
    }

    public func loadRecord(requestId: String) throws -> GenerationDiagnosticsRecord {
        lock.lock()
        defer { lock.unlock() }

        for url in diagnosticsFileURLs() where url.deletingPathExtension().lastPathComponent == requestId {
            return try decodeRecord(at: url)
        }
        throw GenerationDiagnosticsError.recordNotFound(requestId: requestId)
    }

    public func recentRecords(limit: Int) -> [GenerationDiagnosticsRecord] {
        lock.lock()
        defer { lock.unlock() }

        return diagnosticsFileURLs()
            .compactMap { try? decodeRecord(at: $0) }
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(max(limit, 0))
            .map { $0 }
    }

    public func cleanup(olderThan days: Int) throws {
        lock.lock()
        defer { lock.unlock() }

        let cutoff = Date().addingTimeInterval(-Double(max(days, 0)) * 24 * 60 * 60)
        for url in diagnosticsFileURLs() {
            guard let record = try? decodeRecord(at: url), record.createdAt < cutoff else { continue }
            try fileManager.removeItem(at: url)
        }
    }

    public func referenceImageInfo(for url: URL, petId: String) throws -> ReferenceImageInfo {
        let image = try loadImageMetadata(at: url)
        return ReferenceImageInfo(
            path: privatePath(for: url, petId: petId),
            exists: fileManager.fileExists(atPath: url.path),
            width: image.width,
            height: image.height,
            hasAlpha: image.hasAlpha,
            fileSizeBytes: try fileSizeBytes(at: url),
            digest: try digest(at: url)
        )
    }

    public func outputImageInfo(for url: URL) throws -> OutputImageInfo {
        let image = try loadImageMetadata(at: url)
        let colors = analyzeColors(in: image.rep)
        return OutputImageInfo(
            width: image.width,
            height: image.height,
            hasAlpha: image.hasAlpha,
            fileSizeBytes: try fileSizeBytes(at: url),
            dominantColors: colors.dominantColors,
            backgroundColor: colors.backgroundColor,
            visibleAreaRatio: colors.visibleAreaRatio
        )
    }

    private func diagnosticsDirectory(petId: String) -> URL {
        baseDirectory
            .appendingPathComponent(petId)
            .appendingPathComponent("visual-actions")
            .appendingPathComponent("diagnostics")
    }

    private func diagnosticsFileURLs() -> [URL] {
        guard let enumerator = fileManager.enumerator(
            at: baseDirectory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return enumerator
            .compactMap { $0 as? URL }
            .filter { $0.pathExtension == "json" && $0.deletingLastPathComponent().lastPathComponent == "diagnostics" }
    }

    private func decodeRecord(at url: URL) throws -> GenerationDiagnosticsRecord {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(GenerationDiagnosticsRecord.self, from: data)
    }

    private func loadImageMetadata(at url: URL) throws -> ImageMetadata {
        guard let data = try? Data(contentsOf: url) else {
            throw GenerationDiagnosticsError.imageDataUnavailable(path: url.lastPathComponent)
        }
        guard let rep = NSBitmapImageRep(data: data) else {
            throw GenerationDiagnosticsError.imageMetadataUnavailable(path: url.lastPathComponent)
        }
        return ImageMetadata(
            rep: rep,
            width: rep.pixelsWide,
            height: rep.pixelsHigh,
            hasAlpha: rep.hasAlpha
        )
    }

    private func analyzeColors(in rep: NSBitmapImageRep) -> ColorAnalysis {
        guard rep.pixelsWide > 0, rep.pixelsHigh > 0 else {
            return ColorAnalysis(dominantColors: [], backgroundColor: nil, visibleAreaRatio: 0)
        }

        var colorCounts: [String: Int] = [:]
        var edgeCounts: [String: Int] = [:]
        var visiblePixels = 0
        let totalPixels = rep.pixelsWide * rep.pixelsHigh

        for y in 0..<rep.pixelsHigh {
            for x in 0..<rep.pixelsWide {
                guard let sample = pixelSample(in: rep, x: x, y: y), sample.alpha >= 0.05 else {
                    continue
                }
                visiblePixels += 1

                let hex = sample.hex
                colorCounts[hex, default: 0] += 1
                if x == 0 || y == 0 || x == rep.pixelsWide - 1 || y == rep.pixelsHigh - 1 {
                    edgeCounts[hex, default: 0] += 1
                }
            }
        }

        let dominantColors = colorCounts
            .sorted { lhs, rhs in
                if lhs.value == rhs.value { return lhs.key < rhs.key }
                return lhs.value > rhs.value
            }
            .prefix(5)
            .map(\.key)

        let backgroundColor = edgeCounts
            .sorted { lhs, rhs in
                if lhs.value == rhs.value { return lhs.key < rhs.key }
                return lhs.value > rhs.value
            }
            .first?
            .key

        let visibleAreaRatio = totalPixels == 0 ? 0 : Double(visiblePixels) / Double(totalPixels)
        return ColorAnalysis(
            dominantColors: dominantColors,
            backgroundColor: backgroundColor,
            visibleAreaRatio: roundedRatio(visibleAreaRatio)
        )
    }

    private func pixelSample(in rep: NSBitmapImageRep, x: Int, y: Int) -> PixelSample? {
        if let data = rep.bitmapData,
           !rep.isPlanar,
           rep.bitsPerSample == 8,
           rep.samplesPerPixel >= 3 {
            let bytesPerPixel = max(rep.bitsPerPixel / 8, rep.samplesPerPixel)
            let offset = y * rep.bytesPerRow + x * bytesPerPixel
            let alphaFirst = rep.hasAlpha && rep.bitmapFormat.contains(.alphaFirst)
            let redIndex = alphaFirst ? 1 : 0
            let greenIndex = redIndex + 1
            let blueIndex = redIndex + 2
            let alphaIndex = rep.hasAlpha ? (alphaFirst ? 0 : rep.samplesPerPixel - 1) : nil
            let maxIndex = max(redIndex, greenIndex, blueIndex, alphaIndex ?? 0)
            guard rep.samplesPerPixel > maxIndex, offset + maxIndex < (y + 1) * rep.bytesPerRow else {
                return nil
            }

            let alpha = alphaIndex.map { Double(data[offset + $0]) / 255.0 } ?? 1
            return PixelSample(
                hex: hexColor(
                    red: Int(data[offset + redIndex]),
                    green: Int(data[offset + greenIndex]),
                    blue: Int(data[offset + blueIndex])
                ),
                alpha: alpha
            )
        }

        guard let color = rep.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else {
            return nil
        }
        return PixelSample(
            hex: hexColor(
                red: max(0, min(255, Int((color.redComponent * 255).rounded()))),
                green: max(0, min(255, Int((color.greenComponent * 255).rounded()))),
                blue: max(0, min(255, Int((color.blueComponent * 255).rounded())))
            ),
            alpha: color.alphaComponent
        )
    }

    private func hexColor(red: Int, green: Int, blue: Int) -> String {
        return String(format: "#%02X%02X%02X", red, green, blue)
    }

    private func roundedRatio(_ value: Double) -> Double {
        (value * 10_000).rounded() / 10_000
    }

    private func fileSizeBytes(at url: URL) throws -> Int {
        let attrs = try fileManager.attributesOfItem(atPath: url.path)
        return attrs[.size] as? Int ?? 0
    }

    private func digest(at url: URL) throws -> String {
        let data = try Data(contentsOf: url)
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func privatePath(for url: URL, petId: String) -> String {
        let petDirectory = baseDirectory.appendingPathComponent(petId)
        let relative = relativePath(of: url, under: petDirectory)
        if let relative {
            return relative
        }
        return "\(url.lastPathComponent)#\(shortDigest(for: url.path))"
    }

    private func relativePath(of url: URL, under base: URL) -> String? {
        let basePath = base.standardizedFileURL.path
        let fullPath = url.standardizedFileURL.path
        guard fullPath == basePath || fullPath.hasPrefix(basePath + "/") else {
            return nil
        }
        guard fullPath != basePath else {
            return ""
        }
        let start = fullPath.index(fullPath.startIndex, offsetBy: basePath.count + 1)
        return String(fullPath[start...])
    }

    private func shortDigest(for value: String) -> String {
        let digest = SHA256.hash(data: Data(value.utf8))
        return digest.prefix(8).map { String(format: "%02x", $0) }.joined()
    }

    private func redactLocalPaths(_ value: String?) -> String? {
        guard var value else { return nil }
        value = value.replacingOccurrences(of: baseDirectory.path, with: "<desktop-pet-data>")
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        value = value.replacingOccurrences(of: home, with: "~")
        return value
    }
}

private struct ImageMetadata {
    let rep: NSBitmapImageRep
    let width: Int
    let height: Int
    let hasAlpha: Bool
}

private struct ColorAnalysis {
    let dominantColors: [String]
    let backgroundColor: String?
    let visibleAreaRatio: Double
}

private struct PixelSample {
    let hex: String
    let alpha: Double
}
