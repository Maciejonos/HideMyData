import SwiftUI

struct FloatingToolbar: View {
    let detector: PIIDetector
    @Bindable var pdfRedactor: PDFRedactor
    @Bindable var imageRedactor: ImageRedactor
    let inputMode: InputMode

    var body: some View {
        GlassEffectContainer(spacing: 10) {
            HStack(spacing: 10) {
                fileGroup
                detectButton
                Spacer(minLength: 10)
                modeSegmented
                clearButton
                styleSegmented
            }
        }
        .controlSize(.large)
    }

    // MARK: - Buttons

    @ViewBuilder
    private var fileGroup: some View {
        HStack(spacing: 4) {
            Button(action: openAction) {
                HStack(spacing: 6) {
                    Image(systemName: openIcon)
                    Text("Open")
                }
                .padding(.horizontal, 4)
            }
            .keyboardShortcut("o", modifiers: [.command])
            .help("Open  ⌘O")

            Button(action: saveAction) {
                HStack(spacing: 6) {
                    Image(systemName: "square.and.arrow.down")
                    Text("Save")
                }
                .padding(.horizontal, 4)
            }
            .disabled(!hasFile)
            .keyboardShortcut("s", modifiers: [.command])
            .help("Save redacted copy  ⌘S")
        }
        .buttonStyle(.glass)
    }

    @ViewBuilder
    private var detectButton: some View {
        Button(action: detect) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .symbolEffect(.pulse, isActive: isDetecting)
                Text("Detect")
            }
            .padding(.horizontal, 4)
        }
        .buttonStyle(.glassProminent)
        .disabled(!detector.isReady || !canDetect)
        .keyboardShortcut("d", modifiers: [.command])
        .help("Auto-detect PII  ⌘D")
    }

    @ViewBuilder
    private var modeSegmented: some View {
        GlassSegmented(
            selection: editingModeBinding,
            items: EditingMode.allCases.map {
                .init(value: $0, image: $0.systemImage, label: $0.displayName, help: $0.helpText)
            }
        )
        .fixedSize()
        .disabled(!detector.isReady || !hasFile || isDetecting)
    }

    @ViewBuilder
    private var clearButton: some View {
        Button("Clear all redactions", systemImage: "xmark.circle", action: clearAction)
            .labelStyle(.iconOnly)
            .buttonStyle(.glass)
            .disabled(!hasRedactions || isDetecting)
            .help("Clear all redactions")
    }

    @ViewBuilder
    private var styleSegmented: some View {
        GlassSegmented(
            selection: styleBinding,
            items: RedactionStyle.allCases.map {
                .init(value: $0, image: $0.systemImage, label: $0.displayName, help: "\($0.displayName) redaction")
            }
        )
        .fixedSize()
        .disabled(!detector.isReady || isDetecting)
    }

    // MARK: - Mode-aware dispatch

    private var hasFile: Bool {
        switch inputMode {
        case .pdf: pdfRedactor.document != nil
        case .image: imageRedactor.image != nil
        }
    }

    private var canDetect: Bool {
        switch inputMode {
        case .pdf: pdfRedactor.canDetect
        case .image: imageRedactor.canDetect
        }
    }

    private var hasRedactions: Bool {
        switch inputMode {
        case .pdf: pdfRedactor.hasRedactions
        case .image: imageRedactor.hasRedactions
        }
    }

    private var isDetecting: Bool {
        switch inputMode {
        case .pdf: pdfRedactor.phase == .detecting
        case .image: imageRedactor.phase == .detecting
        }
    }

    private var openIcon: String {
        switch inputMode {
        case .pdf: "doc.badge.plus"
        case .image: "photo.badge.plus"
        }
    }

    private var openAction: () -> Void {
        switch inputMode {
        case .pdf: { _ = pdfRedactor.openPDF() }
        case .image: { _ = imageRedactor.openImage() }
        }
    }

    private var saveAction: () -> Void {
        switch inputMode {
        case .pdf: pdfRedactor.save
        case .image: imageRedactor.save
        }
    }

    private var clearAction: () -> Void {
        switch inputMode {
        case .pdf: pdfRedactor.clearRedactions
        case .image: imageRedactor.clearRedactions
        }
    }

    private func detect() {
        switch inputMode {
        case .pdf: pdfRedactor.detectAndRedact(using: detector)
        case .image: imageRedactor.detectAndRedact(using: detector)
        }
    }

    private var styleBinding: Binding<RedactionStyle> {
        switch inputMode {
        case .pdf: $pdfRedactor.redactionStyle
        case .image: $imageRedactor.redactionStyle
        }
    }

    private var editingModeBinding: Binding<EditingMode> {
        switch inputMode {
        case .pdf: $pdfRedactor.editingMode
        case .image: $imageRedactor.editingMode
        }
    }
}
