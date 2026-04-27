import Foundation

nonisolated enum PatternMatcher {
    private struct Pattern {
        let id: String
        let regex: NSRegularExpression
        let category: String
    }

    private struct Spec: Decodable {
        let id: String
        let description: String
        let category: String
        let regex: String
    }

    private struct Manifest: Decodable {
        let patterns: [Spec]
    }

    private static let patterns: [Pattern] = loadPatterns()

    private static func loadPatterns() -> [Pattern] {
        guard let url = Bundle.main.url(forResource: "patterns", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let manifest = try? JSONDecoder().decode(Manifest.self, from: data)
        else {
            return []
        }
        return manifest.patterns.compactMap { spec in
            guard let re = try? NSRegularExpression(pattern: spec.regex) else {
                print("PatternMatcher: failed to compile pattern '\(spec.id)'")
                return nil
            }
            return Pattern(id: spec.id, regex: re, category: spec.category)
        }
    }

    static func detect(_ text: String) -> [DetectedSpan] {
        var spans: [DetectedSpan] = []
        let nsText = text as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)

        for pattern in patterns {
            pattern.regex.enumerateMatches(in: text, options: [], range: fullRange) { match, _, _ in
                guard let match, let swiftRange = Range(match.range, in: text) else { return }
                let matched = String(text[swiftRange])
                let charStart = text.distance(from: text.startIndex, to: swiftRange.lowerBound)
                let charEnd = text.distance(from: text.startIndex, to: swiftRange.upperBound)
                spans.append(DetectedSpan(
                    category: pattern.category,
                    text: matched,
                    start: charStart,
                    end: charEnd,
                    confidence: 0.99
                ))
            }
        }
        return spans
    }
}
