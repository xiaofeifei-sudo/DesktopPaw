import Foundation
import DesktopPet

@MainActor
func runAIMemoryExporterTests() {
    let tests = AIMemoryExporterTests()
    tests.exportToTempCreatesFile()
    tests.exportEmptyMemories()
    tests.exportContainsValidJSON()
}

@MainActor
private struct AIMemoryExporterTests {
    private let testPetId = "export-pet-\(UUID().uuidString.prefix(8))"

    private func makeStore() -> AIMemoryStore {
        AIMemoryStore(fileManager: .default)
    }

    func exportToTempCreatesFile() {
        let store = makeStore()
        defer { try? store.clearAll(petId: testPetId) }

        let memory = AIMemory(
            petId: testPetId,
            category: .preference,
            content: "导出测试",
            source: .userProvided
        )
        try! store.add(memory, petId: testPetId)

        let exporter = AIMemoryExporter(store: store)
        let url = try! exporter.exportToTemp(petId: testPetId)

        expect(FileManager.default.fileExists(atPath: url.path), "export file should exist")
        expect(url.pathExtension == "json", "export file should be json")

        try? FileManager.default.removeItem(at: url)
    }

    func exportEmptyMemories() {
        let store = makeStore()
        defer { try? store.clearAll(petId: testPetId) }

        let exporter = AIMemoryExporter(store: store)
        let url = try! exporter.exportToTemp(petId: testPetId)

        let data = try! Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try! decoder.decode([AIMemory].self, from: data)
        expect(decoded.isEmpty, "empty export should produce empty array")

        try? FileManager.default.removeItem(at: url)
    }

    func exportContainsValidJSON() {
        let store = makeStore()
        defer { try? store.clearAll(petId: testPetId) }

        let m1 = AIMemory(petId: testPetId, category: .nickname, content: "猫猫", source: .userProvided)
        let m2 = AIMemory(petId: testPetId, category: .interaction, content: "一起玩", source: .aiExtracted)
        try! store.add(m1, petId: testPetId)
        try! store.add(m2, petId: testPetId)

        let exporter = AIMemoryExporter(store: store)
        let url = try! exporter.exportToTemp(petId: testPetId)

        let data = try! Data(contentsOf: url)
        let jsonObject = try! JSONSerialization.jsonObject(with: data)
        expect(jsonObject is [Any], "export should be a valid JSON array")

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try! decoder.decode([AIMemory].self, from: data)
        expect(decoded.count == 2, "should have 2 memories, got \(decoded.count)")

        try? FileManager.default.removeItem(at: url)
    }
}
