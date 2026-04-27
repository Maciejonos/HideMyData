import SwiftUI

struct IntroView: View {
    let onContinue: () -> Void

    @State private var heroIn = false
    @State private var ctaIn = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 32)

            VStack(spacing: 16) {
                AppLogo()

                VStack(spacing: 10) {
                    Text("Welcome to HideMyData")
                        .font(.system(size: 32, weight: .bold))
                        .tracking(-0.6)

                    Text("Redact sensitive information from PDFs and images,\nentirely on your Mac.")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .opacity(heroIn ? 1 : 0)
            .offset(y: heroIn ? 0 : 10)

            Spacer(minLength: 44)

            VStack(alignment: .leading, spacing: 26) {
                FeatureRow(
                    icon: "lock.shield.fill",
                    tint: .green,
                    title: "Private by Design",
                    subtitle: "Detection and redaction run entirely on your Mac. No accounts, no servers, no telemetry — your documents never leave the device.",
                    delay: 0.10
                )
                FeatureRow(
                    icon: "sparkles",
                    tint: .indigo,
                    title: "Intelligent Detection",
                    subtitle: "An on‑device language model finds names, emails, phone numbers, addresses, dates and IDs across PDFs and scanned images.",
                    delay: 0.20
                )
                FeatureRow(
                    icon: "rectangle.dashed",
                    tint: .pink,
                    title: "Permanent Redaction",
                    subtitle: "Saved files have the original text removed from the page — not just covered with a black box that can be peeled off.",
                    delay: 0.30
                )
            }
            .frame(maxWidth: 560, alignment: .leading)
            .padding(.horizontal, 40)

            Spacer(minLength: 44)

            Button(action: onContinue) {
                Text("Continue")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(minWidth: 220)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
            .opacity(ctaIn ? 1 : 0)
            .offset(y: ctaIn ? 0 : 8)

            Spacer(minLength: 36)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            withAnimation(.smooth(duration: 0.55)) { heroIn = true }
            withAnimation(.smooth(duration: 0.55).delay(0.45)) { ctaIn = true }
        }
    }
}

private struct AppLogo: View {
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

private struct FeatureRow: View {
    let icon: String
    let tint: Color
    let title: String
    let subtitle: String
    let delay: Double

    @State private var appeared = false

    var body: some View {
        HStack(alignment: .top, spacing: 18) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(tint)
                .frame(width: 32, height: 32, alignment: .center)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .lineSpacing(1.5)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .opacity(appeared ? 1 : 0)
        .offset(x: appeared ? 0 : -6)
        .onAppear {
            withAnimation(.smooth(duration: 0.5).delay(delay)) { appeared = true }
        }
    }
}

#Preview {
    IntroView(onContinue: {})
        .frame(width: 760, height: 600)
        .background(AmbientBackdrop())
}
