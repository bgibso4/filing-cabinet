import Core
import Foundation
import Library
import TestSupport
import Testing
import Understanding

@testable import ScreenModels

/// Settings' Apple Intelligence row over a library of `unread` scans the model hasn't read, on Oct 12, 2026.
@MainActor
private struct IntelligenceHarness {
    let preferences: AppPreferences
    let defaults: UserDefaults
    let pass: SearchWordsPass
    let model: SettingsModel
    private let fresh: FreshDefaults

    init(_ suggester: FakeScanSuggester, unread: Int = 0) throws {
        fresh = try FreshDefaults()
        let noon = Date(timeIntervalSince1970: 1_791_806_400)
        let library = FakeLibrary(
            scans: (0..<unread).map { index in
                ScanSummary(
                    id: ScanID(),
                    title: "Letter \(index)",
                    collection: .documents,
                    scannedAt: noon.addingTimeInterval(-Double(index) * 3600),
                    expiryOverride: nil,
                    pageCount: 1)
            })
        defaults = fresh.defaults
        preferences = AppPreferences(defaults: fresh.defaults)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        pass = SearchWordsPass(
            library: library,
            today: Today(clock: .fixed(noon, calendar: calendar)),
            suggester: suggester,
            preferences: preferences,
            isBusy: { false })
        model = SettingsModel(
            preferences: preferences,
            notifications: FakeNotificationCenter(authorization: .authorized),
            suggester: suggester,
            wordsPass: pass,
            version: "1.0")
    }

    func cleanUp() {
        pass.pause()
        fresh.cleanUp()
    }
}

private let privacyLine = "Runs on this iPhone. Your scans never leave it."

@Test func onByDefaultWhenAvailable() throws {
    let harness = try IntelligenceHarness(FakeScanSuggester(filing: .fails))
    defer { harness.cleanUp() }
    let row = harness.model.intelligence
    #expect(row.isAvailable)
    #expect(row.isOn)
    #expect(row.subtitle == "Names, files and finds your scans")
    #expect(row.footer == privacyLine)
    #expect(row.progress == nil)
}

@Test func unavailableIsOffAndDisabled() throws {
    let harness = try IntelligenceHarness(FakeScanSuggester.unavailable())
    defer { harness.cleanUp() }
    let row = harness.model.intelligence
    #expect(!row.isAvailable)
    #expect(!row.isOn)
    #expect(row.subtitle == "Names, files and finds your scans")
    #expect(
        row.footer
            == "Apple Intelligence isn’t available on this iPhone. Titles come from the text, and you choose each collection."
    )
    // The person's wish is kept for when the model arrives.
    #expect(harness.preferences.appleIntelligenceOn)
}

@Test(.timeLimit(.minutes(1)))
func footerShowsProgressWhileReading() async throws {
    let harness = try IntelligenceHarness(FakeScanSuggester(filing: .fails, words: .never), unread: 4)
    defer { harness.cleanUp() }

    harness.pass.resume()

    #expect(await ReviewHarness.eventually { harness.model.intelligence.progress != nil })
    #expect(
        harness.model.intelligence.footer == "Reading your older scans so search can find them · 0\u{00A0}of\u{00A0}4")
    #expect(harness.model.intelligence.progress == 0)
}

@Test(.timeLimit(.minutes(1)))
func switchingOffPersists() async throws {
    let harness = try IntelligenceHarness(FakeScanSuggester(filing: .fails, words: .never), unread: 2)
    defer { harness.cleanUp() }
    harness.pass.resume()
    #expect(await ReviewHarness.eventually { harness.model.intelligence.progress != nil })

    harness.model.setIntelligence(false)

    #expect(!harness.model.intelligence.isOn)
    #expect(harness.model.intelligence.footer == privacyLine, "the reading stops")
    #expect(harness.pass.progress == nil)
    #expect(!AppPreferences(defaults: harness.defaults).appleIntelligenceOn)

    harness.model.setIntelligence(true)
    #expect(harness.model.intelligence.isOn)
    #expect(await ReviewHarness.eventually { harness.pass.progress != nil }, "back on, it reads again")
}
