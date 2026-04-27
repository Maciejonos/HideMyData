import Foundation
@preconcurrency import OpenMedKit

struct DetectedSpan: Identifiable, Equatable {
    let id = UUID()
    let category: String
    let text: String
    let start: Int
    let end: Int
    let confidence: Float
}

@Observable
@MainActor
final class PIIDetector {
    enum Phase: Equatable {
        case needsDownload
        case downloading(downloaded: Int64, total: Int64)
        case loadingModel
        case warmingUp
        case ready
        case running
        case failed(String)
    }

    var phase: Phase

    private var openmed: OpenMed?

    static let modelRepoID = "OpenMed/privacy-filter-mlx-8bit"
    static let modelURL = URL(string: "https://huggingface.co/\(modelRepoID)")!

    private static func defaultCacheRoot() -> URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return support
            .appendingPathComponent("HideMyData", isDirectory: true)
            .appendingPathComponent("ModelCache", isDirectory: true)
    }

    private var cacheRoot: URL { Self.defaultCacheRoot() }

    init() {
        let state: OpenMedMLXModelCacheState =
            (try? OpenMedModelStore.mlxModelCacheState(
                repoID: Self.modelRepoID,
                cacheDirectory: Self.defaultCacheRoot()
            )) ?? .missing
        self.phase = (state == .ready) ? .loadingModel : .needsDownload
    }

    var statusText: String {
        switch phase {
        case .needsDownload: "Model not downloaded"
        case .downloading(let downloaded, let total): Self.downloadStatus(downloaded: downloaded, total: total)
        case .loadingModel: "Loading model…"
        case .warmingUp: "Warming up…"
        case .ready: "Ready"
        case .running: "Running…"
        case .failed(let message): "Failed: \(message)"
        }
    }

    private static func downloadStatus(downloaded: Int64, total: Int64) -> String {
        let downloadedStr = downloaded.formatted(.byteCount(style: .file))
        guard total > 0 else { return "Downloading… \(downloadedStr) so far" }
        let totalStr = total.formatted(.byteCount(style: .file))
        let pct = (Double(downloaded) / Double(total))
            .formatted(.percent.precision(.fractionLength(0)))
        return "Downloading… \(downloadedStr) / \(totalStr) (\(pct))"
    }

    var isReady: Bool {
        switch phase {
        case .ready, .running: true
        default: false
        }
    }

    var isBusy: Bool {
        switch phase {
        case .loadingModel, .warmingUp, .running, .downloading: return true
        default: return false
        }
    }

    // MARK: - Lifecycle

    func loadIfCached() async {
        ensureCacheDirectoryExists()
        if case .loadingModel = phase {
            await loadCachedModel()
        }
    }

    func startDownload() async {
        ensureCacheDirectoryExists()
        phase = .downloading(downloaded: 0, total: 0)

        let downloader = ModelDownloader(repoID: Self.modelRepoID, cacheRoot: cacheRoot)
        downloader.onProgress = { [weak self] downloaded, total in
            guard let self else { return }
            self.phase = .downloading(downloaded: downloaded, total: total)
        }

        do {
            _ = try await downloader.download()
            await loadCachedModel()
        } catch {
            phase = .failed("Download failed: \(error.localizedDescription)")
        }
    }

    private func loadCachedModel() async {
        phase = .loadingModel
        do {
            let modelURL = try await OpenMedModelStore.downloadMLXModel(repoID: Self.modelRepoID, cacheDirectory: cacheRoot)
            openmed = try OpenMed(backend: .mlx(modelDirectoryURL: modelURL))
            await warmUp()
        } catch {
            phase = .failed("Load failed: \(error.localizedDescription)")
        }
    }

    private func warmUp() async {
        phase = .warmingUp
        let model = openmed
        _ = await runOnBackground { try? model?.extractPII("Warm up.", confidenceThreshold: 0.5, useSmartMerging: false) }
        phase = .ready
    }

    // MARK: - Inference

    func detect(_ text: String) async -> Result<[DetectedSpan], Error> {
        guard let model = openmed else {
            return .failure(HMDError.message("Detector not loaded"))
        }
        let prevPhase = phase
        phase = .running
        defer { phase = prevPhase }

        return await runOnBackground {
            do {
                let entities = try model.extractPII(text, confidenceThreshold: 0.4, useSmartMerging: false)
                let modelSpans = entities.map {
                    DetectedSpan(category: $0.label, text: $0.text, start: $0.start, end: $0.end, confidence: $0.confidence)
                }
                let patternSpans = PatternMatcher.detect(text)
                return .success(modelSpans + patternSpans)
            } catch {
                return .failure(error)
            }
        }
    }

    // MARK: - Helpers

    private func runOnBackground<T: Sendable>(_ work: @Sendable @escaping () -> T) async -> T {
        await Task.detached(priority: .userInitiated) { work() }.value
    }

    private func ensureCacheDirectoryExists() {
        try? FileManager.default.createDirectory(at: cacheRoot, withIntermediateDirectories: true)
    }
}

enum HMDError: LocalizedError {
    case message(String)
    var errorDescription: String? {
        if case .message(let s) = self { return s }
        return nil
    }
}
