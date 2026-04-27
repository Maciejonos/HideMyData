import SwiftUI

struct ContentView: View {
    @State private var detector = PIIDetector()
    @State private var pdfRedactor = PDFRedactor()
    @State private var imageRedactor = ImageRedactor()
    @State private var recents = RecentsStore()
    @State private var inputMode: InputMode = .pdf

    @AppStorage("hasSeenIntro") private var hasSeenIntro: Bool = false

    var body: some View {
        Group {
            if !hasSeenIntro {
                IntroView(onContinue: { hasSeenIntro = true })
            } else {
                switch detector.phase {
                case .needsDownload, .downloading, .failed:
                    FirstRunView(detector: detector)
                default:
                    MainView(
                        detector: detector,
                        pdfRedactor: pdfRedactor,
                        imageRedactor: imageRedactor,
                        recents: recents,
                        inputMode: $inputMode
                    )
                }
            }
        }
        .frame(minWidth: 760, minHeight: 600)
        .background(AmbientBackdrop())
        .background(WindowGlassConfigurator())
        .task { await detector.loadIfCached() }
    }
}

#Preview {
    ContentView()
}
