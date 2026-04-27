import SwiftUI
import PDFKit
import AppKit

struct PDFKitView: NSViewRepresentable {
    let document: PDFDocument?
    let editingMode: EditingMode
    let redactor: PDFRedactor

    func makeNSView(context: Context) -> InteractivePDFView {
        let view = InteractivePDFView()
        view.displayMode = .singlePageContinuous
        view.autoScales = true
        view.backgroundColor = .clear
        view.redactor = redactor
        view.editingMode = editingMode
        return view
    }

    func updateNSView(_ nsView: InteractivePDFView, context: Context) {
        if nsView.document !== document {
            nsView.document = document
            nsView.goToFirstPage(nil)
        }
        if nsView.editingMode != editingMode {
            nsView.editingMode = editingMode
        }
        if nsView.redactor !== redactor {
            nsView.redactor = redactor
        }
    }
}

final class InteractivePDFView: PDFView {
    weak var redactor: PDFRedactor?

    var editingMode: EditingMode = .view {
        didSet {
            if oldValue != editingMode {
                applyCursor()
            }
        }
    }

    private var dragStart: NSPoint?
    private var dragPage: PDFPage?
    private var previewAnnotation: PDFAnnotation?
    private var cursorTrackingArea: NSTrackingArea?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(clearAnySelection),
            name: .PDFViewSelectionChanged,
            object: self
        )
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(clearAnySelection),
            name: .PDFViewSelectionChanged,
            object: self
        )
    }

    @objc private func clearAnySelection() {
        if currentSelection != nil {
            setCurrentSelection(nil, animate: false)
        }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = cursorTrackingArea {
            removeTrackingArea(existing)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.activeInKeyWindow, .inVisibleRect, .cursorUpdate, .mouseEnteredAndExited, .mouseMoved],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        cursorTrackingArea = area
    }

    override func setCursorFor(_ areaOfInterest: PDFAreaOfInterest) {
        if editingMode != .view {
            applyCursor()
            return
        }
        super.setCursorFor(areaOfInterest)
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        applyCursor()
    }

    override func mouseMoved(with event: NSEvent) {
        applyCursor()
    }

    override func cursorUpdate(with event: NSEvent) {
        if editingMode == .view {
            super.cursorUpdate(with: event)
        } else {
            applyCursor()
        }
    }

    private func applyCursor() {
        switch editingMode {
        case .view: break // let PDFView decide
        case .add: NSCursor.crosshair.set()
        case .remove: NSCursor.pointingHand.set()
        }
    }

    override func mouseDown(with event: NSEvent) {
        guard let redactor else { super.mouseDown(with: event); return }

        switch editingMode {
        case .view:
            return

        case .remove:
            let viewLocation = convert(event.locationInWindow, from: nil)
            guard let page = page(for: viewLocation, nearest: true) else { return }
            let pagePoint = convert(viewLocation, to: page)
            if let ann = page.annotation(at: pagePoint), redactor.isRedaction(ann) {
                redactor.removeRedaction(ann, on: page)
            }

        case .add:
            let viewLocation = convert(event.locationInWindow, from: nil)
            guard let page = page(for: viewLocation, nearest: true) else { return }
            let pagePoint = convert(viewLocation, to: page)
            dragStart = pagePoint
            dragPage = page
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard editingMode == .add, let start = dragStart, let page = dragPage else {
            super.mouseDragged(with: event)
            return
        }
        let viewLocation = convert(event.locationInWindow, from: nil)
        let pagePoint = convert(viewLocation, to: page)
        let rect = makeRect(start, pagePoint)

        if let prev = previewAnnotation {
            page.removeAnnotation(prev)
        }
        let preview = PDFAnnotation(bounds: rect, forType: .square, withProperties: nil)
        preview.border = nil
        preview.color = NSColor.systemRed.withAlphaComponent(0.7)
        preview.interiorColor = NSColor.systemRed.withAlphaComponent(0.25)
        page.addAnnotation(preview)
        previewAnnotation = preview
    }

    override func mouseUp(with event: NSEvent) {
        guard editingMode == .add, let start = dragStart, let page = dragPage, let redactor else {
            super.mouseUp(with: event)
            cleanupDrag()
            return
        }

        let viewLocation = convert(event.locationInWindow, from: nil)
        let pagePoint = convert(viewLocation, to: page)
        let rect = makeRect(start, pagePoint)

        if let prev = previewAnnotation {
            page.removeAnnotation(prev)
        }

        if rect.width > 4 && rect.height > 4 {
            redactor.addRedaction(rect: rect, on: page)
        }
        cleanupDrag()
    }

    private func cleanupDrag() {
        dragStart = nil
        dragPage = nil
        previewAnnotation = nil
    }

    private func makeRect(_ a: NSPoint, _ b: NSPoint) -> CGRect {
        CGRect(x: min(a.x, b.x), y: min(a.y, b.y),
               width: abs(b.x - a.x), height: abs(b.y - a.y))
    }
}
