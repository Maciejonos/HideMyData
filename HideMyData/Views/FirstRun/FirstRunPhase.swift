import SwiftUI

struct FirstRunPhase: View {
    @Bindable var detector: PIIDetector
    @State private var downloadStartedAt: Date = .now

    var body: some View {
        switch detector.phase {
        case .needsDownload:
            DownloadCTA(start: startDownload)
        case .downloading(let downloaded, let total):
            DownloadProgress(downloaded: downloaded, total: total, startedAt: downloadStartedAt)
        case .failed(let msg):
            DownloadFailure(message: msg, retry: startDownload)
        default:
            EmptyView()
        }
    }

    private func startDownload() {
        downloadStartedAt = .now
        Task { await detector.startDownload() }
    }
}

private struct DownloadCTA: View {
    let start: () -> Void

    var body: some View {
        Button(action: start) {
            Label("Download model", systemImage: "arrow.down.circle.fill")
                .frame(minWidth: 220)
                .padding(.vertical, 4)
        }
        .controlSize(.large)
        .buttonStyle(.glassProminent)
        .keyboardShortcut(.defaultAction)
    }
}

private struct DownloadProgress: View {
    let downloaded: Int64
    let total: Int64
    let startedAt: Date

    var body: some View {
        VStack(spacing: 10) {
            if total > 0 {
                ProgressView(value: Double(downloaded), total: Double(total))
                    .progressViewStyle(.linear)
                    .frame(width: 320)
                TimelineView(.periodic(from: startedAt, by: 1)) { context in
                    Text(progressLabel(now: context.date))
                        .font(.footnote.monospaced())
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                }
            } else {
                ProgressView().controlSize(.small)
                Text("Preparing download…")
                    .font(.footnote.monospaced())
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func progressLabel(now: Date) -> String {
        let downloadedGB = (Double(downloaded) / 1_000_000_000)
            .formatted(.number.precision(.fractionLength(1)))
        let totalGB = (Double(total) / 1_000_000_000)
            .formatted(.number.precision(.fractionLength(1)))
        let elapsed = Duration.seconds(now.timeIntervalSince(startedAt))
            .formatted(.time(pattern: .minuteSecond))
        return "\(downloadedGB) / \(totalGB) GB  ·  \(elapsed)"
    }
}

private struct DownloadFailure: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            Text(message)
                .font(.callout)
                .foregroundStyle(.red)
                .multilineTextAlignment(.center)
            Button("Retry", systemImage: "arrow.clockwise", action: retry)
                .buttonStyle(.glass)
                .controlSize(.large)
        }
    }
}
