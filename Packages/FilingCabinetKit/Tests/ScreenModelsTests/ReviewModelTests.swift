import Core
import Foundation
import TestSupport
import Testing
import Understanding

@testable import ScreenModels

// MARK: - Title

@Test(.timeLimit(.minutes(1)))
func titleStartsAsFallbackThenTakesTheReadTitle() async {
    let harness = ReviewHarness()
    #expect(harness.model.title == "Scan · Oct 12")
    await harness.model.startReading()
    #expect(harness.model.title == "City Pharmacy")
}

@Test(.timeLimit(.minutes(1)))
func typedTitleIsNeverOverwritten() async {
    let harness = ReviewHarness()
    harness.model.editTitle("Batteries")
    await harness.model.startReading()
    #expect(harness.model.title == "Batteries")
}

@Test(.timeLimit(.minutes(1)))
func clearedTitleSavesAsFallback() async {
    let harness = ReviewHarness(preselected: .receipts)
    await harness.model.startReading()
    harness.model.editTitle("  ")
    _ = await harness.model.save()
    #expect(harness.library.saved.map(\.title) == ["Scan · Oct 12"])
}

@Test(.timeLimit(.minutes(1)))
func noReadableTextKeepsFallback() async {
    let harness = ReviewHarness(reads: [.page(PageText(lines: []))])
    await harness.model.startReading()
    #expect(harness.model.title == "Scan · Oct 12")
    #expect(harness.model.fallbackTitle == "Scan · Oct 12")
}

// MARK: - Pages

@Test func onePageCountsAsOnePage() {
    let harness = ReviewHarness()
    #expect(harness.model.pageCountText == "1 page")
    #expect(harness.model.pageAccessibilityLabel == "Page 1 of 1")
}

@Test func severalPagesShowWhereYouAre() {
    let harness = ReviewHarness(pages: [ReviewHarness.page1, ReviewHarness.page2, ReviewHarness.page3])
    harness.model.currentPage = 1
    #expect(harness.model.pageCountText == "Page 2 of 3")
    #expect(harness.model.pageAccessibilityLabel == "Page 2 of 3")
}

@Test func anotherReviewPageStartsUnzoomed() {
    let harness = ReviewHarness(pages: [ReviewHarness.page1, ReviewHarness.page2, ReviewHarness.page3])
    harness.model.isPageZoomed = true
    harness.model.currentPage = 0
    #expect(harness.model.isPageZoomed, "the same page stays zoomed")
    harness.model.currentPage = 1
    #expect(!harness.model.isPageZoomed)
    harness.model.isPageZoomed = true
    harness.model.replacePages([ReviewHarness.page1])
    #expect(!harness.model.isPageZoomed, "a rescan starts unzoomed")
}

// MARK: - Collection and expiry

@Test func saveIsOffUntilACollectionIsChosen() {
    let harness = ReviewHarness()
    #expect(harness.model.collection == nil)
    #expect(!harness.model.canSave)
    #expect(harness.model.saveTitle == "Save")
    #expect(harness.model.collectionLabel == "Collection · required")
    #expect(harness.model.collectionValue == "Choose a collection")
    #expect(!harness.model.isExpiryEnabled)
    #expect(harness.model.expiryValue == "Set by the collection")

    harness.model.choose(.receipts)
    #expect(harness.model.canSave)
    #expect(harness.model.saveTitle == "Save to Receipts")
    #expect(harness.model.collectionLabel == "Collection")
    #expect(harness.model.collectionValue == "Receipts")
}

@Test func preselectedCollectionIsChosen() {
    let harness = ReviewHarness(preselected: .wallet)
    #expect(harness.model.collection == .wallet)
    #expect(harness.model.canSave)
}

@Test func collectionOptionsListEveryCollectionWithItsLifespan() {
    let options = ReviewHarness().model.collectionOptions
    #expect(options.map(\.collection) == BuiltInCollection.allCases)
    #expect(options.map(\.name) == ["Wallet", "Receipts", "Notes", "Documents", "Throwaways"])
    #expect(
        options.map(\.lifespan) == ["Kept forever", "3 months", "Kept forever", "Kept forever", "1 week"])
}

@Test func choosingACollectionFillsExpiry() {
    let harness = ReviewHarness()
    harness.model.choose(.receipts)
    #expect(harness.model.isExpiryEnabled)
    #expect(harness.model.expiryValue == "3 months · until Jan 9, 2027")
}

@Test func expiryOptionsListDefaultFirstThenChoicesAndForever() {
    let harness = ReviewHarness(preselected: .receipts)
    let options = harness.model.expiryOptions
    #expect(options.map(\.label) == ["Receipts default", "1 week", "1 month", "3 months", "1 year", "Forever"])
    #expect(
        options.map(\.detail) == ["Jan 9, 2027", "Oct 18", "Nov 10", "Jan 9, 2027", "Oct 11, 2027", "Never expires"])
    #expect(
        options.map(\.override) == [
            nil, .lifespan(.week), .lifespan(.month), .lifespan(.threeMonths), .lifespan(.year), .lifespan(.forever),
        ])
    #expect(options.map(\.isSelected) == [true, false, false, false, false, false])

    harness.model.chooseExpiry(.lifespan(.year))
    #expect(harness.model.expiryOverride == .lifespan(.year))
    #expect(harness.model.expiryOptions.map(\.isSelected) == [false, false, false, false, true, false])
    #expect(harness.model.expiryValue == "1 year · until Oct 11, 2027")
}

@Test func foreverCollectionDefaultNeverExpires() {
    let harness = ReviewHarness(preselected: .documents)
    #expect(harness.model.expiryOptions.first?.label == "Documents default")
    #expect(harness.model.expiryOptions.first?.detail == "Never expires")
}

@Test func customDateBeforeTodayIsRefused() {
    let harness = ReviewHarness(preselected: .receipts)
    #expect(
        harness.model.earliestCustomDate == CalendarDay(year: 2026, month: 10, day: 12).date(in: ReviewHarness.newYork))

    let yesterday = CalendarDay(year: 2026, month: 10, day: 11).date(in: ReviewHarness.newYork)
    harness.model.chooseExpiryDate(yesterday)
    #expect(harness.model.expiryOverride == nil)

    let today = CalendarDay(year: 2026, month: 10, day: 12).date(in: ReviewHarness.newYork)
    harness.model.chooseExpiryDate(today)
    #expect(harness.model.expiryOverride == .lastDay(CalendarDay(year: 2026, month: 10, day: 12)))
    #expect(harness.model.expiryOptions.allSatisfy { !$0.isSelected })
    #expect(harness.model.expiryValue == "Until Oct 12")
}

// MARK: - Discard

@Test func discardMessageCountsPages() {
    #expect(ReviewHarness().model.discardMessage == "The page you just scanned won’t be saved.")
    #expect(
        ReviewHarness(pages: [ReviewHarness.page1, ReviewHarness.page2, ReviewHarness.page3]).model.discardMessage
            == "The 3 pages you just scanned won’t be saved.")
}

@Test func discardSendsCancelledReview() {
    let harness = ReviewHarness()
    harness.model.discard()
    #expect(harness.analytics.events == [.scanCancelled(stage: .review)])
}

@Test func dateChoiceUsesTheClocksCalendarAndLocale() {
    let harness = ReviewHarness(preselected: .receipts)
    #expect(harness.model.calendar.timeZone == ReviewHarness.newYork.timeZone)
    #expect(harness.model.locale.identifier == "en_US")
}
