import Core
import Testing

@testable import ScreenModels

@Test func gridRoutesNameTheirGrid() {
    #expect(AppRoute.collection(.wallet).gridKind == .collection(.wallet))
    #expect(AppRoute.recent.gridKind == .recent)
    #expect(AppRoute.all.gridKind == .all)
    #expect(AppRoute.favorites.gridKind == .favorites)
}

@Test func otherRoutesAreNoGrid() {
    let id = ScanID()
    let others: [AppRoute] = [
        .trash, .scan(id), .trashedScan(id), .settings, .collections, .collectionSettings(.notes), .search,
    ]
    #expect(others.allSatisfy { $0.gridKind == nil })
}
