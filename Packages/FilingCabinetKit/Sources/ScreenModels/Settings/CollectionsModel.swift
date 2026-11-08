import Core
import Foundation
import Library
import Observation

/// The Collections screen (10-02): each collection with how long it keeps scans and how many it holds.
@Observable
package final class CollectionsModel {
    @ObservationIgnored private let library: any ScanLibrary
    @ObservationIgnored private let today: Today
    @ObservationIgnored private let calendar: Calendar

    package init(library: any ScanLibrary, today: Today, calendar: Calendar) {
        self.library = library
        self.today = today
        self.calendar = calendar
    }

    package var subtitle: String { String(localized: "How long each one keeps scans", bundle: #bundle) }

    package var footer: String { String(localized: "Counted from each scan’s date.", bundle: #bundle) }

    package var rows: [CollectionsRow] {
        let shelf = LibraryShelf(
            scans: library.scans, lifespans: library.lifespans, today: today.day, calendar: calendar)
        return BuiltInCollection.allCases.map { collection in
            CollectionsRow(
                collection: collection,
                name: CollectionText.name(collection),
                detail: String(
                    localized:
                        "\(CollectionText.kept(shelf.lifespans[collection])) · \(CollectionText.scanCount(shelf.count(in: collection)))",
                    bundle: #bundle))
        }
    }
}
