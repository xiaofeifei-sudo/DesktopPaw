import Foundation
import DesktopPet

func runPetdexURLResolverTests() {
  let tests = PetdexURLResolverTests()
  tests.resolvesPetPageURL()
  tests.resolvesPetPageURLWithoutScheme()
  tests.resolvesDirectZipURL()
  tests.resolvesDirectDownloadURL()
  tests.rejectsNonPetdexURL()
  tests.rejectsUnsupportedPetdexPath()
}

private struct PetdexURLResolverTests {
  func resolvesPetPageURL() {
    let request = resolve("https://petdex.crafter.run/zh/pets/my-cat-v3-large")
    expect(request.kind == .page, "Petdex pet page should resolve as page request")
    expect(request.sourceURL.absoluteString == "https://petdex.crafter.run/zh/pets/my-cat-v3-large", "source URL should be preserved")
    expect(request.suggestedFileName == "my-cat-v3-large.zip", "page URL should derive zip filename from pet slug")
  }

  func resolvesPetPageURLWithoutScheme() {
    let request = resolve("petdex.crafter.run/zh/pets/my-cat-v3-large")
    expect(request.kind == .page, "scheme-less Petdex URL should default to https page request")
    expect(request.sourceURL.scheme == "https", "scheme-less Petdex URL should default to https")
  }

  func resolvesDirectZipURL() {
    let request = resolve("https://petdex.crafter.run/downloads/my-cat-v3-large.zip")
    expect(request.kind == .archive, "direct .zip URL should resolve as archive request")
    expect(request.suggestedFileName == "my-cat-v3-large.zip", "direct zip URL should preserve file name")
  }

  func resolvesDirectDownloadURL() {
    let request = resolve("https://petdex.crafter.run/zh/pets/my-cat-v3-large/download")
    expect(request.kind == .archive, "Petdex download endpoint should resolve as archive request")
    expect(request.suggestedFileName == "my-cat-v3-large.zip", "download endpoint should derive filename from pet slug")
  }

  func rejectsNonPetdexURL() {
    expectPetdexError(.unsupportedPetdexURL("https://example.com/pets/my-cat-v3-large")) {
      _ = try PetdexURLResolver().resolve("https://example.com/pets/my-cat-v3-large")
    }
  }

  func rejectsUnsupportedPetdexPath() {
    expectPetdexError(.unsupportedPetdexURL("https://petdex.crafter.run/about")) {
      _ = try PetdexURLResolver().resolve("https://petdex.crafter.run/about")
    }
  }

  private func resolve(_ input: String) -> PetdexDownloadRequest {
    do {
      return try PetdexURLResolver().resolve(input)
    } catch {
      fail("Petdex URL should resolve: \(error)")
    }
  }

  private func expectPetdexError(
    _ expected: PetdexImportError,
    operation: () throws -> Void
  ) {
    do {
      try operation()
      fail("expected Petdex error \(expected)")
    } catch let error as PetdexImportError {
      expect(error == expected, "expected \(expected), got \(error)")
    } catch {
      fail("expected PetdexImportError \(expected), got \(error)")
    }
  }
}
