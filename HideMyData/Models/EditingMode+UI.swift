import Foundation

extension EditingMode {
    var helpText: String {
        switch self {
        case .view: "View — scroll the document"
        case .add: "Add — drag to mark a region"
        case .remove: "Remove — click a box to unmark"
        }
    }
}
