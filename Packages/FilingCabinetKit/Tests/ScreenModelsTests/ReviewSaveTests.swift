import Core
import CoreGraphics
import Foundation
import Library
import TestSupport
import Testing
import Understanding

@testable import ScreenModels

// MARK: - Save

@Test(.timeLimit(.minutes(1)))
func fastReadingIsSavedWithTheScan() async {
    let harness = ReviewHarness(
        preselected: .receipts, reads: [.page(ReviewHarness.pharmacy, delay: .milliseconds(20))])
    _ = await harness.model.save()
    #expect(harness.library.saved.first?.searchText == "CITY PHARMACY\nTOTAL 12.40")
    #expect(harness.library.saved.first?.title == "City Pharmacy")
}

@Test(.timeLimit(.minutes(1)))
func slowReadingSavesFirstAndAddsTextLater() async throws {
    let harness = ReviewHarness(
        preselected: .receipts,
        reads: [.page(ReviewHarness.pharmacy, delay: .milliseconds(500))],
        readingWaitLimit: .milliseconds(20)
    )
    let saved = await harness.model.save()

    let draft = harness.library.saved.first
    #expect(draft?.searchText == nil)
    // Save returned without waiting for reading: the title showing is still the fallback, and it is what was saved.
    #expect(draft?.title == "Scan · Oct 12")
    #expect(harness.model.title == "Scan · Oct 12")
    #expect(harness.library.searchTextUpdates.isEmpty)

    #expect(await harness.laterSearchText(for: try #require(saved?.id)) == "CITY PHARMACY\nTOTAL 12.40")
}

@Test(.timeLimit(.minutes(1)))
func readingThatEndsDuringTheSaveStillAddsText() async throws {
    // Reading ends while the library is still writing: the text must wait for the record to exist.
    let harness = ReviewHarness(
        preselected: .receipts,
        reads: [.page(ReviewHarness.pharmacy, delay: .milliseconds(100))],
        readingWaitLimit: .milliseconds(10)
    )
    harness.library.saveDelay = .milliseconds(400)
    let saved = await harness.model.save()

    #expect(harness.library.saved.first?.searchText == nil)
    #expect(await harness.laterSearchText(for: try #require(saved?.id)) == "CITY PHARMACY\nTOTAL 12.40")
}

/// Two pages, the first read slowly, so a reading cancelled mid-way would leave only page 1's text.
@MainActor
private func slowTwoPageReview() -> ReviewHarness {
    ReviewHarness(
        pages: [ReviewHarness.page1, ReviewHarness.page2],
        preselected: .receipts,
        reads: [.page(ReviewHarness.pharmacy, delay: .milliseconds(300)), .page(ReviewHarness.market)],
        readingWaitLimit: .milliseconds(10)
    )
}

/// Two pages, a blank line between them (M11).
private let bothPagesText = "CITY PHARMACY\nTOTAL 12.40\n\nCORNER MARKET"

@Test(.timeLimit(.minutes(1)))
func discardDuringASaveIsIgnored() async throws {
    let harness = slowTwoPageReview()
    harness.library.saveDelay = .milliseconds(100)
    let saving = Task { await harness.model.save() }
    while !harness.model.isSaving { await Task.yield() }

    harness.model.discard()
    let saved = await saving.value

    #expect(!harness.analytics.events.contains(.scanCancelled(stage: .review)))
    #expect(await harness.laterSearchText(for: try #require(saved?.id)) == bothPagesText)
}

@Test(.timeLimit(.minutes(1)))
func replacingPagesDuringASaveIsIgnored() async throws {
    let harness = slowTwoPageReview()
    harness.library.saveDelay = .milliseconds(100)
    let saving = Task { await harness.model.save() }
    while !harness.model.isSaving { await Task.yield() }

    harness.model.replacePages([ReviewHarness.page3])
    let saved = await saving.value

    #expect(harness.model.pages == [ReviewHarness.page1, ReviewHarness.page2])
    #expect(harness.library.saved.first?.pages == [ReviewHarness.page1, ReviewHarness.page2])
    #expect(await harness.laterSearchText(for: try #require(saved?.id)) == bothPagesText)
}

@Test(.timeLimit(.minutes(1)))
func readingCancelledAfterTheSaveAddsNoText() async throws {
    let harness = slowTwoPageReview()
    let saved = await harness.model.save()

    // Cancelled reading stops after page 1; its partial text must not reach the saved scan.
    harness.model.discard()

    #expect(await harness.laterSearchText(for: try #require(saved?.id), within: .seconds(1)) == nil)
}

