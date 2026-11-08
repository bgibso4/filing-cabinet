import Testing

@testable import Core

@Test func builtInsAreInDisplayOrder() {
    #expect(BuiltInCollection.allCases.map(\.rawValue) == ["wallet", "receipts", "notes", "documents", "throwaways"])
}

@Test func lifespanDays() {
    #expect(Lifespan.allCases.map(\.days) == [7, 30, 90, 365, nil])
}
