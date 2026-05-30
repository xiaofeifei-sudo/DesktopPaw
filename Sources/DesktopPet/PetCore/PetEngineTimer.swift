@preconcurrency import Foundation

@MainActor
public final class PetEngineTimer {
    private let interval: TimeInterval
    private let onTick: (Date) -> Void
    private var timer: Timer?

    public init(interval: TimeInterval = 1.0, onTick: @escaping (Date) -> Void) {
        self.interval = interval
        self.onTick = onTick
    }

    public var isRunning: Bool {
        timer != nil
    }

    public func start() {
        guard timer == nil else {
            return
        }

        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.onTick(Date())
            }
        }
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
    }

}
