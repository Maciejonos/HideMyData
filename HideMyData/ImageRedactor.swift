import Foundation
import AppKit
import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins
import ImageIO
internal import UniformTypeIdentifiers

@Observable
@MainActor
final class ImageRedactor {
    enum Phase: Equatable {
        case empty
        case loaded
        case detecting
        case redacted(spanCount: Int, rectCount: Int)
        case saved(URL)
        case failed(String)
    }

    var phase: Phase = .empty
    var image: CGImage?
    var sourceURL: URL?
    var sourceUTI: UTType?
    var redactionRects: [CGRect] = []  // image-pixel coords, origin top-left
    var redactionStyle: RedactionStyle = .blackRectangle
    var editingMode: EditingMode = .view

    private var sourceImageProperties: [CFString: Any]?
    private var detectionTask: Task<Void, Never>?

    var statusText: String {
        switch phase {
        case .empty: return "No image"
        case .loaded:
            if redactionRects.isEmpty { return "Loaded" }
            return "\(redactionRects.count) rectangle\(redactionRects.count == 1 ? "" : "s")"
        case .detecting: return "Detecting PII…"
        case .redacted(_, let r):
            return "\(r) redaction\(r == 1 ? "" : "s")"
        case .saved(let url): return "Saved → \(url.lastPathComponent)"
        case .failed(let m): return "Failed: \(m)"
        }
    }

    var hasRedactions: Bool { !redactionRects.isEmpty }
    var canDetect: Bool { image != nil && phase != .detecting }

    var pixelSize: CGSize {
        guard let image else { return .zero }
        return CGSize(width: image.width, height: image.height)
    }

    // MARK: - Open / Save

