import Core
import Foundation
import Testing

@testable import ScreenModels

@MainActor
@Test func keepsThreeNewestWithoutRepeats() throws {
    let fresh = try FreshDefaults()
    defer { fresh.cleanUp() }
    let history = SearchHistory(defaults: fresh.defaults)
    for search in ["insurance", "wifi", "laptop", "wifi", "bike"] { history.record(search: search) }
    #expect(history.recentSearches == ["bike", "wifi", "laptop"])
    #expect(SearchHistory(defaults: fresh.defaults).recentSearches == ["bike", "wifi", "laptop"])
}

@MainActor
@Test func ignoresCaseForRepeats() throws {
    let fresh = try FreshDefaults()
    defer { fresh.cleanUp() }
    let history = SearchHistory(defaults: fresh.defaults)
    history.record(search: "WiFi")
    history.record(search: "laptop")
    history.record(search: "wifi")
    #expect(history.recentSearches == ["wifi", "laptop"])
}

@MainActor
@Test func trimsAndSkipsEmpty() throws {
    let fresh = try FreshDefaults()
    defer { fresh.cleanUp() }
    let history = SearchHistory(defaults: fresh.defaults)
    history.record(search: "  bike \n")
    history.record(search: "   ")
    history.record(search: "")
    history.record(search: " bike \t  lock ")
    #expect(history.recentSearches == ["bike lock", "bike"])
}

@MainActor
@Test func clearRemovesSearchesOnly() throws {
    let fresh = try FreshDefaults()
    defer { fresh.cleanUp() }
    let history = SearchHistory(defaults: fresh.defaults)
    let id = ScanID()
    history.record(search: "bike")
    history.record(viewed: id)
    history.clearSearches()
    #expect(history.recentSearches.isEmpty)
    #expect(history.recentlyViewed == [id])
    #expect(SearchHistory(defaults: fresh.defaults).recentSearches.isEmpty)
}

@MainActor
@Test func keepsEightViewed() throws {
    let fresh = try FreshDefaults()
    defer { fresh.cleanUp() }
    let history = SearchHistory(defaults: fresh.defaults)
    let ids = (0..<10).map { _ in ScanID() }
    for id in ids { history.record(viewed: id) }
    history.record(viewed: ids[5])
    let expected = [ids[5], ids[9], ids[8], ids[7], ids[6], ids[4], ids[3], ids[2]]
    #expect(history.recentlyViewed == expected)
    #expect(SearchHistory(defaults: fresh.defaults).recentlyViewed == expected)
}
