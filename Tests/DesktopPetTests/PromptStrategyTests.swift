import AppKit
import Foundation
import DesktopPet

@MainActor
func runPromptStrategyTests() async throws {
    let tests = PromptStrategyTests()
    tests.subtleExpressionTemplateContainsConstraints()
    tests.subtleAmbienceTemplateContainsConstraints()
    tests.smallAccessoryTemplateContainsConstraints()
    tests.themeVariationTemplateContainsConstraints()
    tests.creativeVariationTemplateContainsConstraints()

    tests.identityConstraintsIncludeSpeciesAndColors()
    tests.identityConstraintsIncludeStyleAndAlpha()
    tests.identityConstraintsOmitEmptyFields()
    tests.identityConstraintsIncludeLearnedConstraints()

    tests.conservativeNegativeConstraintsAreStrict()
    tests.balancedNegativeConstraintsAreModerate()
    tests.creativeNegativeConstraintsPreserveIdentityOnly()
    tests.subtleIntentsAddBodyConstraint()

    tests.visualNotesIncludedInFinalPrompt()
    tests.emptyVisualNotesOmitted()

    tests.finalPromptAssembledCorrectly()
    tests.finalPromptTruncatedAtMaxLength()
    tests.finalPromptWithoutDescriptorStillValid()

    tests.defaultIntentForUserRequestIsSubtleAmbience()
    tests.defaultIntentForChatIsSubtleAmbienceConservative()
    tests.defaultIntentForChatIsSubtleAmbienceCreative()

    try await tests.mediatorUsesPromptStrategy()
    try await tests.mediatorUsesCurrentPetsConsistencyPreference()
    try await tests.mediatorPassesStrategyMetadataToGenerationRequest()
}

@MainActor
private struct PromptStrategyTests {
    private let strategy = PromptStrategy()

    private func makeDescriptor(
        speciesHint: String? = "fox",
        nameHint: String? = "Test Pet",
        dominantColors: [String] = ["#FFB6C1", "#FFFFFF"],
        hasAlpha: Bool = true,
        estimatedStyle: String? = "2d-sprite",
        width: Int = 192,
        height: Int = 208,
        visualNotes: String? = nil,
        learnedConstraints: [String] = []
    ) -> PetDescriptor {
        PetDescriptor(
            petId: "test-pet",
            speciesHint: speciesHint,
            nameHint: nameHint,
            referenceImageTraits: ImageTraits(
                dominantColors: dominantColors,
                hasAlpha: hasAlpha,
                estimatedStyle: estimatedStyle,
                width: width,
                height: height
            ),
            visualNotes: visualNotes,
            learnedConstraints: learnedConstraints
        )
    }

    // MARK: - D-3.4 Intent Templates

    func subtleExpressionTemplateContainsConstraints() {
        let result = strategy.buildPrompt(
            intent: .subtleExpression,
            petDescriptor: makeDescriptor(),
            preference: .conservative,
            actionKind: .expression
        )
        expect(result.corePrompt.contains("subtle expression-only change"), "subtleExpression core should mention expression change")
        expect(result.corePrompt.contains("colors"), "subtleExpression should mention keeping colors")
        expect(result.finalPrompt.contains("expression-only change"), "final should contain core prompt")
    }

    func subtleAmbienceTemplateContainsConstraints() {
        let result = strategy.buildPrompt(
            intent: .subtleAmbience,
            petDescriptor: makeDescriptor(),
            preference: .conservative,
            actionKind: .ambience
        )
        expect(result.corePrompt.contains("subtle ambient effect"), "subtleAmbience core should mention ambient")
        expect(result.corePrompt.contains("Do not change the character itself"), "subtleAmbience should preserve character")
    }

    func smallAccessoryTemplateContainsConstraints() {
        let result = strategy.buildPrompt(
            intent: .smallAccessory,
            petDescriptor: makeDescriptor(),
            preference: .balanced,
            actionKind: .accessory
        )
        expect(result.corePrompt.contains("small accessory"), "smallAccessory core should mention accessory")
        expect(result.corePrompt.contains("Keep the character unchanged"), "smallAccessory should keep character")
    }

