import Core
import CoreGraphics
import Foundation
import TestSupport
import Testing
import Understanding

@testable import ScreenModels

@MainActor
private struct Harness {
    let preferences: AppPreferences
    let analytics = RecordingAnalytics()
    let rating: RatingPrompt
    private let fresh: FreshDefaults

    init(version: String = "1.0") throws {
        fresh = try FreshDefaults()
        preferences = AppPreferences(defaults: fresh.defaults)
        rating = RatingPrompt(preferences: preferences, version: version, analytics: analytics)
    }

    /// Another prompt on the same defaults, as after a relaunch (and an update, when `version` changes).
    func relaunched(version: String) -> RatingPrompt {
        RatingPrompt(
            preferences: AppPreferences(defaults: fresh.defaults), version: version, analytics: analytics)
    }

    func save(_ count: Int, onDay day: Int) {
        for _ in 0..<count { rating.recordSave(on: CalendarDay(year: 2027, month: 1, day: day)) }
    }
}

@Test func nineSavesDoesNotAsk() throws {
    let harness = try Harness()
    harness.save(3, onDay: 1)
    harness.save(3, onDay: 2)
    harness.save(3, onDay: 3)
    #expect(!harness.rating.isDue)
}

@Test func tenOnTwoDaysDoesNotAsk() throws {
    let harness = try Harness()
    harness.save(5, onDay: 1)
    harness.save(5, onDay: 2)
    #expect(!harness.rating.isDue)
}

@Test func tenthSaveOnThirdDayAsks() throws {
    let harness = try Harness()
    harness.save(5, onDay: 1)
    harness.save(4, onDay: 2)
    #expect(!harness.rating.isDue)
    harness.save(1, onDay: 3)
    #expect(harness.rating.isDue)
}

@Test func failedSaveDoesNotCount() async throws {
    let harness = try Harness()
    let flow = ScanFlowModel(
        cameraAccess: FakeCameraAccess(status: .authorized, grantsOnRequest: true),
        clock: .system,
        analytics: harness.analytics,
        suggester: FakeScanSuggester.unavailable(),
        suggestionsOn: { false },
        makeReview: { _ in fatalError("never reviewed") },
        scanSaved: { harness.rating.recordSave(on: CalendarDay(year: 2027, month: 1, day: 1)) }
    )
    flow.reviewEnded(saved: nil)
    #expect(harness.preferences.savesCount == 0)
    #expect(harness.preferences.saveDays.isEmpty)
}

@Test func aSavedScanCounts() async throws {
    let harness = try Harness()
    let flow = ScanFlowModel(
        cameraAccess: FakeCameraAccess(status: .authorized, grantsOnRequest: true),
        clock: .system,
        analytics: harness.analytics,
        suggester: FakeScanSuggester.unavailable(),
        suggestionsOn: { false },
        makeReview: { _ in fatalError("never reviewed") },
        scanSaved: { harness.rating.recordSave(on: CalendarDay(year: 2027, month: 1, day: 1)) }
    )
    flow.reviewEnded(saved: SavedScan(id: ScanID(), announcement: "Saved"))
    #expect(harness.preferences.savesCount == 1)
}

@Test func asksOncePerVersion() throws {
    let harness = try Harness()
    harness.save(4, onDay: 1)
    harness.save(3, onDay: 2)
    harness.save(3, onDay: 3)
    harness.rating.asked()
    #expect(!harness.rating.isDue)
    #expect(harness.analytics.events == [.ratingRequested])
    harness.save(1, onDay: 4)
    #expect(!harness.rating.isDue)
    #expect(!harness.relaunched(version: "1.0").isDue)
}

@Test func aNewVersionAsksAfterItsNextSave() throws {
    let harness = try Harness()
    harness.save(4, onDay: 1)
    harness.save(3, onDay: 2)
    harness.save(3, onDay: 3)
    harness.rating.asked()
    let updated = harness.relaunched(version: "1.1")
    #expect(!updated.isDue)
    updated.recordSave(on: CalendarDay(year: 2027, month: 1, day: 4))
    #expect(updated.isDue)
}

/// Only a save makes the prompt due: a scan cancelled after an update (no save) never asks (Plan 6 §6b).
@Test func aCancelledScanNeverMakesItDue() async throws {
    let harness = try Harness()
    harness.save(4, onDay: 1)
    harness.save(3, onDay: 2)
    harness.save(3, onDay: 3)
    harness.rating.asked()
    let updated = harness.relaunched(version: "1.1")
    let flow = ScanFlowModel(
        cameraAccess: FakeCameraAccess(status: .authorized, grantsOnRequest: true),
        clock: .system,
        analytics: harness.analytics,
        suggester: FakeScanSuggester.unavailable(),
        suggestionsOn: { false },
        makeReview: { _ in fatalError("never reviewed") },
        scanSaved: { updated.recordSave(on: CalendarDay(year: 2027, month: 1, day: 4)) }
    )
    await flow.scan(from: .home, preselected: nil)
    flow.cameraCancelled()
    #expect(flow.phase == .idle)
    #expect(!updated.isDue)
}

@Test func dayIsTheCalendarDay() throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
    let late = try #require(calendar.date(from: DateComponents(year: 2027, month: 1, day: 1, hour: 23, minute: 59)))
    let early = late.addingTimeInterval(120)
    let harness = try Harness()
    harness.rating.recordSave(on: CalendarDay(late, in: calendar))
    harness.rating.recordSave(on: CalendarDay(early, in: calendar))
    #expect(harness.preferences.saveDays.count == 2)
}

@Test func keepsTheThreeMostRecentDistinctDays() throws {
    let harness = try Harness()
    for day in [1, 2, 2, 3, 4] { harness.save(1, onDay: day) }
    #expect(harness.preferences.saveDays == [20_270_102, 20_270_103, 20_270_104])
}
