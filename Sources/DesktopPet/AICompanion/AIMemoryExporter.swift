import AppKit
import Foundation

public final class AIMemoryExporter: @unchecked Sendable {
    private let store: AIMemoryStoring

    public init(store: AIMemoryStoring) {
        self.store = store
    }

    @MainActor
    @discardableResult
    public func exportWithPanel(petId: String) throws -> Bool {
        let memories = store.loadAll(petId: petId)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(memories)

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "ai-memory-\(petId).json"
        panel.title = "导出 AI 记忆"
        panel.message = "选择保存位置以导出 AI 记忆文件"

        guard panel.runModal() == .OK, let url = panel.url else { return false }
        try data.write(to: url)
        return true
    }

    public func exportToTemp(petId: String) throws -> URL {
        try store.exportMemories(petId: petId)
    }
}