    func themeVariationTemplateContainsConstraints() {
        let result = strategy.buildPrompt(
            intent: .themeVariation,
            petDescriptor: makeDescriptor(),
            preference: .balanced,
            actionKind: .theme
        )
        expect(result.corePrompt.contains("themed variation"), "themeVariation core should mention theme")
        expect(result.corePrompt.contains("same character identity"), "themeVariation should preserve identity")
    }

    func creativeVariationTemplateContainsConstraints() {
        let result = strategy.buildPrompt(
            intent: .creativeVariation,
            petDescriptor: makeDescriptor(),
            preference: .creative,
            actionKind: .theme
        )
        expect(result.corePrompt.contains("creative variation"), "creativeVariation core should mention creative")
        expect(result.corePrompt.contains("core character identity"), "creativeVariation should preserve identity")
    }

    // MARK: - D-3.5 Identity Constraints

    func identityConstraintsIncludeSpeciesAndColors() {
        let result = strategy.buildPrompt(
            intent: .subtleAmbience,
            petDescriptor: makeDescriptor(),
            preference: .conservative,
            actionKind: .ambience
        )
        expect(result.identityConstraints.contains(where: { $0.contains("fox") }), "should include species")
        expect(result.identityConstraints.contains(where: { $0.contains("#FFB6C1") }), "should include dominant color")
        expect(result.finalPrompt.contains("fox"), "final prompt should contain species")
    }

    func identityConstraintsIncludeStyleAndAlpha() {
        let result = strategy.buildPrompt(
            intent: .subtleAmbience,
            petDescriptor: makeDescriptor(),
            preference: .conservative,
            actionKind: .ambience
        )
        expect(result.identityConstraints.contains(where: { $0.contains("2d-sprite") }), "should include style")
        expect(result.identityConstraints.contains(where: { $0.contains("Transparent") }), "should mention transparency")
        expect(result.styleGuidance == "Preserve the 2d-sprite art style.", "style guidance should reference detected style")
    }

    func identityConstraintsOmitEmptyFields() {
        let descriptor = PetDescriptor(petId: "empty-pet")
        let result = strategy.buildPrompt(
            intent: .subtleAmbience,
            petDescriptor: descriptor,
            preference: .conservative,
            actionKind: .ambience
        )
        expect(result.identityConstraints.isEmpty, "empty descriptor should have no identity constraints")
    }

    func identityConstraintsIncludeLearnedConstraints() {
        let descriptor = makeDescriptor(learnedConstraints: ["no-3d", "keep-pink-white"])
        let result = strategy.buildPrompt(
            intent: .subtleAmbience,
            petDescriptor: descriptor,
            preference: .conservative,
            actionKind: .ambience
        )
        expect(result.identityConstraints.contains("no-3d"), "should include learned constraint")
        expect(result.identityConstraints.contains("keep-pink-white"), "should include learned constraint")
    }

    // MARK: - D-3.6 Negative Constraints by Preference

    func conservativeNegativeConstraintsAreStrict() {
        let result = strategy.buildPrompt(
            intent: .subtleAmbience,
            petDescriptor: makeDescriptor(),
            preference: .conservative,
            actionKind: .ambience
        )
        expect(result.negativeConstraints.count >= 5, "conservative should have at least 5 negative constraints")
        expect(result.negativeConstraints.contains(where: { $0.contains("Do not redesign") }), "should forbid redesign")
        expect(result.negativeConstraints.contains(where: { $0.contains("3D") }), "should forbid 3D")
        expect(result.negativeConstraints.contains(where: { $0.contains("Preserve all visible accessories") }), "should preserve accessories")
        expect(result.finalPrompt.contains("Do not redesign"), "final prompt should contain negative constraints")
    }

    func balancedNegativeConstraintsAreModerate() {
        let result = strategy.buildPrompt(
            intent: .subtleAmbience,
            petDescriptor: makeDescriptor(),
            preference: .balanced,
            actionKind: .ambience
        )
        expect(result.negativeConstraints.count >= 3, "balanced should have fewer constraints than conservative")
        expect(result.negativeConstraints.contains(where: { $0.contains("Do not redesign") }), "should forbid redesign")
    }

    func creativeNegativeConstraintsPreserveIdentityOnly() {
        let result = strategy.buildPrompt(
            intent: .subtleAmbience,
            petDescriptor: makeDescriptor(),
            preference: .creative,
            actionKind: .ambience
        )
        expect(result.negativeConstraints.count >= 2, "creative should have fewest constraints")
        expect(result.negativeConstraints.contains(where: { $0.contains("same character species and identity") }), "should preserve species and identity")
    }

