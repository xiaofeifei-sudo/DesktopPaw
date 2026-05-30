import Foundation

public protocol EmotionalModelStoring: AnyObject, Sendable {
    func loadModel(petId: String) throws -> AIEmotionalModel
    func saveModel(_ model: AIEmotionalModel, petId: String) throws
}

public final class EmotionalModelStore: EmotionalModelStoring, @unchecked Sendable {
    private let fileManager: FileManager
    private var modelCache: [String: AIEmotionalModel] = [:]

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func loadModel(petId: String) throws -> AIEmotionalModel {
        if let cached = modelCache[petId] {
            return cached
        }

        let url = modelFileURL(petId: petId)
        guard fileManager.fileExists(atPath: url.path) else {
            return AIEmotionalModel()
        }

        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let model = try decoder.decode(AIEmotionalModel.self, from: data)
            modelCache[petId] = model
            return model
        } catch {
            DesktopPetLog.aiCompanion.warning("Failed to load emotional model for \(petId): \(error.localizedDescription)")
            return AIEmotionalModel()
        }
    }

    public func saveModel(_ model: AIEmotionalModel, petId: String) throws {
        let url = modelFileURL(petId: petId)
        let directory = url.deletingLastPathComponent()

        if !fileManager.fileExists(atPath: directory.path) {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(model)
        try data.write(to: url, options: .atomic)

        modelCache[petId] = model
    }

    private func modelFileURL(petId: String) -> URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport
            .appendingPathComponent("DesktopPet")
            .appendingPathComponent(petId)
            .appendingPathComponent("emotional-model.json")
    }
}
