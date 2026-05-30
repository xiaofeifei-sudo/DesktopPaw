import AppKit
import Foundation

// MARK: - D-5.1 Gate Result Models

public enum GateVerdict: String, Codable, Sendable, Equatable {
    case pass
    case warn
    case fail
}

public enum RiskLevel: String, Codable, Sendable, Equatable {
    case low
    case medium
    case high
    case unacceptable
}

public enum GateAutoAction: String, Codable, Sendable, Equatable {
    case applyDirectly
    case requirePreview
    case rejectWithMessage
}

public struct GateResult: Codable, Sendable, Equatable {
    public let overall: GateVerdict
    public let checks: [GateCheckResult]
    public let riskLevel: RiskLevel
    public let userFacingMessage: String?
    public let autoAction: GateAutoAction

    public init(
        overall: GateVerdict,
        checks: [GateCheckResult],
        riskLevel: RiskLevel,
        userFacingMessage: String?,
        autoAction: GateAutoAction
    ) {
        self.overall = overall
        self.checks = checks
        self.riskLevel = riskLevel
        self.userFacingMessage = userFacingMessage
        self.autoAction = autoAction
    }
}

// MARK: - D-5.2 Gate Check Models

public enum GateCheckType: String, Codable, Sendable, Equatable, CaseIterable {
    case size
    case alpha
    case dominantColor
    case background
    case visibleAreaRatio
    case centering
}

public struct GateCheckResult: Codable, Sendable, Equatable {
    public let checkType: GateCheckType
    public let passed: Bool
    public let score: Double
    public let detail: String

    public init(checkType: GateCheckType, passed: Bool, score: Double, detail: String) {
        self.checkType = checkType
        self.passed = passed
        self.score = score
        self.detail = detail
    }
}

// MARK: - D-5.3 Protocol

public protocol QualityGateChecking: Sendable {
    func evaluate(
        reference: ImageSnapshot,
        output: URL,
        petDescriptor: PetDescriptor,
        preference: ConsistencyPreference
    ) async throws -> GateResult
}

// MARK: - D-5.4–D-5.14 Quality Gate Implementation

public final class QualityGateStore: QualityGateChecking, @unchecked Sendable {

    private struct GateThresholds {
        let minOutputSize: Int
        let colorSimilarityMin: Double
        let maxBackgroundRatio: Double
        let minVisibleArea: Double
        let maxVisibleArea: Double
        let maxCenterOffset: Double

        static func forPreference(_ preference: ConsistencyPreference) -> GateThresholds {
            switch preference {
            case .conservative:
                return GateThresholds(
                    minOutputSize: 128,
                    colorSimilarityMin: 0.6,
                    maxBackgroundRatio: 0.70,
                    minVisibleArea: 0.15,
                    maxVisibleArea: 0.85,
                    maxCenterOffset: 0.15
                )
            case .balanced:
                return GateThresholds(
                    minOutputSize: 128,
                    colorSimilarityMin: 0.5,
                    maxBackgroundRatio: 0.80,
                    minVisibleArea: 0.10,
                    maxVisibleArea: 0.90,
                    maxCenterOffset: 0.20
                )
            case .creative:
                return GateThresholds(
                    minOutputSize: 128,
                    colorSimilarityMin: 0.4,
                    maxBackgroundRatio: 0.90,
                    minVisibleArea: 0.05,
                    maxVisibleArea: 0.95,
                    maxCenterOffset: 0.25
                )
            }
        }
    }

    private struct OutputAnalysis {
        let width: Int
        let height: Int
        let hasAlpha: Bool
        let dominantColors: [String]
        let backgroundColor: String?
        let backgroundRatio: Double
        let visibleAreaRatio: Double
        let centroidX: Double
        let centroidY: Double
    }

    public init() {}

