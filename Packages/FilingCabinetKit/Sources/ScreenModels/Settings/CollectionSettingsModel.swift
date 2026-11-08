import Core
import Foundation
import Library
import Observation

/// One collection's screen (10-03): its count and "Keep scans for". Shortening the lifespan asks first when it
/// would send scans to Trash now (10-04).
@Observable
public final class CollectionSettingsModel {
    /// Set by a shortening that expires scans; nothing changes until `confirm()`.
    package private(set) var confirmation: LifespanConfirmation?
    /// Set when a write fails; the change did nothing (M18).
    package private(set) var editAlert: EditAlert?

    @ObservationIgnored package let collection: BuiltInCollection
    @ObservationIgnored private let library: any ScanLibrary
    @ObservationIgnored private let today: Today
    @ObservationIgnored private let calendar: Calendar
    @ObservationIgnored private let analytics: any Analytics

    public init(
        collection: BuiltInCollection,
        library: any ScanLibrary,
        today: Today,
        calendar: Calendar,
        analytics: any Analytics
    ) {
        self.collection = collection
        self.library = library
        self.today = today
        self.calendar = calendar
        self.analytics = analytics
    }

    package var title: String { CollectionText.name(collection) }

    package var countLine: String {
        let shelf = LibraryShelf(
            scans: library.scans, lifespans: library.lifespans, today: today.day, calendar: calendar)
        return CollectionText.scanCount(shelf.count(in: collection))
    }

    package var lifespanValue: String { CollectionText.lifespanChoice(library.lifespans[collection]) }

    package var choices: [LifespanChoice] {
        let current = library.lifespans[collection]
        return Lifespan.allCases.map {
            LifespanChoice(lifespan: $0, title: CollectionText.lifespanChoice($0), isCurrent: $0 == current)
        }
    }

    package var note: String {
        String(
            localized:
                "Applies to \(CollectionText.noun(collection, count: 2)) you already have. Scans you gave their own expiry keep it.",
            bundle: #bundle)
    }

    /// Picks a lifespan. Scans it would send to Trash are asked about first; otherwise it applies at once.
    package func choose(_ lifespan: Lifespan) {
        guard lifespan != library.lifespans[collection] else { return }
        let expiring = library.scansExpiring(ifLifespan: lifespan, for: collection)
        if expiring > 0, let ask = LifespanConfirmation(collection: collection, lifespan: lifespan, expiring: expiring)
        {
            confirmation = ask
        } else {
            apply(lifespan)
        }
    }

    package func confirm() {
        guard let confirmation else { return }
        self.confirmation = nil
        apply(confirmation.lifespan)
    }

    package func cancel() { confirmation = nil }

    package func dismissEditAlert() { editAlert = nil }

    private func apply(_ lifespan: Lifespan) {
        do {
            try library.setLifespan(lifespan, for: collection)
        } catch {
            editAlert = EditAlert()
            return
        }
        analytics.send(.lifespanChanged(collection: collection, lifespan: lifespan))
    }
}
