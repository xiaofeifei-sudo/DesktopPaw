import Foundation

public struct FeedbackContext: Codable, Sendable, Equatable {
    public let petId: String
    public let promptDigest: String?
    public let lifecycleState: AssetLifecycleState

    public init(
        petId: String,
        promptDigest: String? = nil,
        lifecycleState: AssetLifecycleState
    ) {
        self.petId = petId
        self.promptDigest = promptDigest
        self.lifecycleState = lifecycleState
    }
}

public struct UserFeedbackEntry: Codable, Sendable, Equatable {
    public let id: String
    public let assetId: String
    public let petId: String
    public let type: PreviewFeedbackType
    public let context: FeedbackContext
    public let createdAt: Date

    public init(
        id: String = UUID().uuidString,
        assetId: String,
        petId: String,
        type: PreviewFeedbackType,
        context: FeedbackContext,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.assetId = assetId
        self.petId = petId
        self.type = type
        self.context = context
        self.createdAt = createdAt
    }
}

public struct FeedbackStats: Codable, Sendable, Equatable {
    public let totalCount: Int
    public let notLikeOriginalCount: Int
    public let styleWrongCount: Int
    public let colorWrongCount: Int
    public let accessoryLostCount: Int
    public let goodDirectionCount: Int

    public init(
        totalCount: Int = 0,
        notLikeOriginalCount: Int = 0,
        styleWrongCount: Int = 0,
        colorWrongCount: Int = 0,
        accessoryLostCount: Int = 0,
        goodDirectionCount: Int = 0
    ) {
        self.totalCount = totalCount
        self.notLikeOriginalCount = notLikeOriginalCount
        self.styleWrongCount = styleWrongCount
        self.colorWrongCount = colorWrongCount
        self.accessoryLostCount = accessoryLostCount
        self.goodDirectionCount = goodDirectionCount
    }
}

public protocol UserFeedbackRecording: Sendable {
    func recordFeedback(
        assetId: String,
        type: PreviewFeedbackType,
        context: FeedbackContext
    ) throws

    func feedbackHistory(for petId: String, limit: Int) -> [UserFeedbackEntry]
    func feedbackStats(for petId: String) -> FeedbackStats
    func cleanup(olderThan days: Int) throws
}

public final class UserFeedbackStore: UserFeedbackRecording, @unchecked Sendable {
    private let baseDirectory: URL
    private let fileManager: FileManager
    private let lock = NSLock()

    public init(
        baseDirectory: URL? = nil,
        fileManager: FileManager = .default
    ) {
        self.baseDirectory = baseDirectory ?? PetVisualAssetStore.defaultBaseDirectory()
        self.fileManager = fileManager
    }

    public func recordFeedback(
        assetId: String,
        type: PreviewFeedbackType,
        context: FeedbackContext
    ) throws {
        lock.lock()
        defer { lock.unlock() }

        let entry = UserFeedbackEntry(
            assetId: assetId,
            petId: context.petId,
            type: type,
            context: context
        )

        let dir = feedbackDirectory(petId: context.petId)
        try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)

        let url = dir.appendingPathComponent("\(entry.id).json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(entry)
        try data.write(to: url, options: [.atomic])
    }

    public func feedbackHistory(for petId: String, limit: Int) -> [UserFeedbackEntry] {
        lock.lock()
        defer { lock.unlock() }

        let dir = feedbackDirectory(petId: petId)
        guard let files = try? fileManager.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return files
            .filter { $0.pathExtension == "json" }
            .compactMap { try? decodeEntry(at: $0) }
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(max(limit, 0))
            .map { $0 }
    }

    public func feedbackStats(for petId: String) -> FeedbackStats {
        let entries = feedbackHistory(for: petId, limit: .max)
        return FeedbackStats(
            totalCount: entries.count,
            notLikeOriginalCount: entries.filter { $0.type == .notLikeOriginal }.count,
            styleWrongCount: entries.filter { $0.type == .styleWrong }.count,
            colorWrongCount: entries.filter { $0.type == .colorWrong }.count,
            accessoryLostCount: entries.filter { $0.type == .accessoryLost }.count,
            goodDirectionCount: entries.filter { $0.type == .goodDirection }.count
        )
    }

    public func cleanup(olderThan days: Int) throws {
        lock.lock()
        defer { lock.unlock() }

        let cutoff = Date().addingTimeInterval(-Double(max(days, 0)) * 24 * 60 * 60)
        for petDir in feedbackPetDirectories() {
            guard let files = try? fileManager.contentsOfDirectory(
                at: petDir,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ) else { continue }

            for file in files where file.pathExtension == "json" {
                guard let entry = try? decodeEntry(at: file), entry.createdAt < cutoff else { continue }
                try fileManager.removeItem(at: file)
            }
        }
    }

    // MARK: - Learned Constraints (D-8.9)

    public func learnedConstraintsFromStats(for petId: String) -> [String] {
        let stats = feedbackStats(for: petId)
        var constraints: [String] = []

        if stats.notLikeOriginalCount >= 2 {
            constraints.append("keep-original-appearance")
        }
        if stats.styleWrongCount >= 2 {
            constraints.append("no-style-change")
        }
        if stats.colorWrongCount >= 2 {
            constraints.append("keep-original-colors")
        }
        if stats.accessoryLostCount >= 2 {
            constraints.append("preserve-accessories")
        }

        return constraints
    }

    // MARK: - Private

    private func feedbackDirectory(petId: String) -> URL {
        baseDirectory
            .appendingPathComponent(petId)
            .appendingPathComponent("visual-actions")
            .appendingPathComponent("feedback")
    }

    private func feedbackPetDirectories() -> [URL] {
        guard let petDirs = try? fileManager.contentsOfDirectory(
            at: baseDirectory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return petDirs.compactMap { petDir in
            let feedbackDir = petDir
                .appendingPathComponent("visual-actions")
                .appendingPathComponent("feedback")
            return fileManager.fileExists(atPath: feedbackDir.path) ? feedbackDir : nil
        }
    }

    private func decodeEntry(at url: URL) throws -> UserFeedbackEntry {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(UserFeedbackEntry.self, from: data)
    }
}
