import Foundation

extension RedactionStyle {
    var systemImage: String {
        switch self {
        case .blackRectangle: "square.fill"
        case .blur: "camera.filters"
        }
    }
}
