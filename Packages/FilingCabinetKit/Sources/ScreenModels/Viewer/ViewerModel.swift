import Core
import Foundation
import Library
import Observation

/// One scan on screen: its header and which page is showing. Everything but the page is read from the library and
/// from `Today`, so the header moves when either does and the view pops when the scan goes away (M5). A scan opened
/// from Trash (09-04) reads its days left in Trash and offers Restore and Delete now, which Trash's own model runs.
@Observable
public final class ViewerModel {
    /// Where the scan was opened from.
    public enum Mode {
        case library
        case trash
    }

    /// 0-based. The pager writes it. Another page starts unzoomed.
    public var currentPage = 0 {
        didSet {
            if currentPage != oldValue { isPageZoomed = false }
        }
    }

    /// Whether the current page is zoomed past 1×; the page writes it.
    package var isPageZoomed = false

    /// Set when Move to Trash fails to save; the scan stays (M18).
    private var moveAlert: EditAlert?

    package let id: ScanID
    package let mode: Mode

    private let library: any ScanLibrary
    private let today: Today
    private let calendar: Calendar
    private let analytics: any Analytics
    /// Runs Restore and Delete now in Trash mode, with Trash's confirmation and announcements; nil in the library.
    private let trash: TrashModel?

    public init(
        id: ScanID,
        library: any ScanLibrary,
        today: Today,
        calendar: Calendar,
        analytics: any Analytics,
        mode: Mode = .library
    ) {
        self.id = id
        self.library = library
        self.today = today
        self.calendar = calendar
        self.analytics = analytics
        self.mode = mode
        trash =
            mode == .trash ? TrashModel(library: library, today: today, calendar: calendar, analytics: analytics) : nil
    }

    package var title: String { scan?.title ?? "" }
    package var collection: BuiltInCollection? { scan?.collection }
    package var collectionName: String { scan.map { CollectionText.name($0.collection) } ?? "" }
    /// "5 days left": of its life in the library, or of its days in Trash.
    package var timeLeftText: String {
        guard let scan else { return "" }
        switch mode {
        case .library: return TimeLeftText.text(shelf.timeLeft(scan))
        case .trash: return TimeLeftText.text(.days(shelf.trashDaysLeft(scan)))
        }
    }
    /// Orange: the library's rule, or Trash's last 7 days.
    package var isSoon: Bool {
        guard let scan else { return false }
        switch mode {
        case .library: return shelf.isSoon(scan)
        case .trash: return !isMissing && Lifecycle.isTrashSoon(daysLeft: shelf.trashDaysLeft(scan))
        }
    }
    package var pageCount: Int { scan?.pageCount ?? 0 }
    package var showsStrip: Bool { pageCount > 1 }
    /// No longer where it was opened from (gone, expired, restored or moved to Trash): the view pops.
    package var isMissing: Bool {
        switch mode {
        case .library: shelf.visible.isEmpty
        case .trash: shelf.trash.isEmpty
        }
    }

    /// Set when an edit fails to save; the scan stays where it is (M18).
    package var editAlert: EditAlert? { moveAlert ?? trash?.editAlert }

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
            moveAlert = EditAlert()
            return false
        }
        analytics.send(.scanMovedToTrash(collection: scan.collection))
        return true
    }

    /// The edit alert's OK.
    package func dismissEditAlert() {
        moveAlert = nil
        trash?.dismissEditAlert()
    }

    // MARK: Opened from Trash

    /// Delete now's confirmation, naming the scan (09-06); nil until Delete now.
    package var confirmation: TrashConfirmation? { trash?.confirmation }

    /// Back to its collection, kept forever, without asking (M10). Returns the announcement (M19), or nil when the
    /// write failed (the alert shows).
    @discardableResult
    package func restore() -> String? {
        trash?.restore([id])
    }

    /// Asks before deleting the scan for good.
    package func deleteNow() {
        trash?.confirmDelete([id])
    }

    package func cancelConfirmation() {
        trash?.cancelConfirmation()
    }

    /// The confirmation's Delete. Returns the announcement, or nil when the write failed.
    @discardableResult
    package func performConfirmation(_ asked: TrashConfirmation) async -> String? {
        await trash?.performConfirmation(asked)
    }

    private var scan: ScanSummary? { library.scans.first { $0.id == id } }

    private var shelf: LibraryShelf {
        LibraryShelf(
            scans: scan.map { [$0] } ?? [], lifespans: library.lifespans, today: today.day, calendar: calendar)
    }
}
