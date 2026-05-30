import AppKit
import DesktopPet

@MainActor
func runPetHitTestViewTests() {
    let tests = PetHitTestViewTests()
    tests.hitTestPrefersSubviewInsideInteractiveRegion()
    tests.hitTestFallsBackToPetViewOutsideInteractiveRegion()
    tests.hitTestFallsBackToPetViewWhenNoInteractiveRegionIsConfigured()
}

@MainActor
private struct PetHitTestViewTests {
    func hitTestPrefersSubviewInsideInteractiveRegion() {
        let view = PetHitTestView(frame: CGRect(x: 0, y: 0, width: 200, height: 200))
        let button = NSButton(frame: CGRect(x: 40, y: 40, width: 80, height: 32))
        view.addSubview(button)
        view.interactiveHitTestRegion = button.frame

        let hitView = view.hitTest(CGPoint(x: 60, y: 56))

        expect(hitView === button || hitView?.isDescendant(of: button) == true,
               "hit testing should allow interactive subviews to receive clicks")
    }

    func hitTestFallsBackToPetViewOutsideInteractiveRegion() {
        let view = PetHitTestView(frame: CGRect(x: 0, y: 0, width: 200, height: 200))
        let button = NSButton(frame: CGRect(x: 40, y: 40, width: 80, height: 32))
        view.addSubview(button)
        view.interactiveHitTestRegion = button.frame

        let hitView = view.hitTest(CGPoint(x: 180, y: 180))

        expect(hitView === view, "empty areas should still support pet dragging and clicks")
    }

    func hitTestFallsBackToPetViewWhenNoInteractiveRegionIsConfigured() {
        let view = PetHitTestView(frame: CGRect(x: 0, y: 0, width: 200, height: 200))
        let hostingLikeSubview = NSView(frame: view.bounds)
        view.addSubview(hostingLikeSubview)

        let hitView = view.hitTest(CGPoint(x: 60, y: 56))

        expect(hitView === view, "subviews should not capture pet clicks unless an interactive region is configured")
    }
}
