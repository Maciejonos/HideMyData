import SwiftUI

struct HomeButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "house.fill")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.primary)
                .frame(width: 50, height: 50)
                .glassEffect(.regular, in: .circle)
        }
        .buttonStyle(.plain)
        .help("Back to file selection  ⌘H")
        .keyboardShortcut("h", modifiers: [.command])
    }
}
