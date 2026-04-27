import SwiftUI

struct DocumentSurface: View {
    @Bindable var redactor: PDFRedactor

    var body: some View {
        if let document = redactor.document {
            PDFKitView(
                document: document,
                editingMode: redactor.editingMode,
                redactor: redactor
            )
            .clipShape(.rect(cornerRadius: 16))
            .shadow(color: .black.opacity(0.10), radius: 22, y: 6)
            .padding(.horizontal, 18)
            .padding(.top, 84)
            .padding(.bottom, 18)
        }
    }
}
