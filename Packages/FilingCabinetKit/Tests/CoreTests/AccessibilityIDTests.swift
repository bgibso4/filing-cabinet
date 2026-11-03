import Testing

@testable import Core

@Test func everyScreensIdentifiersAreUniqueAndPrefixed() {
    #expect(AccessibilityID.Home.all.allSatisfy { $0.hasPrefix("home.") })
    #expect(Set(AccessibilityID.all).count == AccessibilityID.all.count)
}

@Test func collectionRowsUseTheRawValue() {
    #expect(AccessibilityID.Home.collectionRow(.throwaways) == "home.collection.throwaways")
    #expect(AccessibilityID.Home.all.contains(AccessibilityID.Home.scan))
    #expect(AccessibilityID.Home.all.contains(AccessibilityID.Home.recentRow))
    #expect(AccessibilityID.Home.all.contains(AccessibilityID.Home.allRow))
}
