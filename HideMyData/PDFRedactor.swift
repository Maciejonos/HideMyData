import Foundation
import PDFKit
import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins
internal import UniformTypeIdentifiers

enum RedactionStyle: String, CaseIterable, Identifiable {
    case blackRectangle
    case blur

    var id: Self { self }

    var displayName: String {
        switch self {
        case .blackRectangle: return "Black"
        case .blur: return "Blur"
        }
    }
}

enum EditingMode: String, CaseIterable, Identifiable {
    case view
    case add
    case remove

    var id: Self { self }

    var displayName: String {
        switch self {
        case .view: return "View"
        case .add: return "Add"
        case .remove: return "Remove"
        }
    }

    var systemImage: String {
        switch self {
        case .view: return "eye"
        case .add: return "plus.square"
        case .remove: return "minus.square"
        }
    }
}

@Observable
@MainActor
final class PDFRedactor {
    enum Phase: Equatable {
        case empty
        case loaded
        case detecting
        case redacted(spanCount: Int, rectCount: Int)
        case saved(URL)
        case failed(String)
    }

    var phase: Phase = .empty
    var document: PDFDocument?
    var sourceURL: URL?
    var editingMode: EditingMode = .view
    var redactionStyle: RedactionStyle = .blackRectangle {
        didSet { if oldValue != redactionStyle { restyleAllAnnotations() } }
    }

    private var redactionAnnotations: [(page: PDFPage, annotation: PDFAnnotation)] = []
    private let blurCache: NSCache<PDFPage, CGImage> = {
        let cache = NSCache<PDFPage, CGImage>()
        cache.countLimit = 8
        return cache
    }()
    private var detectionTask: Task<Void, Never>?

    var statusText: String {
        switch phase {
        case .empty: return "No document"
        case .loaded:
            if redactionAnnotations.isEmpty { return "Loaded" }
            return "\(redactionAnnotations.count) rectangle\(redactionAnnotations.count == 1 ? "" : "s")"
        case .detecting: return "Detecting PII…"
        case .redacted(_, let r):
            return "\(r) redaction\(r == 1 ? "" : "s")"
        case .saved(let url): return "Saved → \(url.lastPathComponent)"
        case .failed(let m): return "Failed: \(m)"
        }
    }

    var hasRedactions: Bool { !redactionAnnotations.isEmpty }
    var canDetect: Bool { document != nil && phase != .detecting }
    var redactionCount: Int { redactionAnnotations.count }

    // MARK: - Open / Save

