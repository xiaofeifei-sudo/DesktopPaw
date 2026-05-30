import Foundation
import DesktopPet

@MainActor
func runDefaultBubblePhraseSafetyTests() {
    let tests = DefaultBubblePhraseSafetyTests()
    tests.allDefaultPhrasesPassSafetyValidation()
    tests.defaultCatalogPassesSafetyValidation()
}

@MainActor
private struct DefaultBubblePhraseSafetyTests {

    private let validator = BubbleSafetyValidator()

    func allDefaultPhrasesPassSafetyValidation() {
        let phrases = BubblePhraseCatalogBuilder.defaultPhrases()
        for phrase in phrases {
            let result = validator.validate(phrase)
            expect(result.passed,
                   "default phrase '\(phrase.text)' (id: \(phrase.id)) should pass safety validation. " +
                   "Violations: \(result.violations.map { $0.category.rawValue })")
        }
    }

    func defaultCatalogPassesSafetyValidation() {
        let catalog = BubblePhraseCatalogBuilder.defaultCatalog()
        let results = validator.validate(catalog)
        let failures = results.filter { !$0.passed }
        expect(failures.isEmpty,
               "all default catalog phrases should pass safety. " +
               "Failed: \(failures.map { "\($0.phraseId): \($0.violations.map { $0.category.rawValue })" })")
    }
}
