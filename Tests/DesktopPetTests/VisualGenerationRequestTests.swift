import Foundation
import DesktopPet

@MainActor
func runVisualGenerationRequestTests() {
    let tests = VisualGenerationRequestTests()
    tests.defaultInitializerKeepsExtendedMetadataNil()
    tests.extendedInitializerStoresConsistencyMetadata()
    tests.equalityIncludesExtendedMetadata()
}

private struct VisualGenerationRequestTests {
    func defaultInitializerKeepsExtendedMetadataNil() {
        let request = VisualGenerationRequest(
            actionId: "action-1",
            petId: "pet-1",
            prompt: "gentle ambience",
            outputDirectory: URL(fileURLWithPath: "/tmp/out"),
            outputPrefix: "action-1"
        )

        expect(request.generationIntent == nil, "generationIntent should default to nil")
        expect(request.consistencyPreference == nil, "consistencyPreference should default to nil")
        expect(request.processedReferenceURL == nil, "processedReferenceURL should default to nil")
        expect(request.negativeConstraints == nil, "negativeConstraints should default to nil")
        expect(request.identityDescription == nil, "identityDescription should default to nil")
        expect(request.targetWidth == nil, "targetWidth should default to nil")
        expect(request.targetHeight == nil, "targetHeight should default to nil")
        expect(request.seed == nil, "seed should default to nil")
        expect(request.responseFormat == nil, "responseFormat should default to nil")
    }

    func extendedInitializerStoresConsistencyMetadata() {
        let processedURL = URL(fileURLWithPath: "/tmp/ref/reference-provider.png")
        let request = VisualGenerationRequest(
            actionId: "action-2",
            petId: "pet-1",
            prompt: "gentle ambience",
            referenceImageURL: URL(fileURLWithPath: "/tmp/ref/original.png"),
            aspectRatio: "1:1",
            outputDirectory: URL(fileURLWithPath: "/tmp/out"),
            outputPrefix: "action-2",
            count: 1,
            generationIntent: .subtleAmbience,
            consistencyPreference: .balanced,
            processedReferenceURL: processedURL,
            negativeConstraints: ["Do not redesign the character"],
            identityDescription: "pink-white 2D sprite",
            targetWidth: 1024,
            targetHeight: 1024,
            seed: 42,
            responseFormat: "base64"
        )

        expect(request.generationIntent == .subtleAmbience, "should store generation intent")
        expect(request.consistencyPreference == .balanced, "should store consistency preference")
        expect(request.processedReferenceURL == processedURL, "should store processed reference URL")
        expect(request.negativeConstraints == ["Do not redesign the character"], "should store negative constraints")
        expect(request.identityDescription == "pink-white 2D sprite", "should store identity description")
        expect(request.targetWidth == 1024, "should store target width")
        expect(request.targetHeight == 1024, "should store target height")
        expect(request.seed == 42, "should store seed")
        expect(request.responseFormat == "base64", "should store response format")
    }

    func equalityIncludesExtendedMetadata() {
        let base = VisualGenerationRequest(
            actionId: "action-3",
            petId: "pet-1",
            prompt: "gentle ambience",
            outputDirectory: URL(fileURLWithPath: "/tmp/out"),
            outputPrefix: "action-3",
            generationIntent: .subtleAmbience
        )
        let changed = VisualGenerationRequest(
            actionId: "action-3",
            petId: "pet-1",
            prompt: "gentle ambience",
            outputDirectory: URL(fileURLWithPath: "/tmp/out"),
            outputPrefix: "action-3",
            generationIntent: .smallAccessory
        )

        expect(base != changed, "request equality should include extended consistency metadata")
    }
}
