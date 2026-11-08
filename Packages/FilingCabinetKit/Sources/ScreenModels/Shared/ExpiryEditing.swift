import Core
import Foundation
import Observation

/// A model whose expiry the shared expiry menu edits: Review's new scan and Details' saved one.
package protocol ExpiryEditing: AnyObject, Observable {
    /// What the Expiry row shows.
    var expiryValue: String { get }
    var expiryOptions: [ExpiryOption] { get }
    /// The calendar and locale "Choose a date…" shows its days in (M6).
    var calendar: Calendar { get }
    var locale: Locale { get }
    /// The first day "Choose a date…" offers.
    var earliestCustomDate: Date { get }
    /// Nil is the collection default.
    func chooseExpiry(_ override: ExpiryOverride?)
    func chooseExpiryDate(_ date: Date)
}
