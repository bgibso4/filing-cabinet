import Core
import Foundation
import Library
import Synchronization
import Testing

@testable import ScreenModels
@testable import TestSupport

private let utc: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? calendar.timeZone
    return calendar
}()

private let noon = CalendarDay(year: 2026, month: 10, day: 12).date(in: utc).addingTimeInterval(12 * 3600)

/// A clock the test moves by hand.
nonisolated private final class MovableNow: Sendable {
    private let date: Mutex<Date>

    init(_ date: Date) {
        self.date = Mutex(date)
    }

    var now: Date { date.withLock { $0 } }

    func set(_ newDate: Date) {
        date.withLock { $0 = newDate }
    }
}

private func summary(
    _ title: String, _ collection: BuiltInCollection, scanned: CalendarDay? = nil, pages: Int = 1
) -> ScanSummary {
    ScanSummary(
        id: ScanID(),
        title: title,
        collection: collection,
        scannedAt: scanned?.date(in: utc) ?? noon,
        expiryOverride: nil,
        pageCount: pages)
}

private func model(_ scan: ScanSummary, library: FakeLibrary? = nil, today: Today? = nil) -> ViewerModel {
    ViewerModel(
        id: scan.id,
        library: library ?? FakeLibrary(scans: [scan]),
        today: today ?? Today(clock: AppClock.fixed(noon, calendar: utc)),
        calendar: utc)
}

@Test func leaseHeaderReadsKeptForever() {
    let viewer = model(summary("Lease 2026", .documents, pages: 3))
    #expect(viewer.title == "Lease 2026")
    #expect(viewer.collection == .documents)
    #expect(viewer.collectionName == "Documents")
    #expect(viewer.timeLeftText == "Kept forever")
    #expect(!viewer.isSoon)
    #expect(!viewer.isMissing)
}

@Test func receiptFiveDaysLeftIsSoon() {
    // Scanned on Jul 19, the 90th day is Oct 16: five days left, Oct 12 included.
    let viewer = model(summary("Corner Market", .receipts, scanned: CalendarDay(year: 2026, month: 7, day: 19)))
    #expect(viewer.timeLeftText == "5 days left")
    #expect(viewer.isSoon)
}

@Test func pageLabelCounts() {
    let viewer = model(summary("Lease 2026", .documents, pages: 3))
    #expect(viewer.pageCount == 3)
    #expect(viewer.currentPage == 0)
    #expect(viewer.pageLabel == "Page 1 of 3")
    viewer.currentPage = 1
    #expect(viewer.pageLabel == "Page 2 of 3")
}

@Test func singlePageHasNoStrip() {
    #expect(!model(summary("Corner Market", .receipts)).showsStrip)
    #expect(model(summary("Lease 2026", .documents, pages: 2)).showsStrip)
}

@Test func expiredScanIsMissing() {
    let scan = summary("Old receipt", .receipts, scanned: CalendarDay(year: 2026, month: 1, day: 1))
    let viewer = model(scan)
    #expect(viewer.isMissing)
    // What the header shows while the view pops: never a claim that it is kept.
    #expect(viewer.timeLeftText == "0 days left")
    #expect(!viewer.isSoon)
}

@Test func scanGoneFromTheLibraryIsMissing() {
    let viewer = model(summary("Gone", .notes), library: FakeLibrary())
    #expect(viewer.isMissing)
    #expect(viewer.pageCount == 0)
    #expect(!viewer.showsStrip)
}

@Test func aScanOnItsLastDayIsMissingTheNextDay() {
    let now = MovableNow(noon)
    let today = Today(clock: AppClock(now: { now.now }, calendar: utc, locale: Locale(identifier: "en_US")))
    let scan = summary("Coat check", .throwaways, scanned: CalendarDay(year: 2026, month: 10, day: 6))
    let viewer = model(scan, today: today)
    #expect(!viewer.isMissing)

    now.set(noon.addingTimeInterval(86_400))
    today.refresh()
    #expect(viewer.isMissing)
}

@Test func onlyTheCurrentPageAndItsNeighboursAreHeld() {
    let viewer = model(summary("Long", .documents, pages: 20))
    #expect(viewer.neighbouringPages == [1])
    #expect((0..<20).filter(viewer.holdsPage) == [0, 1])

    viewer.currentPage = 10
    #expect(viewer.neighbouringPages == [11, 9])
    #expect((0..<20).filter(viewer.holdsPage) == [9, 10, 11])

    viewer.currentPage = 19
    #expect(viewer.neighbouringPages == [18])
    #expect((0..<20).filter(viewer.holdsPage) == [18, 19])
}

@Test func theOpenPageSurvivesALibraryChange() async throws {
    let scan = summary("Lease 2026", .documents, pages: 3)
    let library = FakeLibrary(scans: [scan])
    let viewer = model(scan, library: library)
    viewer.currentPage = 2
    try await library.save(
        ScanDraft(
            id: ScanID(),
            title: "New",
            collection: .notes,
            scannedAt: noon,
            expiryOverride: nil,
            pages: [],
            searchText: ""))
    #expect(viewer.currentPage == 2)
    #expect(viewer.pageLabel == "Page 3 of 3")
}
