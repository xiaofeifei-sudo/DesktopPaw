import Foundation
import DesktopPet
import CoreGraphics

@MainActor
func runVisualGenerationCapabilitiesTests() {
    let tests = VisualGenerationCapabilitiesTests()
    tests.defaultInitializerHasNewFieldsOff()
    tests.fullIncludesAllFields()
    tests.basicEqualsDefault()
    tests.equalityIncludesNewFields()
    tests.existingInitCallSitesCompile()
    tests.supportedOutputSizesStored()
    tests.maxInputImageSizeStored()
}

private struct VisualGenerationCapabilitiesTests {
    func defaultInitializerHasNewFieldsOff() {
        let cap = VisualGenerationCapabilities()
        expect(!cap.supportsSubjectReference, "default supportsSubjectReference should be false")
        expect(!cap.supportsNegativePrompt, "default supportsNegativePrompt should be false")
        expect(cap.supportedOutputSizes.isEmpty, "default supportedOutputSizes should be empty")
        expect(cap.maxInputImageSize == 0, "default maxInputImageSize should be 0")
        expect(!cap.supportsSeed, "default supportsSeed should be false")
        expect(!cap.supportsBase64Response, "default supportsBase64Response should be false")
    }

    func fullIncludesAllFields() {
        let cap = VisualGenerationCapabilities.full
        expect(cap.supportsSubjectReference, "full supportsSubjectReference should be true")
        expect(cap.supportsNegativePrompt, "full supportsNegativePrompt should be true")
        expect(!cap.supportedOutputSizes.isEmpty, "full supportedOutputSizes should not be empty")
        expect(cap.maxInputImageSize > 0, "full maxInputImageSize should be positive")
        expect(cap.supportsSeed, "full supportsSeed should be true")
        expect(cap.supportsBase64Response, "full supportsBase64Response should be true")
    }

    func basicEqualsDefault() {
        let basic = VisualGenerationCapabilities.basic
        let `default` = VisualGenerationCapabilities()
        expect(basic == `default`, "basic should equal default init")
    }

    func equalityIncludesNewFields() {
        let a = VisualGenerationCapabilities(supportsSeed: true)
        let b = VisualGenerationCapabilities(supportsSeed: false)
        expect(a != b, "different supportsSeed should not be equal")

        let c = VisualGenerationCapabilities(supportedOutputSizes: [CGSize(width: 512, height: 512)])
        let d = VisualGenerationCapabilities(supportedOutputSizes: [CGSize(width: 1024, height: 1024)])
        expect(c != d, "different supportedOutputSizes should not be equal")

        let e = VisualGenerationCapabilities(maxInputImageSize: 2048)
        let f = VisualGenerationCapabilities(maxInputImageSize: 4096)
        expect(e != f, "different maxInputImageSize should not be equal")
    }

    func existingInitCallSitesCompile() {
        let _ = VisualGenerationCapabilities(
            supportsReferenceImage: true,
            supportsImageEdit: false,
            supportsTransparentBackground: true,
            supportsQuotaSnapshot: false
        )
        let _ = VisualGenerationCapabilities(
            supportsReferenceImage: false,
            supportsImageEdit: false,
            supportsTransparentBackground: false,
            supportsQuotaSnapshot: false
        )
    }

    func supportedOutputSizesStored() {
        let sizes = [
            CGSize(width: 512, height: 512),
            CGSize(width: 1024, height: 1024),
        ]
        let cap = VisualGenerationCapabilities(supportedOutputSizes: sizes)
        expect(cap.supportedOutputSizes == sizes, "supportedOutputSizes should store provided sizes")
    }

    func maxInputImageSizeStored() {
        let cap = VisualGenerationCapabilities(maxInputImageSize: 4096)
        expect(cap.maxInputImageSize == 4096, "maxInputImageSize should store provided value")
    }
}
