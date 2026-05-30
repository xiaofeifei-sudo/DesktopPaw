import Foundation
import DesktopPet

func runMicroDialogTests() {
    let tests = MicroDialogTests()
    tests.createWithValidOptions()
    tests.createRejectsMoreThanThreeOptions()
    tests.createRejectsEmptyTitle()
    tests.createRejectsWhitespaceOnlyTitle()
    tests.isExpiredReturnsTrueWhenExpired()
    tests.isExpiredReturnsFalseWhenNotExpired()
    tests.optionCreateTrimsWhitespace()
    tests.optionCreateRejectsEmptyTitle()
    tests.microDialogIdAndOptionIdUsage()
    tests.codableRoundTrip()
}

private struct MicroDialogTests {
    private let now = Date()
    private let futureDate = Date().addingTimeInterval(60)

    func createWithValidOptions() {
        let options = [
            MicroDialogOption(id: MicroDialogOptionId(rawValue: "feed"), title: "Feed", command: .feed),
            MicroDialogOption(id: MicroDialogOptionId(rawValue: "wait"), title: "Wait", command: .dismiss(replyTrigger: nil))
        ]

        let dialog = MicroDialog.create(
            id: "dialog-1",
            promptPhraseId: "hungry-0",
            options: options,
            expiresAt: futureDate
        )

        expect(dialog != nil, "create should succeed with valid options")
        expect(dialog!.id == "dialog-1", "id should match")
        expect(dialog!.promptPhraseId == "hungry-0", "promptPhraseId should match")
        expect(dialog!.options.count == 2, "options count should be 2")
        expect(dialog!.expiresAt == futureDate, "expiresAt should match")
    }

    func createRejectsMoreThanThreeOptions() {
        let options = (1...4).map { i in
            MicroDialogOption(id: MicroDialogOptionId(rawValue: "opt-\(i)"), title: "Option \(i)", command: .dismiss(replyTrigger: nil))
        }

        let dialog = MicroDialog.create(
            id: "dialog-2",
            promptPhraseId: "prompt",
            options: options,
            expiresAt: futureDate
        )

        expect(dialog == nil, "create should reject more than 3 options")
    }

    func createRejectsEmptyTitle() {
        let options = [
            MicroDialogOption(id: MicroDialogOptionId(rawValue: "feed"), title: "", command: .feed)
        ]

        let dialog = MicroDialog.create(
            id: "dialog-3",
            promptPhraseId: "prompt",
            options: options,
            expiresAt: futureDate
        )

        expect(dialog == nil, "create should reject empty title option")
    }

    func createRejectsWhitespaceOnlyTitle() {
        let options = [
            MicroDialogOption(id: MicroDialogOptionId(rawValue: "opt"), title: "  ", command: .pet)
        ]

        let dialog = MicroDialog.create(
            id: "dialog-4",
            promptPhraseId: "prompt",
            options: options,
            expiresAt: futureDate
        )

        expect(dialog == nil, "create should reject whitespace-only title (since create uses MicroDialogOption which trims)")
    }

    func isExpiredReturnsTrueWhenExpired() {
        let pastDate = now.addingTimeInterval(-1)
        let dialog = MicroDialog(
            id: "expired",
            promptPhraseId: "prompt",
            options: [],
            expiresAt: pastDate
        )

        expect(dialog.isExpired(at: now), "dialog should be expired when expiresAt is in the past")
    }

    func isExpiredReturnsFalseWhenNotExpired() {
        let dialog = MicroDialog(
            id: "active",
            promptPhraseId: "prompt",
            options: [],
            expiresAt: futureDate
        )

        expect(!dialog.isExpired(at: now), "dialog should not be expired when expiresAt is in the future")
    }

    func optionCreateTrimsWhitespace() {
        let option = MicroDialogOption.create(
            id: MicroDialogOptionId(rawValue: "opt"),
            title: "  Feed it  ",
            command: .feed
        )

        expect(option != nil, "create should accept whitespace-padded title")
        expect(option!.title == "Feed it", "create should trim whitespace from title")
    }

    func optionCreateRejectsEmptyTitle() {
        let option = MicroDialogOption.create(
            id: MicroDialogOptionId(rawValue: "opt"),
            title: "",
            command: .pet
        )

        expect(option == nil, "create should reject empty title")
    }

    func microDialogIdAndOptionIdUsage() {
        let dialogId: MicroDialogId = "test-dialog-123"
        let optionId = MicroDialogOptionId(rawValue: "option-a")

        expect(dialogId == "test-dialog-123", "MicroDialogId should be a String")
        expect(optionId.rawValue == "option-a", "MicroDialogOptionId should preserve rawValue")
    }

    func codableRoundTrip() {
        let options = [
            MicroDialogOption(id: MicroDialogOptionId(rawValue: "pet"), title: "Pet", command: .pet),
            MicroDialogOption(id: MicroDialogOptionId(rawValue: "dismiss"), title: "Later", command: .dismiss(replyTrigger: .idle))
        ]
        let dialog = MicroDialog(
            id: "encode-test",
            promptPhraseId: "hungry-0",
            options: options,
            expiresAt: futureDate
        )

        do {
            let data = try JSONEncoder().encode(dialog)
            let decoded = try JSONDecoder().decode(MicroDialog.self, from: data)

            expect(decoded == dialog, "MicroDialog should round-trip through Codable")
            expect(decoded.options.count == 2, "decoded options count should be 2")
        } catch {
            fail("MicroDialog Codable round-trip should not throw: \(error)")
        }
    }
}
