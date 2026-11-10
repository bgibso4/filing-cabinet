import Core
import Testing

@testable import ScreenModels

// Where a drag in Favorites puts the tiles it moves (M8).

private let ids = (0..<5).map { _ in ScanID() }
private let (one, two, three, four, five) = (ids[0], ids[1], ids[2], ids[3], ids[4])

@Test func moveOneForward() {
    #expect(FavoriteReorder.order([one, two, three, four], moving: [three], before: one) == [three, one, two, four])
}

@Test func moveOneToEnd() {
    #expect(FavoriteReorder.order([one, two, three, four], moving: [one], before: nil) == [two, three, four, one])
}

@Test func moveSeveralKeepsTheirOrder() {
    // Listed out of order, they still land in the order the grid shows them.
    let order = FavoriteReorder.order([one, two, three, four, five], moving: [four, two], before: one)
    #expect(order == [two, four, one, three, five])
}

@Test func moveOntoItselfChangesNothing() {
    #expect(FavoriteReorder.order([one, two, three, four], moving: [two], before: two) == [one, two, three, four])
    #expect(FavoriteReorder.order([one, two, three, four], moving: [two], before: three) == [one, two, three, four])
    #expect(FavoriteReorder.order([one, two, three, four], moving: [], before: one) == [one, two, three, four])
}

@Test func unknownIDsAreIgnored() {
    #expect(FavoriteReorder.order([one, two, three], moving: [five, three], before: four) == [one, two, three])
    #expect(FavoriteReorder.order([one, two, three], moving: [three], before: five) == [one, two, three])
}
