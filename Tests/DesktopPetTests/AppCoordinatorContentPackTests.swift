import Foundation
import DesktopPet

@MainActor
func runAppCoordinatorContentPackTests() {
    let tests = AppCoordinatorContentPackTests()
    tests.contentPackCommandsRouteToManager()
    tests.contentPackCommandsNotifyAfterSuccessfulMutation()
}

@MainActor
private struct AppCoordinatorContentPackTests {
    func contentPackCommandsRouteToManager() {
        let manager = CoordinatorContentPackManagerSpy()
        let coordinator = AppCoordinator(
            petWindow: CoordinatorContentPackWindowSpy(),
            petCommands: CoordinatorContentPackCommandSpy(),
            settingsWindow: CoordinatorContentPackSettingsSpy(),
            launchAtLogin: CoordinatorContentPackLaunchSpy(),
            application: CoordinatorContentPackApplicationSpy(),
            contentPackManager: manager
        )
        let url = URL(fileURLWithPath: "/tmp/test.dpcp")

        coordinator.handle(.importContentPack(from: url))
        coordinator.handle(.enableContentPack(packId: "pack-a"))
        coordinator.handle(.disableContentPack(packId: "pack-a"))
        coordinator.handle(.removeContentPack(packId: "pack-a"))
        coordinator.handle(.restoreDefaultContent)

        expect(manager.importedURLs == [url], "importContentPack should route to manager")
        expect(manager.enabledIds == ["pack-a"], "enableContentPack should route to manager")
        expect(manager.disabledIds == ["pack-a"], "disableContentPack should route to manager")
        expect(manager.removedIds == ["pack-a"], "removeContentPack should route to manager")
        expect(manager.restoreCount == 1, "restoreDefaultContent should route to manager")
    }

    func contentPackCommandsNotifyAfterSuccessfulMutation() {
        let manager = CoordinatorContentPackManagerSpy()
        var refreshCount = 0
        let coordinator = AppCoordinator(
            petWindow: CoordinatorContentPackWindowSpy(),
            petCommands: CoordinatorContentPackCommandSpy(),
            settingsWindow: CoordinatorContentPackSettingsSpy(),
            launchAtLogin: CoordinatorContentPackLaunchSpy(),
            application: CoordinatorContentPackApplicationSpy(),
            contentPackManager: manager,
            onContentPacksChanged: {
                refreshCount += 1
            }
        )

        coordinator.handle(.importContentPack(from: URL(fileURLWithPath: "/tmp/test.dpcp")))
        coordinator.handle(.enableContentPack(packId: "pack-a"))
        coordinator.handle(.disableContentPack(packId: "pack-a"))
        coordinator.handle(.removeContentPack(packId: "pack-a"))
        coordinator.handle(.restoreDefaultContent)

        expect(refreshCount == 5, "successful content pack commands should refresh runtime integrations")
    }
}

private final class CoordinatorContentPackManagerSpy: ContentPackManaging, @unchecked Sendable {
    private(set) var importedURLs: [URL] = []
    private(set) var enabledIds: [String] = []
    private(set) var disabledIds: [String] = []
    private(set) var removedIds: [String] = []
    private(set) var restoreCount = 0

    func importPack(from url: URL) throws -> ContentPack {
        importedURLs.append(url)
        return ContentPack(
            manifest: ContentPackManifest(
                id: "pack-a",
                name: "Pack",
                author: "Tester",
                version: "1.0.0",
                type: .dialogue,
                description: "Pack",
                previewPhrases: ["hi"],
                safetyTags: ["safe"],
                compatiblePetVersion: ">=1.0.0"
            ),
            installedURL: url,
            isEnabled: false
        )
    }

    func validatePack(at url: URL) -> ContentPackValidationResult { ContentPackValidationResult() }
    func getInstalledPacks() -> [ContentPack] { [] }

    func enablePack(_ packId: String) throws {
        enabledIds.append(packId)
    }

    func disablePack(_ packId: String) throws {
        disabledIds.append(packId)
    }

    func removePack(_ packId: String) throws {
        removedIds.append(packId)
    }

    func previewPack(_ packId: String) throws -> ContentPackPreview {
        ContentPackPreview(packId: packId, type: .dialogue, name: "Pack", previewPhrases: [])
    }

    func restoreDefaultContent() throws {
        restoreCount += 1
    }
}

@MainActor
private final class CoordinatorContentPackCommandSpy: PetCommandHandling {
    var runtimeState = PetRuntimeState.defaultState(at: Date())
    var catalog = PetActionCatalog(petId: "test", actions: [], warnings: [])
    var isSleeping: Bool { false }

    func clicked() {}
    func pet() {}
    func feed() {}
    func sleep() {}
    func wake() {}
    func dragStarted() {}
    func dragEnded() {}
    func playAction(_ id: ActionId) {}
    func setScale(_ scale: Double) {}
    func setRandomWalkingEnabled(_ enabled: Bool) {}
    func tick(at date: Date) {}
}

@MainActor
private final class CoordinatorContentPackWindowSpy: PetWindowControlling {
    var isPetVisible = true
    func showPet() { isPetVisible = true }
    func hidePet() { isPetVisible = false }
    func resetPosition() {}
    func saveStateBeforeQuit() {}
}

@MainActor
private final class CoordinatorContentPackSettingsSpy: SettingsWindowControlling {
    func showSettings() {}
}

@MainActor
private final class CoordinatorContentPackLaunchSpy: LaunchAtLoginControlling {
    var isLaunchAtLoginEnabled = false
    func setLaunchAtLoginEnabled(_ enabled: Bool) { isLaunchAtLoginEnabled = enabled }
}

@MainActor
private final class CoordinatorContentPackApplicationSpy: ApplicationTerminating {
    func terminate() {}
}
