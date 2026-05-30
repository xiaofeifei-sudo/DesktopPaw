import Foundation
import AppKit

public final class DesktopSpaceService: DesktopSpaceServicing, @unchecked Sendable {
    private let engine: SpatialBehaviorEngine
    private let pollInterval: TimeInterval
    private let petPositionProvider: () -> CGPoint
    private let isDraggingProvider: () -> Bool

    private var pollTimer: Timer?
    private var _activityZones: [ActivityZone] = []
    private var _isMovementConstrained = false
    private var isRunning = false

    public var isEnabled: Bool { isRunning }
    public var activityZones: [ActivityZone] { _activityZones }
    public var isMovementConstrained: Bool { _isMovementConstrained }
    public var onSuggestion: (@Sendable (SpatialSuggestion) -> Void)?

    public init(
        engine: SpatialBehaviorEngine = SpatialBehaviorEngine(),
        pollInterval: TimeInterval = 0.5,
        petPositionProvider: @escaping () -> CGPoint,
        isDraggingProvider: @escaping () -> Bool = { false }
    ) {
        self.engine = engine
        self.pollInterval = pollInterval
        self.petPositionProvider = petPositionProvider
        self.isDraggingProvider = isDraggingProvider
    }

    deinit {
        stop()
    }

    public func start() {
        guard !isRunning else { return }
        isRunning = true
        pollTimer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            self?.poll()
        }
    }

    public func stop() {
        isRunning = false
        pollTimer?.invalidate()
        pollTimer = nil
    }

    public func setActivityZones(_ zones: [ActivityZone]) {
        _activityZones = zones
    }

    public func setMovementConstrained(_ constrained: Bool) {
        _isMovementConstrained = constrained
    }

    private func poll() {
        guard isRunning else { return }

        let environment = SpatialBehaviorEngine.Environment(
            screens: engine.screenDetector.currentScreens(),
            windows: engine.windowDetector.onScreenWindows()
        )

        let pet = SpatialBehaviorEngine.PetState(
            position: petPositionProvider(),
            isDragging: isDraggingProvider()
        )

        let suggestion = engine.suggest(
            pet: pet,
            environment: environment,
            activityZones: _activityZones
        )

        onSuggestion?(suggestion)
    }
}
