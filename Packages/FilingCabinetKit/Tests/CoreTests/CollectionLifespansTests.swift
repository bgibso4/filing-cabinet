import Testing

@testable import Core

@Test func defaultsMatchTheRequirements() {
    let lifespans = CollectionLifespans.defaults
    #expect(
        BuiltInCollection.allCases.map { lifespans[$0] } == [.forever, .threeMonths, .forever, .forever, .week])
}

@Test func settingOneCollectionLeavesTheOthers() {
    let changed = CollectionLifespans.defaults.setting(.year, for: .receipts)
    #expect(changed[.receipts] == .year)
    #expect(changed[.wallet] == .forever)
    #expect(changed[.throwaways] == .week)
    #expect(changed != .defaults)
    #expect(changed.setting(.threeMonths, for: .receipts) == .defaults)
}