    func subtleIntentsAddBodyConstraint() {
        let exprResult = strategy.buildPrompt(
            intent: .subtleExpression,
            petDescriptor: makeDescriptor(),
            preference: .conservative,
            actionKind: .expression
        )
        expect(exprResult.negativeConstraints.contains(where: { $0.contains("body shape") }), "subtle expression should forbid body changes")

        let themeResult = strategy.buildPrompt(
            intent: .themeVariation,
            petDescriptor: makeDescriptor(),
            preference: .conservative,
            actionKind: .theme
        )
        expect(!themeResult.negativeConstraints.contains(where: { $0.contains("body shape") }), "theme variation should not add body constraint")
    }

    // MARK: - D-3.7 Visual Notes

    func visualNotesIncludedInFinalPrompt() {
        let descriptor = makeDescriptor(visualNotes: "pink-white fox with purple chest ornament")
        let result = strategy.buildPrompt(
            intent: .subtleAmbience,
            petDescriptor: descriptor,
            preference: .conservative,
            actionKind: .ambience
        )
        expect(result.finalPrompt.contains("pink-white fox with purple chest ornament"), "final prompt should include visual notes")
        expect(result.finalPrompt.contains("User description:"), "should label user description")
    }

    func emptyVisualNotesOmitted() {
        let descriptor = makeDescriptor(visualNotes: nil)
        let result = strategy.buildPrompt(
            intent: .subtleAmbience,
            petDescriptor: descriptor,
            preference: .conservative,
            actionKind: .ambience
        )
        expect(!result.finalPrompt.contains("User description:"), "should not include user description label when notes are nil")
    }

    // MARK: - D-3.8 Prompt Assembly

    func finalPromptAssembledCorrectly() {
        let result = strategy.buildPrompt(
            intent: .subtleAmbience,
            petDescriptor: makeDescriptor(),
            preference: .conservative,
            actionKind: .ambience
        )
        expect(result.finalPrompt.contains("centered character"), "should include quality constraint")
        expect(result.finalPrompt.contains("macOS desktop pet"), "should include platform constraint")
        expect(!result.finalPrompt.contains("fresh"), "should NOT contain old prompt language")
        expect(!result.finalPrompt.contains("cute visual variation"), "should NOT contain old prompt language")
    }

    func finalPromptTruncatedAtMaxLength() {
        let shortStrategy = PromptStrategy(maxPromptLength: 100)
        let result = shortStrategy.buildPrompt(
            intent: .subtleAmbience,
            petDescriptor: makeDescriptor(),
            preference: .conservative,
            actionKind: .ambience
        )
        expect(result.finalPrompt.count <= 100, "should truncate to max length")
    }

    func finalPromptWithoutDescriptorStillValid() {
        let emptyDescriptor = PetDescriptor(petId: "empty")
        let result = strategy.buildPrompt(
            intent: .subtleAmbience,
            petDescriptor: emptyDescriptor,
            preference: .conservative,
            actionKind: .ambience
        )
        expect(!result.finalPrompt.isEmpty, "should produce a valid prompt even without descriptor")
        expect(result.finalPrompt.contains("ambient effect"), "should still have core prompt")
    }

    // MARK: - D-3.1 Default Intent Mapping

    func defaultIntentForUserRequestIsSubtleAmbience() {
        let intent = GenerationIntent.defaultIntent(for: .userRequest, preference: .conservative)
        expect(intent == .subtleAmbience, "user request should default to subtleAmbience")
    }

    func defaultIntentForChatIsSubtleAmbienceConservative() {
        let intent = GenerationIntent.defaultIntent(for: .chat, preference: .conservative)
        expect(intent == .subtleAmbience, "chat with conservative should be subtleAmbience")
    }

    func defaultIntentForChatIsSubtleAmbienceCreative() {
        let intent = GenerationIntent.defaultIntent(for: .chat, preference: .creative)
        expect(intent == .smallAccessory, "chat with creative should be smallAccessory")
    }

    // MARK: - Mediator Integration

