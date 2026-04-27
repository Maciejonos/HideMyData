import SwiftUI
import AppKit

struct ImageDocumentSurface: View {
    @Bindable var redactor: ImageRedactor
    @State private var dragStart: CGPoint?
    @State private var dragCurrent: CGPoint?

    var body: some View {
        if let image = redactor.image {
            GeometryReader { geo in
                let pixelSize = redactor.pixelSize
                let scale = min(geo.size.width / pixelSize.width,
                                geo.size.height / pixelSize.height,
                                1.0)
                let displaySize = CGSize(width: pixelSize.width * scale,
                                         height: pixelSize.height * scale)

                ZStack(alignment: .topLeading) {
                    Image(decorative: image, scale: 1, orientation: .up)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: displaySize.width, height: displaySize.height)

                    redactionsLayer(image: image, scale: scale, displaySize: displaySize)

                    if redactor.editingMode == .add, let s = dragStart, let c = dragCurrent {
                        DragPreview(start: s, end: c)
                    }
                }
                .frame(width: displaySize.width, height: displaySize.height)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 5, coordinateSpace: .local)
                        .onChanged { value in
                            guard redactor.editingMode == .add else { return }
                            dragStart = value.startLocation
                            dragCurrent = value.location
                        }
                        .onEnded { value in
                            defer { dragStart = nil; dragCurrent = nil }
                            guard redactor.editingMode == .add else { return }
                            let r = displayRect(from: value.startLocation, to: value.location)
                            let inImage = CGRect(
                                x: r.minX / scale,
                                y: r.minY / scale,
                                width: r.width / scale,
                                height: r.height / scale
                            ).intersection(CGRect(origin: .zero, size: pixelSize))
                            if inImage.width > 4 && inImage.height > 4 {
                                redactor.addRedaction(rect: inImage)
                            }
                        }
                )
                .onTapGesture(coordinateSpace: .local) { loc in
                    guard redactor.editingMode == .remove else { return }
                    let p = CGPoint(x: loc.x / scale, y: loc.y / scale)
                    if let idx = redactor.redactionRects.firstIndex(where: { $0.contains(p) }) {
                        redactor.removeRedaction(at: idx)
                    }
                }
                .onContinuousHover(coordinateSpace: .local) { phase in
                    switch phase {
                    case .active:
                        switch redactor.editingMode {
                        case .view: NSCursor.arrow.set()
                        case .add: NSCursor.crosshair.set()
                        case .remove: NSCursor.disappearingItem.set()
                        }
                    case .ended:
                        NSCursor.arrow.set()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipShape(.rect(cornerRadius: 16))
                .shadow(color: .black.opacity(0.10), radius: 22, y: 6)
            }
            .padding(.horizontal, 18)
            .padding(.top, 84)
            .padding(.bottom, 18)
        }
    }

    @ViewBuilder
    private func redactionsLayer(image: CGImage, scale: CGFloat, displaySize: CGSize) -> some View {
        switch redactor.redactionStyle {
        case .blackRectangle:
            ForEach(Array(redactor.redactionRects.enumerated()), id: \.offset) { _, rect in
                let scaled = scaledRect(rect, scale: scale)
                Rectangle()
                    .fill(Color.black)
                    .frame(width: scaled.width, height: scaled.height)
                    .offset(x: scaled.minX, y: scaled.minY)
            }
        case .blur:
            Image(decorative: image, scale: 1, orientation: .up)
                .resizable()
                .interpolation(.high)
                .frame(width: displaySize.width, height: displaySize.height)
                .blur(radius: 14)
                .mask(alignment: .topLeading) {
                    ZStack(alignment: .topLeading) {
                        ForEach(Array(redactor.redactionRects.enumerated()), id: \.offset) { _, rect in
                            let scaled = scaledRect(rect, scale: scale)
                            Rectangle()
                                .frame(width: scaled.width, height: scaled.height)
                                .offset(x: scaled.minX, y: scaled.minY)
                        }
                    }
                    .frame(width: displaySize.width, height: displaySize.height, alignment: .topLeading)
                }
        }
    }

    private func scaledRect(_ rect: CGRect, scale: CGFloat) -> CGRect {
        CGRect(
            x: rect.minX * scale,
            y: rect.minY * scale,
            width: rect.width * scale,
            height: rect.height * scale
        )
    }

    private func displayRect(from start: CGPoint, to end: CGPoint) -> CGRect {
        CGRect(
            x: min(start.x, end.x),
            y: min(start.y, end.y),
            width: abs(end.x - start.x),
            height: abs(end.y - start.y)
        )
    }
}

private struct DragPreview: View {
    let start: CGPoint
    let end: CGPoint

    var body: some View {
        let r = CGRect(
            x: min(start.x, end.x),
            y: min(start.y, end.y),
            width: abs(end.x - start.x),
            height: abs(end.y - start.y)
        )
        Rectangle()
            .strokeBorder(.red, lineWidth: 1.5)
            .background(Color.red.opacity(0.18))
            .frame(width: r.width, height: r.height)
            .offset(x: r.minX, y: r.minY)
    }
}
