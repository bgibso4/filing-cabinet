import Testing

@testable import Core

@Test func identifiersAreUnique() {
    #expect(Set(AccessibilityID.all).count == AccessibilityID.all.count)
}

@Test func collectionRowsUseTheRawValue() {
    #expect(AccessibilityID.collectionRow(.throwaways) == "home.collection.throwaways")
    #expect(AccessibilityID.all.contains(AccessibilityID.scanButton))
}
