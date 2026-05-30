import Foundation
import DesktopPet

func makeContentPackRoot(_ name: String = "content-pack-\(UUID().uuidString)") -> URL {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(name, isDirectory: true)
    try? FileManager.default.removeItem(at: root)
    try! FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    return root
}

func makeContentPackDirectory(
    root: URL = makeContentPackRoot(),
    id: String,
    type: ContentPackType,
    previewPhrases: [String] = ["预览短句"],
    manifestExtras: String = "",
    contentFileName: String,
    contentJSON: String
) -> URL {
    let packURL = root.appendingPathComponent("\(id).dpcp", isDirectory: true)
    let contentURL = packURL.appendingPathComponent("content", isDirectory: true)
    try! FileManager.default.createDirectory(at: contentURL, withIntermediateDirectories: true)

    let preview = previewPhrases.map { "\"\($0)\"" }.joined(separator: ", ")
    let extras = manifestExtras.isEmpty ? "" : ",\n\(manifestExtras)"
    let manifest = """
    {
      "id": "\(id)",
      "name": "测试内容包",
      "author": "Tester",
      "version": "1.0.0",
      "type": "\(type.rawValue)",
      "description": "用于单元测试的内容包",
      "previewPhrases": [\(preview)],
      "safetyTags": ["safe"],
      "compatiblePetVersion": ">=1.0.0"\(extras)
    }
    """
    try! manifest.data(using: .utf8)!.write(to: packURL.appendingPathComponent("manifest.json"))
    try! contentJSON.data(using: .utf8)!.write(to: contentURL.appendingPathComponent(contentFileName))
    return packURL
}

func makeDialoguePackDirectory(root: URL = makeContentPackRoot(), id: String = "com.test.dialogue") -> URL {
    makeContentPackDirectory(
        root: root,
        id: id,
        type: .dialogue,
        contentFileName: "phrases.json",
        contentJSON: """
        [
          { "id": "hello", "trigger": "idle", "text": "新台词", "priority": "ambient", "weight": 2.0, "safetyTags": ["safe"] }
        ]
        """
    )
}

func makePersonalityPackDirectory(root: URL = makeContentPackRoot(), id: String = "com.test.personality") -> URL {
    makeContentPackDirectory(
        root: root,
        id: id,
        type: .personality,
        previewPhrases: ["轻轻陪你"],
        contentFileName: "personality.json",
        contentJSON: """
        {
          "guidelines": "温和、安静、短句表达。",
          "previewPhrases": ["轻轻陪你", "不打扰你"]
        }
        """
    )
}

func makeActionPackDirectory(root: URL = makeContentPackRoot(), id: String = "com.test.action") -> URL {
    makeContentPackDirectory(
        root: root,
        id: id,
        type: .action,
        contentFileName: "actions.json",
        contentJSON: """
        [
          {
            "id": "wave_extra",
            "displayName": "挥手",
            "role": null,
            "tags": ["greeting"],
            "frames": [{ "column": 0, "row": 0 }],
            "frameDurationMs": 120,
            "loop": false,
            "nextActionId": null
          }
        ]
        """
    )
}