    public func evaluate(
        reference: ImageSnapshot,
        output: URL,
        petDescriptor: PetDescriptor,
        preference: ConsistencyPreference
    ) async throws -> GateResult {
        let thresholds = GateThresholds.forPreference(preference)
        let analysis = try analyzeOutput(at: output)

        var checks: [GateCheckResult] = []
        checks.append(checkSize(analysis, thresholds: thresholds))
        checks.append(checkAlpha(analysis, reference: reference))
        checks.append(checkDominantColor(analysis, reference: reference, thresholds: thresholds))
        checks.append(checkBackground(analysis, reference: reference, thresholds: thresholds))
        checks.append(checkVisibleAreaRatio(analysis, reference: reference, thresholds: thresholds))
        checks.append(checkCentering(analysis, thresholds: thresholds))

        let verdict = determineVerdict(checks)
        let riskLevel = determineRiskLevel(checks: checks, verdict: verdict)
        let autoAction = determineAutoAction(verdict: verdict, riskLevel: riskLevel)
        let message = userFacingMessage(for: autoAction)

        return GateResult(
            overall: verdict,
            checks: checks,
            riskLevel: riskLevel,
            userFacingMessage: message,
            autoAction: autoAction
        )
    }

    // MARK: - D-5.4 Size Check

    private func checkSize(_ analysis: OutputAnalysis, thresholds: GateThresholds) -> GateCheckResult {
        let minDim = min(analysis.width, analysis.height)
        let passed = minDim >= thresholds.minOutputSize
        let score = min(1.0, Double(minDim) / Double(thresholds.minOutputSize))
        return GateCheckResult(
            checkType: .size,
            passed: passed,
            score: score,
            detail: "Output \(analysis.width)x\(analysis.height), min required \(thresholds.minOutputSize)"
        )
    }

    // MARK: - D-5.5 Alpha Check

    private func checkAlpha(_ analysis: OutputAnalysis, reference: ImageSnapshot) -> GateCheckResult {
        guard reference.hasAlpha else {
            return GateCheckResult(checkType: .alpha, passed: true, score: 1.0, detail: "Reference has no alpha, skipped")
        }
        let passed = analysis.hasAlpha
        return GateCheckResult(
            checkType: .alpha,
            passed: passed,
            score: passed ? 1.0 : 0.0,
            detail: passed ? "Output has alpha" : "Reference has alpha but output does not"
        )
    }

    // MARK: - D-5.6 & D-5.7 Dominant Color Similarity

    private func checkDominantColor(
        _ analysis: OutputAnalysis,
        reference: ImageSnapshot,
        thresholds: GateThresholds
    ) -> GateCheckResult {
        let refColors = reference.dominantColors
        let outColors = analysis.dominantColors

        guard !refColors.isEmpty else {
            return GateCheckResult(checkType: .dominantColor, passed: true, score: 1.0, detail: "No reference colors")
        }
        guard !outColors.isEmpty else {
            return GateCheckResult(checkType: .dominantColor, passed: false, score: 0.0, detail: "No output colors")
        }

        let score = paletteSimilarity(reference: refColors, output: outColors)
        let passed = score >= thresholds.colorSimilarityMin
        return GateCheckResult(
            checkType: .dominantColor,
            passed: passed,
            score: rounded(score),
            detail: String(format: "Similarity %.3f (threshold %.2f)", score, thresholds.colorSimilarityMin)
        )
    }

    // MARK: - D-5.8 Background Check

    private func checkBackground(
        _ analysis: OutputAnalysis,
        reference: ImageSnapshot,
        thresholds: GateThresholds
    ) -> GateCheckResult {
        guard reference.hasAlpha else {
            return GateCheckResult(checkType: .background, passed: true, score: 1.0, detail: "Reference has no alpha, skipped")
        }
        let passed = analysis.backgroundRatio <= thresholds.maxBackgroundRatio
        let score = max(0, 1.0 - analysis.backgroundRatio)
        return GateCheckResult(
            checkType: .background,
            passed: passed,
            score: rounded(score),
            detail: String(format: "Background %.2f (max %.2f)", analysis.backgroundRatio, thresholds.maxBackgroundRatio)
        )
    }

    // MARK: - D-5.9 Visible Area Ratio

