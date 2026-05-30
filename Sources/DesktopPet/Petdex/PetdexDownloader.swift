import Foundation

public protocol PetdexDownloading: Sendable {
    func download(_ request: PetdexDownloadRequest) async throws -> URL
}

public final class PetdexDownloader: PetdexDownloading, @unchecked Sendable {
    public typealias DataLoader = @Sendable (URLRequest) async throws -> (Data, URLResponse)

    public static let defaultMaximumDownloadBytes = 50 * 1024 * 1024
    public static let defaultTimeoutSeconds: TimeInterval = 30
    public static let temporaryDownloadDirectoryPrefix = "PetdexDownload-"
    public static let allowedAssetHost = "pub-94495283df974cfea5e98d6a9e3fa462.r2.dev"

    private let maximumDownloadBytes: Int
    private let timeoutSeconds: TimeInterval
    private let temporaryDirectoryURL: URL
    private let fileManager: FileManager
    private let dataLoader: DataLoader

    public init(
        maximumDownloadBytes: Int = PetdexDownloader.defaultMaximumDownloadBytes,
        timeoutSeconds: TimeInterval = PetdexDownloader.defaultTimeoutSeconds,
        temporaryDirectoryURL: URL = FileManager.default.temporaryDirectory,
        fileManager: FileManager = .default,
        dataLoader: @escaping DataLoader = PetdexDownloader.urlSessionDataLoader
    ) {
        self.maximumDownloadBytes = maximumDownloadBytes
        self.timeoutSeconds = timeoutSeconds
        self.temporaryDirectoryURL = temporaryDirectoryURL
        self.fileManager = fileManager
        self.dataLoader = dataLoader
    }

    public func download(_ request: PetdexDownloadRequest) async throws -> URL {
        do {
            switch request.kind {
            case .archive:
                return try await downloadArchive(
                    from: request.sourceURL,
                    suggestedFileName: request.suggestedFileName
                )
            case .page:
                let archiveURL = try await archiveURL(fromPage: request.sourceURL)
                return try await downloadArchive(
                    from: archiveURL,
                    suggestedFileName: request.suggestedFileName
                )
            }
        } catch is CancellationError {
            throw PetdexImportError.downloadCancelled
        } catch let error as PetdexImportError {
            throw error
        } catch {
            throw PetdexImportError.downloadFailed(error.localizedDescription)
        }
    }

    private func archiveURL(fromPage pageURL: URL) async throws -> URL {
        let htmlData = try await loadData(from: pageURL)
        guard let html = String(data: htmlData, encoding: .utf8) else {
            throw PetdexImportError.downloadFailed("The Petdex page could not be decoded.")
        }

        if let zip = archiveURLs(in: html, relativeTo: pageURL).first(where: isAllowedArchiveURL) {
            return zip
        }

        throw PetdexImportError.downloadFailed("Could not find a Petdex zip download link.")
    }

    private func downloadArchive(
        from url: URL,
        suggestedFileName: String
    ) async throws -> URL {
        let data = try await loadData(from: url)
        let directoryURL = temporaryDirectoryURL.appendingPathComponent("\(Self.temporaryDownloadDirectoryPrefix)\(UUID().uuidString)", isDirectory: true)
        let fileURL = directoryURL.appendingPathComponent(safeFileName(suggestedFileName), isDirectory: false)

        do {
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            try data.write(to: fileURL, options: [.atomic])
            return fileURL
        } catch {
            try? fileManager.removeItem(at: directoryURL)
            throw PetdexImportError.downloadFailed(error.localizedDescription)
        }
    }

    private func loadData(from url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = timeoutSeconds
        request.cachePolicy = .reloadIgnoringLocalCacheData

        let (data, response) = try await dataLoader(request)

        if Task.isCancelled {
            throw PetdexImportError.downloadCancelled
        }

        if let http = response as? HTTPURLResponse,
           !(200..<300).contains(http.statusCode) {
            throw PetdexImportError.downloadFailed("HTTP status \(http.statusCode).")
        }

        if response.expectedContentLength > Int64(maximumDownloadBytes) {
            throw PetdexImportError.downloadTooLarge(maximumBytes: maximumDownloadBytes)
        }

        guard data.count <= maximumDownloadBytes else {
            throw PetdexImportError.downloadTooLarge(maximumBytes: maximumDownloadBytes)
        }

        return data
    }

    private func hrefs(in html: String) -> [String] {
        let pattern = #"href\s*=\s*["']([^"']+)["']"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return []
        }

        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        return regex.matches(in: html, range: range).compactMap { match in
            guard match.numberOfRanges > 1,
                  let hrefRange = Range(match.range(at: 1), in: html) else {
                return nil
            }
            return String(html[hrefRange])
        }
    }

    private func archiveURLs(in html: String, relativeTo pageURL: URL) -> [URL] {
        var seen: Set<String> = []
        return (hrefs(in: html) + archiveURLStrings(in: html)).compactMap { rawValue in
            let normalized = normalizedURLString(rawValue)
            guard let url = URL(string: normalized, relativeTo: pageURL)?.absoluteURL,
                  seen.insert(url.absoluteString).inserted else {
                return nil
            }
            return url
        }
    }

    private func archiveURLStrings(in html: String) -> [String] {
        let pattern = #"https?:\\?/\\?/[^"'<>\s\\]+?(?:/zip\.zip|\.zip)(?:\?[^"'<>\s\\]+)?"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return []
        }

        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        return regex.matches(in: html, range: range).compactMap { match in
            guard let matchRange = Range(match.range, in: html) else {
                return nil
            }
            return String(html[matchRange])
        }
    }

    private func normalizedURLString(_ value: String) -> String {
        value
            .replacingOccurrences(of: #"\/"#, with: "/")
            .replacingOccurrences(of: "&amp;", with: "&")
    }

    private func isAllowedArchiveURL(_ url: URL) -> Bool {
        guard PetdexURLResolver.isArchiveURL(url) else {
            return false
        }

        let host = url.host?.lowercased()
        return PetdexURLResolver.isAllowedHost(host) || host == Self.allowedAssetHost
    }

    private func safeFileName(_ fileName: String) -> String {
        guard !fileName.isEmpty,
              fileName != ".",
              fileName != "..",
              !fileName.contains("/"),
              !fileName.contains("\\") else {
            return PetdexURLResolver.fallbackFileName
        }
        return fileName
    }

    public static func urlSessionDataLoader(_ request: URLRequest) async throws -> (Data, URLResponse) {
        try await URLSession.shared.data(for: request)
    }
}
