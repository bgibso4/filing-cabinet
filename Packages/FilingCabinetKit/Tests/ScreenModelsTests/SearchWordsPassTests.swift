import Core
import Foundation
import Library
import Synchronization
import TestSupport
import Testing
import Understanding

@testable import ScreenModels

/// Answers each words call only when the test says so, so a test can look between scans. A call the pass gives up
/// on stays waiting, as the real model's might; the bounded call stops waiting for it.
private final class SteppedSuggester: ScanSuggester {
    private let isAvailable: Bool
    private let waiting = Mutex<[CheckedContinuation<[String]?, Never>]>([])
    private let asked = Mutex<[String]>([])

    init(isAvailable: Bool = true) {
        self.isAvailable = isAvailable
    }

    var availability: SuggesterAvailability { isAvailable ? .available : .unavailable }

    /// The title of every scan asked about, in order.
    var titles: [String] { asked.withLock { $0 } }

    func suggestFiling(_ input: SuggestionInput) async -> ScanSuggestion? { nil }

    func suggestWords(_ input: SuggestionInput, title: String, collectionName: String) async -> [String]? {
        asked.withLock { $0.append(title) }
        return await withCheckedContinuation { continuation in waiting.withLock { $0.append(continuation) } }
    }

    func prewarm(collections: [SuggestionCollection]) {}

    /// Answers the oldest call still waiting; nil means the model failed.
    func answer(_ words: [String]?) {
        let next = waiting.withLock { $0.isEmpty ? nil : $0.removeFirst() }
        next?.resume(returning: words)
    }

    /// Ends every call still waiting, so none is left behind when the test ends.
    func finish() {
        for continuation in waiting.withLock({ calls in
            defer { calls = [] }; return calls
        }) {
            continuation.resume(returning: nil)
        }
    }
}

/// A pass over a library of `titles` scans (the first newest), all in Documents on Oct 12, 2026, none read yet.
@MainActor
private struct PassHarness {
    static let words = ["letter", "document"]

    let library: FakeLibrary
    let suggester: SteppedSuggester
    let preferences: AppPreferences
    let pass: SearchWordsPass
    let ids: [ScanID]
    private let fresh: FreshDefaults

    init(_ titles: [String], isAvailable: Bool = true, isBusy: @escaping () -> Bool = { false }) throws {
        fresh = try FreshDefaults()
        let noon = Date(timeIntervalSince1970: 1_791_806_400)
        let scans = titles.enumerated().map { index, title in
            ScanSummary(
                id: ScanID(),
                title: title,
                collection: .documents,
                scannedAt: noon.addingTimeInterval(-Double(index) * 3600),
                expiryOverride: nil,
                pageCount: 1)
        }
        ids = scans.map(\.id)
        library = FakeLibrary(scans: scans)
        suggester = SteppedSuggester(isAvailable: isAvailable)
        preferences = AppPreferences(defaults: fresh.defaults)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        pass = SearchWordsPass(
            library: library,
            today: Today(clock: .fixed(noon, calendar: calendar)),
            suggester: suggester,
            preferences: preferences,
            isBusy: isBusy,
            callLimit: .seconds(30),
            busyRecheck: .milliseconds(10))
    }

    /// Waits until the model has been asked about `count` scans in all.
    func asked(_ count: Int) async -> Bool {
        await ReviewHarness.eventually { suggester.titles.count == count }
    }

    func needing() -> [ScanID] { library.scansNeedingWords(version: ScanSuggestion.promptVersion) }

    func cleanUp() {
        pass.pause()
        suggester.finish()
        fresh.cleanUp()
    }
}

@Test(.timeLimit(.minutes(1)))
func readsNewestFirstAndWritesOnlyWords() async throws {
    let harness = try PassHarness(["Lease", "Letter", "Note"])
    defer { harness.cleanUp() }
    let before = harness.library.scans

    harness.pass.resume()
    for count in 1...3 {
        #expect(await harness.asked(count))
        harness.suggester.answer(PassHarness.words)
    }

    #expect(await ReviewHarness.eventually { harness.needing().isEmpty })
    #expect(harness.suggester.titles == ["Lease", "Letter", "Note"])
    #expect(harness.library.searchWords()[harness.ids[0]] == PassHarness.words)
    #expect(harness.library.scans == before, "titles and collections are left alone")
}

@Test(.timeLimit(.minutes(1)))
func resumesAfterPause() async throws {
    let harness = try PassHarness(["Lease", "Letter"])
    defer { harness.cleanUp() }

    harness.pass.resume()
    #expect(await harness.asked(1))
    harness.pass.pause()
    #expect(harness.pass.progress == nil)
    harness.suggester.answer(PassHarness.words)  // too late: the pass has let go of this call
    #expect(harness.needing() == harness.ids)

    harness.pass.resume()
    #expect(await harness.asked(2))
    harness.suggester.answer(PassHarness.words)
    #expect(await ReviewHarness.eventually { harness.needing() == [harness.ids[1]] })
    // Lease again, from the start; then the pass moves on to Letter.
    #expect(harness.suggester.titles.prefix(2) == ["Lease", "Lease"])
}

