import Core
import Foundation
import Library
import Testing

@testable import ScreenModels
@testable import TestSupport

// The viewer's Share and More (M10-M12, M19, M20).

private let utc: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? calendar.timeZone
    return calendar
}()

private let clock = AppClock.fixed(
    CalendarDay(year: 2026, month: 10, day: 12).date(in: utc).addingTimeInterval(12 * 3600), calendar: utc)

private func summary(_ title: String, _ collection: BuiltInCollection, pages: Int = 1) -> ScanSummary {
    ScanSummary(
        id: ScanID(),
        title: title,
        collection: collection,
        scannedAt: clock.now(),
        expiryOverride: nil,
        pageCount: pages)
}

/// A library folder and an export folder of their own under the temporary directory.
struct ExportFolder {
    let base = FileManager.default.temporaryDirectory.appending(path: "ViewerExportTests-\(UUID().uuidString)")
    var files: PageFileStore {
        PageFileStore(
            location: LibraryLocation(root: base.appending(path: "Root"), caches: base.appending(path: "Caches")),
            fileSystem: LocalFileSystem())
    }
    var folder: URL { base.appending(path: "Export") }
    var export: ScanExport { ScanExport(files: files, folder: folder) }
}

private func model(
    _ scan: ScanSummary,
    library: FakeLibrary? = nil,
    analytics: RecordingAnalytics = RecordingAnalytics(),
    export: ScanExport = ExportFolder().export,
    photos: FakePhotoSaving = FakePhotoSaving()
) -> ViewerModel {
    ViewerModel(
        id: scan.id,
        library: library ?? FakeLibrary(scans: [scan], clock: clock),
        today: Today(clock: clock),
        calendar: utc,
        analytics: analytics,
        history: SearchHistory(defaults: .standard),
        export: export,
        photos: photos)
}

@Test func copyTextJoinsPagesWithABlankLine() {
    let scan = summary("Lease 2026", .documents, pages: 2)
    let library = FakeLibrary(scans: [scan], clock: clock)
    // As the reader stores it: each page's lines, and a blank line between pages.
    library.updateSearchText("Harlow Property\nDear Alex,\n\nSincerely,", for: scan.id)
    let viewer = model(scan, library: library)
    var copied: [String] = []

    #expect(viewer.canCopyText)
    #expect(viewer.copyText { copied.append($0) })
    #expect(copied == ["Harlow Property\nDear Alex,\n\nSincerely,"])
}

@Test(arguments: [nil, "", " \n "])
func copyTextDisabledWithoutText(text: String?) {
    let scan = summary("Coat check", .throwaways)
    let library = FakeLibrary(scans: [scan], clock: clock)
    if let text { library.updateSearchText(text, for: scan.id) }
    let analytics = RecordingAnalytics()
    let viewer = model(scan, library: library, analytics: analytics)
    var copied: [String] = []

    #expect(!viewer.canCopyText)
    #expect(!viewer.copyText { copied.append($0) })
    #expect(copied.isEmpty)
    #expect(analytics.events.isEmpty)
}

@Test func exportsSendAnalyticsWithoutText() async throws {
    let folder = ExportFolder()
    let scan = summary("Lease 2026", .documents, pages: 2)
    _ = try await folder.files.write([SyntheticPages.blank(), SyntheticPages.blank()], for: scan.id)
    let library = FakeLibrary(scans: [scan], clock: clock)
    library.updateSearchText("Harlow Property", for: scan.id)
    let analytics = RecordingAnalytics()
    let viewer = model(scan, library: library, analytics: analytics, export: folder.export)

    _ = try await #require(viewer.sharedPDF).file()
    _ = viewer.copyText { _ in }
    #expect(await viewer.saveToPhotos())
    #expect(viewer.savedToFiles(.success(folder.base.appending(path: "Chosen.pdf"))))

    #expect(
        analytics.events == [
            .scansExported(kind: .share, count: 1),
            .scansExported(kind: .copyText, count: 1),
            .scansExported(kind: .photos, count: 1),
            .scansExported(kind: .files, count: 1),
        ])
}

@Test func sharedPDFIsNamedAfterTheScan() throws {
    let viewer = model(summary("Rent: October", .documents))
    #expect(try #require(viewer.sharedPDF).suggestedFileName == "Rent- October")
    #expect(try #require(viewer.savedPDF).suggestedFileName == "Rent- October")
}

@Test func saveToPhotosAddsEveryPage() async {
    let folder = ExportFolder()
    let scan = summary("Lease 2026", .documents, pages: 3)
    let photos = FakePhotoSaving()
    let viewer = model(scan, export: folder.export, photos: photos)

    #expect(await viewer.saveToPhotos())

    #expect(photos.saved == [folder.files.originalURLs(pageCount: 3, for: scan.id)])
}

@Test func saveToPhotosDeniedAsksForSettings() async {
    let analytics = RecordingAnalytics()
    let viewer = model(
        summary("Lease 2026", .documents), analytics: analytics, photos: FakePhotoSaving(failing: .denied))

    #expect(!(await viewer.saveToPhotos()))

    #expect(viewer.isPhotosAccessOff)
    #expect(viewer.editAlert == nil)
    #expect(analytics.events.isEmpty)
}

@Test func failedSaveToPhotosShowsTheAlert() async {
    let analytics = RecordingAnalytics()
    let viewer = model(
        summary("Lease 2026", .documents), analytics: analytics, photos: FakePhotoSaving(failing: .failed))

    #expect(!(await viewer.saveToPhotos()))

    #expect(!viewer.isPhotosAccessOff)
    #expect(viewer.editAlert?.title == "Couldn’t save to Photos")
    #expect(viewer.editAlert?.message == "Something went wrong. Try again.")
    #expect(analytics.events.isEmpty)
}

@Test func failedSaveToFilesShowsTheAlert() {
    let analytics = RecordingAnalytics()
    let viewer = model(summary("Lease 2026", .documents), analytics: analytics)

    #expect(!viewer.savedToFiles(.failure(CocoaError(.fileWriteUnknown))))

    #expect(viewer.editAlert?.title == "Couldn’t save to Files")
    #expect(analytics.events.isEmpty)
}

@Test func exportsAnnounceWithoutANote() {
    #expect(ExportText.savedToPhotos == "Saved to Photos")
    #expect(ExportText.savedToFiles == "Saved to Files")
    #expect(ExportText.copied == "Copied")
}

@Test func endingAnExportRemovesExportedFiles() async throws {
    let folder = ExportFolder()
    let scan = summary("Lease 2026", .documents)
    _ = try await folder.files.write([SyntheticPages.blank()], for: scan.id)
    let viewer = model(scan, export: folder.export)
    let url = try await #require(viewer.sharedPDF).file()
    #expect(FileManager.default.fileExists(atPath: url.path(percentEncoded: false)))

    viewer.exportEnded()

    #expect(!FileManager.default.fileExists(atPath: folder.folder.path(percentEncoded: false)))
}
