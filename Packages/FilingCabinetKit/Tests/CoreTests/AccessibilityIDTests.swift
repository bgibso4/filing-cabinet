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
    #expect(AccessibilityID.Home.all.contains(AccessibilityID.Home.cleanupBanner))
}

@Test func cameraIdentifiersArePrefixedAndInAll() {
    #expect(AccessibilityID.Camera.all.allSatisfy { $0.hasPrefix("camera.") })
    #expect(AccessibilityID.CameraOff.all.allSatisfy { $0.hasPrefix("cameraOff.") })
    #expect(Set(AccessibilityID.Camera.all + AccessibilityID.CameraOff.all).isSubset(of: AccessibilityID.all))
}

@Test func reviewIdentifiersArePrefixedAndInAll() {
    #expect(AccessibilityID.Review.all.allSatisfy { $0.hasPrefix("review.") })
    #expect(AccessibilityID.ExpiryDate.all.allSatisfy { $0.hasPrefix("expiryDate.") })
    #expect(Set(AccessibilityID.Review.all + AccessibilityID.ExpiryDate.all).isSubset(of: AccessibilityID.all))
}

@Test func viewerIdentifiersArePrefixedAndBackIsTheSystems() {
    #expect(AccessibilityID.Viewer.back == AccessibilityID.Grid.back)
    #expect(AccessibilityID.Viewer.header.hasPrefix("viewer."))
    #expect(AccessibilityID.Viewer.page.hasPrefix("viewer."))
    #expect(AccessibilityID.Viewer.strip.hasPrefix("viewer."))
    #expect(Set(AccessibilityID.Viewer.all).isSubset(of: AccessibilityID.all))
}

@Test func gridIdentifiersArePrefixedAndTilesAreCheckedByPrefix() {
    #expect(AccessibilityID.Grid.scan.hasPrefix("grid."))
    // The back button is the system's, so its identifier is the system's too.
    #expect(AccessibilityID.Grid.back == "BackButton")
    #expect(Set(AccessibilityID.Grid.all).isSubset(of: AccessibilityID.all))
    let id = ScanID()
    #expect(AccessibilityID.Grid.tile(id).hasPrefix(AccessibilityID.Grid.tilePrefix))
    #expect(AccessibilityID.Grid.tile(id) != AccessibilityID.Grid.tile(ScanID()))
}

@Test func aPillTitleIsNamedAfterItsPillAndClashesWithNothing() {
    let titles = [AccessibilityID.Viewer.header, AccessibilityID.Review.pagePill].map(AccessibilityID.pillTitle)
    #expect(titles == ["viewer.header.title", "review.pagePill.title"])
    #expect(Set(titles).isDisjoint(with: AccessibilityID.all))
}

@Test func trashIdentifiersArePrefixedAndTilesAreCheckedByPrefix() {
    #expect(AccessibilityID.Trash.all.allSatisfy { $0.hasPrefix("trash.") })
    #expect(Set(AccessibilityID.Trash.all).isSubset(of: AccessibilityID.all))
    #expect(AccessibilityID.Home.all.contains(AccessibilityID.Home.trashRow))
    let id = ScanID()
    #expect(AccessibilityID.Trash.tile(id).hasPrefix(AccessibilityID.Trash.tilePrefix))
    #expect(AccessibilityID.Trash.tile(id) != AccessibilityID.Grid.tile(id))
}

@Test func trashViewerIdentifiersArePrefixedAndListed() {
    #expect(AccessibilityID.TrashViewer.all.allSatisfy { $0.hasPrefix("trashViewer.") })
    #expect(Set(AccessibilityID.TrashViewer.all).isSubset(of: AccessibilityID.all))
}

@Test func settingsIdentifiersArePrefixedAndListed() {
    #expect(AccessibilityID.Home.settings == "home.settings")
    #expect(AccessibilityID.Home.all.contains(AccessibilityID.Home.settings))
    #expect(AccessibilityID.Settings.all.allSatisfy { $0.hasPrefix("settings.") })
    #expect(AccessibilityID.Collections.all.allSatisfy { $0.hasPrefix("collections.") })
    #expect(AccessibilityID.CollectionSettings.all.allSatisfy { $0.hasPrefix("collectionSettings.") })
    #expect(AccessibilityID.Collections.row(.receipts) == "collections.receipts")
    let settings =
        AccessibilityID.Settings.all + AccessibilityID.Collections.all + AccessibilityID.CollectionSettings.all
    #expect(Set(settings).isSubset(of: AccessibilityID.all))
}

@Test func searchIdentifiersArePrefixedAndInAll() {
    #expect(AccessibilityID.Search.chip(nil) == "search.chip.all")
    #expect(AccessibilityID.Search.chip(.wallet) == "search.chip.wallet")
    #expect(AccessibilityID.Search.recent(0) == "search.recent.0")
    let search = AccessibilityID.Search.all + [AccessibilityID.Search.clear, AccessibilityID.Search.searchAll]
    #expect(search.allSatisfy { $0.hasPrefix("search.") })
    #expect(Set(search).isSubset(of: AccessibilityID.all))
    #expect(AccessibilityID.Home.all.contains(AccessibilityID.Home.search))
}
