import SwiftUI
internal import UniformTypeIdentifiers

struct MainView: View {
    let detector: PIIDetector
    @Bindable var pdfRedactor: PDFRedactor
    @Bindable var imageRedactor: ImageRedactor
    @Bindable var recents: RecentsStore
    @Binding var inputMode: InputMode
    @State private var showHome: Bool = false

    private var activeIsEmpty: Bool {
        switch inputMode {
        case .pdf: return pdfRedactor.document == nil
        case .image: return imageRedactor.image == nil
        }
    }

    private var shouldShowEmpty: Bool { showHome || activeIsEmpty }

    var body: some View {
        ZStack(alignment: .top) {
            if shouldShowEmpty {
                EmptyState(
                    inputMode: $inputMode,
                    recents: recents,
                    onOpenPDF: openPDFAndAdd,
                    onOpenImage: openImageAndAdd,
                    onDropFile: handleDrop,
                    onOpenRecent: openRecent
                )
            } else {
                Color.black.opacity(0.28)
                    .ignoresSafeArea()

                Group {
                    switch inputMode {
                    case .pdf:
                        DocumentSurface(redactor: pdfRedactor)
                    case .image:
                        ImageDocumentSurface(redactor: imageRedactor)
                    }
                }

                FloatingToolbar(
                    detector: detector,
                    pdfRedactor: pdfRedactor,
                    imageRedactor: imageRedactor,
                    inputMode: inputMode
                )
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity)
            }

            StatusPill(
                detector: detector,
                pdfRedactor: pdfRedactor,
                imageRedactor: imageRedactor,
                inputMode: inputMode,
                showingDocument: !shouldShowEmpty
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .padding(.horizontal, 22)
            .padding(.top, shouldShowEmpty ? 22 : 78)
            .allowsHitTesting(false)

            if !shouldShowEmpty {
                HomeButton { showHome = true }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(22)
            }
        }
    }

    // MARK: - Open actions

    private func openPDFAndAdd() {
        guard pdfRedactor.openPDF(), let url = pdfRedactor.sourceURL else { return }
        recents.add(url: url, kind: .pdf)
        showHome = false
    }

    private func openImageAndAdd() {
        guard imageRedactor.openImage(), let url = imageRedactor.sourceURL else { return }
        recents.add(url: url, kind: .image)
        showHome = false
    }

    private func handleDrop(_ url: URL) {
        let type = (try? url.resourceValues(forKeys: [.contentTypeKey]).contentType) ?? .data
        if type.conforms(to: .pdf) {
            inputMode = .pdf
            if pdfRedactor.loadPDF(from: url) {
                recents.add(url: url, kind: .pdf)
                showHome = false
            }
        } else if type.conforms(to: .image) {
            inputMode = .image
            if imageRedactor.loadImage(from: url) {
                recents.add(url: url, kind: .image)
                showHome = false
            }
        }
    }

    private func openRecent(_ item: RecentItem) {
        guard let resolved = recents.resolve(item) else {
            recents.remove(item)
            return
        }
        defer { if resolved.didStartScope { resolved.url.stopAccessingSecurityScopedResource() } }

        guard let data = try? Data(contentsOf: resolved.url) else {
            recents.remove(item)
            return
        }

        switch item.kind {
        case .pdf:
            inputMode = .pdf
            if pdfRedactor.loadPDF(data: data, originalURL: resolved.url) {
                recents.add(url: resolved.url, kind: .pdf)
                showHome = false
            }
        case .image:
            inputMode = .image
            if imageRedactor.loadImage(data: data, originalURL: resolved.url) {
                recents.add(url: resolved.url, kind: .image)
                showHome = false
            }
        }
    }
}
