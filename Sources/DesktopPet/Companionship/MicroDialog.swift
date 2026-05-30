import Foundation

public typealias MicroDialogId = String

public struct MicroDialog: Codable, Equatable, Identifiable, Sendable {
    public let id: MicroDialogId
    public let promptPhraseId: String
    public let options: [MicroDialogOption]
    public let expiresAt: Date

    public init(
        id: MicroDialogId,
        promptPhraseId: String,
        options: [MicroDialogOption],
        expiresAt: Date
    ) {
        self.id = id
        self.promptPhraseId = promptPhraseId
        self.options = options
        self.expiresAt = expiresAt
    }

    public static let maxOptionCount = 3

    public static func create(
        id: MicroDialogId,
        promptPhraseId: String,
        options: [MicroDialogOption],
        expiresAt: Date
    ) -> MicroDialog? {
        guard options.count <= maxOptionCount else { return nil }
        guard options.allSatisfy({ !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else { return nil }
        return MicroDialog(
            id: id,
            promptPhraseId: promptPhraseId,
            options: options,
            expiresAt: expiresAt
        )
    }

    public func isExpired(at date: Date) -> Bool {
        expiresAt <= date
    }
}

public struct MicroDialogOption: Codable, Equatable, Identifiable, Sendable {
    public let id: MicroDialogOptionId
    public let title: String
    public let command: MicroDialogCommand

    public init(id: MicroDialogOptionId, title: String, command: MicroDialogCommand) {
        self.id = id
        self.title = title
        self.command = command
    }

    public static func create(
        id: MicroDialogOptionId,
        title: String,
        command: MicroDialogCommand
    ) -> MicroDialogOption? {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return MicroDialogOption(id: id, title: trimmed, command: command)
    }
}
