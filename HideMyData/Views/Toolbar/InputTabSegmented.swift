import SwiftUI

struct InputTabSegmented: View {
    @Binding var inputMode: InputMode

    var body: some View {
        GlassSegmented(
            selection: $inputMode,
            items: InputMode.allCases.map {
                .init(value: $0, image: $0.systemImage, label: $0.displayName, help: "\($0.displayName) input")
            }
        )
    }
}
