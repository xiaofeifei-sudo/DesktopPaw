import DesktopPet
import Foundation

@MainActor
func runPetVisualStateControllerTests() {
    let tests = PetVisualStateControllerTests()
    tests.applySetsOverlayOnViewModel()
    tests.restoreClearsOverlayFromViewModel()
    tests.clearAllRemovesOverlay()
    tests.tickExpiryDoesNothingWhenNoOverlay()
    tests.tickExpiryDoesNotRestoreWhenNotExpired()
    tests.applyingExpiredOverlayImmediatelyRestores()
    tests.currentOverlayReturnsNilInitially()
    tests.currentOverlayReturnsAppliedOverlay()
    tests.applyReplacesExistingOverlay()
    tests.pendingExpireTimerDoesNotRetainViewModelAfterControllerDeinit()
    tests.overlayStateIsExpiredWorks()
    tests.overlayStateRemainingSeconds()
}

@MainActor
private struct PetVisualStateControllerTests {
    private func makeOverlay(
        id: String = "test-overlay",
        renderMode: PetVisualRenderMode = .replaceWholeImage,
        expiresIn seconds: TimeInterval = 60
    ) -> PetVisualOverlayState {
        PetVisualOverlayState(
            id: id,
            assetId: "asset-\(id)",
            imageURL: URL(fileURLWithPath: "/tmp/test.png"),
            renderMode: renderMode,
            startedAt: Date(),
            expiresAt: Date().addingTimeInterval(seconds),
            canRestore: true
        )
    }

    func applySetsOverlayOnViewModel() {
        let controller = PetVisualStateController()
        let viewModel = PetViewModel()
        let overlay = makeOverlay()

        controller.apply(overlay, to: viewModel)

        expect(viewModel.visualOverlay != nil, "visualOverlay should be set after apply")
        expect(viewModel.visualOverlay?.id == "test-overlay", "visualOverlay id should match")
    }

    func restoreClearsOverlayFromViewModel() {
        let controller = PetVisualStateController()
        let viewModel = PetViewModel()
        let overlay = makeOverlay()

        controller.apply(overlay, to: viewModel)
        controller.restore(viewModel: viewModel)

        expect(viewModel.visualOverlay == nil, "visualOverlay should be nil after restore")
    }

    func clearAllRemovesOverlay() {
        let controller = PetVisualStateController()
        let viewModel = PetViewModel()
        let overlay = makeOverlay()

        controller.apply(overlay, to: viewModel)
        controller.clearAll(viewModel: viewModel)

        expect(viewModel.visualOverlay == nil, "visualOverlay should be nil after clearAll")
        expect(controller.currentOverlay() == nil, "controller should have no active overlay")
    }

    func tickExpiryDoesNothingWhenNoOverlay() {
        let controller = PetVisualStateController()
        let viewModel = PetViewModel()

        controller.tickExpiry(viewModel: viewModel)

        expect(viewModel.visualOverlay == nil, "visualOverlay should remain nil with no overlay")
    }

    func tickExpiryDoesNotRestoreWhenNotExpired() {
        let controller = PetVisualStateController()
        let viewModel = PetViewModel()
        let overlay = makeOverlay(expiresIn: 300)

        controller.apply(overlay, to: viewModel)
        controller.tickExpiry(viewModel: viewModel)

        expect(viewModel.visualOverlay != nil, "visualOverlay should still be set when not expired")
    }

    func applyingExpiredOverlayImmediatelyRestores() {
        let controller = PetVisualStateController()
        let viewModel = PetViewModel()
        let expiredOverlay = makeOverlay(expiresIn: -1)

        controller.apply(expiredOverlay, to: viewModel)

        expect(viewModel.visualOverlay == nil, "applying expired overlay should immediately restore")
        expect(controller.currentOverlay() == nil, "expired overlay should not be active")
    }

    func currentOverlayReturnsNilInitially() {
        let controller = PetVisualStateController()

        expect(controller.currentOverlay() == nil, "currentOverlay should be nil initially")
    }

    func currentOverlayReturnsAppliedOverlay() {
        let controller = PetVisualStateController()
        let overlay = makeOverlay(id: "check-current")
        let viewModel = PetViewModel()

        controller.apply(overlay, to: viewModel)

        expect(controller.currentOverlay()?.id == "check-current", "currentOverlay should return the applied overlay")
    }

    func applyReplacesExistingOverlay() {
        let controller = PetVisualStateController()
        let viewModel = PetViewModel()
        let first = makeOverlay(id: "first")
        let second = makeOverlay(id: "second")

        controller.apply(first, to: viewModel)
        controller.apply(second, to: viewModel)

        expect(viewModel.visualOverlay?.id == "second", "visualOverlay should be the most recently applied")
        expect(controller.currentOverlay()?.id == "second", "currentOverlay should be the most recently applied")
    }

    func pendingExpireTimerDoesNotRetainViewModelAfterControllerDeinit() {
        weak var weakViewModel: PetViewModel?

        do {
            let controller = PetVisualStateController()
            let viewModel = PetViewModel()
            weakViewModel = viewModel
            controller.apply(makeOverlay(expiresIn: 300), to: viewModel)
        }

        expect(weakViewModel == nil, "pending expire timer should not retain view model after controller deinit")
    }

    func overlayStateIsExpiredWorks() {
        let expired = PetVisualOverlayState(
            id: "expired",
            assetId: "a1",
            imageURL: URL(fileURLWithPath: "/tmp/test.png"),
            renderMode: .replaceWholeImage,
            startedAt: Date().addingTimeInterval(-120),
            expiresAt: Date().addingTimeInterval(-60)
        )
        let active = PetVisualOverlayState(
            id: "active",
            assetId: "a2",
            imageURL: URL(fileURLWithPath: "/tmp/test.png"),
            renderMode: .replaceWholeImage,
            startedAt: Date(),
            expiresAt: Date().addingTimeInterval(60)
        )

        expect(expired.isExpired(), "overlay with past expiresAt should be expired")
        expect(!active.isExpired(), "overlay with future expiresAt should not be expired")
    }

    func overlayStateRemainingSeconds() {
        let overlay = PetVisualOverlayState(
            id: "remaining",
            assetId: "a3",
            imageURL: URL(fileURLWithPath: "/tmp/test.png"),
            renderMode: .replaceWholeImage,
            startedAt: Date(),
            expiresAt: Date().addingTimeInterval(30)
        )

        let remaining = overlay.remainingSeconds
        expect(remaining > 25 && remaining <= 30, "remainingSeconds should be close to 30, got \(remaining)")
    }
}