@Test(.timeLimit(.minutes(1)))
func savedDraftCarriesEverything() async {
    let harness = ReviewHarness(
        pages: [ReviewHarness.page1, ReviewHarness.page2],
        preselected: .receipts,
        reads: [.page(ReviewHarness.pharmacy), .page(ReviewHarness.market)]
    )
    await harness.model.startReading()
    harness.model.editTitle("Batteries")
    harness.model.chooseExpiry(.lifespan(.week))
    let saved = await harness.model.save()

    let draft = harness.library.saved.first
    #expect(draft?.id == saved?.id)
    #expect(draft?.title == "Batteries")
    #expect(draft?.collection == .receipts)
    #expect(draft?.expiryOverride == .lifespan(.week))
    #expect(draft?.scannedAt == ReviewHarness.now)
    #expect(draft?.pages == [ReviewHarness.page1, ReviewHarness.page2])
    #expect(draft?.searchText == bothPagesText)
    #expect(saved?.announcement == "Saved to Receipts")
}

@Test(.timeLimit(.minutes(1)))
func scanSavedEventCarriesPagesAndCollection() async {
    let harness = ReviewHarness(pages: [ReviewHarness.page1, ReviewHarness.page2, ReviewHarness.page3])
    await harness.model.startReading()
    harness.model.choose(.documents)
    _ = await harness.model.save()
    #expect(harness.analytics.events == [.scanSaved(pageCount: 3, collection: .documents)])
}

@Test(.timeLimit(.minutes(1)))
func saveWithoutACollectionDoesNothing() async {
    let harness = ReviewHarness()
    #expect(await harness.model.save() == nil)
    #expect(harness.library.saved.isEmpty)
}

@Test(.timeLimit(.minutes(1)))
func diskFullKeepsPagesAndOffersTryAgain() async {
    let harness = ReviewHarness(pages: [ReviewHarness.page1, ReviewHarness.page2], preselected: .receipts)
    await harness.model.startReading()
    harness.library.failNextSave = .diskFull

    #expect(await harness.model.save() == nil)
    #expect(
        harness.model.saveAlert
            == SaveAlert(
                title: "Couldn’t save this scan",
                message: "Your iPhone is out of space. Free some up, then try again. Your pages are still here."))
    #expect(harness.model.pages == [ReviewHarness.page1, ReviewHarness.page2])
    #expect(harness.model.title == "City Pharmacy")
    #expect(!harness.model.isSaving)
    #expect(harness.analytics.events == [.saveFailed(reason: .diskFull)])

    let saved = await harness.model.retrySave()
    #expect(saved != nil)
    #expect(harness.model.saveAlert == nil)
    #expect(harness.library.saved.map(\.pages) == [[ReviewHarness.page1, ReviewHarness.page2]])
}

@Test(.timeLimit(.minutes(1)))
func otherFailureUsesTheGenericMessage() async {
    let harness = ReviewHarness(preselected: .receipts)
    await harness.model.startReading()
    harness.library.failNextSave = .writeFailed
    _ = await harness.model.save()
    #expect(harness.model.saveAlert?.title == "Couldn’t save this scan")
    #expect(harness.model.saveAlert?.message == "Something went wrong. Your pages are still here.")
    #expect(harness.analytics.events == [.saveFailed(reason: .writeFailed)])

    harness.model.dismissSaveAlert()
    #expect(harness.model.saveAlert == nil)
}

// MARK: - Reading

@Test(.timeLimit(.minutes(1)))
func failedReadingPagesAreReported() async {
    let harness = ReviewHarness(
        pages: [ReviewHarness.page1, ReviewHarness.page2],
        reads: [.page(ReviewHarness.pharmacy), .failure(.recognitionFailed)])
    await harness.model.startReading()
    #expect(harness.analytics.events == [.textReadingFailed(failedPages: 1)])
}

@Test(.timeLimit(.minutes(1)))
func readingRunsOncePerPageSet() async {
    let harness = ReviewHarness(pages: [ReviewHarness.page1, ReviewHarness.page2])
    await harness.model.startReading()
    await harness.model.startReading()
    harness.model.choose(.receipts)
    _ = await harness.model.save()
    #expect(harness.reader.readCount == 2)
}

