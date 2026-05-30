import Foundation

@MainActor
public final class PetEngineCommandHandler: PetCommandHandling {
    public let engine: PetEngine
    public let catalog: PetActionCatalog
    public var onStateChanged: ((PetRuntimeState) -> Void)?

    public init(engine: PetEngine, catalog: PetActionCatalog) {
        self.engine = engine
        self.catalog = catalog
        publish(self.engine.handle(.appLaunched))
    }

    public var isSleeping: Bool {
        engine.state.currentState == .sleeping
    }

    public func clicked() {
        publish(engine.handle(.clicked))
    }

    public func pet() {
        publish(engine.handle(.pet))
    }

    public func feed() {
        publish(engine.handle(.feed))
    }

    public func sleep() {
        publish(engine.handle(.sleepRequested))
    }

    public func wake() {
        publish(engine.handle(.wakeRequested))
    }

    public func dragStarted() {
        publish(engine.handle(.dragStarted))
    }

    public func dragEnded() {
        publish(engine.handle(.dragEnded))
    }

    public func playAction(_ id: ActionId) {
        publish(engine.handle(.playAction(id)))
    }

    public func setScale(_ scale: Double) {
        publish(engine.updateScale(scale))
    }

    public func setRandomWalkingEnabled(_ enabled: Bool) {
        engine.isRandomWalkingEnabled = enabled
    }

    public func tick(at date: Date) {
        publish(engine.handle(.tick(date)))
    }

    public var runtimeState: PetRuntimeState {
        engine.state
    }

    func applyInteractiveBubbleEffect(changes: StateChanges, animation: PetState?) {
        engine.applyStateChanges(changes)
        if let anim = animation,
           let action = catalog.actions(for: ActionRole(legacyState: anim)).first {
            publish(engine.handle(.playAction(action.id)))
        } else {
            publish(engine.state)
        }
    }

    private func publish(_ state: PetRuntimeState) {
        onStateChanged?(state)
    }
}
