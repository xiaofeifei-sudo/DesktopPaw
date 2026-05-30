import Foundation
import DesktopPet

func runPetdexDownloaderTests() {
  let tests = PetdexDownloaderTests()
  tests.downloadsDirectArchiveToTemporaryDirectory()
  tests.downloadsArchiveLinkedFromPetPage()
  tests.downloadsArchiveFromEmbeddedPetdexZipURL()
  tests.appliesTimeoutAndUsesGetWithoutUploadBody()
  tests.rejectsOversizedDownloadAndLeavesNoTempFile()
  tests.cancellationMapsToPetdexCancelledError()
  tests.httpFailureCleansUpWithoutWritingArchive()
}

private struct PetdexDownloaderTests {
  func downloadsDirectArchiveToTemporaryDirectory() {
    runAsyncTest {
      let scratch = PetdexDownloaderScratch()
      defer { scratch.cleanUp() }

      let zipData = Data("PK-test-zip".utf8)
      let downloader = PetdexDownloader(
        temporaryDirectoryURL: scratch.root,
        dataLoader: { request in
          expect(request.url?.absoluteString == "https://petdex.crafter.run/downloads/cat.zip", "downloader should request direct archive URL")
          return (zipData, response(url: request.url!, expectedLength: zipData.count))
        }
      )

      let fileURL = try await downloader.download(PetdexDownloadRequest(
        sourceURL: URL(string: "https://petdex.crafter.run/downloads/cat.zip")!,
        kind: .archive,
        suggestedFileName: "cat.zip"
      ))

      expect(FileManager.default.fileExists(atPath: fileURL.path), "downloaded archive should be written to temp file")
      let writtenData = try Data(contentsOf: fileURL)
      expect(writtenData == zipData, "downloaded archive data should be preserved")
      expect(fileURL.deletingLastPathComponent().deletingLastPathComponent() == scratch.root, "archive should be written under configured temp directory")
    }
  }

  func downloadsArchiveLinkedFromPetPage() {
    runAsyncTest {
      let scratch = PetdexDownloaderScratch()
      defer { scratch.cleanUp() }

      let pageURL = URL(string: "https://petdex.crafter.run/zh/pets/my-cat-v3-large")!
      let zipURL = URL(string: "https://petdex.crafter.run/downloads/my-cat-v3-large.zip")!
      let zipData = Data("PK-page-zip".utf8)
      let recorder = PetdexDownloaderRequestRecorder()
      let downloader = PetdexDownloader(
        temporaryDirectoryURL: scratch.root,
        dataLoader: { request in
          let url = request.url!
          recorder.append(url)
          if url == pageURL {
            let html = #"<html><body><a href="/downloads/my-cat-v3-large.zip">Download</a></body></html>"#
            return (Data(html.utf8), response(url: url, expectedLength: html.utf8.count))
          }
          if url == zipURL {
            return (zipData, response(url: url, expectedLength: zipData.count))
          }
          throw PetdexImportError.downloadFailed("unexpected URL \(url.absoluteString)")
        }
      )

      let fileURL = try await downloader.download(PetdexDownloadRequest(
        sourceURL: pageURL,
        kind: .page,
        suggestedFileName: "my-cat-v3-large.zip"
      ))

      expect(recorder.urls == [pageURL, zipURL], "page download should fetch page then linked zip")
      let writtenData = try Data(contentsOf: fileURL)
      expect(writtenData == zipData, "linked archive data should be written")
    }
  }

