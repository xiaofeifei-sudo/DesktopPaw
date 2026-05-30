public protocol AfterTagStateMaintaining: AnyObject {
    var pending: ActionTag? { get }

    func mark(after reaction: PetState)
    func consume()
    func cancel()
}

public final class DefaultAfterTagState: AfterTagStateMaintaining {
    public private(set) var pending: ActionTag?

    public init(pending: ActionTag? = nil) {
        self.pending = pending
    }

    public func mark(after reaction: PetState) {
        guard let tag = Self.afterTag(for: reaction) else {
            return
        }
        pending = tag
    }

    public func consume() {
        pending = nil
    }

    public func cancel() {
        pending = nil
    }

    private static func afterTag(for reaction: PetState) -> ActionTag? {
        switch reaction {
        case .happy:
            return ActionTag(rawValue: "after.pet")!
        case .eating:
            return ActionTag(rawValue: "after.feed")!
        case .jumping:
            return ActionTag(rawValue: "after.click")!
        case .idle, .walking, .sleeping, .dragging:
            return nil
        }
    }
}
