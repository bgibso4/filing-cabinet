import Core
import Testing

@testable import ScreenModels

@Test func selectingTicksAndUnticks() {
    let first = ScanID()
    let second = ScanID()
    var selection = ScanSelection()
    selection.toggle(first)
    #expect(selection.selected(among: [first]).isEmpty, "ticked outside select mode")
    selection.toggleSelecting()
    #expect(selection.isSelecting)
    selection.toggle(first)
    selection.toggle(second)
    #expect(selection.selected(among: [first, second]) == [first, second])
    selection.toggle(second)
    #expect(selection.selected(among: [first, second]) == [first])
}

@Test func onlyScansStillShownCountAsSelected() {
    let staying = ScanID()
    let leaving = ScanID()
    var selection = ScanSelection()
    selection.toggleSelecting()
    selection.toggle(staying)
    selection.toggle(leaving)
    #expect(selection.selected(among: [staying]) == [staying])
}

@Test func leavingOrFinishingForgetsTheTicks() {
    let id = ScanID()
    var selection = ScanSelection()
    selection.toggleSelecting()
    selection.toggle(id)
    selection.toggleSelecting()
    #expect(!selection.isSelecting)
    selection.toggleSelecting()
    #expect(selection.selected(among: [id]).isEmpty)
    selection.toggle(id)
    selection.finish()
    #expect(!selection.isSelecting)
    #expect(selection.selected(among: [id]).isEmpty)
}

@Test func theSelectedLineCounts() {
    #expect(ScanSelection.selectedLine(0) == "0 selected")
    #expect(ScanSelection.selectedLine(2) == "2 selected")
}
