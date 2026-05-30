import Foundation
import DesktopPet

func runActivityZoneTests() {
    func testActivityZoneContainsPoint() {
        let zone = ActivityZone(id: "z1", rect: CGRect(x: 0, y: 0, width: 100, height: 100))
        expect(zone.contains(CGPoint(x: 50, y: 50)), "zone should contain point inside")
        expect(!zone.contains(CGPoint(x: 150, y: 50)), "zone should not contain point outside")
        expect(zone.contains(CGPoint(x: 0, y: 0)), "zone should contain point on origin edge")
        expect(zone.contains(CGPoint(x: 99, y: 99)), "zone should contain point near far corner")
    }

    func testActivityZoneEquatable() {
        let z1 = ActivityZone(id: "z1", rect: CGRect(x: 0, y: 0, width: 100, height: 100))
        let z2 = ActivityZone(id: "z1", rect: CGRect(x: 0, y: 0, width: 100, height: 100))
        let z3 = ActivityZone(id: "z1", rect: CGRect(x: 10, y: 0, width: 100, height: 100))
        expect(z1 == z2, "identical zones should be equal")
        expect(z1 != z3, "zones with different rects should not be equal")
    }

    func testActivityZoneCodableRoundtrip() {
        let zone = ActivityZone(id: "test-zone", rect: CGRect(x: 10, y: 20, width: 800, height: 600))
        guard let data = try? JSONEncoder().encode(zone),
              let decoded = try? JSONDecoder().decode(ActivityZone.self, from: data) else {
            fail("activity zone codable roundtrip failed")
        }
        expect(decoded.id == "test-zone", "id should survive roundtrip")
        expect(decoded.rect.origin.x == 10, "origin.x should survive roundtrip")
        expect(decoded.rect.origin.y == 20, "origin.y should survive roundtrip")
        expect(decoded.rect.width == 800, "width should survive roundtrip")
        expect(decoded.rect.height == 600, "height should survive roundtrip")
    }

    func testScreenEdgeAllCases() {
        let allCases = ScreenEdge.allCases
        expect(allCases.count == 4, "should have 4 screen edges")
        expect(allCases.contains(.top), "should contain top")
        expect(allCases.contains(.bottom), "should contain bottom")
        expect(allCases.contains(.left), "should contain left")
        expect(allCases.contains(.right), "should contain right")
    }

    func testSpatialSuggestionEquatable() {
        let s1 = SpatialSuggestion.freeRoam
        let s2 = SpatialSuggestion.freeRoam
        let s3 = SpatialSuggestion.lookToward(direction: .top)
        expect(s1 == s2, "identical suggestions should be equal")
        expect(s1 != s3, "different suggestions should not be equal")
    }

    func testDesktopSpaceErrorDescription() {
        let error = DesktopSpaceError.windowListUnavailable
        expect(!error.localizedDescription.isEmpty, "error should have description")
    }

    testActivityZoneContainsPoint()
    testActivityZoneEquatable()
    testActivityZoneCodableRoundtrip()
    testScreenEdgeAllCases()
    testSpatialSuggestionEquatable()
    testDesktopSpaceErrorDescription()
}
