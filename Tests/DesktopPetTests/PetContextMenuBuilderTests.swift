import AppKit
import Foundation
import DesktopPet

@MainActor
func runPetContextMenuBuilderTests() {
    let tests = PetContextMenuBuilderTests()
    tests.matchesActionsMenuBuilderStructureAndState()
    tests.menuItemTriggerPassesActionIdToClosure()
    tests.menuItemTriggerCallsActionTriggerService()
    tests.rightMouseDownDoesNotInvokeDragCallbacks()
}

@MainActor
private struct PetContextMenuBuilderTests {
    private let baseDate = Date(timeIntervalSince1970: 1_800_100_000)

    func matchesActionsMenuBuilderStructureAndState() {
        let disabledId = ActionId(rawValue: "extra_5")!
        let catalog = makeCatalog(extraNames: [
            "Extra A",
            "Extra B",
            "Extra C",
            "Extra D",
            "Extra E",
            "Extra F"
        ])
        let eligibility: (ActionId) -> ActionTriggerEligibility = { actionId in
            actionId == disabledId ? .rejectedBusy(reason: ActionTriggerService.busyReason) : .allowed
        }

        let actionsMenu = ActionsMenuBuilder().buildMenu(
            catalog: catalog,
            eligibility: eligibility,
            trigger: { _ in }
        )
        let contextMenu = PetContextMenuBuilder().buildMenu(
            catalog: catalog,
            eligibility: eligibility,
            trigger: { _ in }
        )

        expect(
            snapshots(in: contextMenu) == snapshots(in: actionsMenu),
            "pet context menu should match ActionsMenuBuilder titles, ordering, More submenu, and enabled state"
        )
        expect(contextMenu.item(withTitle: "More")?.submenu?.items.count == 1, "context menu should preserve More overflow")
        expect(contextMenu.item(withTitle: "Extra F") == nil, "overflow item should not stay in the top-level context menu")
        expect(contextMenu.item(withTitle: "More")?.submenu?.item(withTitle: "Extra F")?.isEnabled == false, "overflow eligibility should be preserved")
    }

    func menuItemTriggerPassesActionIdToClosure() {
        let catalog = makeCatalog(extraNames: ["Extra A"])
        var triggered: [ActionId] = []
        let menu = PetContextMenuBuilder().buildMenu(
            catalog: catalog,
            eligibility: { _ in .allowed },
            trigger: { actionId in
                triggered.append(actionId)
            }
        )

        let handler = firstActionHandler(in: menu)
        handler.trigger()

        expect(triggered == [handler.actionId], "context menu action item should pass its actionId to trigger closure")
    }

    func menuItemTriggerCallsActionTriggerService() {
        let extra = makeAction(id: "extra_play", role: nil, displayName: "Play Extra")
        let catalog = makeStandardCatalog(petId: "context-menu-test-pet", extras: [extra])
        let commands = SpyPetContextMenuCommands(
            runtimeState: PetRuntimeState.defaultState(at: baseDate),
            catalog: catalog
        )
        let service = ActionTriggerService(commandHandler: commands, now: { baseDate })
        let menu = PetContextMenuBuilder().buildMenu(catalog: catalog, triggerService: service)

        let handler = firstActionHandler(in: menu)
        handler.trigger()

        expect(commands.playedActionIds == [handler.actionId], "context menu should trigger ActionTriggerService")
    }

    func rightMouseDownDoesNotInvokeDragCallbacks() {
        let view = PetHitTestView(frame: CGRect(x: 0, y: 0, width: 128, height: 128))
        var mouseDownCount = 0
        var mouseDraggedCount = 0
        var mouseUpCount = 0
        var rightMouseDownCount = 0

        view.onMouseDown = { _ in mouseDownCount += 1 }
        view.onMouseDragged = { _ in mouseDraggedCount += 1 }
        view.onMouseUp = { _ in mouseUpCount += 1 }
        view.onRightMouseDown = { _ in rightMouseDownCount += 1 }

        view.rightMouseDown(with: makeMouseEvent(type: .rightMouseDown))

        expect(rightMouseDownCount == 1, "rightMouseDown should call right mouse callback")
        expect(mouseDownCount == 0, "rightMouseDown should not call mouseDown drag setup")
        expect(mouseDraggedCount == 0, "rightMouseDown should not call mouseDragged")
        expect(mouseUpCount == 0, "rightMouseDown should not consume or synthesize mouseUp")
    }

    private func makeCatalog(extraNames: [String]) -> PetActionCatalog {
        let extras = extraNames.enumerated().map { index, name in
            makeAction(id: "extra_\(index)", role: nil, displayName: name)
        }
        return PetActionCatalog(
            petId: "context-menu-test-pet",
            actions: extras + Array(roleActions().reversed()),
            warnings: []
        )
    }

    private func roleActions() -> [Action] {
        [
            makeAction(id: "idle_default", role: .idle, displayName: "Idle"),
            makeAction(id: "walking_default", role: .walking, displayName: "Walking"),
            makeAction(id: "sleeping_default", role: .sleeping, displayName: "Sleeping"),
            makeAction(id: "happy_default", role: .happy, displayName: "Happy"),
            makeAction(id: "eating_default", role: .eating, displayName: "Eating"),
            makeAction(id: "jumping_default", role: .jumping, displayName: "Jumping"),
            makeAction(id: "dragging_default", role: .dragging, displayName: "Dragging")
        ]
    }

    private func snapshots(in menu: NSMenu) -> [MenuSnapshot] {
        menu.items.map { item in
            MenuSnapshot(
                title: item.title,
                isEnabled: item.isEnabled,
                children: item.submenu.map { snapshots(in: $0) } ?? []
            )
        }
    }

    private func firstActionHandler(in menu: NSMenu) -> ActionsMenuItemTrigger {
        guard let handler = menu.items.first(where: { !$0.isSeparatorItem && $0.submenu == nil })?.representedObject as? ActionsMenuItemTrigger else {
            fail("context menu should retain an ActionsMenuItemTrigger representedObject")
        }
        return handler
    }

    private func makeMouseEvent(type: NSEvent.EventType) -> NSEvent {
        guard let event = NSEvent.mouseEvent(
            with: type,
            location: CGPoint(x: 16, y: 24),
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            eventNumber: 1,
            clickCount: 1,
            pressure: 1
        ) else {
            fail("NSEvent.mouseEvent should create a test event")
        }
        return event
    }
}

private struct MenuSnapshot: Equatable {
    let title: String
    let isEnabled: Bool
    let children: [MenuSnapshot]
}

@MainActor
private final class SpyPetContextMenuCommands: PetCommandHandling {
    var runtimeState: PetRuntimeState
    let catalog: PetActionCatalog
    var playedActionIds: [ActionId] = []

    init(runtimeState: PetRuntimeState, catalog: PetActionCatalog) {
        self.runtimeState = runtimeState
        self.catalog = catalog
    }

    var isSleeping: Bool {
        runtimeState.currentState == .sleeping
    }

    func clicked() {}
    func pet() {}
    func feed() {}
    func sleep() { runtimeState.currentState = .sleeping }
    func wake() { runtimeState.currentState = .idle }
    func dragStarted() {
        runtimeState.currentState = .dragging
        runtimeState.isDragging = true
    }
    func dragEnded() {
        runtimeState.currentState = .idle
        runtimeState.isDragging = false
    }
    func playAction(_ id: ActionId) {
        playedActionIds.append(id)
    }
    func setScale(_ scale: Double) {
        runtimeState.scale = scale
    }
    func setRandomWalkingEnabled(_ enabled: Bool) {}
    func tick(at date: Date) {}
}