  func downloadsArchiveFromEmbeddedPetdexZipURL() {
    runAsyncTest {
      let scratch = PetdexDownloaderScratch()
      defer { scratch.cleanUp() }

      let pageURL = URL(string: "https://petdex.crafter.run/zh/pets/tianmingren")!
      let zipURL = URL(string: "https://pub-94495283df974cfea5e98d6a9e3fa462.r2.dev/pets/tianmingren-c639b75adbaa/zip.zip")!
      let zipData = Data("PK-embedded-zip".utf8)
      let recorder = PetdexDownloaderRequestRecorder()
      let downloader = PetdexDownloader(
        temporaryDirectoryURL: scratch.root,
        dataLoader: { request in
          let url = request.url!
          recorder.append(url)
          if url == pageURL {
            let html = #"""
            <script>
            self.__next_f.push([1,"{\"pet\":{\"slug\":\"tianmingren\",\"zipUrl\":\"https://pub-94495283df974cfea5e98d6a9e3fa462.r2.dev/pets/tianmingren-c639b75adbaa/zip.zip\"}}"])
            </script>
            """#
            return (Data(html.utf8), response(url: url, expectedLength: html.utf8.count))
          }
          if url == zipURL {
            return (zipData, response(url: url, expectedLength: zipData.count))
          }
          throw PetdexImportError.downloadFailed("unexpected URL \(url.absoluteString)")
        }
      )

      let fileURL = try await downloader.download(PetdexDownloadRequest(
        sourceURL: pageURL,
        kind: .page,
        suggestedFileName: "tianmingren.zip"
      ))

      expect(recorder.urls == [pageURL, zipURL], "page download should fetch page then embedded Petdex zipUrl")
      let writtenData = try Data(contentsOf: fileURL)
      expect(writtenData == zipData, "embedded archive data should be written")
      expect(fileURL.lastPathComponent == "tianmingren.zip", "embedded archive file name should use the Petdex page slug")
    }
  }

  func appliesTimeoutAndUsesGetWithoutUploadBody() {
    runAsyncTest {
      let scratch = PetdexDownloaderScratch()
      defer { scratch.cleanUp() }

      let recorder = PetdexDownloaderRequestRecorder()
      let downloader = PetdexDownloader(
        timeoutSeconds: 12,
        temporaryDirectoryURL: scratch.root,
        dataLoader: { request in
          recorder.setRequest(request)
          let data = Data("PK-timeout".utf8)
          return (data, response(url: request.url!, expectedLength: data.count))
        }
      )

      _ = try await downloader.download(PetdexDownloadRequest(
        sourceURL: URL(string: "https://petdex.crafter.run/downloads/cat.zip")!,
        kind: .archive,
        suggestedFileName: "cat.zip"
      ))

      let observedRequest = recorder.request
      expect(observedRequest?.httpMethod == "GET", "Petdex downloader should use GET")
      expect(observedRequest?.httpBody == nil, "Petdex downloader should not upload a request body")
      expect(observedRequest?.timeoutInterval == 12, "Petdex downloader should apply configured timeout")
    }
  }

  func rejectsOversizedDownloadAndLeavesNoTempFile() {
    runAsyncTest {
      let scratch = PetdexDownloaderScratch()
      defer { scratch.cleanUp() }

      let downloader = PetdexDownloader(
        maximumDownloadBytes: 4,
        temporaryDirectoryURL: scratch.root,
        dataLoader: { request in
          let data = Data("too-large".utf8)
          return (data, response(url: request.url!, expectedLength: data.count))
        }
      )

      try await expectPetdexError(.downloadTooLarge(maximumBytes: 4)) {
        _ = try await downloader.download(PetdexDownloadRequest(
          sourceURL: URL(string: "https://petdex.crafter.run/downloads/cat.zip")!,
          kind: .archive,
          suggestedFileName: "cat.zip"
        ))
      }

      expect(scratch.downloadedFiles().isEmpty, "oversized download should not leave temp archive files")
    }
  }

  func cancellationMapsToPetdexCancelledError() {
    runAsyncTest {
      let downloader = PetdexDownloader(dataLoader: { _ in
        throw CancellationError()
      })

      try await expectPetdexError(.downloadCancelled) {
        _ = try await downloader.download(PetdexDownloadRequest(
          sourceURL: URL(string: "https://petdex.crafter.run/downloads/cat.zip")!,
          kind: .archive,
          suggestedFileName: "cat.zip"
        ))
      }
    }
  }

  func httpFailureCleansUpWithoutWritingArchive() {
    runAsyncTest {
      let scratch = PetdexDownloaderScratch()
      defer { scratch.cleanUp() }

      let downloader = PetdexDownloader(
        temporaryDirectoryURL: scratch.root,
        dataLoader: { request in
          let response = HTTPURLResponse(
            url: request.url!,
            statusCode: 404,
            httpVersion: nil,
            headerFields: nil
          )!
          return (Data(), response)
        }
      )

      try await expectDownloadFailed {
        _ = try await downloader.download(PetdexDownloadRequest(
          sourceURL: URL(string: "https://petdex.crafter.run/downloads/missing.zip")!,
          kind: .archive,
          suggestedFileName: "missing.zip"
        ))
      }

      expect(scratch.downloadedFiles().isEmpty, "failed HTTP download should not leave temp archive files")
    }
  }
}

private final class PetdexDownloaderScratch: @unchecked Sendable {
  let root: URL

  init() {
    root = FileManager.default.temporaryDirectory
      .appendingPathComponent("PetdexDownloaderTests-\(UUID().uuidString)", isDirectory: true)
    try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
  }

  func cleanUp() {
    try? FileManager.default.removeItem(at: root)
  }

  func downloadedFiles() -> [URL] {
    guard let enumerator = FileManager.default.enumerator(
      at: root,
      includingPropertiesForKeys: [.isRegularFileKey],
      options: [.skipsHiddenFiles]
    ) else {
      return []
    }

    return enumerator.compactMap { item in
      guard let url = item as? URL else { return nil }
      var isDirectory: ObjCBool = false
      return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) && !isDirectory.boolValue ? url : nil
    }
  }
}

private final class AsyncTestResultBox: @unchecked Sendable {
  var error: Error?
}

private final class PetdexDownloaderRequestRecorder: @unchecked Sendable {
  private let lock = NSLock()
  private var storedURLs: [URL] = []
  private var storedRequest: URLRequest?

  var urls: [URL] {
    lock.lock()
    defer { lock.unlock() }
    return storedURLs
  }

  var request: URLRequest? {
    lock.lock()
    defer { lock.unlock() }
    return storedRequest
  }

  func append(_ url: URL) {
    lock.lock()
    storedURLs.append(url)
    lock.unlock()
  }

  func setRequest(_ request: URLRequest) {
    lock.lock()
    storedRequest = request
    lock.unlock()
  }
}

private func runAsyncTest(_ operation: @escaping @Sendable () async throws -> Void) {
  let semaphore = DispatchSemaphore(value: 0)
  let box = AsyncTestResultBox()
  Task {
    do {
      try await operation()
    } catch {
      box.error = error
    }
    semaphore.signal()
  }
  semaphore.wait()
  if let error = box.error {
    fail("async test failed: \(error)")
  }
}

private func response(url: URL, expectedLength: Int) -> URLResponse {
  URLResponse(
    url: url,
    mimeType: "application/zip",
    expectedContentLength: expectedLength,
    textEncodingName: nil
  )
}

private func expectPetdexError(
  _ expected: PetdexImportError,
  operation: () async throws -> Void
) async throws {
  do {
    try await operation()
    fail("expected Petdex error \(expected)")
  } catch let error as PetdexImportError {
    expect(error == expected, "expected \(expected), got \(error)")
  } catch {
    fail("expected PetdexImportError \(expected), got \(error)")
  }
}

private func expectDownloadFailed(operation: () async throws -> Void) async throws {
  do {
    try await operation()
    fail("expected downloadFailed error")
  } catch PetdexImportError.downloadFailed {
  } catch {
    fail("expected downloadFailed, got \(error)")
  }
}
