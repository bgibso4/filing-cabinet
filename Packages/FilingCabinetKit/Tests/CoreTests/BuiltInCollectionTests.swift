import Testing

@testable import Core

@Test func builtInsAreInDisplayOrder() {
    #expect(BuiltInCollection.allCases.map(\.rawValue) == ["wallet", "receipts", "notes", "documents", "throwaways"])
}

@Test func lifespansMatchTheRequirements() {
    #expect(BuiltInCollection.allCases.map(\.lifespan) == [.forever, .threeMonths, .forever, .forever, .week])
}
