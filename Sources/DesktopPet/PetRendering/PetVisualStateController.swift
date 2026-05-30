import Foundation

public protocol PetVisualStateControlling: Sendable {
    @MainActor func apply(_ overlay: PetVisualOverlayState, to viewModel: PetViewModel)
    @MainActor func restore(viewModel: PetViewModel)
    @MainActor func clearAll(viewModel: PetViewModel)
    @MainActor func tickExpiry(viewModel: PetViewModel)
}

@MainActor
public final class PetVisualStateController: PetVisualStateControlling, @unchecked Sendable {
    private var activeOverlay: PetVisualOverlayState?
    private var expireTimer: Timer?

    public init() {}

    deinit {
        MainActor.assumeIsolated {
            expireTimer?.invalidate()
        }
    }

    public func apply(_ overlay: PetVisualOverlayState, to viewModel: PetViewModel) {
        cancelExpireTimer()

        activeOverlay = overlay
        viewModel.update(visualOverlay: overlay)

        scheduleExpireTimer(viewModel: viewModel)
    }

    public func restore(viewModel: PetViewModel) {
        cancelExpireTimer()
        activeOverlay = nil
        viewModel.update(visualOverlay: nil)
    }

    public func clearAll(viewModel: PetViewModel) {
        cancelExpireTimer()
        activeOverlay = nil
        viewModel.update(visualOverlay: nil)
    }

    public func tickExpiry(viewModel: PetViewModel) {
        guard let overlay = activeOverlay, overlay.isExpired() else { return }
        restore(viewModel: viewModel)
    }

    public func currentOverlay() -> PetVisualOverlayState? {
        activeOverlay
    }

    private func scheduleExpireTimer(viewModel: PetViewModel) {
        guard let overlay = activeOverlay else { return }

        let delay = max(overlay.remainingSeconds, 0)
        guard delay > 0 else {
            restore(viewModel: viewModel)
            return
        }

        expireTimer = Timer.scheduledTimer(
            withTimeInterval: delay,
            repeats: false
        ) { [weak self, weak viewModel] _ in
            Task { @MainActor [weak self, weak viewModel] in
                guard let viewModel else {
                    return
                }
                self?.tickExpiry(viewModel: viewModel)
            }
        }
    }

    private func cancelExpireTimer() {
        expireTimer?.invalidate()
        expireTimer = nil
    }
}
