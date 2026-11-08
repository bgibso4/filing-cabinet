import Foundation

/// The note under the collection row after a move, with Undo (07-05, M17).
package enum MovedNote: Equatable {
    /// The scan's expiry now follows its new collection, named here.
    case follows(String)
    /// The scan has its own expiry, which the move kept.
    case keepsOwn

    /// "Expiry now follows Documents.", "Keeps its own expiry."
    package var text: String {
        switch self {
        case .follows(let collectionName):
            String(localized: "Expiry now follows \(collectionName).", bundle: #bundle)
        case .keepsOwn:
            String(localized: "Keeps its own expiry.", bundle: #bundle)
        }
    }
}