@Test(.timeLimit(.minutes(1)))
func skipsDeletedScans() async throws {
    let harness = try PassHarness(["Lease", "Letter", "Note"])
    defer { harness.cleanUp() }

    harness.pass.resume()
    #expect(await harness.asked(1))
    try await harness.library.deleteNow([harness.ids[1]])
    harness.suggester.answer(PassHarness.words)

    #expect(await harness.asked(2))
    #expect(harness.suggester.titles == ["Lease", "Note"])
}

@Test(.timeLimit(.minutes(1)))
func skipsTrashedScans() async throws {
    let harness = try PassHarness(["Lease", "Letter", "Note"])
    defer { harness.cleanUp() }

    harness.pass.resume()
    #expect(await harness.asked(1))
    try harness.library.moveToTrash([harness.ids[1]])
    harness.suggester.answer(PassHarness.words)

    #expect(await harness.asked(2))
    #expect(harness.suggester.titles == ["Lease", "Note"])
}

@Test(.timeLimit(.minutes(1)))
func passStopsWhenSwitchedOff() async throws {
    let harness = try PassHarness(["Lease", "Letter"])
    defer { harness.cleanUp() }

    harness.pass.resume()
    #expect(await harness.asked(1))
    harness.preferences.appleIntelligenceOn = false
    harness.suggester.answer(PassHarness.words)

    #expect(await ReviewHarness.eventually { harness.pass.progress == nil })
    #expect(harness.suggester.titles == ["Lease"])
    harness.pass.resume()
    #expect(harness.pass.progress == nil)
    #expect(harness.suggester.titles == ["Lease"])
}

@Test(.timeLimit(.minutes(1)))
func doesNothingWhenUnavailable() async throws {
    let harness = try PassHarness(["Lease"], isAvailable: false)
    defer { harness.cleanUp() }

    harness.pass.resume()
    await Task.yield()

    #expect(harness.pass.progress == nil)
    #expect(harness.suggester.titles.isEmpty)
}

@Test(.timeLimit(.minutes(1)))
func failedReadIsRetriedNextResume() async throws {
    let harness = try PassHarness(["Lease", "Letter"])
    defer { harness.cleanUp() }

    harness.pass.resume()
    #expect(await harness.asked(1))
    harness.suggester.answer(nil)
    // Skipped for this run, not asked again straight away.
    #expect(await harness.asked(2))
    harness.suggester.answer(PassHarness.words)
    #expect(await ReviewHarness.eventually { harness.pass.progress == nil })
    #expect(harness.suggester.titles == ["Lease", "Letter"])
    #expect(harness.needing() == [harness.ids[0]])

    harness.pass.resume()
    #expect(await harness.asked(3))
    harness.suggester.answer(PassHarness.words)
    #expect(await ReviewHarness.eventually { harness.needing().isEmpty })
    #expect(harness.suggester.titles == ["Lease", "Letter", "Lease"])
}

@Test(.timeLimit(.minutes(1)))
func progressCountsDown() async throws {
    let harness = try PassHarness(["Lease", "Letter", "Note"])
    defer { harness.cleanUp() }
    // One scan already has words, so it counts as read from the start.
    harness.library.updateSearchWords(PassHarness.words, version: ScanSuggestion.promptVersion, for: harness.ids[2])
    #expect(harness.pass.progress == nil)

    harness.pass.resume()
    #expect(await harness.asked(1))
    #expect(harness.pass.progress == SearchWordsPass.Progress(done: 1, total: 3))
    harness.suggester.answer(PassHarness.words)
    #expect(await harness.asked(2))
    #expect(harness.pass.progress == SearchWordsPass.Progress(done: 2, total: 3))
    harness.suggester.answer(PassHarness.words)

    #expect(await ReviewHarness.eventually { harness.pass.progress == nil })
}

@Test(.timeLimit(.minutes(1)))
func waitsWhileAScanIsUnderWay() async throws {
    let busy = Mutex(true)
    let harness = try PassHarness(["Lease"], isBusy: { busy.withLock { $0 } })
    defer { harness.cleanUp() }

    harness.pass.resume()
    try await Task.sleep(for: .milliseconds(50))
    #expect(harness.suggester.titles.isEmpty)

    busy.withLock { $0 = false }
    #expect(await harness.asked(1))
}

/// Launch or coming back awaits other work before `resume()`; if the app left meanwhile, the pass stays stopped (M9).
@Test(.timeLimit(.minutes(1)))
func resumeOutsideTheForegroundDoesNothing() async throws {
    let harness = try PassHarness(["Lease"])
    defer { harness.cleanUp() }

    harness.pass.leftForeground()
    harness.pass.resume()
    try await Task.sleep(for: .milliseconds(50))
    #expect(harness.suggester.titles.isEmpty)
    #expect(harness.pass.progress == nil)

    harness.pass.enteredForeground()
    harness.pass.resume()
    #expect(await harness.asked(1))
}

@Test(.timeLimit(.minutes(1)))
func leavingTheForegroundStopsReading() async throws {
    let harness = try PassHarness(["Lease", "Letter"])
    defer { harness.cleanUp() }

    harness.pass.resume()
    #expect(await harness.asked(1))
    harness.pass.leftForeground()
    harness.suggester.answer(PassHarness.words)

    #expect(harness.pass.progress == nil)
    try await Task.sleep(for: .milliseconds(50))
    #expect(harness.suggester.titles == ["Lease"])
    #expect(harness.needing() == harness.ids)
}
