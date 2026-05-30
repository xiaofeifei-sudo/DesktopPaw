import AppKit
import Foundation
import UniformTypeIdentifiers
import DesktopPet

@MainActor
func runPetImageSelectingTests() {
    let tests = PetImageSelectingTests()
    tests.cancelReturnsNil()
    tests.acceptsSupportedExtension()
    tests.rejectsUnsupportedExtension()
    tests.uppercasedExtensionAccepted()
    tests.disallowsMultipleSelection()
    tests.disallowsDirectorySelection()
    tests.appliesAllowedContentTypes()
    tests.viewModelInjectsSelectingProtocol()
    tests.viewModelHonoursCancelFromSelectingProtocol()
    tests.packageSelectorAcceptsPetFolder()
    tests.packageSelectorRejectsNonPetFolder()
    tests.packageSelectorAllowsDirectorySelection()
    tests.viewModelInjectsPackageSelectingProtocol()
}

@MainActor
private struct PetImageSelectingTests {
    func cancelReturnsNil() {
        let panel = PetImageOpenPanel(runner: { _ in nil })
        expect(panel.selectImage() == nil, "user cancelling should return nil")
    }

    func acceptsSupportedExtension() {
        let url = URL(fileURLWithPath: "/tmp/cute.png")
        let panel = PetImageOpenPanel(runner: { _ in url })
        expect(panel.selectImage() == url, "supported extension should be returned")
    }

    func rejectsUnsupportedExtension() {
        let url = URL(fileURLWithPath: "/tmp/cute.gif")
        let panel = PetImageOpenPanel(runner: { _ in url })
        expect(panel.selectImage() == nil, "unsupported extension should be filtered out")
    }

    func uppercasedExtensionAccepted() {
        let url = URL(fileURLWithPath: "/tmp/Mascot.JPEG")
        let panel = PetImageOpenPanel(runner: { _ in url })
        expect(panel.selectImage() == url, "uppercase extension should still be accepted")
    }

    func disallowsMultipleSelection() {
        let captured = CapturedPanel()
        let panel = PetImageOpenPanel(runner: { p in
            captured.panel = p
            return nil
        })
        _ = panel.selectImage()
        expect(captured.panel?.allowsMultipleSelection == false, "panel should disallow multiple selection")
    }

    func disallowsDirectorySelection() {
        let captured = CapturedPanel()
        let panel = PetImageOpenPanel(runner: { p in
            captured.panel = p
            return nil
        })
        _ = panel.selectImage()
        expect(captured.panel?.canChooseDirectories == false, "panel should not allow directories")
        expect(captured.panel?.canChooseFiles == true, "panel should allow choosing files")
        expect(captured.panel?.canCreateDirectories == false, "panel should not allow creating directories")
    }

    func appliesAllowedContentTypes() {
        let captured = CapturedPanel()
        let panel = PetImageOpenPanel(runner: { p in
            captured.panel = p
            return nil
        })
        _ = panel.selectImage()
        let types = captured.panel?.allowedContentTypes ?? []
        expect(types.contains(where: { $0.conforms(to: .png) }), "panel should allow PNG content type")
        expect(types.contains(where: { $0.conforms(to: .jpeg) }), "panel should allow JPEG content type")
    }

    func viewModelInjectsSelectingProtocol() {
        let url = URL(fileURLWithPath: "/tmp/Mascot.png")
        let stub = StubImageSelector(result: url)
        let model = PetImportViewModel(imageSelecting: stub)
        var observed: [(URL, String)] = []
        model.onImportRequested = { observed.append(($0, $1)) }
        model.requestImport()
        expect(observed.count == 1, "view model should call selecting protocol via injected selector")
        expect(observed.first?.1 == "Mascot", "view model should derive display name from selected URL")
        expect(stub.callCount == 1, "selecting protocol should be invoked once")
    }

    func viewModelHonoursCancelFromSelectingProtocol() {
        let stub = StubImageSelector(result: nil)
        let model = PetImportViewModel(imageSelecting: stub)
        var observed = false
        model.onImportRequested = { _, _ in observed = true }
        model.requestImport()
        expect(observed == false, "cancelling from selector should not request import")
        expect(model.state == .idle, "cancelled selection should leave view model idle")
        expect(stub.callCount == 1, "selector should still be invoked when user cancels")
    }

    func packageSelectorAcceptsPetFolder() {
        let url = URL(fileURLWithPath: "/tmp/Mascot.pet", isDirectory: true)
        let panel = PetPackageOpenPanel(runner: { _ in url })
        expect(panel.selectPackage() == url, "package selector should accept .pet folders")
    }

    func packageSelectorRejectsNonPetFolder() {
        let url = URL(fileURLWithPath: "/tmp/Mascot", isDirectory: true)
        let panel = PetPackageOpenPanel(runner: { _ in url })
        expect(panel.selectPackage() == nil, "package selector should reject folders without .pet extension")
    }

    func packageSelectorAllowsDirectorySelection() {
        let captured = CapturedPanel()
        let panel = PetPackageOpenPanel(runner: { p in
            captured.panel = p
            return nil
        })
        _ = panel.selectPackage()
        expect(captured.panel?.allowsMultipleSelection == false, "package panel should disallow multiple selection")
        expect(captured.panel?.canChooseDirectories == true, "package panel should allow directories")
        expect(captured.panel?.canChooseFiles == false, "package panel should not allow regular files")
        expect(captured.panel?.canCreateDirectories == false, "package panel should not create directories")
    }

    func viewModelInjectsPackageSelectingProtocol() {
        let url = URL(fileURLWithPath: "/tmp/Pack.pet", isDirectory: true)
        let imageStub = StubImageSelector(result: nil)
        let packageStub = StubPackageSelector(result: url)
        let model = PetImportViewModel(imageSelecting: imageStub, packageSelecting: packageStub)
        var observed: [URL] = []
        model.onPackageImportRequested = { observed.append($0) }
        model.requestPackageImport()
        expect(observed == [url], "view model should call package selecting protocol")
        expect(packageStub.callCount == 1, "package selector should be invoked once")
        expect(imageStub.callCount == 0, "image selector should not be used for package import")
    }
}

@MainActor
private final class CapturedPanel {
    var panel: NSOpenPanel?
}

@MainActor
private final class StubImageSelector: PetImageSelecting {
    private let result: URL?
    private(set) var callCount = 0

    init(result: URL?) {
        self.result = result
    }

    func selectImage() -> URL? {
        callCount += 1
        return result
    }
}

@MainActor
private final class StubPackageSelector: PetPackageSelecting {
    private let result: URL?
    private(set) var callCount = 0

    init(result: URL?) {
        self.result = result
    }

    func selectPackage() -> URL? {
        callCount += 1
        return result
    }
}
