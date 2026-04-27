import SwiftUI

struct ModelSourceCard: View {
    var body: some View {
        Link(destination: PIIDetector.modelURL) {
            VStack(spacing: 4) {
                HStack(spacing: 6) {
                    Text(PIIDetector.modelRepoID)
                        .font(.callout.monospaced())
                        .foregroundStyle(.primary)
                    Image(systemName: "arrow.up.right.square")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text("huggingface.co · ≈ 1.5 GB · cached locally")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(.quinary, in: .rect(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(.separator.opacity(0.5), lineWidth: 0.5)
            }
        }
        .buttonStyle(.plain)
        .help("Open \(PIIDetector.modelURL.absoluteString) in your browser")
        .accessibilityLabel("Model: \(PIIDetector.modelRepoID), from Hugging Face, about 1.5 gigabytes, cached locally. Opens in browser.")
    }
}
