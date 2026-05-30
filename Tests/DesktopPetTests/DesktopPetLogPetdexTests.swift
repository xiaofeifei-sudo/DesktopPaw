import Foundation
import DesktopPet

func runDesktopPetLogPetdexTests() {
  let tests = DesktopPetLogPetdexTests()
  tests.exposesPetdexLogCategory()
  tests.petdexFailureStagesCoverImportPipeline()
  tests.petdexFailureLogIncludesSourceAndReason()
}

private struct DesktopPetLogPetdexTests {
  func exposesPetdexLogCategory() {
    expect(DesktopPetLog.petdexCategory == "petdex", "petdex log category should be stable")
    expect(
      DesktopPetLog.categoryNames.contains("petdex"),
      "categoryNames should include petdex"
    )
  }

  func petdexFailureStagesCoverImportPipeline() {
    expect(PetdexImportError.invalidArchive.failureStage == "archive", "archive failures should log archive stage")
    expect(PetdexImportError.manifestDecodingFailed.failureStage == "manifest", "manifest failures should log manifest stage")
    expect(PetdexImportError.unreadableImage("spritesheet.webp").failureStage == "image", "image failures should log image stage")
    expect(PetdexImportError.writeFailed("/tmp/Pets/cat").failureStage == "write", "write failures should log write stage")
  }

  func petdexFailureLogIncludesSourceAndReason() {
    let sourceURL = URL(fileURLWithPath: "/tmp/my-cat-v3-large.zip")
    let log = PetdexImportError.missingManifest.failureLog(
      sourceURL: sourceURL,
      underlyingErrorDescription: "central directory was readable"
    )

    expect(log.stage == "archive", "missing pet.json should be logged as archive-stage failure")
    expect(log.sourceFileName == "my-cat-v3-large.zip", "log should include selected archive filename")
    expect(log.reason == PetdexImportError.missingManifest.errorDescription, "log should include user-facing failure reason")
    expect(log.message.contains("my-cat-v3-large.zip"), "log message should include source file")
    expect(log.message.contains("archive"), "log message should include failure stage")
    expect(log.message.contains("pet.json"), "log message should include concrete failure reason")
    expect(log.message.contains("central directory was readable"), "log message should include underlying reason when present")
  }
}
