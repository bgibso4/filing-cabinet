import Foundation

/// The one alert an edit that fails to save shows (M18). The edit changed nothing, so OK is all it offers.
package struct EditAlert: Equatable {
    package let title: String
    package let message: String

    init() {
        title = String(localized: "Couldn’t save this change", bundle: #bundle)
        message = String(localized: "Something went wrong. Try again.", bundle: #bundle)
    }
}
