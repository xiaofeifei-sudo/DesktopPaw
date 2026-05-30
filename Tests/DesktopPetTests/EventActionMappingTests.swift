import Foundation
import DesktopPet

func runEventActionMappingTests() {
    func testRegisterAndRetrieveMapping() {
        let store = EventActionMappingStore()
        store.register(event: "build.success", actionId: "celebrate", bubbleText: "编译成功！")
        let mapping = store.mapping(for: "build.success")
        expect(mapping?.event == "build.success", "should retrieve registered mapping")
        expect(mapping?.actionId == "celebrate", "should retrieve actionId")
        expect(mapping?.bubbleText == "编译成功！", "should retrieve bubbleText")
    }

    func testUnregisterMapping() {
        let store = EventActionMappingStore()
        store.register(event: "build.success", actionId: "celebrate", bubbleText: nil)
        store.unregister(event: "build.success")
        expect(store.mapping(for: "build.success") == nil, "should return nil after unregister")
    }

    func testOverwriteMapping() {
        let store = EventActionMappingStore()
        store.register(event: "build.success", actionId: "celebrate", bubbleText: "编译成功")
        store.register(event: "build.success", actionId: "dance", bubbleText: "完成！")
        let mapping = store.mapping(for: "build.success")
        expect(mapping?.actionId == "dance", "overwritten mapping should have new actionId")
        expect(mapping?.bubbleText == "完成！", "overwritten mapping should have new bubbleText")
    }

    func testAllMappingsSorted() {
        let store = EventActionMappingStore()
        store.register(event: "c", actionId: nil, bubbleText: nil)
        store.register(event: "a", actionId: nil, bubbleText: nil)
        store.register(event: "b", actionId: nil, bubbleText: nil)
        let all = store.allMappings()
        expect(all.count == 3, "should have 3 mappings")
        expect(all[0].event == "a", "should be sorted by event name")
        expect(all[1].event == "b", "should be sorted by event name")
        expect(all[2].event == "c", "should be sorted by event name")
    }

    func testMappingNilActionAndBubble() {
        let store = EventActionMappingStore()
        store.register(event: "test.event", actionId: nil, bubbleText: nil)
        let mapping = store.mapping(for: "test.event")
        expect(mapping?.actionId == nil, "actionId should be nil")
        expect(mapping?.bubbleText == nil, "bubbleText should be nil")
    }

    func testMappingCodableRoundtrip() {
        let mapping = EventActionMapping(event: "build.success", actionId: "celebrate", bubbleText: "成功")
        guard let data = try? JSONEncoder().encode(mapping),
              let decoded = try? JSONDecoder().decode(EventActionMapping.self, from: data) else {
            fail("mapping codable roundtrip failed")
        }
        expect(decoded.event == "build.success", "event should survive roundtrip")
        expect(decoded.actionId == "celebrate", "actionId should survive roundtrip")
        expect(decoded.bubbleText == "成功", "bubbleText should survive roundtrip")
    }

    testRegisterAndRetrieveMapping()
    testUnregisterMapping()
    testOverwriteMapping()
    testAllMappingsSorted()
    testMappingNilActionAndBubble()
    testMappingCodableRoundtrip()
}
