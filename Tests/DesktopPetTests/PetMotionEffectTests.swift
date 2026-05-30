import CoreGraphics
import Foundation
import DesktopPet

@MainActor
func runPetMotionEffectTests() {
    let tests = PetMotionEffectTests()
    tests.identityIsZeroTransform()
    tests.identityIsEqualToItself()
    tests.distinctValuesAreNotEqual()
    tests.identityFromExplicitInitMatchesConstant()
    tests.modifierAcceptsAnyMotionValue()
}

@MainActor
private struct PetMotionEffectTests {
    func identityIsZeroTransform() {
        let value = MotionValue.identity
        expect(value.offset == .zero, "identity should have zero offset")
        expect(value.scale == 1.0, "identity should have unit scale")
        expect(value.rotationDegrees == 0, "identity should have zero rotation")
        expect(value.opacity == 1.0, "identity should have full opacity")
    }

    func identityIsEqualToItself() {
        expect(MotionValue.identity == MotionValue.identity, "identity should equal identity")
    }

    func distinctValuesAreNotEqual() {
        let a = MotionValue(offset: CGSize(width: 1, height: 0), scale: 1.0, rotationDegrees: 0, opacity: 1.0)
        let b = MotionValue(offset: CGSize(width: 0, height: 1), scale: 1.0, rotationDegrees: 0, opacity: 1.0)
        expect(a != b, "different offset axes should not compare equal")
    }

    func identityFromExplicitInitMatchesConstant() {
        let explicit = MotionValue(offset: .zero, scale: 1.0, rotationDegrees: 0, opacity: 1.0)
        expect(explicit == MotionValue.identity, "explicit identity init should equal MotionValue.identity")
    }

    func modifierAcceptsAnyMotionValue() {
        let scaledValue = MotionValue(
            offset: CGSize(width: 5, height: -10),
            scale: 1.2,
            rotationDegrees: 8,
            opacity: 0.9
        )
        let modifier = PetMotionEffect(motionValue: scaledValue)
        _ = modifier
        expect(scaledValue.scale == 1.2, "value should preserve scale field")
        expect(scaledValue.rotationDegrees == 8, "value should preserve rotation field")
        expect(scaledValue.offset.width == 5, "value should preserve x offset")
        expect(scaledValue.offset.height == -10, "value should preserve y offset")
        expect(scaledValue.opacity == 0.9, "value should preserve opacity")
    }
}
