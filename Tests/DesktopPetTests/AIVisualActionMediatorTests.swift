import Foundation
import DesktopPet

@MainActor
func runAIVisualActionMediatorTests() {
    let tests = AIVisualActionMediatorTests()
    tests.manualGenerationRequestsConfirmationWithUserRequestCandidate()
    tests.manualGenerationReportsDisabledPreference()
}

@MainActor
private struct AIVisualActionMediatorTests {
    private func makeMediator(
        preferences: AIVisualPreferences = AIVisualPreferences(isEnabled: true),
        hasPreviousConfirmation: Bool = false,
        hasActiveOverlay: Bool = false
    ) -> AIVisualActionMediator {
        let suiteName = "AIVisualActionMediatorTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defaults.removePersistentDomain(forName: suiteName)

        let preferencesStore = AIVisualPreferencesStore(userDefaults: defaults)
        preferencesStore.savePreferences(preferences)

        let quotaStore = AIVisualQuotaStore(userDefaults: defaults)
        let coordinator = AIVisualActionCoordinator(
            policy: AIVisualActionPolicy(),
            confirmationController: AIVisualConfirmationController(
                hasPreviousConfirmation: hasPreviousConfirmation
            ),
            quotaStore: quotaStore
        )
        let registry = VisualGenerationProviderRegistry()
        let generationService = VisualGenerationService(registry: registry)
        let baseDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("AIVisualActionMediatorTests-\(UUID().uuidString)", isDirectory: true)

        return AIVisualActionMediator(
            coordinator: coordinator,
            generationService: generationService,
            assetStore: PetVisualAssetStore(baseDirectory: baseDirectory),
            stateController: PetVisualStateController(),
            safetyService: AIVisualSafetyService(),
            quotaStore: quotaStore,
            preferencesStore: preferencesStore,
            visualPreferenceStore: PetVisualPreferenceStore(userDefaults: defaults),
            referenceImageProvider: PetReferenceImageProvider(baseDirectory: baseDirectory),
            hasActiveOverlayProvider: { hasActiveOverlay }
        )
    }

    func manualGenerationRequestsConfirmationWithUserRequestCandidate() {
        let mediator = makeMediator(preferences: AIVisualPreferences(
            isEnabled: true,
            durationPreset: .medium
        ))
        var request: AIVisualConfirmationRequest?
        mediator.onConfirmationRequested = { request = $0 }

        mediator.requestManualGeneration(petId: "pet-1", petName: "Mimi")
        waitForMediatorEvent {
            request != nil
        }

        guard let candidate = request?.candidate else {
            expect(false, "manual generation should request confirmation on first trigger")
            return
        }

        expect(candidate.petId == "pet-1", "candidate should target the current pet")
        expect(candidate.source == .userRequest, "candidate should be a user request")
        expect(candidate.kind == .ambience, "candidate should request an ambient change")
        expect(candidate.renderMode == .replaceWholeImage, "candidate should replace the pet image")
        expect(candidate.requestedDurationSeconds == AIVisualDurationPreset.medium.durationSeconds, "candidate should use the selected duration")
    }

    func manualGenerationReportsDisabledPreference() {
        let mediator = makeMediator(preferences: AIVisualPreferences(isEnabled: false))
        var message: String?
        mediator.onPolicyDenied = { message = $0 }

        mediator.requestManualGeneration(petId: "pet-1", petName: "Mimi")

        expect(message == "AI 视觉表达未开启", "manual generation should report disabled visual expression")
    }

    private func waitForMediatorEvent(
        timeout: TimeInterval = 1,
        condition: @escaping () -> Bool
    ) {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() && Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.01))
        }
        expect(condition(), "timed out waiting for visual mediator event")
    }
}
