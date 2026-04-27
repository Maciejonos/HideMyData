import Foundation

enum InputMode: String, CaseIterable, Identifiable {
    case pdf
    case image

    var id: Self { self }

    var displayName: String {
        switch self {
        case .pdf: return "PDF"
        case .image: return "Image"
        }
    }

    var systemImage: String {
        switch self {
        case .pdf: return "doc.richtext"
        case .image: return "photo"
        }
    }
}
