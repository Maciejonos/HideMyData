import SwiftUI
import AppKit

struct AmbientBackdrop: View {
    var body: some View {
        BehindWindowBlur()
            .ignoresSafeArea()
    }
}

private struct BehindWindowBlur: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .popover
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

struct WindowGlassConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { WindowConfiguringView() }
    func updateNSView(_ nsView: NSView, context: Context) {}
}

private final class WindowConfiguringView: NSView {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard let window else { return }
        window.isOpaque = false
        window.backgroundColor = .clear
    }
}