    @discardableResult
    func openImage() -> Bool {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return false }
        return loadImage(from: url)
    }

    @discardableResult
    func loadImage(from url: URL) -> Bool {
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil),
              let cg = normalizedCGImage(from: src) else {
            phase = .failed("Could not open image \(url.lastPathComponent)")
            return false
        }
        let utiString = CGImageSourceGetType(src) as String? ?? ""
        let properties = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any]
        ingest(cg: cg, sourceURL: url, uti: UTType(utiString) ?? .png, properties: properties)
        return true
    }

    @discardableResult
    func loadImage(data: Data, originalURL: URL) -> Bool {
        guard let src = CGImageSourceCreateWithData(data as CFData, nil),
              let cg = normalizedCGImage(from: src) else {
            phase = .failed("Could not open image \(originalURL.lastPathComponent)")
            return false
        }
        let utiString = CGImageSourceGetType(src) as String? ?? ""
        let properties = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any]
        ingest(cg: cg, sourceURL: originalURL, uti: UTType(utiString) ?? .png, properties: properties)
        return true
    }

    private func normalizedCGImage(from source: CGImageSource) -> CGImage? {
        guard let cg = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
        let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let raw = (props?[kCGImagePropertyOrientation] as? UInt32) ?? 1
        guard raw != 1, let orientation = CGImagePropertyOrientation(rawValue: raw) else {
            return cg
        }
        let ci = CIImage(cgImage: cg).oriented(orientation)
        let ctx = CIContext(options: [.useSoftwareRenderer: false])
        return ctx.createCGImage(ci, from: ci.extent)
    }

    private func ingest(cg: CGImage, sourceURL: URL, uti: UTType, properties: [CFString: Any]?) {
        cancelDetection()
        self.image = cg
        self.sourceURL = sourceURL
        self.sourceUTI = uti
        self.sourceImageProperties = properties
        self.redactionRects = []
        self.phase = .loaded
    }

    func save() {
        guard image != nil else { return }
        let outUTI = sourceUTI ?? .png
        let panel = NSSavePanel()
        let exportAccessory = ExportOptionsAccessoryView()
        panel.allowedContentTypes = [outUTI]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = suggestedSaveName(uti: outUTI)
        panel.accessoryView = exportAccessory
        guard panel.runModal() == .OK, let url = panel.url else { return }

        if writeRedacted(to: url, uti: outUTI, options: exportAccessory.options) {
            phase = .saved(url)
        } else {
            phase = .failed("Could not write redacted image")
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
        guard let cg = image else { return }
        redactionRects.removeAll()
        phase = .detecting

        guard let ocr = try? await OCREngine.recognize(cg) else {
            phase = .failed("OCR failed")
            return
        }
        if Task.isCancelled { return }
        if ocr.combinedText.isEmpty {
            phase = .redacted(spanCount: 0, rectCount: 0)
            return
        }

        let (modelInput, offsetMap) = OCRNormalizer.normalize(ocr.combinedText)
        let originalCount = ocr.combinedText.count

        let result = await detector.detect(modelInput)
        if Task.isCancelled { return }
        switch result {
        case .failure(let err):
            phase = .failed("Inference error: \(err.localizedDescription)")
        case .success(let spans):
            for span in spans {
                let (origStart, origEnd) = OCRNormalizer.translateRange(
                    start: span.start, end: span.end, map: offsetMap, originalCount: originalCount
                )
                let normRects = ocr.normalizedBoxes(start: origStart, end: origEnd)
                for norm in normRects {
                    redactionRects.append(pixelRect(fromNormalized: norm))
                }
            }
            phase = .redacted(spanCount: spans.count, rectCount: redactionRects.count)
        }
    }

    func clearRedactions() {
        cancelDetection()
        redactionRects.removeAll()
        if image != nil { phase = .loaded }
    }

    func addRedaction(rect: CGRect) {
        redactionRects.append(rect)
        switch phase {
        case .loaded, .redacted:
            phase = .redacted(spanCount: 0, rectCount: redactionRects.count)
        default:
            break
        }
    }

    func removeRedaction(at index: Int) {
        guard redactionRects.indices.contains(index) else { return }
        redactionRects.remove(at: index)
        if redactionRects.isEmpty, image != nil {
            phase = .loaded
        } else if case .redacted = phase {
            phase = .redacted(spanCount: 0, rectCount: redactionRects.count)
        }
    }

    // MARK: - Helpers

    private func pixelRect(fromNormalized norm: CGRect) -> CGRect {
        let w = CGFloat(image?.width ?? 0)
        let h = CGFloat(image?.height ?? 0)
        let x = norm.minX * w
        let y = (1 - norm.maxY) * h
        return CGRect(x: x, y: y, width: norm.width * w, height: norm.height * h)
    }

    private func writeRedacted(to url: URL, uti: UTType, options: ExportOptions) -> Bool {
        guard let cg = image else { return false }
        guard let baked = bakeRedactions(into: cg) else { return false }
        guard let dest = CGImageDestinationCreateWithURL(url as CFURL, uti.identifier as CFString, 1, nil) else {
            return false
        }
        CGImageDestinationAddImage(dest, baked, imageProperties(for: uti, options: options))
        return CGImageDestinationFinalize(dest)
    }

    private func imageProperties(for uti: UTType, options: ExportOptions) -> CFDictionary? {
        var properties = options.removeMetadata ? [:] : sourceImageProperties ?? [:]
        properties[kCGImagePropertyOrientation] = 1

        if options.removeMetadata {
            if uti.conforms(to: .png) {
                properties[kCGImagePropertyPNGDictionary] = [:] as CFDictionary
            } else if uti.conforms(to: .jpeg) {
                properties[kCGImagePropertyJFIFDictionary] = [:] as CFDictionary
            } else if uti.conforms(to: .tiff) {
                properties[kCGImagePropertyTIFFDictionary] = [:] as CFDictionary
            }
        }

        return properties as CFDictionary
    }

    private func bakeRedactions(into image: CGImage) -> CGImage? {
        let width = image.width
        let height = image.height
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: nil, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        let flippedRects = redactionRects.map { r in
            CGRect(x: r.minX, y: CGFloat(height) - r.maxY, width: r.width, height: r.height)
                .insetBy(dx: -2, dy: -2)
        }

        switch redactionStyle {
        case .blackRectangle:
            ctx.setFillColor(NSColor.black.cgColor)
            for r in flippedRects { ctx.fill(r) }

        case .blur:
            guard let snapshot = ctx.makeImage(),
                  let blurred = gaussianBlurred(snapshot) else { return nil }
            for r in flippedRects {
                ctx.saveGState()
                ctx.clip(to: r)
                ctx.draw(blurred, in: CGRect(x: 0, y: 0, width: width, height: height))
                ctx.restoreGState()
            }
        }

        return ctx.makeImage()
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

    private func suggestedSaveName(uti: UTType) -> String {
        let base = sourceURL?.deletingPathExtension().lastPathComponent ?? "image"
        let ext = uti.preferredFilenameExtension ?? "png"
        return "\(base)-redacted.\(ext)"
    }
}
