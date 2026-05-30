import AppKit
import DesktopPet

@MainActor
func runActionsMenuBuilderTests() {
    let tests = ActionsMenuBuilderTests()
    tests.twelveActionsStayInMainMenuWithoutMore()
    tests.thirteenActionsKeepTwelveMainItemsAndMoveOneToMore()
    tests.sortsRolesBeforeExtrasByDisplayName()
    tests.rejectedBusyDisablesActionItems()
    tests.menuItemTitlesDoNotIncludeTags()
    tests.menuItemTriggerPassesActionIdToClosure()
}

@MainActor
private struct ActionsMenuBuilderTests {
    func twelveActionsStayInMainMenuWithoutMore() {
        let catalog = makeCatalog(extraNames: ["Extra A", "Extra B", "Extra C", "Extra D", "Extra E"])
        let menu = makeMenu(catalog: catalog)

        expect(menu.items.count == 12, "12 actions should produce 12 main menu items")
        expect(menu.item(withTitle: "More") == nil, "12 actions should not create More submenu")
    }

    func thirteenActionsKeepTwelveMainItemsAndMoveOneToMore() {
        let catalog = makeCatalog(extraNames: ["Extra A", "Extra B", "Extra C", "Extra D", "Extra E", "Extra F"])
        let menu = makeMenu(catalog: catalog)

        expect(menu.items.count == 13, "13 actions should produce 12 action items plus More")
        let moreItem = menu.item(withTitle: "More")
        expect(moreItem?.submenu?.items.count == 1, "More submenu should contain one overflow action")
        expect(actionItems(in: menu).count == 12, "main menu should keep first 12 action items")
    }

    func sortsRolesBeforeExtrasByDisplayName() {
        let catalog = makeCatalog(extraNames: ["Zulu", "Alpha", "Middle"])
        let menu = makeMenu(catalog: catalog)

        let expected = [
            "Idle",
            "Walking",
            "Sleeping",
            "Happy",
            "Eating",
            "Jumping",
            "Dragging",
            "Alpha",
            "Middle",
            "Zulu"
        ]
        expect(actionItems(in: menu).map(\.title) == expected, "actions should be role ordered, then extras by displayName")
    }

    func rejectedBusyDisablesActionItems() {
        let catalog = makeCatalog(extraNames: ["Extra A", "Extra B", "Extra C", "Extra D", "Extra E"])
        let menu = makeMenu(catalog: catalog) { _ in
            .rejectedBusy(reason: ActionTriggerService.busyReason)
        }

        expect(actionItems(in: menu).allSatisfy { !$0.isEnabled }, "rejectedBusy should disable every action item")
    }

    func menuItemTitlesDoNotIncludeTags() {
        let tag = ActionTag(rawValue: "mood:high")!
        let extra = makeAction(id: "extra_tagged", displayName: "Tagged Extra", role: nil, tags: [tag])
        let catalog = PetActionCatalog(petId: "pet", actions: roleActions() + [extra], warnings: [])
        let menu = makeMenu(catalog: catalog)

        let titles = actionItems(in: menu).map(\.title)
        expect(titles.contains("Tagged Extra"), "menu should show action displayName")
        expect(!titles.contains(tag.rawValue), "menu should not render tag as its own title")
        expect(titles.allSatisfy { !$0.contains(tag.rawValue) }, "menu titles should not include tag text")
    }

    func menuItemTriggerPassesActionIdToClosure() {
        let catalog = makeCatalog(extraNames: ["Extra A"])
        var triggered: [ActionId] = []
        let menu = ActionsMenuBuilder().buildMenu(
            catalog: catalog,
            eligibility: { _ in .allowed },
            trigger: { actionId in
                triggered.append(actionId)
            }
        )

        let representedObject = actionItems(in: menu).first?.representedObject
        expect(representedObject is ActionsMenuItemTrigger, "menu item should retain an ActionsMenuItemTrigger representedObject")
        let handler = representedObject as! ActionsMenuItemTrigger

        handler.trigger()
        expect(triggered == [handler.actionId], "trigger closure should receive represented actionId")
    }

    private func makeMenu(
        catalog: PetActionCatalog,
        eligibility: @escaping (ActionId) -> ActionTriggerEligibility = { _ in .allowed }
    ) -> NSMenu {
        ActionsMenuBuilder().buildMenu(
            catalog: catalog,
            eligibility: eligibility,
            trigger: { _ in }
        )
    }

    private func makeCatalog(extraNames: [String]) -> PetActionCatalog {
        let extras = extraNames.enumerated().map { index, name in
            makeAction(id: "extra_\(index)", displayName: name, role: nil)
        }
        return PetActionCatalog(
            petId: "pet",
            actions: extras + Array(roleActions().reversed()),
            warnings: []
        )
    }

    private func roleActions() -> [Action] {
        [
            makeAction(id: "idle_default", displayName: "Idle", role: .idle),
            makeAction(id: "walking_default", displayName: "Walking", role: .walking),
            makeAction(id: "sleeping_default", displayName: "Sleeping", role: .sleeping),
            makeAction(id: "happy_default", displayName: "Happy", role: .happy),
            makeAction(id: "eating_default", displayName: "Eating", role: .eating),
            makeAction(id: "jumping_default", displayName: "Jumping", role: .jumping),
            makeAction(id: "dragging_default", displayName: "Dragging", role: .dragging)
        ]
    }

    private func makeAction(
        id rawId: String,
        displayName: String,
        role: ActionRole?,
        tags: [ActionTag] = []
    ) -> Action {
        Action(
            id: ActionId(rawValue: rawId)!,
            displayName: displayName,
            role: role,
            tags: tags,
            frames: [SpriteFrame(column: 0, row: 0)],
            frameDurationMs: 120,
            loop: role == .idle || role == .walking || role == .sleeping || role == .dragging
        )
    }

    private func actionItems(in menu: NSMenu) -> [NSMenuItem] {
        menu.items.filter { $0.submenu == nil && !$0.isSeparatorItem }
    }
}
