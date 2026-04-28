import SwiftUI

struct FirstRunView: View {
    @Bindable var detector: PIIDetector

    @State private var titleIn = false
    @State private var cardIn = false
    @State private var ctaIn = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 32)

            VStack(spacing: 12) {
                Text("Model download")
                    .font(.system(size: 32, weight: .bold))
                    .tracking(-0.6)

                Text("""
                HideMyData uses a small on‑device language model to find personal information in your documents. \
                The model is downloaded once from Hugging Face and runs entirely on your Mac from then on — \
                nothing is uploaded to the cloud. OCR for images uses Apple Vision, which is already on your device.
                """)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)

            }
            .frame(maxWidth: 540)
            .padding(.horizontal, 40)
            .opacity(titleIn ? 1 : 0)
            .offset(y: titleIn ? 0 : 10)

            Spacer(minLength: 36)

            ModelSourceCard()
                .frame(maxWidth: 460)
                .padding(.horizontal, 40)
                .opacity(cardIn ? 1 : 0)
                .offset(y: cardIn ? 0 : 8)

            Spacer(minLength: 28)

            FirstRunPhase(detector: detector)
                .frame(minHeight: 70)
                .opacity(ctaIn ? 1 : 0)
                .offset(y: ctaIn ? 0 : 8)

            Spacer(minLength: 36)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            withAnimation(.smooth(duration: 0.55)) { titleIn = true }
            withAnimation(.smooth(duration: 0.55).delay(0.15)) { cardIn = true }
            withAnimation(.smooth(duration: 0.55).delay(0.30)) { ctaIn = true }
        }
    }
}
