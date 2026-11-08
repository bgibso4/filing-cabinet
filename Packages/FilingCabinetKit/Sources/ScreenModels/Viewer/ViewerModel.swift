import Core
import Foundation
import Library
import Observation

/// One scan on screen: its header and which page is showing. Everything but the page is read from the library and
/// from `Today`, so the header moves when either does and the view pops when the scan goes away (M5).
@Observable
public final class ViewerModel {
    /// 0-based. The pager writes it. Another page starts unzoomed.
    public var currentPage = 0 {
        didSet {
            if currentPage != oldValue { isPageZoomed = false }
        }
    }

    /// Whether the current page is zoomed past 1×; the page writes it.
    package var isPageZoomed = false

    /// Set when Move to Trash fails to save; the scan stays (M18).
    package private(set) var editAlert: EditAlert?

    package let id: ScanID

    private let library: any ScanLibrary
    private let today: Today
    private let calendar: Calendar
    private let analytics: any Analytics

    public init(id: ScanID, library: any ScanLibrary, today: Today, calendar: Calendar, analytics: any Analytics) {
        self.id = id
        self.library = library
        self.today = today
        self.calendar = calendar
        self.analytics = analytics
    }

    package var title: String { scan?.title ?? "" }
    package var collection: BuiltInCollection? { scan?.collection }
    package var collectionName: String { scan.map { CollectionText.name($0.collection) } ?? "" }
    package var timeLeftText: String { scan.map { TimeLeftText.text(shelf.timeLeft($0)) } ?? "" }
    package var isSoon: Bool { scan.map(shelf.isSoon) ?? false }
    package var pageCount: Int { scan?.pageCount ?? 0 }
    package var showsStrip: Bool { pageCount > 1 }
    /// Gone or expired: the view pops.
    package var isMissing: Bool { shelf.visible.isEmpty }

    package var pageLabel: String {
        String(localized: "Page \(currentPage + 1) of \(pageCount)", bundle: #bundle)
    }

    /// What VoiceOver reads for a page's image: "Lease 2026, page 1".
    package func pageImageLabel(_ page: Int) -> String {
        String(localized: "\(title), page \(page + 1)", bundle: #bundle)
    }

    /// The pages to have ready for the next swipe, the likelier one first.
    package var neighbouringPages: [Int] {
        [currentPage + 1, currentPage - 1].filter { (0..<pageCount).contains($0) }
    }

    /// Whether a page may hold its full-size image: the current one and its neighbours, so a long scan never has more
    /// than three decoded however far it is swiped.
    package func holdsPage(_ page: Int) -> Bool {
        page == currentPage || neighbouringPages.contains(page)
    }

    // MARK: Trash

    /// The Trash button's confirmation (06-04): "This receipt moves to Trash. You can restore it for 30 days."
    package var trashMessage: String {
        let noun = scan.map { CollectionText.noun($0.collection, count: 1) } ?? CollectionText.scansNoun(count: 1)
        return String(
            localized: "This \(noun) moves to Trash. You can restore it for \(Lifecycle.trashDays) days.",
            bundle: #bundle)
    }

    /// The confirmation's Move to Trash. True once the scan is in Trash (the view pops); false with `editAlert` when
    /// the move fails to save.
    @discardableResult
    package func moveToTrash() -> Bool {
        guard let scan else { return false }
        do {
            try library.moveToTrash([id])
        } catch {
            editAlert = EditAlert()
            return false
        }
        analytics.send(.scanMovedToTrash(collection: scan.collection))
        return true
    }

    /// The edit alert's OK.
    package func dismissEditAlert() {
        editAlert = nil
    }

    private var scan: ScanSummary? { library.scans.first { $0.id == id } }

    private var shelf: LibraryShelf {
        LibraryShelf(
            scans: scan.map { [$0] } ?? [], lifespans: library.lifespans, today: today.day, calendar: calendar)
    }
}
