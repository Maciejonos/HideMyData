import SwiftUI
internal import UniformTypeIdentifiers

struct EmptyState: View {
    @Binding var inputMode: InputMode
    @Bindable var recents: RecentsStore
    let onOpenPDF: () -> Void
    let onOpenImage: () -> Void
    let onDropFile: (URL) -> Void
    let onOpenRecent: (RecentItem) -> Void
    @State private var isTargeted: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 60)

            dropZone
                .padding(.horizontal, 60)

            Spacer(minLength: 36)

            if !recents.items.isEmpty {
                RecentsRow(store: recents, onOpen: onOpenRecent)
                    .padding(.horizontal, 36)
                    .padding(.bottom, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Spacer().frame(height: 18)
            }

            UpdateStatusFooter()
                .padding(.bottom, 14)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .dropDestination(for: URL.self) { urls, _ in
            guard let url = urls.first else { return false }
            onDropFile(url)
            return true
        } isTargeted: { hovering in
            withAnimation(.smooth(duration: 0.20)) { isTargeted = hovering }
        }
    }

    @ViewBuilder
    private var dropZone: some View {
        VStack(spacing: 28) {
            Text("HIDE MY DATA")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .tracking(3.2)
                .foregroundStyle(.tertiary)

            VStack(spacing: 10) {
                Text(isTargeted ? "Drop to open" : "Redact, locally.")
                    .font(.system(size: 38, weight: .medium, design: .rounded))
                    .foregroundStyle(.primary)
                    .contentTransition(.opacity)

                HStack(spacing: 6) {
                    Image(systemName: "arrow.down.doc")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.tertiary)
                    Text("Drag a file here, or use the button below.")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(.secondary)
                }
                .opacity(isTargeted ? 0 : 1)
            }
            .multilineTextAlignment(.center)

            HStack(spacing: 14) {
                InputTabSegmented(inputMode: $inputMode)
                    .fixedSize()

                Button(action: openAction) {
                    Label("Open", systemImage: openIcon)
                        .padding(.horizontal, 6)
                }
                .buttonStyle(.glassProminent)
                .controlSize(.large)
                .keyboardShortcut("o", modifiers: [.command])
            }
            .padding(.top, 4)
        }
        .padding(.horizontal, 56)
        .padding(.vertical, 44)
        .frame(maxWidth: 560)
        .glassEffect(
            .regular.tint(isTargeted ? Color.accentColor.opacity(0.18) : Color.white.opacity(0.06)),
            in: .rect(cornerRadius: 28)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(
                    isTargeted ? AnyShapeStyle(Color.accentColor.opacity(0.85)) : AnyShapeStyle(.white.opacity(0.18)),
                    style: StrokeStyle(
                        lineWidth: isTargeted ? 1.6 : 1,
                        dash: isTargeted ? [] : [6, 5]
                    )
                )
        )
        .scaleEffect(isTargeted ? 1.015 : 1.0)
        .animation(.smooth(duration: 0.22), value: isTargeted)
    }

    private var openIcon: String {
        switch inputMode {
        case .pdf: "doc.badge.plus"
        case .image: "photo.badge.plus"
        }
    }

    private var openAction: () -> Void {
        switch inputMode {
        case .pdf: onOpenPDF
        case .image: onOpenImage
        }
    }
}
