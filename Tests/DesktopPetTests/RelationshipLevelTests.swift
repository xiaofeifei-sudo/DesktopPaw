import Foundation
import DesktopPet

func runRelationshipLevelTests() {
    let tests = RelationshipLevelTests()
    tests.mapsDocumentedPointThresholds()
    tests.exposesGentleDisplayNames()
    tests.reportsNextLevelThresholds()
}

private struct RelationshipLevelTests {
    func mapsDocumentedPointThresholds() {
        expect(RelationshipLevel.level(for: 0) == .acquaintance, "0 points should map to Lv.1")
        expect(RelationshipLevel.level(for: 99) == .acquaintance, "99 points should map to Lv.1")
        expect(RelationshipLevel.level(for: 100) == .familiar, "100 points should map to Lv.2")
        expect(RelationshipLevel.level(for: 249) == .familiar, "249 points should map to Lv.2")
        expect(RelationshipLevel.level(for: 250) == .close, "250 points should map to Lv.3")
        expect(RelationshipLevel.level(for: 499) == .close, "499 points should map to Lv.3")
        expect(RelationshipLevel.level(for: 500) == .trusted, "500 points should map to Lv.4")
        expect(RelationshipLevel.level(for: 899) == .trusted, "899 points should map to Lv.4")
        expect(RelationshipLevel.level(for: 900) == .bonded, "900 points should map to Lv.5")
        expect(RelationshipLevel.level(for: -10) == .acquaintance, "negative points should clamp to Lv.1")
    }

    func exposesGentleDisplayNames() {
        expect(RelationshipLevel.acquaintance.levelNumber == 1, "acquaintance should be Lv.1")
        expect(RelationshipLevel.acquaintance.displayName == "初识", "Lv.1 display name should be 初识")
        expect(RelationshipLevel.familiar.displayName == "熟悉", "Lv.2 display name should be 熟悉")
        expect(RelationshipLevel.close.displayName == "亲近", "Lv.3 display name should be 亲近")
        expect(RelationshipLevel.trusted.displayName == "信赖", "Lv.4 display name should be 信赖")
        expect(RelationshipLevel.bonded.displayName == "默契", "Lv.5 display name should be 默契")
    }

    func reportsNextLevelThresholds() {
        expect(RelationshipLevel.acquaintance.minimumPoints == 0, "Lv.1 should start at 0")
        expect(RelationshipLevel.acquaintance.nextLevelMinimumPoints == 100, "Lv.2 should start at 100")
        expect(RelationshipLevel.familiar.nextLevelMinimumPoints == 250, "Lv.3 should start at 250")
        expect(RelationshipLevel.close.nextLevelMinimumPoints == 500, "Lv.4 should start at 500")
        expect(RelationshipLevel.trusted.nextLevelMinimumPoints == 900, "Lv.5 should start at 900")
        expect(RelationshipLevel.bonded.nextLevelMinimumPoints == nil, "Lv.5 should not expose a next threshold")
    }
}
