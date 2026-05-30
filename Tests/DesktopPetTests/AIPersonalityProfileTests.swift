import Foundation
import DesktopPet

@MainActor
func runAIPersonalityProfileTests() {
    let tests = AIPersonalityProfileTests()
    tests.defaultProfilesContainsFourTypes()
    tests.gentleProfileHasCorrectProperties()
    tests.livelyProfileHasCorrectProperties()
    tests.quietProfileHasCorrectProperties()
    tests.playfulProfileHasCorrectProperties()
    tests.eachProfileHasPreviewPhrases()
    tests.defaultBubbleMaxLengthIs12()
    tests.defaultPanelMaxLengthIs200()
    tests.profileIsCodable()
    tests.profileIsEquatable()
    tests.defaultProfileIdIsGentle()
}

@MainActor
private struct AIPersonalityProfileTests {
    func defaultProfilesContainsFourTypes() {
        let profiles = AIPersonalityProfile.defaultProfiles
        expect(profiles.count == 4, "should have 4 default profiles")
        let names = profiles.map(\.name)
        expect(names.contains("温柔"), "should contain gentle profile")
        expect(names.contains("活泼"), "should contain lively profile")
        expect(names.contains("安静"), "should contain quiet profile")
        expect(names.contains("调皮"), "should contain playful profile")
    }

    func gentleProfileHasCorrectProperties() {
        let p = AIPersonalityProfile.gentle
        expect(p.id == "built-in-gentle", "gentle id")
        expect(p.name == "温柔", "gentle name")
        expect(!p.description.isEmpty, "gentle should have description")
        expect(p.canInitiativeBubble, "gentle can initiative bubble")
    }

    func livelyProfileHasCorrectProperties() {
        let p = AIPersonalityProfile.lively
        expect(p.id == "built-in-lively", "lively id")
        expect(p.name == "活泼", "lively name")
        expect(!p.description.isEmpty, "lively should have description")
        expect(p.canInitiativeBubble, "lively can initiative bubble")
    }

    func quietProfileHasCorrectProperties() {
        let p = AIPersonalityProfile.quiet
        expect(p.id == "built-in-quiet", "quiet id")
        expect(p.name == "安静", "quiet name")
        expect(!p.description.isEmpty, "quiet should have description")
        expect(!p.canInitiativeBubble, "quiet cannot initiative bubble")
    }

    func playfulProfileHasCorrectProperties() {
        let p = AIPersonalityProfile.playful
        expect(p.id == "built-in-playful", "playful id")
        expect(p.name == "调皮", "playful name")
        expect(!p.description.isEmpty, "playful should have description")
        expect(p.canInitiativeBubble, "playful can initiative bubble")
    }

    func eachProfileHasPreviewPhrases() {
        for profile in AIPersonalityProfile.defaultProfiles {
            expect(profile.previewPhrases.count >= 3,
                   "\(profile.name) should have at least 3 preview phrases, got \(profile.previewPhrases.count)")
            for phrase in profile.previewPhrases {
                expect(!phrase.isEmpty, "\(profile.name) preview phrase should not be empty")
            }
        }
    }

    func defaultBubbleMaxLengthIs12() {
        for profile in AIPersonalityProfile.defaultProfiles {
            expect(profile.responseMaxLength == 12,
                   "\(profile.name) bubble max length should be 12")
        }
    }

    func defaultPanelMaxLengthIs200() {
        for profile in AIPersonalityProfile.defaultProfiles {
            expect(profile.panelResponseMaxLength == 200,
                   "\(profile.name) panel max length should be 200")
        }
    }

    func profileIsCodable() {
        let original = AIPersonalityProfile.gentle
        let encoder = JSONEncoder()
        let data = try! encoder.encode(original)
        let decoder = JSONDecoder()
        let decoded = try! decoder.decode(AIPersonalityProfile.self, from: data)
        expect(decoded == original, "profile should survive round-trip coding")
    }

    func profileIsEquatable() {
        let a = AIPersonalityProfile.gentle
        let b = AIPersonalityProfile.gentle
        let c = AIPersonalityProfile.lively
        expect(a == b, "same profiles should be equal")
        expect(a != c, "different profiles should not be equal")
    }

    func defaultProfileIdIsGentle() {
        expect(AIPersonalityProfile.defaultProfileId == AIPersonalityProfile.gentle.id,
               "default profile id should be gentle")
    }
}