    func mediatorUsesPromptStrategy() async throws {
        let fm = FileManager.default
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("prompt-strategy-tests-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: dir) }

        let suiteName = "PromptStrategyTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let petDir = dir.appendingPathComponent("pet-strategy-test")
        let manifest: [String: Any] = [
            "id": "kitsune-miko",
            "displayName": "Yae Miko",
            "description": "Fox pet",
            "schemaVersion": 2,
            "asset": "sprite.png",
            "assetKind": "spriteSheet",
            "frameSize": ["width": 192, "height": 208],
            "defaultScale": 1.0,
            "actions": [],
        ]
        try fm.createDirectory(at: petDir, withIntermediateDirectories: true)
        let manifestData = try JSONSerialization.data(withJSONObject: manifest)
        try manifestData.write(to: petDir.appendingPathComponent("manifest.json"))

        let preferenceStore = PetVisualPreferenceStore(userDefaults: defaults)
        var visualPrefs = preferenceStore.loadPreferences()
        visualPrefs.consistencyPreference = .conservative
        preferenceStore.savePreferences(visualPrefs)

        let identityStore = PetIdentityDescriptorStore(
            baseDirectory: dir,
            visualPreferenceStore: preferenceStore
        )
        let traits = ImageTraits(
            dominantColors: ["#FFB6C1"],
            hasAlpha: true,
            estimatedStyle: "2d-sprite",
            width: 192,
            height: 208
        )
        identityStore.updateReferenceImageTraits(traits, for: "pet-strategy-test")
        try await identityStore.updateVisualNotes("pink-white fox", for: "pet-strategy-test")

        let aiPreferencesStore = AIVisualPreferencesStore(userDefaults: defaults)
        aiPreferencesStore.savePreferences(AIVisualPreferences(isEnabled: true, durationPreset: .short))
        let quotaStore = AIVisualQuotaStore(userDefaults: defaults)
        let coordinator = AIVisualActionCoordinator(
            policy: AIVisualActionPolicy(),
            confirmationController: AIVisualConfirmationController(hasPreviousConfirmation: true),
            quotaStore: quotaStore
        )
        let generationService = PromptCapturingGenerationService()
        let diagnosticsStore = GenerationDiagnosticsStore(baseDirectory: dir)
        let promptStrategy = PromptStrategy()

        let mediator = AIVisualActionMediator(
            coordinator: coordinator,
            generationService: generationService,
            assetStore: PetVisualAssetStore(baseDirectory: dir),
            stateController: PetVisualStateController(),
            safetyService: AIVisualSafetyService(),
            quotaStore: quotaStore,
            preferencesStore: aiPreferencesStore,
            visualPreferenceStore: preferenceStore,
            generationDiagnosticsRecorder: diagnosticsStore,
            petIdentityDescriber: identityStore,
            promptStrategy: promptStrategy,
            referenceImageProvider: PetReferenceImageProvider(baseDirectory: dir),
            getReferenceImage: {
                let size = NSSize(width: 8, height: 8)
                let image = NSImage(size: size)
                image.lockFocus()
                NSColor(deviceRed: 1, green: 0.42, blue: 0.7, alpha: 1)
                    .drawSwatch(in: NSRect(origin: .zero, size: size))
                image.unlockFocus()
                return image
            },
            hasActiveOverlayProvider: { false }
        )

        var changedDescription: String?
        mediator.onVisualChanged = { changedDescription = $0 }

        mediator.requestManualGeneration(petId: "pet-strategy-test", petName: "Yae Miko")
        try await waitUntil(timeout: 3) {
            changedDescription != nil
        }

        guard let capturedPrompt = generationService.capturedPrompt else {
            fail("generation service should have captured the prompt")
            return
        }

        expect(!capturedPrompt.contains("fresh"), "should NOT contain old 'fresh' language")
        expect(!capturedPrompt.contains("cute visual variation"), "should NOT contain old variation language")
        expect(capturedPrompt.contains("ambient"), "should contain strategy-built ambient prompt")
        expect(capturedPrompt.contains("fox"), "should contain species from PetDescriptor")
        expect(capturedPrompt.contains("Yae Miko"), "should contain name from PetDescriptor")
        expect(capturedPrompt.contains("#FFB6C1"), "should contain dominant color")
        expect(capturedPrompt.contains("pink-white fox"), "should contain visual notes")
        expect(capturedPrompt.contains("Do not redesign"), "should contain negative constraints")
        expect(capturedPrompt.contains("2d-sprite"), "should contain style guidance")

        let records = diagnosticsStore.recentRecords(limit: 1)
        guard let record = records.first else {
            fail("mediator should finalize a diagnostics record")
            return
        }
        expect(record.finalPrompt == capturedPrompt, "diagnostics should record the strategy-built prompt")
    }

    func mediatorUsesCurrentPetsConsistencyPreference() async throws {
        let fm = FileManager.default
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("PromptStrategyPerPetPreference-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: dir) }

        let suiteName = "PromptStrategyPerPetPreference-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let preferenceStore = PetVisualPreferenceStore(userDefaults: defaults)
        try await preferenceStore.setPreference(.creative, for: "pet-creative")
        try await preferenceStore.setPreference(.conservative, for: "pet-conservative")

        let identityStore = PetIdentityDescriptorStore(
            baseDirectory: dir,
            visualPreferenceStore: preferenceStore
        )
        let traits = ImageTraits(
            dominantColors: ["#FFB6C1"],
            hasAlpha: true,
            estimatedStyle: "2d-sprite",
            width: 128,
            height: 128
        )
        identityStore.updateReferenceImageTraits(traits, for: "pet-creative")

        let aiPreferencesStore = AIVisualPreferencesStore(userDefaults: defaults)
        aiPreferencesStore.savePreferences(AIVisualPreferences(isEnabled: true, durationPreset: .short))
        let quotaStore = AIVisualQuotaStore(userDefaults: defaults)
        let coordinator = AIVisualActionCoordinator(
            policy: AIVisualActionPolicy(),
            confirmationController: AIVisualConfirmationController(hasPreviousConfirmation: true),
            quotaStore: quotaStore
        )
        let generationService = PromptCapturingGenerationService()

        let mediator = AIVisualActionMediator(
            coordinator: coordinator,
            generationService: generationService,
            assetStore: PetVisualAssetStore(baseDirectory: dir),
            stateController: PetVisualStateController(),
            safetyService: AIVisualSafetyService(),
            quotaStore: quotaStore,
            preferencesStore: aiPreferencesStore,
            visualPreferenceStore: preferenceStore,
            petIdentityDescriber: identityStore,
            promptStrategy: PromptStrategy(),
            referenceImageProvider: PetReferenceImageProvider(baseDirectory: dir),
            getReferenceImage: {
                let size = NSSize(width: 8, height: 8)
                let image = NSImage(size: size)
                image.lockFocus()
                NSColor(deviceRed: 1, green: 0.42, blue: 0.7, alpha: 1)
                    .drawSwatch(in: NSRect(origin: .zero, size: size))
                image.unlockFocus()
                return image
            },
            hasActiveOverlayProvider: { false }
        )

        var changedDescription: String?
        mediator.onVisualChanged = { changedDescription = $0 }

        mediator.requestManualGeneration(petId: "pet-creative", petName: "Creative Pet")
        try await waitUntil(timeout: 3) {
            changedDescription != nil
        }

        guard let capturedPrompt = generationService.capturedPrompt else {
            fail("generation service should capture the prompt")
            return
        }

        expect(capturedPrompt.contains("Keep the same character species and identity"), "prompt should use creative preference constraints for the current pet")
        expect(!capturedPrompt.contains("Do not redesign the character"), "prompt should not use conservative constraints for a creative pet")
    }

    func mediatorPassesStrategyMetadataToGenerationRequest() async throws {
        let fm = FileManager.default
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("PromptStrategyRequestMetadata-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: dir) }

        let suiteName = "PromptStrategyRequestMetadata-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let preferenceStore = PetVisualPreferenceStore(userDefaults: defaults)
        try await preferenceStore.setPreference(.balanced, for: "pet-request")
        try await preferenceStore.setVisualNotes("pink-white fox", for: "pet-request")

        let identityStore = PetIdentityDescriptorStore(
            baseDirectory: dir,
            visualPreferenceStore: preferenceStore
        )
        identityStore.updateReferenceImageTraits(
            ImageTraits(
                dominantColors: ["#FFB6C1"],
                hasAlpha: true,
                estimatedStyle: "2d-sprite",
                width: 128,
                height: 128
            ),
            for: "pet-request"
        )

        let aiPreferencesStore = AIVisualPreferencesStore(userDefaults: defaults)
        aiPreferencesStore.savePreferences(AIVisualPreferences(isEnabled: true, durationPreset: .short))
        let quotaStore = AIVisualQuotaStore(userDefaults: defaults)
        let coordinator = AIVisualActionCoordinator(
            policy: AIVisualActionPolicy(),
            confirmationController: AIVisualConfirmationController(hasPreviousConfirmation: true),
            quotaStore: quotaStore
        )
        let generationService = PromptCapturingGenerationService()

        let mediator = AIVisualActionMediator(
            coordinator: coordinator,
            generationService: generationService,
            assetStore: PetVisualAssetStore(baseDirectory: dir),
            stateController: PetVisualStateController(),
            safetyService: AIVisualSafetyService(),
            quotaStore: quotaStore,
            preferencesStore: aiPreferencesStore,
            visualPreferenceStore: preferenceStore,
            petIdentityDescriber: identityStore,
            promptStrategy: PromptStrategy(),
            referenceImageProvider: PetReferenceImageProvider(baseDirectory: dir),
            referenceImagePipeline: ReferenceImagePipeline(baseDirectory: dir),
            getReferenceImage: {
                let size = NSSize(width: 8, height: 8)
                let image = NSImage(size: size)
                image.lockFocus()
                NSColor(deviceRed: 1, green: 0.42, blue: 0.7, alpha: 1)
                    .drawSwatch(in: NSRect(origin: .zero, size: size))
                image.unlockFocus()
                return image
            },
            hasActiveOverlayProvider: { false }
        )

        var changedDescription: String?
        mediator.onVisualChanged = { changedDescription = $0 }

        mediator.requestManualGeneration(petId: "pet-request", petName: "Request Pet")
        try await waitUntil(timeout: 3) {
            changedDescription != nil
        }

        guard let request = generationService.capturedRequest else {
            fail("generation service should capture the request")
            return
        }

        expect(request.generationIntent == .subtleAmbience, "request should include generated intent")
        expect(request.consistencyPreference == .balanced, "request should include current pet consistency preference")
        expect(request.processedReferenceURL == request.referenceImageURL, "request should expose the processed provider reference URL")
        expect(request.processedReferenceURL?.lastPathComponent == "reference-provider.png", "processed reference should be provider friendly")
        expect(request.negativeConstraints?.contains("Do not redesign the character") == true, "request should carry negative constraints")
        expect(request.identityDescription?.contains("#FFB6C1") == true, "request should carry identity colors")
        expect(request.identityDescription?.contains("pink-white fox") == true, "request should carry visual notes")
    }

    private func waitUntil(
        timeout: TimeInterval = 2,
        condition: @escaping () -> Bool
    ) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() && Date() < deadline {
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        expect(condition(), "timed out waiting for async condition")
    }
}

private final class PromptCapturingGenerationService: VisualGenerationServicing, @unchecked Sendable {
    var capturedPrompt: String?
    var capturedRequest: VisualGenerationRequest?

    func generate(_ request: VisualGenerationRequest) async throws -> VisualGenerationResult {
        capturedRequest = request
        capturedPrompt = request.prompt
        let outputURL = request.outputDirectory.appendingPathComponent("\(request.outputPrefix).png")
        try makeRedPNG(at: outputURL)
        return VisualGenerationResult(
            actionId: request.actionId,
            imageURL: outputURL,
            providerId: "prompt-capturing"
        )
    }

    func quotaSnapshot() async throws -> VisualProviderQuotaSnapshot? { nil }
    func currentProviderId() -> String? { "prompt-capturing" }
    func availableProviders() -> [ProviderInfo] { [] }
    func selectProvider(_ providerId: String) -> Bool { true }
    func currentCapabilities() -> VisualGenerationCapabilities? { .full }

    private func makeRedPNG(at url: URL) throws {
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: 4,
            pixelsHigh: 4,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )!
        for y in 0..<4 {
            for x in 0..<4 {
                rep.setColor(NSColor(deviceRed: 1, green: 0, blue: 0, alpha: 1), atX: x, y: y)
            }
        }
        guard let data = rep.representation(using: .png, properties: [:]) else {
            throw PetVisualAssetError.conversionFailed
        }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url)
    }
}