    @discardableResult
    func openPDF() -> Bool {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.pdf]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return false }
        return loadPDF(from: url)
    }

    @discardableResult
    func loadPDF(from url: URL) -> Bool {
        guard let doc = PDFDocument(url: url) else {
            phase = .failed("Could not open PDF at \(url.lastPathComponent)")
            return false
        }
        cancelDetection()
        clearRedactions(silently: true)
        blurCache.removeAllObjects()
        self.document = doc
        self.sourceURL = url
        self.phase = .loaded
        return true
    }

    /// Load a PDF whose bytes are already in memory. Used by the recents flow so the
    /// security-scoped resource can be released as soon as the file is read, while
    /// `sourceURL` still points at the original location for save-name suggestions.
    @discardableResult
    func loadPDF(data: Data, originalURL: URL) -> Bool {
        guard let doc = PDFDocument(data: data) else {
            phase = .failed("Could not open PDF at \(originalURL.lastPathComponent)")
            return false
        }
        cancelDetection()
        clearRedactions(silently: true)
        blurCache.removeAllObjects()
        self.document = doc
        self.sourceURL = originalURL
        self.phase = .loaded
        return true
    }

    func save() {
        guard document != nil else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = suggestedSaveName()
        guard panel.runModal() == .OK, let url = panel.url else { return }

        if let outURL = saveSecurely(to: url) {
            phase = .saved(outURL)
        } else {
            phase = .failed("Could not write redacted PDF")
        }
    }

    // MARK: - Detection

    func detectAndRedact(using detector: PIIDetector) {
        cancelDetection()
        detectionTask = Task { [weak self] in
            await self?.runDetection(using: detector)
        }
    }

    func cancelDetection() {
        detectionTask?.cancel()
        detectionTask = nil
    }

    private func runDetection(using detector: PIIDetector) async {
        guard let doc = document else { return }
        clearRedactions(silently: true)
        phase = .detecting

        var totalSpans = 0
        var totalRects = 0

        for pageIndex in 0..<doc.pageCount {
            if Task.isCancelled { return }
            guard let page = doc.page(at: pageIndex) else { continue }

            let pageText = page.string ?? ""
            let source: PageTextSource
            let modelInput: String
            let offsetMap: [Int]
            if pageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                guard let ocrPage = await ocrText(for: page) else { continue }
                if ocrPage.combinedText.isEmpty { continue }
                source = .ocr(ocrPage)
                let n = OCRNormalizer.normalize(ocrPage.combinedText)
                modelInput = n.text
                offsetMap = n.offsetMap
            } else {
                source = .nativeText(pageText)
                modelInput = pageText
                offsetMap = []
            }

            let result = await detector.detect(modelInput)
            if Task.isCancelled { return }
            switch result {
            case .failure(let err):
                phase = .failed("Inference error on page \(pageIndex + 1): \(err.localizedDescription)")
                return
            case .success(let spans):
                totalSpans += spans.count
                for span in spans {
                    let (s, e) = OCRNormalizer.translateRange(
                        start: span.start, end: span.end, map: offsetMap, originalCount: source.text.count
                    )
                    let translated = DetectedSpan(
                        category: span.category, text: span.text,
                        start: s, end: e, confidence: span.confidence
                    )
                    let rects = boundingRects(for: translated, source: source, on: page)
                    for rect in rects {
                        addRedaction(rect: rect, on: page, source: .auto)
                        totalRects += 1
                    }
                }
            }
        }

        phase = .redacted(spanCount: totalSpans, rectCount: totalRects)
    }

    private enum PageTextSource {
        case nativeText(String)
        case ocr(OCRPage)

        var text: String {
            switch self {
            case .nativeText(let s): return s
            case .ocr(let p): return p.combinedText
            }
        }
    }

    private func ocrText(for page: PDFPage) async -> OCRPage? {
        guard let cg = renderPageToCGImage(page, scale: 2) else { return nil }
        return try? await OCREngine.recognize(cg)
    }

    private func renderPageToCGImage(_ page: PDFPage, scale: CGFloat) -> CGImage? {
        let pageBounds = page.bounds(for: .mediaBox)
        let pixelWidth = Int(pageBounds.width * scale)
        let pixelHeight = Int(pageBounds.height * scale)
        guard pixelWidth > 0, pixelHeight > 0 else { return nil }

        let detached = redactionAnnotations.filter { $0.page === page }.map { $0.annotation }
        for ann in detached { page.removeAnnotation(ann) }
        defer { for ann in detached { page.addAnnotation(ann) } }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: nil, width: pixelWidth, height: pixelHeight,
            bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        ctx.setFillColor(NSColor.white.cgColor)
        ctx.fill(CGRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight))
        ctx.scaleBy(x: scale, y: scale)
        page.draw(with: .mediaBox, to: ctx)
        return ctx.makeImage()
    }

    // MARK: - Annotations

    enum RedactionSource { case auto, manual }

    @discardableResult
    func addRedaction(rect: CGRect, on page: PDFPage, source: RedactionSource = .manual) -> PDFAnnotation {
        let padded = rect.insetBy(dx: -1, dy: -1)
        let ann: PDFAnnotation
        switch redactionStyle {
        case .blackRectangle:
            let blackAnn = BlackRedactionAnnotation(bounds: padded, forType: .square, withProperties: nil)
            blackAnn.border = nil
            ann = blackAnn
        case .blur:
            let blurAnn = BlurRedactionAnnotation(bounds: padded, forType: .square, withProperties: nil)
            blurAnn.border = nil
            blurAnn.blurredPageImage = blurredImage(for: page)
            blurAnn.pageMediaBoxRect = page.bounds(for: .mediaBox)
            ann = blurAnn
        }
        page.addAnnotation(ann)
        redactionAnnotations.append((page, ann))

        let count = redactionAnnotations.count
        switch phase {
        case .loaded, .saved:
            if source == .manual { phase = .redacted(spanCount: 0, rectCount: count) }
        case .redacted:
            phase = .redacted(spanCount: 0, rectCount: count)
        default:
            break
        }
        return ann
    }

    func removeRedaction(_ ann: PDFAnnotation, on page: PDFPage) {
        page.removeAnnotation(ann)
        redactionAnnotations.removeAll { $0.annotation === ann }
        if redactionAnnotations.isEmpty, document != nil {
            phase = .loaded
        } else if case .redacted = phase {
            phase = .redacted(spanCount: 0, rectCount: redactionAnnotations.count)
        }
    }

    func isRedaction(_ ann: PDFAnnotation) -> Bool {
        redactionAnnotations.contains { $0.annotation === ann }
    }

    func clearRedactions() {
        cancelDetection()
        clearRedactions(silently: false)
    }

    private func clearRedactions(silently: Bool) {
        for (page, ann) in redactionAnnotations {
            page.removeAnnotation(ann)
        }
        redactionAnnotations.removeAll()
        if !silently, document != nil { phase = .loaded }
    }

    private func restyleAllAnnotations() {
        let priorPhase = phase
        let snapshot = redactionAnnotations
        redactionAnnotations.removeAll()
        for (page, ann) in snapshot {
            let bounds = ann.bounds.insetBy(dx: 1, dy: 1)
            page.removeAnnotation(ann)
            addRedaction(rect: bounds, on: page, source: .auto)
        }
        phase = priorPhase
    }

    // MARK: - Bounding rects via character offsets (with text-search fallback)

    private func boundingRects(for span: DetectedSpan, source: PageTextSource, on page: PDFPage) -> [CGRect] {
        switch source {
        case .nativeText(let pageText):
            if span.start >= 0,
               span.end > span.start,
               let utf16Range = nsRange(start: span.start, end: span.end, in: pageText),
               let selection = page.selection(for: utf16Range) {
                let rects = perLineRects(of: selection, on: page)
                if !rects.isEmpty { return rects }
            }
            return rectsByTextSearch(needle: span.text, on: page)

        case .ocr(let ocrPage):
            let normRects = ocrPage.normalizedBoxes(start: span.start, end: span.end)
            let pageBounds = page.bounds(for: .mediaBox)
            return normRects.map { norm in
                CGRect(
                    x: norm.minX * pageBounds.width,
                    y: norm.minY * pageBounds.height,
                    width: norm.width * pageBounds.width,
                    height: norm.height * pageBounds.height
                )
            }
        }
    }

    private func nsRange(start: Int, end: Int, in text: String) -> NSRange? {
        guard start <= text.count, end <= text.count, start <= end else { return nil }
        let s = text.index(text.startIndex, offsetBy: start)
        let e = text.index(text.startIndex, offsetBy: end)
        let utf16Start = text.utf16.distance(from: text.utf16.startIndex, to: s.samePosition(in: text.utf16) ?? text.utf16.startIndex)
        let utf16End = text.utf16.distance(from: text.utf16.startIndex, to: e.samePosition(in: text.utf16) ?? text.utf16.startIndex)
        return NSRange(location: utf16Start, length: utf16End - utf16Start)
    }

    private func perLineRects(of selection: PDFSelection, on page: PDFPage) -> [CGRect] {
        var rects: [CGRect] = []
        for line in selection.selectionsByLine() {
            for selPage in line.pages where selPage === page {
                let bounds = line.bounds(for: selPage)
                if bounds.width > 0.5 && bounds.height > 0.5 {
                    rects.append(bounds)
                }
            }
        }
        return rects
    }

    private func rectsByTextSearch(needle: String, on page: PDFPage) -> [CGRect] {
        guard let doc = page.document, !needle.isEmpty else { return [] }
        let selections = doc.findString(needle, withOptions: [.caseInsensitive])
        var rects: [CGRect] = []
        for selection in selections {
            rects.append(contentsOf: perLineRects(of: selection, on: page))
        }
        return rects
    }

    // MARK: - Blurred page snapshot (for editor preview)

    private func blurredImage(for page: PDFPage) -> CGImage? {
        if let cached = blurCache.object(forKey: page) { return cached }

        let pageBounds = page.bounds(for: .mediaBox)
        let scale: CGFloat = 2.0
        let pixelWidth = Int(pageBounds.width * scale)
        let pixelHeight = Int(pageBounds.height * scale)
        guard pixelWidth > 0, pixelHeight > 0 else { return nil }

        let detached = redactionAnnotations.filter { $0.page === page }.map { $0.annotation }
        for ann in detached { page.removeAnnotation(ann) }
        defer { for ann in detached { page.addAnnotation(ann) } }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: nil,
            width: pixelWidth,
            height: pixelHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        ctx.setFillColor(NSColor.white.cgColor)
        ctx.fill(CGRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight))
        ctx.scaleBy(x: scale, y: scale)
        page.draw(with: .mediaBox, to: ctx)

        guard let sharpCG = ctx.makeImage() else { return nil }
        guard let blurred = gaussianBlurred(sharpCG) else { return nil }

        blurCache.setObject(blurred, forKey: page)
        return blurred
    }

    private func gaussianBlurred(_ sharp: CGImage) -> CGImage? {
        let sharpCI = CIImage(cgImage: sharp)
        let blur = CIFilter.gaussianBlur()
        blur.inputImage = sharpCI
        blur.radius = Float(min(sharp.width, sharp.height)) * 0.02
        guard let blurredCI = blur.outputImage?.cropped(to: sharpCI.extent) else { return nil }
        let ciContext = CIContext(options: [.useSoftwareRenderer: false])
        return ciContext.createCGImage(blurredCI, from: blurredCI.extent)
    }

    // MARK: - True (rasterized) save

    private func saveSecurely(to url: URL) -> URL? {
        guard let doc = document else { return nil }
        let newDoc = PDFDocument()

        for pageIndex in 0..<doc.pageCount {
            guard let page = doc.page(at: pageIndex) else { continue }
            let rectsForPage = redactionAnnotations
                .filter { $0.page === page }
                .map { $0.annotation.bounds }

            if rectsForPage.isEmpty {
                if let copy = page.copy() as? PDFPage {
                    newDoc.insert(copy, at: newDoc.pageCount)
                }
            } else {
                guard let baked = bakedPage(page, rects: rectsForPage, style: redactionStyle) else {
                    return nil
                }
                newDoc.insert(baked, at: newDoc.pageCount)
            }
        }

        return newDoc.write(to: url) ? url : nil
    }

    private func bakedPage(_ page: PDFPage, rects: [CGRect], style: RedactionStyle) -> PDFPage? {
        let pageBounds = page.bounds(for: .mediaBox)
        let scale: CGFloat = 2.0
        let pixelWidth = Int(pageBounds.width * scale)
        let pixelHeight = Int(pageBounds.height * scale)
        guard pixelWidth > 0, pixelHeight > 0 else { return nil }

        let detached = redactionAnnotations.filter { $0.page === page }.map { $0.annotation }
        for ann in detached { page.removeAnnotation(ann) }
        defer { for ann in detached { page.addAnnotation(ann) } }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: nil,
            width: pixelWidth,
            height: pixelHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        ctx.setFillColor(NSColor.white.cgColor)
        ctx.fill(CGRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight))
        ctx.saveGState()
        ctx.scaleBy(x: scale, y: scale)
        page.draw(with: .mediaBox, to: ctx)
        ctx.restoreGState()

        let pixelRects: [CGRect] = rects.map { r in
            CGRect(x: r.minX * scale, y: r.minY * scale,
                   width: r.width * scale, height: r.height * scale)
                .insetBy(dx: -2, dy: -2)
        }

        switch style {
        case .blackRectangle:
            ctx.setFillColor(NSColor.black.cgColor)
            for r in pixelRects { ctx.fill(r) }

        case .blur:
            guard let sharpCG = ctx.makeImage() else { return nil }
            guard let blurredCG = gaussianBlurred(sharpCG) else { return nil }

            for r in pixelRects {
                ctx.saveGState()
                ctx.clip(to: r)
                ctx.draw(blurredCG, in: CGRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight))
                ctx.restoreGState()
            }
        }

        guard let finalCG = ctx.makeImage() else { return nil }
        let image = NSImage(cgImage: finalCG, size: pageBounds.size)
        return PDFPage(image: image)
    }

    private func suggestedSaveName() -> String {
        let base = sourceURL?.deletingPathExtension().lastPathComponent ?? "document"
        return "\(base)-redacted.pdf"
    }
}
