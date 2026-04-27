import SwiftUI
import ImageIO
import CoreGraphics

struct RecentsRow: View {
    @Bindable var store: RecentsStore
    let onOpen: (RecentItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("RECENT")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .tracking(2.4)
                .foregroundStyle(.tertiary)
                .padding(.leading, 4)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 16) {
                    ForEach(store.items) { item in
                        RecentTile(
                            item: item,
                            store: store,
                            onOpen: { onOpen(item) },
                            onDelete: {
                                withAnimation(.smooth(duration: 0.22)) {
                                    store.remove(item)
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 6)
            }
        }
    }
}

private struct RecentTile: View {
    let item: RecentItem
    let store: RecentsStore
    let onOpen: () -> Void
    let onDelete: () -> Void

    @State private var thumbnail: CGImage?
    @State private var isHovering = false

    private let tileWidth: CGFloat = 132
    private let tileHeight: CGFloat = 92

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            tileBody
            Text(item.title)
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(width: tileWidth, alignment: .leading)
                .padding(.horizontal, 2)
        }
        .onAppear(perform: loadThumbnail)
        .onHover { hovering in
            withAnimation(.smooth(duration: 0.16)) { isHovering = hovering }
        }
    }

    @ViewBuilder
    private var tileBody: some View {
        Button(action: onOpen) {
            ZStack(alignment: .topTrailing) {
                thumbnailLayer
                    .frame(width: tileWidth, height: tileHeight)
                    .clipShape(.rect(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
                    )

                if isHovering {
                    Button(action: onDelete) {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 18, height: 18)
                            .background(Circle().fill(Color.black.opacity(0.62)))
                            .overlay(Circle().strokeBorder(.white.opacity(0.18), lineWidth: 0.5))
                    }
                    .buttonStyle(.plain)
                    .padding(7)
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
                }
            }
            .shadow(color: Color.black.opacity(isHovering ? 0.32 : 0.18),
                    radius: isHovering ? 14 : 6,
                    y: isHovering ? 6 : 3)
            .scaleEffect(isHovering ? 1.025 : 1.0)
        }
        .buttonStyle(.plain)
        .help(item.title)
    }

    @ViewBuilder
    private var thumbnailLayer: some View {
        if let img = thumbnail {
            Image(decorative: img, scale: 1, orientation: .up)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fill)
        } else {
            ZStack {
                Rectangle().fill(.thinMaterial)
                Image(systemName: item.kind == .pdf ? "doc.text" : "photo")
                    .font(.system(size: 22, weight: .light))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func loadThumbnail() {
        guard thumbnail == nil else { return }
        let url = store.thumbnailURL(for: item)
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil),
              let img = CGImageSourceCreateImageAtIndex(src, 0, nil) else { return }
        thumbnail = img
    }
}
