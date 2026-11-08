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

    /// Sets the scan's search text once reading finishes. A failure is logged; the scan stays saved.
    func updateSearchText(_ text: String, for id: ScanID)

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
}
