import CoreGraphics
import Foundation
import Vision

struct OCRLine {
    let text: String
    let candidate: RecognizedText
}

struct OCRPage {
    let lines: [OCRLine]
    let combinedText: String
    private let lineStartOffsets: [Int]  // char offset in combinedText where each line starts

    init(lines: [OCRLine]) {
        self.lines = lines
        var combined = ""
        var starts: [Int] = []
        for (i, line) in lines.enumerated() {
            starts.append(combined.count)
            combined += line.text
            if i < lines.count - 1 { combined += "\n" }
        }
        self.combinedText = combined
        self.lineStartOffsets = starts
    }

    func normalizedBoxes(start: Int, end: Int) -> [CGRect] {
        guard start >= 0, end <= combinedText.count, start < end else { return [] }
        var rects: [CGRect] = []
        for (i, line) in lines.enumerated() {
            let lineStart = lineStartOffsets[i]
            let lineEnd = lineStart + line.text.count
            let lo = max(start, lineStart)
            let hi = min(end, lineEnd)
            guard lo < hi else { continue }

            let localStartOffset = lo - lineStart
            let localEndOffset = hi - lineStart
            let s = line.text.index(line.text.startIndex, offsetBy: localStartOffset)
            let e = line.text.index(line.text.startIndex, offsetBy: localEndOffset)
            if let region = line.candidate.boundingBox(for: s..<e) {
                rects.append(region.boundingBox.cgRect)
            }
        }
        return rects
    }
}

enum OCREngine {
    static func recognize(_ image: CGImage) async throws -> OCRPage {
        var request = RecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.automaticallyDetectsLanguage = true

        let observations = try await request.perform(on: image)
        let lines: [OCRLine] = observations.compactMap { obs in
            guard let candidate = obs.topCandidates(1).first else { return nil }
            return OCRLine(text: candidate.string, candidate: candidate)
        }
        return OCRPage(lines: lines)
    }
}
