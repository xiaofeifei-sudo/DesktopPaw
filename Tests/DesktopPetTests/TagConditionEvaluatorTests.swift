import Foundation
import DesktopPet

func runTagConditionEvaluatorTests() {
    let tests = TagConditionEvaluatorTests()
    tests.noTagsAreNeutral()
    tests.nonReservedTagIsNeutral()
    tests.moodHighMatchesHigh()
    tests.moodLowMismatchesHigh()
    tests.moodAnyIsNeutral()
    tests.unknownMoodValueIsNeutral()
    tests.afterPetMatchesPendingPet()
    tests.afterPetMismatchesPendingFeed()
    tests.afterPetWithNoPendingTagIsNeutral()
    tests.unknownAfterValueIsNeutral()
    tests.unknownAfterValueMatchingPendingTagCountsAsMatch()
    tests.afterPetWithUnknownPendingAfterTagIsNeutral()
    tests.timeMorningMatchesContextSlot()
    tests.timeMorningMissingFromContextZerosWeight()
    tests.unknownTimeValueIsNeutral()
    tests.moodAndTimeMultipliersCompound()
    tests.reverseConditionInMultiTagZerosWeight()
    tests.afterAndMoodMultipliersCompound()
}

private struct TagConditionEvaluatorTests {
    private let evaluator = DefaultTagConditionEvaluator()

    func noTagsAreNeutral() {
        assertWeight(tags: [], context: context(), equals: 1, "action without tags should have base weight")
    }

    func nonReservedTagIsNeutral() {
        assertWeight(tags: ["vibe:cozy"], context: context(), equals: 1, "non-reserved tags should be neutral")
    }

    func moodHighMatchesHigh() {
        assertWeight(tags: ["mood:high"], context: context(moodLevel: .high), equals: 3, "mood:high should match high mood")
    }

    func moodLowMismatchesHigh() {
        assertWeight(tags: ["mood:low"], context: context(moodLevel: .high), equals: 0, "mood:low should be zero at high mood")
    }

    func moodAnyIsNeutral() {
        assertWeight(tags: ["mood:any"], context: context(moodLevel: .low), equals: 1, "mood:any should stay neutral")
    }

    func unknownMoodValueIsNeutral() {
        assertWeight(tags: ["mood:bright"], context: context(moodLevel: .high), equals: 1, "unknown mood values should be neutral")
    }

    func afterPetMatchesPendingPet() {
        assertWeight(
            tags: ["after.pet"],
            context: context(pendingAfterTag: tag("after.pet")),
            equals: 3,
            "after.pet should match pending after.pet"
        )
    }

    func afterPetMismatchesPendingFeed() {
        assertWeight(
            tags: ["after.pet"],
            context: context(pendingAfterTag: tag("after.feed")),
            equals: 0,
            "after.pet should be zero when pending after tag is after.feed"
        )
    }

    func afterPetWithNoPendingTagIsNeutral() {
        assertWeight(tags: ["after.pet"], context: context(pendingAfterTag: nil), equals: 1, "after tags should be neutral with no pending tag")
    }

    func unknownAfterValueIsNeutral() {
        assertWeight(
            tags: ["after.play"],
            context: context(pendingAfterTag: tag("after.pet")),
            equals: 1,
            "unknown after values should be neutral"
        )
    }

    func unknownAfterValueMatchingPendingTagCountsAsMatch() {
        assertWeight(
            tags: ["after.play"],
            context: context(pendingAfterTag: tag("after.play")),
            equals: 3,
            "unknown after values should match when they are exactly pending"
        )
    }

    func afterPetWithUnknownPendingAfterTagIsNeutral() {
        assertWeight(
            tags: ["after.pet"],
            context: context(pendingAfterTag: tag("after.play")),
            equals: 1,
            "known after tags should be neutral when pending after value is unknown"
        )
    }

    func timeMorningMatchesContextSlot() {
        assertWeight(
            tags: ["time.morning"],
            context: context(timeSlots: [.morning, .workday]),
            equals: 3,
            "time.morning should match morning slot"
        )
    }

    func timeMorningMissingFromContextZerosWeight() {
        assertWeight(
            tags: ["time.morning"],
            context: context(timeSlots: [.afternoon, .workday]),
            equals: 0,
            "time.morning should be zero outside morning slot"
        )
    }

    func unknownTimeValueIsNeutral() {
        assertWeight(
            tags: ["time.lunch"],
            context: context(timeSlots: [.morning, .workday]),
            equals: 1,
            "unknown time values should be neutral"
        )
    }

    func moodAndTimeMultipliersCompound() {
        assertWeight(
            tags: ["mood:high", "time.morning"],
            context: context(moodLevel: .high, timeSlots: [.morning, .workday]),
            equals: 9,
            "matching mood and time tags should multiply"
        )
    }

    func reverseConditionInMultiTagZerosWeight() {
        assertWeight(
            tags: ["mood:high", "time.night"],
            context: context(moodLevel: .high, timeSlots: [.morning, .workday]),
            equals: 0,
            "any reverse known condition should make the final weight zero"
        )
    }

    func afterAndMoodMultipliersCompound() {
        assertWeight(
            tags: ["after.feed", "mood:medium"],
            context: context(moodLevel: .medium, pendingAfterTag: tag("after.feed")),
            equals: 9,
            "matching after and mood tags should multiply"
        )
    }

    private func assertWeight(
        tags rawTags: [String],
        context: TagConditionContext,
        equals expected: Double,
        _ message: String
    ) {
        let action = makeAction(id: "tagged_action", role: nil, tags: rawTags.map(tag))
        let actual = evaluator.weight(for: action, context: context)
        expect(actual == expected, "\(message): expected \(expected), got \(actual)")
    }

    private func context(
        moodLevel: MoodLevel = .medium,
        timeSlots: Set<TimeSlot> = [.afternoon, .workday],
        pendingAfterTag: ActionTag? = nil
    ) -> TagConditionContext {
        TagConditionContext(
            moodLevel: moodLevel,
            timeSlots: timeSlots,
            pendingAfterTag: pendingAfterTag
        )
    }

    private func tag(_ rawValue: String) -> ActionTag {
        guard let tag = ActionTag(rawValue: rawValue) else {
            fail("test tag should be valid: \(rawValue)")
        }
        return tag
    }
}
