import Core
import Foundation

/// The expiry menu Review and Details share (07-06, M15) for one scan: the collection default first, then every
/// lifespan, shortest first and Forever last. A choice whose last day is behind today is passed: greyed,
/// "Oct 7 · passed".
struct ExpiryChoices {
    let scanDay: CalendarDay
    let today: CalendarDay
    let lifespans: CollectionLifespans
    let clock: AppClock

    func options(collection: BuiltInCollection, override: ExpiryOverride?) -> [ExpiryOption] {
        let defaultChoice = (
            label: String(localized: "\(CollectionText.name(collection)) default", bundle: #bundle),
            override: ExpiryOverride?.none
        )
        let lifespanChoices = Lifespan.allCases.map { lifespan in
            (
                label: lifespan == .forever
                    ? String(localized: "Forever", bundle: #bundle) : CollectionText.lifespanShort(lifespan),
                override: ExpiryOverride?.some(.lifespan(lifespan))
            )
        }
        return ([defaultChoice] + lifespanChoices).map { choice in
            let lastDay = Expiry.lastDay(
                scanDay: scanDay,
                collectionLifespan: lifespans[collection],
                override: choice.override,
                in: clock.calendar)
            let passed = isPassed(lastDay)
            return ExpiryOption(
                label: choice.label,
                detail: detail(lastDay: lastDay, passed: passed),
                override: choice.override,
                isSelected: choice.override == override,
                isPassed: passed)
        }
    }

    /// Whether a scan in the library with this last day would already be in Trash today.
    private func isPassed(_ lastDay: CalendarDay?) -> Bool {
        guard case .library = Lifecycle.place(lastDay: lastDay, trashedDay: nil, today: today, in: clock.calendar)
        else { return true }
        return false
    }

    private func detail(lastDay: CalendarDay?, passed: Bool) -> String {
        guard let lastDay else { return String(localized: "Never expires", bundle: #bundle) }
        let date = ExpiryText.untilDate(lastDay, today: today, clock: clock)
        return passed ? String(localized: "\(date) · passed", bundle: #bundle) : date
    }
}
