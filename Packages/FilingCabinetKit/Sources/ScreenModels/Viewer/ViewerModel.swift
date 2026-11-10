import Core
import Foundation
import Library
import Observation

/// One scan on screen: its header and which page is showing. Everything but the page is read from the library and
/// from `Today`, so the header moves when either does and the view pops when the scan goes away (M5). A scan opened
/// from Trash (09-04) reads its days left in Trash and offers Restore and Delete now, which Trash's own model runs.
/// Opened in the library, the scan goes first in Search's recently viewed (M4) when the viewer appears. Share and More
/// send the scan out of the app as a PDF, as photos or as its text (M10-M12).
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

    /// Set when Move to Trash or the heart fails to save; the scan stays as it was (M18). Also set when Save to Photos
    /// or Save to Files fails (M12).
    private var ownAlert: EditAlert?

    /// Set when Save to Photos finds add-only access turned off: only Settings can turn it on again (M11).
    package var isPhotosAccessOff = false

    package let id: ScanID
    package let mode: Mode

    private let library: any ScanLibrary
    private let today: Today
    private let calendar: Calendar
    private let analytics: any Analytics
    /// Runs Restore and Delete now in Trash mode, with Trash's confirmation and announcements; nil in the library.
    private let trash: TrashModel?
    private let history: SearchHistory
    private let export: ScanExport
    private let photos: any PhotoSaving
    /// Set once this open is in Search's recently viewed: appearing again (back from a pushed screen) isn't a new one.
    @ObservationIgnored private var isRecorded = false

    /// `history` gets the scan as recently viewed when it opens in the library. `export` makes the shared PDF, and
    /// `photos` adds the pages to Photos.
    public init(
        id: ScanID,
        library: any ScanLibrary,
        today: Today,
        calendar: Calendar,
        analytics: any Analytics,
        history: SearchHistory,
        export: ScanExport,
        photos: any PhotoSaving,
        mode: Mode = .library
    ) {
        self.id = id
        self.library = library
        self.today = today
        self.calendar = calendar
        self.analytics = analytics
        self.mode = mode
        self.history = history
        self.export = export
        self.photos = photos
        trash =
            mode == .trash ? TrashModel(library: library, today: today, calendar: calendar, analytics: analytics) : nil
    }

    /// The viewer is on screen: a scan opened from the library goes first in recently viewed (M4), once per open.
    package func appeared() {
        guard mode == .library, !isRecorded else { return }
        isRecorded = true
        history.record(viewed: id)
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
    package var editAlert: EditAlert? { ownAlert ?? trash?.editAlert }

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
        MoveToTrashText.message(count: 1, collection: scan?.collection)
    }

    /// The confirmation's Move to Trash. True once the scan is in Trash (the view pops); false with `editAlert` when
    /// the move fails to save.
    @discardableResult
    package func moveToTrash() -> Bool {
        guard let scan else { return false }
        do {
            try library.moveToTrash([id])
        } catch {
            ownAlert = EditAlert()
            return false
        }
        analytics.send(.scanMovedToTrash(collection: scan.collection))
        return true
    }

    /// The edit alert's OK.
    package func dismissEditAlert() {
        ownAlert = nil
        trash?.dismissEditAlert()
    }

    // MARK: Favorite

    /// The bottom bar's heart (06-01).
    package var isFavorite: Bool { scan?.isFavorite ?? false }

    /// The heart: favourites the scan, or takes it out of Favorites. A failed write shows the edit alert and changes
    /// nothing, as Move to Trash does.
    package func toggleFavorite() {
        guard let scan else { return }
        let isFavorite = !scan.isFavorite
        do {
            try library.setFavorite(isFavorite, for: [id])
        } catch {
            ownAlert = EditAlert()
            return
        }
        analytics.send(.favoritesChanged(isFavorite: isFavorite, count: 1))
    }

    // MARK: Share and More

    /// What Share sends (06-01): the scan as a PDF named after it (M10), reported once the share sheet makes it.
    package var sharedPDF: ScanPDF? {
        pdf { [analytics] in analytics.send(.scansExported(kind: .share, count: 1)) }
    }

    /// What Save to Files offers: the same PDF, reported by `savedToFiles` once the person has chosen where.
    package var savedPDF: ScanPDF? { pdf() }

    /// Save to Files ended. Its file is copied by then, so the export folder goes (M20). True when it saved; false
    /// with `editAlert` when it failed.
    package func savedToFiles(_ result: Result<URL, any Error>) -> Bool {
        exportEnded()
        switch result {
        case .success:
            analytics.send(.scansExported(kind: .files, count: 1))
            return true
        case .failure(let error):
            ScreenModelsLog.logger.error("Save to Files failed: \(error.localizedDescription, privacy: .private)")
            ownAlert = EditAlert(title: ExportText.filesFailed)
            return false
        }
    }

    /// A share or file export is over, or the viewer has gone: whatever it exported is no longer needed (M20).
    package func exportEnded() {
        export.removeAll()
    }

    /// Adds each page to Photos from its original (M11). True when saved; false with `isPhotosAccessOff` when access
    /// is off, or with `editAlert` when Photos couldn't add them.
    package func saveToPhotos() async -> Bool {
        guard let scan else { return false }
        do {
            try await photos.save(pages: export.originalURLs(for: scan))
        } catch .denied {
            isPhotosAccessOff = true
            return false
        } catch {
            ownAlert = EditAlert(title: ExportText.photosFailed)
            return false
        }
        analytics.send(.scansExported(kind: .photos, count: 1))
        return true
    }

    /// Copy Text is greyed out when the scan has no text (M11), and comes on once reading finishes.
    package var canCopyText: Bool { copiableText != nil }

    /// Hands every page's recognized text, pages separated by a blank line, to `pasteboard`. False, copying nothing,
    /// when there is none.
    package func copyText(to pasteboard: (String) -> Void) -> Bool {
        guard let text = copiableText else { return false }
        pasteboard(text)
        analytics.send(.scansExported(kind: .copyText, count: 1))
        return true
    }

    /// The scan's text as the reader stored it, nil when it has none.
    private var copiableText: String? {
        // Read so the menu updates when reading finishes while the viewer is open.
        _ = library.searchTextRevision
        guard let text = library.searchText(for: id)?.trimmingCharacters(in: .whitespacesAndNewlines),
            !text.isEmpty
        else { return nil }
        return text
    }

    private func pdf(made: @escaping @Sendable () -> Void = {}) -> ScanPDF? {
        scan.map {
            ScanPDF(
                scan: $0, export: export, suggestedFileName: ScanExport.fileName(for: $0.title, taken: []), made: made)
        }
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
