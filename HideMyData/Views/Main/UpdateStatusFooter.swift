import SwiftUI

struct UpdateStatusFooter: View {
    @Environment(UpdaterModel.self) private var updater

    var body: some View {
        HStack(spacing: 8) {
            Text("v\(updater.currentVersion)")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.tertiary)

            Text("·")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)

            switch updater.status {
            case .unknown:
                Button("Check for updates", action: updater.checkForUpdates)
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            case .upToDate:
                Text("Up to date")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.tertiary)
            case .updateAvailable(let version):
                Button {
                    updater.installUpdate()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 10, weight: .semibold))
                        Text("Update to v\(version)")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
}