// MARK: - Rescan

@Test(.timeLimit(.minutes(1)))
func cancelledRescanKeepsPagesAndTitle() async {
    let flow = ReviewHarness.flow()
    await flow.scan(from: .home, preselected: nil)
    flow.cameraFinished([ReviewHarness.page1])
    let review = flow.review
    await review?.startReading()

    flow.rescan()
    flow.cameraCancelled()

    #expect(flow.review === review)
    #expect(review?.pages == [ReviewHarness.page1])
    #expect(review?.title == "City Pharmacy")
}

@Test(.timeLimit(.minutes(1)))
func finishedRescanReplacesTheReviewsPages() async {
    let flow = ReviewHarness.flow()
    await flow.scan(from: .home, preselected: nil)
    flow.cameraFinished([ReviewHarness.page1])
    let review = flow.review

    flow.rescan()
    flow.cameraFinished([ReviewHarness.page2, ReviewHarness.page3])

    #expect(flow.review === review)
    #expect(review?.pages == [ReviewHarness.page2, ReviewHarness.page3])
    flow.reviewEnded(saved: nil)
    #expect(flow.review == nil)
}

@Test(.timeLimit(.minutes(1)))
func rescanReplacesPagesAndRereadsUntouchedTitle() async {
    let harness = ReviewHarness(
        pages: [ReviewHarness.page1, ReviewHarness.page2],
        reads: [.page(ReviewHarness.pharmacy), .page(ReviewHarness.pharmacy), .page(ReviewHarness.market)])
    await harness.model.startReading()
    harness.model.currentPage = 1
    #expect(harness.model.title == "City Pharmacy")

    harness.model.replacePages([ReviewHarness.page3])
    #expect(harness.model.pages == [ReviewHarness.page3])
    #expect(harness.model.currentPage == 0)
    #expect(harness.model.title == "Scan · Oct 12")
    await harness.model.startReading()
    #expect(harness.model.title == "Corner Market")
    #expect(harness.reader.readCount == 3)
}

@Test(.timeLimit(.minutes(1)))
func rescanKeepsATypedTitle() async {
    let harness = ReviewHarness(reads: [.page(ReviewHarness.pharmacy), .page(ReviewHarness.market)])
    await harness.model.startReading()
    harness.model.editTitle("Batteries")
    harness.model.replacePages([ReviewHarness.page2])
    await harness.model.startReading()
    #expect(harness.model.title == "Batteries")
}

@Test(.timeLimit(.minutes(1)))
func rescanDropsTheOldReading() async {
    // The first page set is still being read when the rescan arrives; only the new set's text may land.
    let harness = ReviewHarness(
        preselected: .receipts,
        reads: [.page(ReviewHarness.pharmacy, delay: .seconds(30)), .page(ReviewHarness.market)])
    let first = Task { await harness.model.startReading() }
    while harness.reader.readCount == 0 { await Task.yield() }

    harness.model.replacePages([ReviewHarness.page2])
    await harness.model.startReading()
    await first.value
    #expect(harness.model.title == "Corner Market")
    _ = await harness.model.save()
    #expect(harness.library.saved.first?.searchText == "CORNER MARKET")
}

@Test(.timeLimit(.minutes(1)))
func choicesDuringASaveAreIgnored() async throws {
    // Save waits for a slow reading before it builds the draft: a pick in that window must not change what is saved.
    let harness = ReviewHarness(
        preselected: .receipts,
        reads: [.page(ReviewHarness.pharmacy, delay: .milliseconds(500))],
        readingWaitLimit: .milliseconds(200)
    )
    let saving = Task { await harness.model.save() }
    while !harness.model.isSaving { await Task.yield() }

    harness.model.choose(.wallet)
    harness.model.editTitle("Typed while saving")
    harness.model.chooseExpiry(.lifespan(.week))
    harness.model.chooseExpiryDate(CalendarDay(year: 2026, month: 12, day: 1).date(in: ReviewHarness.newYork))
    _ = await saving.value

    let draft = try #require(harness.library.saved.first)
    #expect(draft.collection == .receipts)
    #expect(draft.title == "Scan · Oct 12")
    #expect(draft.expiryOverride == nil)
    #expect(harness.model.collection == .receipts)
    #expect(harness.model.title == "Scan · Oct 12")
    #expect(harness.model.expiryOverride == nil)
}
