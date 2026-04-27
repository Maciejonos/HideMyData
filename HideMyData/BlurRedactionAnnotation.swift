import Foundation
import PDFKit
import AppKit

nonisolated final class BlurRedactionAnnotation: PDFAnnotation {
    var blurredPageImage: CGImage?
    var pageMediaBoxRect: CGRect = .zero

    override func draw(with box: PDFDisplayBox, in context: CGContext) {
        if let img = blurredPageImage, !pageMediaBoxRect.isEmpty {
            context.saveGState()
            context.clip(to: bounds)
            context.draw(img, in: pageMediaBoxRect)
            context.restoreGState()
        } else {
            context.saveGState()
            context.setFillColor(NSColor(white: 0.55, alpha: 0.9).cgColor)
            context.fill(bounds)
            context.restoreGState()
        }
    }
}
