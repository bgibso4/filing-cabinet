import Core
import ScreenModels
import Screens
import SwiftUI
import TestSupport
import XCTest

/// Search (08-01…08-08) over the home set, with the mocks' texts, history and queries. Never with the keyboard: the
/// field isn't focused.
final class SearchSnapshotTests: XCTestCase {
    /// Search.dc.html lines 266-270: what each result's text says, and 08-05's one Notes scan that mentions "bike".
    private static let texts: [(title: String, text: String)] = [
        ("Lease 2026", "Harlow Property Management\nRe: Lease renewal · Unit 4B · term beginning January 1, 2027"),
        ("Call with landlord", "Call w/ landlord\nrenewal: sign by Nov 15"),
        ("Car registration", "Certificate of Vehicle Registration\nRenew online before this registration expires."),
        ("Gym membership", "IRONWORKS\nPlan · Renews monthly"),
        ("Library card", "Anytown Public Library\nRenew loans at any branch desk."),
        ("Bio 210 notes", "Bio 210 · Oct 10\nBike to the lab on Tuesday"),
    ]

    /// Search pushed on a stack, as in the app, over the home set with `texts`; `history` filled first.
    @MainActor
    private func search(
        query: String = "",
        filter: BuiltInCollection? = nil,
        history fill: @MainActor (SearchHistory) -> Void = { _ in }
    ) -> some View {
        let library = Fixtures.library(.home)
        for id in Fixtures.homeScans(titled: "Driver’s license") {
            library.updateSearchWords(["ID", "driver license", "identity"], version: 1, for: id)
        }
        for (title, text) in Self.texts {
            for id in Fixtures.homeScans(titled: title) { library.updateSearchText(text, for: id) }
        }
        let history = Fixtures.searchHistory()
        fill(history)
        let model = SearchModel(
            library: library,
            today: Today(clock: Fixtures.clock),
            clock: Fixtures.clock,
            history: history,
            analytics: RecordingAnalytics())
        model.query = query
        model.filter = filter
        return NavigationStack(path: .constant([0])) {
            Color.clear.navigationDestination(for: Int.self) { _ in
                SearchView(
                    model: model,
                    thumbnails: Fixtures.thumbnails,
                    focusesOnArrival: false,
                    onOpen: { _ in },
                    onClose: {})
            }
        }
    }

    /// 08-02: four scans opened lately and three searches, newest first.
    @MainActor
    private static func fillHistory(_ history: SearchHistory) {
        for title in ["Bio 210 notes", "Call with landlord", "Corner Market", "Driver’s license"] {
            for id in Fixtures.homeScans(titled: title) { history.record(viewed: id) }
        }
        for search in ["insurance", "wifi", "laptop"] { history.record(search: search) }
    }

    @MainActor
    func testFirstUse() throws {
        try SnapshotHost.assertScreen(search(), testName: "search_first_use")
    }

    @MainActor
    func testBeforeTyping() throws {
        try SnapshotHost.assertScreen(search(history: Self.fillHistory), testName: "search_before_typing")
    }

    @MainActor
    func testResults() throws {
        try SnapshotHost.assertScreen(search(query: "renew"), testName: "search_results")
    }

    /// The Driver’s license never prints "identity": the model's hidden word finds it, with a sparkle (M8).
    @MainActor
    func testHiddenWordResult() throws {
        try SnapshotHost.assertScreen(search(query: "identity"), testName: "search_hidden_word")
    }

    @MainActor
    func testFiltered() throws {
        try SnapshotHost.assertScreen(search(query: "renew", filter: .wallet), testName: "search_filtered")
    }

    @MainActor
    func testNothingHere() throws {
        try SnapshotHost.assertScreen(search(query: "bike", filter: .wallet), testName: "search_nothing_here")
    }

    @MainActor
    func testNothingAnywhere() throws {
        try SnapshotHost.assertScreen(search(query: "renwal"), testName: "search_nothing_anywhere")
    }
}
