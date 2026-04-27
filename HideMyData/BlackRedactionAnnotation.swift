import Foundation
import PDFKit
import AppKit

nonisolated final class BlackRedactionAnnotation: PDFAnnotation {
    override func draw(with box: PDFDisplayBox, in context: CGContext) {
        context.setFillColor(NSColor.black.cgColor)
        context.fill(bounds)
    }
}
