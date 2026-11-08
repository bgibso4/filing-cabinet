import Core
import Foundation
import Library
import Testing

@testable import ScreenModels
@testable import TestSupport

private let utc: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = .gmt
    return calendar
}()

private let oct12 = CalendarDay(year: 2026, month: 10, day: 12)
private let noon = oct12.date(in: utc).addingTimeInterval(12 * 3600)

private func receipt(daysOld: Int) -> ScanSummary {
    ScanSummary(
        id: ScanID(),
        title: "Synthetic",
        collection: .receipts,
        scannedAt: noon.addingTimeInterval(-Double(daysOld) * 86_400),
        expiryOverride: nil,
        pageCount: 1)
}

@MainActor
private struct LifespanHarness {
    let analytics = RecordingAnalytics()
    let library: FakeLibrary
    let model: CollectionSettingsModel

    /// Receipts keep 3 months by default; `daysOld` gives each scan's age on Oct 12, 2026.
    init(daysOld: [Int], collection: BuiltInCollection = .receipts) {
        let clock = AppClock.fixed(noon, calendar: utc)
        library = FakeLibrary(scans: daysOld.map { receipt(daysOld: $0) }, clock: clock)
        model = CollectionSettingsModel(
            collection: collection, library: library, today: Today(clock: clock), calendar: utc, analytics: analytics)
    }
}

@MainActor
@Test func readsTitleCountValueAndChoices() {
    let model = LifespanHarness(daysOld: Array(repeating: 2, count: 23)).model
    #expect(model.title == "Receipts")
    #expect(model.countLine == "23 scans")
    #expect(model.lifespanValue == "3 months")
    #expect(model.choices.map(\.title) == ["1 week", "1 month", "3 months", "1 year", "Forever"])
    #expect(model.choices.map(\.isCurrent) == [false, false, true, false, false])
    #expect(model.note == "Applies to receipts you already have. Scans you gave their own expiry keep it.")
}

@MainActor
@Test func shorteningAsksWithTheCount() throws {
    let harness = LifespanHarness(daysOld: Array(repeating: 40, count: 18) + [2, 3, 4, 5, 6])
    harness.model.choose(.month)
    let confirmation = try #require(harness.model.confirmation)
    #expect(confirmation.title == "Keep receipts 1 month?")
    #expect(
        confirmation.message
            == "18 receipts are older than a month and will go to Trash now. You can restore them for 30 days.")
    #expect(confirmation.confirmTitle == "Change")
    #expect(harness.library.lifespans[.receipts] == .threeMonths)
    #expect(harness.analytics.events.isEmpty)
}

@MainActor
@Test func oneReceiptReadsIs() throws {
    let harness = LifespanHarness(daysOld: [40, 2])
    harness.model.choose(.month)
    #expect(
        try #require(harness.model.confirmation).message
            == "1 receipt is older than a month and will go to Trash now. You can restore them for 30 days.")
}

@MainActor
@Test func confirmingAppliesAndReportsTheChange() throws {
    let harness = LifespanHarness(daysOld: [40, 2])
    harness.model.choose(.week)
    harness.model.confirm()
    #expect(harness.model.confirmation == nil)
    #expect(harness.library.lifespans[.receipts] == .week)
    #expect(harness.model.lifespanValue == "1 week")
    #expect(harness.analytics.events == [.lifespanChanged(collection: .receipts, lifespan: .week)])
}

@MainActor
@Test func lengtheningAppliesAtOnce() {
    let harness = LifespanHarness(daysOld: [40, 2])
    harness.model.choose(.year)
    #expect(harness.model.confirmation == nil)
    #expect(harness.library.lifespans[.receipts] == .year)
    #expect(harness.analytics.events == [.lifespanChanged(collection: .receipts, lifespan: .year)])
}

@MainActor
@Test func shorteningWithNothingToTrashAppliesAtOnce() {
    let harness = LifespanHarness(daysOld: [2, 3])
    harness.model.choose(.month)
    #expect(harness.model.confirmation == nil)
    #expect(harness.library.lifespans[.receipts] == .month)
}

@MainActor
@Test func cancelLeavesTheLifespan() {
    let harness = LifespanHarness(daysOld: [40])
    harness.model.choose(.month)
    harness.model.cancel()
    #expect(harness.model.confirmation == nil)
    #expect(harness.library.lifespans[.receipts] == .threeMonths)
    #expect(harness.analytics.events.isEmpty)
}

@MainActor
@Test func choosingTheCurrentLifespanChangesNothing() {
    let harness = LifespanHarness(daysOld: [40])
    harness.model.choose(.threeMonths)
    #expect(harness.model.confirmation == nil)
    #expect(harness.analytics.events.isEmpty)
}

@MainActor
@Test func aFailedWriteShowsTheAlertAndChangesNothing() {
    let harness = LifespanHarness(daysOld: [2])
    harness.library.failNextEdit = .writeFailed
    harness.model.choose(.year)
    #expect(harness.model.editAlert == EditAlert())
    #expect(harness.library.lifespans[.receipts] == .threeMonths)
    #expect(harness.analytics.events.isEmpty)
}
