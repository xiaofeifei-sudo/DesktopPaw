import Foundation

public protocol PetdexURLResolving: Sendable {
    func resolve(_ input: String) throws -> PetdexDownloadRequest
}

public struct PetdexDownloadRequest: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        case page
        case archive
    }

    public let sourceURL: URL
    public let kind: Kind
    public let suggestedFileName: String

    public init(
        sourceURL: URL,
        kind: Kind,
        suggestedFileName: String
    ) {
        self.sourceURL = sourceURL
        self.kind = kind
        self.suggestedFileName = suggestedFileName
    }
}

public final class PetdexURLResolver: PetdexURLResolving, @unchecked Sendable {
    public static let allowedHost = "petdex.crafter.run"
    public static let fallbackFileName = "petdex-package.zip"

    public init() {}

    public func resolve(_ input: String) throws -> PetdexDownloadRequest {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedInput = trimmed.contains("://") ? trimmed : "https://\(trimmed)"

        guard let url = URL(string: normalizedInput),
              let scheme = url.scheme?.lowercased(),
              scheme == "https" || scheme == "http",
              Self.isAllowedHost(url.host)
        else {
            throw PetdexImportError.unsupportedPetdexURL(input)
        }

        if Self.isArchiveURL(url) {
            return PetdexDownloadRequest(
                sourceURL: url,
                kind: .archive,
                suggestedFileName: Self.suggestedArchiveFileName(for: url)
            )
        }

        guard Self.isPetPageURL(url) else {
            throw PetdexImportError.unsupportedPetdexURL(input)
        }

        return PetdexDownloadRequest(
            sourceURL: url,
            kind: .page,
            suggestedFileName: Self.suggestedArchiveFileName(for: url)
        )
    }

    public static func isArchiveURL(_ url: URL) -> Bool {
        let pathExtension = url.pathExtension.lowercased()
        if pathExtension == "zip" {
            return true
        }

        return pathComponents(for: url).contains("download")
    }

    public static func isPetPageURL(_ url: URL) -> Bool {
        let components = pathComponents(for: url)
        guard let petsIndex = components.firstIndex(of: "pets") else {
            return false
        }
        return components.indices.contains(components.index(after: petsIndex))
    }

    public static func isAllowedHost(_ host: String?) -> Bool {
        host?.lowercased() == allowedHost
    }

    public static func suggestedArchiveFileName(for url: URL) -> String {
        let rawName: String
        if url.pathExtension.lowercased() == "zip" {
            rawName = url.lastPathComponent
        } else if let slug = petSlug(in: url) {
            rawName = "\(slug).zip"
        } else {
            rawName = fallbackFileName
        }

        let sanitized = sanitizeFileName(rawName)
        return sanitized.isEmpty ? fallbackFileName : sanitized
    }

    private static func petSlug(in url: URL) -> String? {
        let components = pathComponents(for: url)
        guard let petsIndex = components.firstIndex(of: "pets") else {
            return components.last(where: { $0 != "download" })
        }

        let nextIndex = components.index(after: petsIndex)
        guard components.indices.contains(nextIndex) else {
            return nil
        }
        return components[nextIndex]
    }

    private static func pathComponents(for url: URL) -> [String] {
        url.pathComponents
            .filter { $0 != "/" }
            .compactMap { $0.removingPercentEncoding }
            .map { $0.lowercased() }
    }

    private static func sanitizeFileName(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_."))
        let scalars = value.unicodeScalars.map { scalar in
            allowed.contains(scalar) ? Character(scalar) : "-"
        }
        return String(scalars)
    }
}