    private func checkVisibleAreaRatio(_ analysis: OutputAnalysis, reference: ImageSnapshot, thresholds: GateThresholds) -> GateCheckResult {
        let inRange = analysis.visibleAreaRatio >= thresholds.minVisibleArea
            && (reference.hasAlpha ? analysis.visibleAreaRatio <= thresholds.maxVisibleArea : true)
        return GateCheckResult(
            checkType: .visibleAreaRatio,
            passed: inRange,
            score: analysis.visibleAreaRatio,
            detail: String(format: "Visible area %.2f (range %.2f–%.2f)",
                           analysis.visibleAreaRatio, thresholds.minVisibleArea, thresholds.maxVisibleArea)
        )
    }

    // MARK: - D-5.10 Centering

    private func checkCentering(_ analysis: OutputAnalysis, thresholds: GateThresholds) -> GateCheckResult {
        guard analysis.visibleAreaRatio > 0 else {
            return GateCheckResult(checkType: .centering, passed: true, score: 1.0, detail: "No visible pixels")
        }
        let dx = analysis.centroidX - 0.5
        let dy = analysis.centroidY - 0.5
        let distance = sqrt(dx * dx + dy * dy)
        let diagonal = sqrt(0.5 * 0.5 + 0.5 * 0.5)
        let normalized = distance / diagonal
        let passed = normalized <= thresholds.maxCenterOffset
        let score = max(0, 1.0 - normalized)
        return GateCheckResult(
            checkType: .centering,
            passed: passed,
            score: rounded(score),
            detail: String(format: "Offset %.3f (max %.2f)", normalized, thresholds.maxCenterOffset)
        )
    }

    // MARK: - D-5.11 Decision Logic

    private func determineVerdict(_ checks: [GateCheckResult]) -> GateVerdict {
        let failed = checks.filter { !$0.passed }.count
        switch failed {
        case 0: return .pass
        case 1: return .warn
        default: return .fail
        }
    }

    // MARK: - D-5.12 Risk Level & Auto Action

    private func determineRiskLevel(checks: [GateCheckResult], verdict: GateVerdict) -> RiskLevel {
        let colorCheck = checks.first(where: { $0.checkType == .dominantColor })

        if let color = colorCheck, color.score < 0.3 {
            return .unacceptable
        }
        if let color = colorCheck, color.score < 0.4 {
            return .high
        }
        let failed = checks.filter { !$0.passed }.count
        if failed >= 3 {
            return .high
        }
        if failed >= 1 {
            return .medium
        }
        return .low
    }

    private func determineAutoAction(verdict: GateVerdict, riskLevel: RiskLevel) -> GateAutoAction {
        switch riskLevel {
        case .unacceptable:
            return .rejectWithMessage
        case .high:
            return .requirePreview
        case .medium:
            return verdict == .pass ? .applyDirectly : .requirePreview
        case .low:
            return verdict == .pass ? .applyDirectly : .requirePreview
        }
    }

    // MARK: - D-5.13 Preference handled via GateThresholds.forPreference

    // MARK: - D-5.14 User-Facing Messages

    private func userFacingMessage(for autoAction: GateAutoAction) -> String? {
        switch autoAction {
        case .rejectWithMessage:
            return "这次结果和原形象差异较大，已为你保留原样。"
        case .requirePreview:
            return "生成完成，请确认是否应用这次变化。"
        case .applyDirectly:
            return nil
        }
    }

    // MARK: - Output Image Analysis

