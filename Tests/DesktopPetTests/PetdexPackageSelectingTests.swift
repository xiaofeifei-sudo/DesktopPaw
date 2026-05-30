import AppKit
import Foundation
import DesktopPet

@MainActor
func runPetdexPackageSelectingTests() {
    let tests = PetdexPackageSelectingTests()
    tests.cancelReturnsNil()
    tests.acceptsZipExtension()
    tests.acceptsUppercaseZipExtension()
    tests.rejectsNonZipExtension()
    tests.disallowsMultipleSelection()
    tests.allowsOnlyFileSelection()
    tests.appliesZipContentType()
}

@MainActor
private struct PetdexPackageSelectingTests {
    func cancelReturnsNil() {
        let panel = PetdexPackageOpenPanel(runner: { _ in nil })
        expect(panel.selectPetdexPackage() == nil, "user cancelling should return nil")
    }

    func acceptsZipExtension() {
        let url = URL(fileURLWithPath: "/tmp/my-cat-v3-large.zip")
        let panel = PetdexPackageOpenPanel(runner: { _ in url })
        expect(panel.selectPetdexPackage() == url, "Petdex selector should accept .zip files")
    }

    func acceptsUppercaseZipExtension() {
        let url = URL(fileURLWithPath: "/tmp/MyCat.ZIP")
        let panel = PetdexPackageOpenPanel(runner: { _ in url })
        expect(panel.selectPetdexPackage() == url, "Petdex selector should accept uppercase .ZIP files")
    }

    func rejectsNonZipExtension() {
        let url = URL(fileURLWithPath: "/tmp/my-cat-v3-large.pet")
        let panel = PetdexPackageOpenPanel(runner: { _ in url })
        expect(panel.selectPetdexPackage() == nil, "Petdex selector should reject non-zip files")
    }

    func disallowsMultipleSelection() {
        let captured = PetdexCapturedPanel()
        let panel = PetdexPackageOpenPanel(runner: { p in
            captured.panel = p
            return nil
        })
        _ = panel.selectPetdexPackage()
        expect(captured.panel?.allowsMultipleSelection == false, "Petdex panel should disallow multiple selection")
    }

    func allowsOnlyFileSelection() {
        let captured = PetdexCapturedPanel()
        let panel = PetdexPackageOpenPanel(runner: { p in
            captured.panel = p
            return nil
        })
        _ = panel.selectPetdexPackage()
        expect(captured.panel?.canChooseFiles == true, "Petdex panel should allow choosing files")
        expect(captured.panel?.canChooseDirectories == false, "Petdex panel should not allow directories")
        expect(captured.panel?.canCreateDirectories == false, "Petdex panel should not allow creating directories")
    }

    func appliesZipContentType() {
        let captured = PetdexCapturedPanel()
        let panel = PetdexPackageOpenPanel(runner: { p in
            captured.panel = p
            return nil
        })
        _ = panel.selectPetdexPackage()

        let extensions = Set((captured.panel?.allowedContentTypes ?? []).compactMap(\.preferredFilenameExtension))
        expect(extensions.contains("zip"), "Petdex panel should allow zip content type")
    }
}

@MainActor
private final class PetdexCapturedPanel {
    var panel: NSOpenPanel?
}
