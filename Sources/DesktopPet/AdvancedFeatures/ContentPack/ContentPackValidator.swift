import Foundation

public enum ContentPackValidationCode: String, Codable, Equatable, Sendable {
    case invalidPackageExtension
    case missingManifest
    case invalidManifest
    case missingContent
    case invalidContent
    case forbiddenContent
    case executableContent
    case restrictedOverride
}

public struct ContentPackValidationIssue: Codable, Equatable, Sendable {
    public let code: ContentPackValidationCode
    public let message: String

    public init(code: ContentPackValidationCode, message: String) {
        self.code = code
        self.message = message
    }
}

public struct ContentPackValidationResult: Codable, Equatable, Sendable {
    public let errors: [ContentPackValidationIssue]

    public init(errors: [ContentPackValidationIssue] = []) {
        self.errors = errors
    }

    public var isValid: Bool {
        errors.isEmpty
    }
}

public final class ContentPackValidator: @unchecked Sendable {
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func validatePack(at url: URL) -> ContentPackValidationResult {
        var errors: [ContentPackValidationIssue] = []

        guard url.pathExtension == "dpcp" else {
            errors.append(.init(code: .invalidPackageExtension, message: "内容包必须是 .dpcp 文件夹"))
            return ContentPackValidationResult(errors: errors)
        }

        let manifestURL = url.appendingPathComponent("manifest.json")
        guard fileManager.fileExists(atPath: manifestURL.path) else {
            errors.append(.init(code: .missingManifest, message: "缺少 manifest.json"))
            return ContentPackValidationResult(errors: errors)
        }

        let manifest: ContentPackManifest
        do {
            manifest = try ContentPackManifest.load(from: url)
        } catch {
            errors.append(.init(code: .invalidManifest, message: "manifest.json 格式错误：\(error.localizedDescription)"))
            return ContentPackValidationResult(errors: errors)
        }

        validateRequiredManifestFields(manifest, errors: &errors)
        validateRestrictedKeys(in: manifestURL, errors: &errors)
        validateExecutableFiles(under: url, errors: &errors)
        validateForbiddenText(under: url, errors: &errors)
        validateTypeSpecificContent(packURL: url, manifest: manifest, errors: &errors)

        return ContentPackValidationResult(errors: errors)
    }

    private func validateRequiredManifestFields(_ manifest: ContentPackManifest, errors: inout [ContentPackValidationIssue]) {
        let required = [
            manifest.id,
            manifest.name,
            manifest.author,
            manifest.version,
            manifest.description,
            manifest.compatiblePetVersion
        ]
        if required.contains(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
            errors.append(.init(code: .invalidManifest, message: "manifest 必填字段不能为空"))
        }
        if manifest.previewPhrases.isEmpty {
            errors.append(.init(code: .invalidManifest, message: "内容包必须提供预览短句"))
        }
    }

    private func validateTypeSpecificContent(
        packURL: URL,
        manifest: ContentPackManifest,
        errors: inout [ContentPackValidationIssue]
    ) {
        do {
            switch manifest.type {
            case .dialogue:
                _ = try DialoguePack.load(from: packURL, manifest: manifest)
            case .personality:
                _ = try PersonalityPack.load(from: packURL, manifest: manifest)
            case .action:
                _ = try ActionPack.load(from: packURL, manifest: manifest)
            }
        } catch {
            errors.append(.init(code: .invalidContent, message: "内容文件格式错误：\(error.localizedDescription)"))
        }
    }

    private func validateExecutableFiles(under root: URL, errors: inout [ContentPackValidationIssue]) {
        let executableExtensions: Set<String> = [
            "sh", "command", "app", "scpt", "applescript", "py", "rb", "js", "jar", "dylib", "so", "exe"
        ]
        let executableNames: Set<String> = ["makefile"]

        for fileURL in fileURLs(under: root) {
            let ext = fileURL.pathExtension.lowercased()
            let name = fileURL.lastPathComponent.lowercased()
            let pathComponents = fileURL.pathComponents.map { $0.lowercased() }
            if executableExtensions.contains(ext) || executableNames.contains(name) || pathComponents.contains("scripts") {
                errors.append(.init(code: .executableContent, message: "内容包不能包含可执行文件：\(fileURL.lastPathComponent)"))
            }
        }
    }

    private func validateRestrictedKeys(in manifestURL: URL, errors: inout [ContentPackValidationIssue]) {
        guard let object = try? JSONSerialization.jsonObject(with: Data(contentsOf: manifestURL)),
              let dictionary = object as? [String: Any] else {
            return
        }
        let restrictedKeys: Set<String> = [
            "safetyRules",
            "safetyOverride",
            "ignoreSafetyRules",
            "allowUnsafeContent",
            "frequencyOverride",
            "minimumIntervalSeconds",
            "bubbleFrequency",
            "quietMode"
        ]
        let manifestKeys = Set(dictionary.keys)
        if !manifestKeys.isDisjoint(with: restrictedKeys) {
            errors.append(.init(code: .restrictedOverride, message: "内容包不能覆盖安全、频率或安静模式设置"))
        }
    }

    private func validateForbiddenText(under root: URL, errors: inout [ContentPackValidationIssue]) {
        let forbiddenPatterns = [
            "PUA",
            "pua",
            "羞辱",
            "废物",
            "蠢货",
            "别和别人说",
            "只有我陪你",
            "不要离开我",
            "你是我的",
            "诊断",
            "治疗承诺",
            "医疗承诺",
            "包治",
            "稳赚",
            "投资建议",
            "自杀"
        ]

        for fileURL in fileURLs(under: root) where ["json", "txt"].contains(fileURL.pathExtension.lowercased()) {
            guard let text = try? String(contentsOf: fileURL, encoding: .utf8) else { continue }
            if forbiddenPatterns.contains(where: { text.localizedCaseInsensitiveContains($0) }) {
                errors.append(.init(code: .forbiddenContent, message: "内容包包含禁止内容：\(fileURL.lastPathComponent)"))
            }
            if containsRestrictedOverrideField(in: text) {
                errors.append(.init(code: .restrictedOverride, message: "内容包不能覆盖安全、频率或安静模式设置"))
            }
        }
    }

    private func containsRestrictedOverrideField(in text: String) -> Bool {
        let restricted = [
            "safetyRules",
            "safetyOverride",
            "ignoreSafetyRules",
            "allowUnsafeContent",
            "frequencyOverride",
            "minimumIntervalSeconds",
            "bubbleFrequency",
            "quietMode"
        ]
        return restricted.contains { text.contains("\"\($0)\"") }
    }

    private func fileURLs(under root: URL) -> [URL] {
        guard let enumerator = fileManager.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return enumerator.compactMap { item in
            guard let url = item as? URL else { return nil }
            let values = try? url.resourceValues(forKeys: [.isRegularFileKey])
            return values?.isRegularFile == true ? url : nil
        }
    }
}
