import Foundation

public final class ExternalStateService: ExternalStateServicing, @unchecked Sendable {
    private let connectionManager: ExternalConnectionManager
    private let mappingStore: EventActionMappingStore
    private let quietModePolicyProvider: (() -> (any QuietModeEvaluating)?)?
    private let companionPreferencesProvider: (() -> CompanionPreferences?)?
    private let bubbleSchedulerCheck: (() -> Bool)?
    private let _socketPath: String

    private var isListening = false

    public var isEnabled: Bool { isListening }
    public var socketPath: String { _socketPath }

    public var onEventTriggered: (@Sendable (ExternalEvent, EventActionMapping?) -> Void)?

    public init(
        socketPath: String,
        mappingStore: EventActionMappingStore = EventActionMappingStore(),
        quietModePolicyProvider: (() -> (any QuietModeEvaluating)?)? = nil,
        companionPreferencesProvider: (() -> CompanionPreferences?)? = nil,
        bubbleSchedulerCheck: (() -> Bool)? = nil
    ) {
        self.connectionManager = ExternalConnectionManager(socketPath: socketPath)
        self.mappingStore = mappingStore
        self.quietModePolicyProvider = quietModePolicyProvider
        self.companionPreferencesProvider = companionPreferencesProvider
        self.bubbleSchedulerCheck = bubbleSchedulerCheck
        self._socketPath = socketPath

        connectionManager.onEventReceived = { [weak self] event in
            self?.handleEvent(event)
        }
    }

    public func startListening() throws {
        guard !isListening else { return }
        try connectionManager.startListening()
        isListening = true
    }

    public func stopListening() {
        guard isListening else { return }
        connectionManager.stopListening()
        isListening = false
    }

    public func getActiveConnections() -> [ExternalConnection] {
        connectionManager.activeConnections
    }

    public func disconnect(_ connectionId: String) {
        connectionManager.disconnect(connectionId)
    }

    public func registerActionMapping(event: String, actionId: String?, bubbleText: String?) {
        mappingStore.register(event: event, actionId: actionId, bubbleText: bubbleText)
    }

    public func unregisterActionMapping(event: String) {
        mappingStore.unregister(event: event)
    }

    public func getActionMappings() -> [EventActionMapping] {
        mappingStore.allMappings()
    }

    private func handleEvent(_ event: ExternalEvent) {
        if let policyProvider = quietModePolicyProvider,
           let policy = policyProvider(),
           let preferences = companionPreferencesProvider?() {
            let state = policy.quietState(preferences: preferences, at: Date())
            if state != .inactive {
                return
            }
        }

        if let schedulerCheck = bubbleSchedulerCheck, !schedulerCheck() {
            return
        }

        let mapping = mappingStore.mapping(for: event.event)
        onEventTriggered?(event, mapping)
    }
}
