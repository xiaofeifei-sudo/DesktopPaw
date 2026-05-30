import Foundation

public protocol MicroDialogServicing: Sendable {
    func dialog(for phrase: BubblePhrase, context: CompanionContext, now: Date) -> MicroDialog?
    func command(for optionId: MicroDialogOptionId, now: Date) -> MicroDialogCommand?
    func dismissActiveDialog()
}

public final class MicroDialogService: MicroDialogServicing, @unchecked Sendable {
    private let ruleCatalog: MicroDialogRuleCatalog
    private let quietModePolicy: any QuietModeEvaluating
    private let dialogDuration: TimeInterval
    private var activeDialog: MicroDialog?

    public init(
        ruleCatalog: MicroDialogRuleCatalog = MicroDialogRuleCatalog(),
        quietModePolicy: any QuietModeEvaluating = QuietModePolicy(),
        dialogDuration: TimeInterval = 30
    ) {
        self.ruleCatalog = ruleCatalog
        self.quietModePolicy = quietModePolicy
        self.dialogDuration = dialogDuration
    }

    public func dialog(for phrase: BubblePhrase, context: CompanionContext, now: Date) -> MicroDialog? {
        guard phrase.canStartMicroDialog else { return nil }
        guard context.preferences.microDialogsEnabled else { return nil }

        let isQuiet = quietModePolicy.quietState(preferences: context.preferences, at: now) != .inactive
        guard !isQuiet else { return nil }

        guard let options = ruleCatalog.options(for: phrase) else { return nil }

        let dialog = MicroDialog.create(
            id: UUID().uuidString,
            promptPhraseId: phrase.id,
            options: options,
            expiresAt: now.addingTimeInterval(dialogDuration)
        )

        guard let dialog else { return nil }
        activeDialog = dialog
        return dialog
    }

    public func command(for optionId: MicroDialogOptionId, now: Date) -> MicroDialogCommand? {
        guard let dialog = activeDialog else { return nil }
        guard !dialog.isExpired(at: now) else { return nil }
        return dialog.options.first(where: { $0.id == optionId })?.command
    }

    public func dismissActiveDialog() {
        activeDialog = nil
    }

    public func activeDialogOptions(now: Date) -> [MicroDialogOption]? {
        guard let dialog = activeDialog, !dialog.isExpired(at: now) else { return nil }
        return dialog.options
    }

    public func setActiveDialog(_ dialog: MicroDialog?) {
        activeDialog = dialog
    }
}
