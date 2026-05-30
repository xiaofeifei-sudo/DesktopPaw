import Foundation
import DesktopPet

func runDesktopPetLogCustomCategoriesTests() {
    let tests = DesktopPetLogCustomCategoriesTests()
    tests.exposesCustomPetLogCategories()
    tests.keepsExistingLogCategories()
}

private struct DesktopPetLogCustomCategoriesTests {
    func exposesCustomPetLogCategories() {
        expect(DesktopPetLog.petLibraryCategory == "petLibrary", "petLibrary category should be stable")
        expect(DesktopPetLog.bubbleCategory == "bubble", "bubble category should be stable")
        expect(
            DesktopPetLog.categoryNames.contains("petLibrary"),
            "categoryNames should include petLibrary"
        )
        expect(
            DesktopPetLog.categoryNames.contains("bubble"),
            "categoryNames should include bubble"
        )
    }

    func keepsExistingLogCategories() {
        let required: Set<String> = [
            "window",
            "engine",
            "assets",
            "preferences",
            "launchAtLogin"
        ]
        expect(
            required.isSubset(of: DesktopPetLog.categoryNames),
            "custom log categories should not remove MVP log categories"
        )
    }
}
