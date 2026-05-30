import Foundation

public struct EventActionMapping: Codable, Equatable, Sendable {
    public let event: String
    public var actionId: String?
    public var bubbleText: String?

    public init(event: String, actionId: String? = nil, bubbleText: String? = nil) {
        self.event = event
        self.actionId = actionId
        self.bubbleText = bubbleText
    }
}

public final class EventActionMappingStore: @unchecked Sendable {
    private var mappings: [String: EventActionMapping] = [:]

    public init() {}

    public func register(event: String, actionId: String?, bubbleText: String?) {
        mappings[event] = EventActionMapping(event: event, actionId: actionId, bubbleText: bubbleText)
    }

    public func unregister(event: String) {
        mappings.removeValue(forKey: event)
    }

    public func mapping(for event: String) -> EventActionMapping? {
        mappings[event]
    }

    public func allMappings() -> [EventActionMapping] {
        Array(mappings.values).sorted { $0.event < $1.event }
    }
}