    private func analyzeOutput(at url: URL) throws -> OutputAnalysis {
        guard let data = try? Data(contentsOf: url) else {
            throw QualityGateError.imageLoadFailed
        }
        guard let rep = NSBitmapImageRep(data: data) else {
            throw QualityGateError.imageAnalysisFailed
        }

        let w = rep.pixelsWide
        let h = rep.pixelsHigh
        let totalPixels = w * h

        guard totalPixels > 0 else {
            return OutputAnalysis(
                width: w, height: h, hasAlpha: rep.hasAlpha,
                dominantColors: [], backgroundColor: nil, backgroundRatio: 0,
                visibleAreaRatio: 0, centroidX: 0.5, centroidY: 0.5
            )
        }

        var colorCounts: [String: Int] = [:]
        var edgeColorCounts: [String: Int] = [:]
        var visiblePixels = 0
        var sumX: Double = 0
        var sumY: Double = 0

        for y in 0..<h {
            for x in 0..<w {
                let sample = pixelSample(in: rep, x: x, y: y)
                guard let sample, sample.alpha >= 0.05 else { continue }

                visiblePixels += 1
                sumX += Double(x)
                sumY += Double(y)
                colorCounts[sample.hex, default: 0] += 1

                if x == 0 || y == 0 || x == w - 1 || y == h - 1 {
                    edgeColorCounts[sample.hex, default: 0] += 1
                }
            }
        }

        let dominantColors = colorCounts
            .sorted { $0.value > $1.value }
            .prefix(5)
            .map(\.key)

        let backgroundColor = edgeColorCounts
            .sorted { $0.value > $1.value }
            .first?.key

        let backgroundRatio: Double
        if let bg = backgroundColor, let bgCount = colorCounts[bg] {
            backgroundRatio = Double(bgCount) / Double(totalPixels)
        } else {
            backgroundRatio = 0
        }

        let visibleAreaRatio = Double(visiblePixels) / Double(totalPixels)
        let centroidX = visiblePixels == 0 ? 0.5 : (sumX / Double(visiblePixels)) / Double(w)
        let centroidY = visiblePixels == 0 ? 0.5 : (sumY / Double(visiblePixels)) / Double(h)

        return OutputAnalysis(
            width: w, height: h, hasAlpha: rep.hasAlpha,
            dominantColors: dominantColors,
            backgroundColor: backgroundColor,
            backgroundRatio: rounded(backgroundRatio),
            visibleAreaRatio: rounded(visibleAreaRatio),
            centroidX: centroidX,
            centroidY: centroidY
        )
    }

    // MARK: - Color Similarity

    private func paletteSimilarity(reference: [String], output: [String]) -> Double {
        let refVecs = reference.compactMap(hexToVector)
        let outVecs = output.compactMap(hexToVector)
        guard !refVecs.isEmpty, !outVecs.isEmpty else { return 0 }

        var total = 0.0
        for ref in refVecs {
            var best = -1.0
            for out in outVecs {
                let sim = cosineSimilarity(ref, out)
                if sim > best { best = sim }
            }
            total += max(0, best)
        }
        return total / Double(refVecs.count)
    }

    private func cosineSimilarity(_ a: [Double], _ b: [Double]) -> Double {
        guard a.count == 3, b.count == 3 else { return 0 }
        let dot = a[0] * b[0] + a[1] * b[1] + a[2] * b[2]
        let magA = sqrt(a[0] * a[0] + a[1] * a[1] + a[2] * a[2])
        let magB = sqrt(b[0] * b[0] + b[1] * b[1] + b[2] * b[2])
        guard magA > 0, magB > 0 else { return 0 }
        return dot / (magA * magB)
    }

    private func hexToVector(_ hex: String) -> [Double]? {
        guard hex.hasPrefix("#"), hex.count == 7 else { return nil }
        let digits = hex.dropFirst(1)
        guard let r = Int(String(digits.prefix(2)), radix: 16),
              let g = Int(String(digits.dropFirst(2).prefix(2)), radix: 16),
              let b = Int(String(digits.suffix(2)), radix: 16) else { return nil }
        return [Double(r) / 255.0, Double(g) / 255.0, Double(b) / 255.0]
    }

    // MARK: - Pixel Sampling

    private struct PixelSample {
        let hex: String
        let alpha: Double
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
        guard let color = rep.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else { return nil }
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
        String(format: "#%02X%02X%02X", red, green, blue)
    }

    private func rounded(_ value: Double) -> Double {
        (value * 10_000).rounded() / 10_000
    }
}

public enum QualityGateError: Error, Equatable, LocalizedError {
    case imageLoadFailed
    case imageAnalysisFailed

    public var errorDescription: String? {
        switch self {
        case .imageLoadFailed: return "Failed to load output image for quality gate"
        case .imageAnalysisFailed: return "Failed to analyze output image for quality gate"
        }
    }
}
