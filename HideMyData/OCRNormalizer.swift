import Foundation

enum OCRNormalizer {
    static func normalize(_ text: String) -> (text: String, offsetMap: [Int]) {
        let chars = Array(text)
        var normalized = ""
        var map: [Int] = []
        var i = 0
        while i < chars.count {
            if i + 2 < chars.count, chars[i] == " ", chars[i + 1] == "/", chars[i + 2] == " " {
                normalized.append("\n")
                map.append(i + 1)
                i += 3
            } else {
                normalized.append(chars[i])
                map.append(i)
                i += 1
            }
        }
        return (normalized, map)
    }

    static func translateRange(start: Int, end: Int, map: [Int], originalCount: Int) -> (start: Int, end: Int) {
        guard !map.isEmpty else { return (start, end) }
        let s = (start >= 0 && start < map.count) ? map[start] : originalCount
        let e = (end > 0 && end <= map.count) ? (map[end - 1] + 1) : originalCount
        return (s, e)
    }
}
