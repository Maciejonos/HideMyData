import Foundation
import AppKit
import PDFKit
import ImageIO
import CoreGraphics
internal import UniformTypeIdentifiers

struct RecentItem: Identifiable, Codable, Equatable {
    let id: UUID
    let kind: Kind
    let title: String
    let bookmarkData: Data
    let thumbnailFilename: String
    let addedAt: Date

    enum Kind: String, Codable {
        case pdf, image
    }
}

@Observable
@MainActor
final class RecentsStore {
    private(set) var items: [RecentItem] = []

    static let maxItems = 8
    private static let storageKey = "HMD.recents.v1"

    init() { load() }

    // MARK: - Public API

    @discardableResult
    func add(url: URL, kind: RecentItem.Kind) -> Bool {
        guard let bookmark = try? url.bookmarkData(options: [.withSecurityScope]) else { return false }
        let thumbName = "\(UUID().uuidString).png"
        let thumbPath = Self.thumbsDir().appendingPathComponent(thumbName)
        guard generateThumbnail(for: url, kind: kind, savingTo: thumbPath) else { return false }

        // Dedupe by resolved path: remove any existing entry pointing at the same file.
        items.removeAll { existing in
            guard let existingURL = resolveURL(from: existing.bookmarkData) else { return false }
            if existingURL.path == url.path {
                deleteThumbnail(filename: existing.thumbnailFilename)
                return true
            }
            return false
        }

        let item = RecentItem(
            id: UUID(),
            kind: kind,
            title: url.lastPathComponent,
            bookmarkData: bookmark,
            thumbnailFilename: thumbName,
            addedAt: Date()
        )
        items.insert(item, at: 0)

        if items.count > Self.maxItems {
            for stale in items.suffix(items.count - Self.maxItems) {
                deleteThumbnail(filename: stale.thumbnailFilename)
            }
            items = Array(items.prefix(Self.maxItems))
        }
        persist()
        return true
    }

    func remove(_ item: RecentItem) {
        items.removeAll { $0.id == item.id }
        deleteThumbnail(filename: item.thumbnailFilename)
        persist()
    }

    /// Resolve to (url, didStartScope, dataLoadedFromScope).
    /// Caller must call `stopAccessingSecurityScopedResource()` if `didStartScope` is true.
    func resolve(_ item: RecentItem) -> (url: URL, didStartScope: Bool)? {
        guard let url = resolveURL(from: item.bookmarkData) else { return nil }
        let didStart = url.startAccessingSecurityScopedResource()
        return (url, didStart)
    }

    func thumbnailURL(for item: RecentItem) -> URL {
        Self.thumbsDir().appendingPathComponent(item.thumbnailFilename)
    }

    // MARK: - Persistence

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey),
              let decoded = try? JSONDecoder().decode([RecentItem].self, from: data) else { return }
        let fm = FileManager.default
        items = decoded.filter { fm.fileExists(atPath: thumbnailURL(for: $0).path) }
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }

    private func resolveURL(from bookmark: Data) -> URL? {
        var stale = false
        return try? URL(
            resolvingBookmarkData: bookmark,
            options: [.withSecurityScope],
            bookmarkDataIsStale: &stale
        )
    }

    // MARK: - Thumbnails

    private static func thumbsDir() -> URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = support.appendingPathComponent("HideMyData/RecentsThumbs", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func deleteThumbnail(filename: String) {
        let path = Self.thumbsDir().appendingPathComponent(filename)
        try? FileManager.default.removeItem(at: path)
    }

    private func generateThumbnail(for url: URL, kind: RecentItem.Kind, savingTo path: URL) -> Bool {
        switch kind {
        case .pdf: return generatePDFThumbnail(url: url, to: path)
        case .image: return generateImageThumbnail(url: url, to: path)
        }
    }

    private func generatePDFThumbnail(url: URL, to path: URL) -> Bool {
        guard let doc = PDFDocument(url: url),
              let page = doc.page(at: 0) else { return false }
        let bounds = page.bounds(for: .mediaBox)
        let maxDim: CGFloat = 320
        let scale = maxDim / max(bounds.width, bounds.height)
        let pw = Int(bounds.width * scale)
        let ph = Int(bounds.height * scale)
        guard pw > 0, ph > 0 else { return false }
        let cs = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: nil, width: pw, height: ph,
            bitsPerComponent: 8, bytesPerRow: 0, space: cs,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return false }
        ctx.setFillColor(NSColor.white.cgColor)
        ctx.fill(CGRect(x: 0, y: 0, width: pw, height: ph))
        ctx.scaleBy(x: scale, y: scale)
        page.draw(with: .mediaBox, to: ctx)
        guard let image = ctx.makeImage() else { return false }
        return savePNG(image, to: path)
    }

    private func generateImageThumbnail(url: URL, to path: URL) -> Bool {
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil) else { return false }
        let opts: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 320
        ]
        guard let thumb = CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary) else { return false }
        return savePNG(thumb, to: path)
    }

    private func savePNG(_ image: CGImage, to path: URL) -> Bool {
        guard let dest = CGImageDestinationCreateWithURL(
            path as CFURL, UTType.png.identifier as CFString, 1, nil
        ) else { return false }
        CGImageDestinationAddImage(dest, image, nil)
        return CGImageDestinationFinalize(dest)
    }
}
