import Core

/// The saved scans as the screens see them. `ScanStore` is the real one; `FakeLibrary` stands in for tests.
///
/// Edits run on the main context and are synchronous (M21). Each one persists before it returns; a failed
/// persist changes nothing and throws `.writeFailed`. A scan with no record is skipped.
@MainActor
public protocol ScanLibrary: AnyObject {
    /// Every scan, newest `scannedAt` first.
    var scans: [ScanSummary] { get }

    /// How long each collection keeps its scans.
    var lifespans: CollectionLifespans { get }

    /// Saves the draft's files and record, all or nothing. Throws `.diskFull` or `.writeFailed`.
    func save(_ draft: ScanDraft) async throws(LibraryError)

    /// Goes up each time `updateSearchText` stores a text, so Search can follow texts without `scans` changing (and
    /// every grid redrawing).
    var searchTextRevision: Int { get }

    /// Sets the scan's search text once reading finishes, and bumps `searchTextRevision`. A failure is logged; the
    /// scan stays saved.
    func updateSearchText(_ text: String, for id: ScanID)

    /// Stores the model's hidden search words for the scan and the prompt version that made them, and bumps
    /// `searchTextRevision`. A scan with no record is ignored; a failure is logged.
    func updateSearchWords(_ words: [String], version: Int, for id: ScanID)

    func rename(_ id: ScanID, to title: String) throws(LibraryError)

    /// Keeps the scan's own expiry. A scan the move expires goes to Trash today; one already there stays (M1).
    func move(_ id: ScanID, to collection: BuiltInCollection) throws(LibraryError)

    /// Nil returns the scan to its collection's lifespan.
    func setExpiry(_ override: ExpiryOverride?, for id: ScanID) throws(LibraryError)

    /// The scans enter Trash today.
    func moveToTrash(_ ids: [ScanID]) throws(LibraryError)

    /// Back to the library, kept forever, in the same collection (M10).
    func restore(_ ids: [ScanID]) throws(LibraryError)

    /// Removes the records, then the files (M11): a failure after the records are gone leaves only orphaned
    /// files, which launch cleanup removes.
    func deleteNow(_ ids: [ScanID]) async throws(LibraryError)

    /// Deletes every scan in Trash, as `deleteNow` does, and returns how many.
    func emptyTrash() async throws(LibraryError) -> Int

    /// Gives the collection a new lifespan (M1): scans already in Trash keep their entry day, and scans on the
    /// collection's lifespan that the change expires enter Trash today. Scans with their own expiry keep it.
    func setLifespan(_ lifespan: Lifespan, for collection: BuiltInCollection) throws(LibraryError)

    /// How many scans in the library `setLifespan` would send to Trash today.
    func scansExpiring(ifLifespan lifespan: Lifespan, for collection: BuiltInCollection) -> Int

    /// Favourites the scans, last and in the order of `ids` (B8), or un-favourites them. A scan already as asked is
    /// left alone. Numbers never clash, Trash included (M3); a stored tie is renumbered first (B11).
    func setFavorite(_ isFavorite: Bool, for ids: [ScanID]) throws(LibraryError)

    /// Puts the visible favourites in the order of `ids`. Favourites in Trash keep their places; a visible favourite
    /// missing from `ids` keeps its place after them; an id that isn't a favourite is ignored (M3).
    func reorderFavorites(_ ids: [ScanID]) throws(LibraryError)

    /// Every scan's recognized text, Trash included, as read, in one fetch. Empty when the fetch fails.
    func searchTexts() -> [ScanID: String]

    /// Every scan's hidden search words, Trash included, in one fetch. Empty when the fetch fails.
    func searchWords() -> [ScanID: [String]]

    /// The scans in the library, not Trash, that the model has not read at `version` or later: never read, or read
    /// by an older version. Newest first (M9).
    func scansNeedingWords(version: Int) -> [ScanID]

    /// The scan's recognized text, as read; nil when there is no such scan or the fetch fails.
    func searchText(for id: ScanID) -> String?
}
