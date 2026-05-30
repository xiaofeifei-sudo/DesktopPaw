import Foundation

public struct AIChatBubbleAdapter: Sendable {
    public static let maxCharacterCount = 12

    public static func adapt(_ bubbleText: String?) -> String? {
        guard let text = bubbleText?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty else {
            return nil
        }
        if cjkCount(text) <= maxCharacterCount {
            return text
        }
        return truncate(text)
    }

    public static func truncate(_ text: String, maxLength: Int = maxCharacterCount) -> String {
        var cjkCount = 0
        var cutIndex = text.endIndex
        for (i, scalar) in text.unicodeScalars.enumerated() {
            if isCJK(scalar) {
                cjkCount += 1
            }
            if cjkCount > maxLength {
                cutIndex = text.index(text.startIndex, offsetBy: i)
                break
            }
        }
        if cutIndex >= text.endIndex {
            return String(text)
        }
        return String(text[..<cutIndex]) + "…"
    }

    public static func cjkCount(_ text: String) -> Int {
        text.unicodeScalars.filter { isCJK($0) }.count
    }

    private static func isCJK(_ scalar: Unicode.Scalar) -> Bool {
        let v = scalar.value
        return (0x4E00...0x9FFF).contains(v) || (0x3400...0x4DBF).contains(v)
    }
}
