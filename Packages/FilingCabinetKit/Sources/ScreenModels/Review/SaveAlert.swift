import Foundation
import Library

/// The alert a failed save shows. The pages stay in review, so Try again can save them.
package struct SaveAlert: Equatable {
    package let title: String
    package let message: String

    init(title: String, message: String) {
        self.title = title
        self.message = message
    }

    /// The out-of-space copy from the design, or the generic one (M4) for any other failure.
    init(_ error: LibraryError) {
        let message =
            switch error {
            case .diskFull:
                String(
                    localized: "Your iPhone is out of space. Free some up, then try again. Your pages are still here.",
                    bundle: #bundle)
            case .writeFailed:
                String(localized: "Something went wrong. Your pages are still here.", bundle: #bundle)
            }
        self.init(title: String(localized: "Couldn’t save this scan", bundle: #bundle), message: message)
    }
}
