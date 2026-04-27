import SwiftUI

struct FirstRunView: View {
    @Bindable var detector: PIIDetector

    var body: some View {
        VStack {
            Spacer()
            VStack(spacing: 24) {
                BrandHero()

                VStack(spacing: 6) {
                    Text("HideMyData")
                        .font(.largeTitle)
                        .bold()
                        .tracking(-0.5)
                    Text("On‑device PII redaction. Your documents never leave this Mac.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                FirstRunPhase(detector: detector)
                    .frame(minHeight: 70)
            }
            .padding(.horizontal, 56)
            .padding(.vertical, 44)
            .glassEffect(.regular, in: .rect(cornerRadius: 28))
            .frame(maxWidth: 460)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct BrandHero: View {
    @ScaledMetric(relativeTo: .largeTitle) private var size: CGFloat = 104

    var body: some View {
        Image(.appLogo)
            .resizable()
            .interpolation(.high)
            .frame(width: size, height: size)
            .clipShape(.rect(cornerRadius: size * 0.22))
            .shadow(color: .black.opacity(0.25), radius: 18, y: 8)
            .accessibilityLabel("HideMyData")
    }
}
