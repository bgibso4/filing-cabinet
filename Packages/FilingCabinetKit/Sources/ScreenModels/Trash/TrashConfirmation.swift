import Core
import Foundation

/// What a Delete or Empty Trash asks before it removes anything for good (09-08 … 09-10).
package struct TrashConfirmation: Equatable {
    package enum Action: Equatable {
        case delete([ScanID])
        case empty
    }

    package let title: String
    package let message: String
    /// The destructive button.
    package let confirmTitle: String
    let action: Action

    /// One scan is named; several are not.
    init(deleting ids: [ScanID], firstTitle: String) {
        let count = ids.count
        title =
            count == 1
            ? String(localized: "Delete permanently?", bundle: #bundle)
            : String(localized: "Delete \(count) scans permanently?", bundle: #bundle)
        message =
            count == 1
            ? String(localized: "\(firstTitle) will be deleted. This can’t be undone.", bundle: #bundle)
            : String(localized: "They’ll be deleted. This can’t be undone.", bundle: #bundle)
        confirmTitle = String(localized: "Delete", bundle: #bundle)
        action = .delete(ids)
    }

    init(emptying count: Int) {
        title = String(localized: "Empty Trash?", bundle: #bundle)
        let scans = CollectionText.scanCount(count)
        message = String(localized: "Deletes \(scans) permanently. This can’t be undone.", bundle: #bundle)
        confirmTitle = String(localized: "Empty Trash", bundle: #bundle)
        action = .empty
    }
}
