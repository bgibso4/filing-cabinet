import Core
import CoreText
import Foundation
import Library
import Testing

@testable import ScreenModels
@testable import TestSupport

// Plan 3, E3: the bar's title slot on FC iPhone 17 is 314 pt beside the back button alone and 222 pt beside back and
// Select. The title is centred, so its room is what is left between the two sides' widest button: 258 pt and 186 pt.
private let roomBesideBack: CGFloat = 258
// E3's centred room beside back and Select (186 pt) isn't checked: no screen with Select beside back keeps its title
// centred yet. Trash, the only one, may sit off-centre (E7).
// Plan 3, E3 and E7 (Ben, 2026-11-09): Trash may sit off-centre at 100+ scans, never truncated, so its subtexts get the
// whole slot beside back and Select.
private let trashSlotBesideBackAndSelect: CGFloat = 222
// Plan 3, E3: the bar draws the subtitle in SF Pro Regular 12 pt with monospaced digits (Tokens.Typography.caption), at
// the default text size whatever the setting (M7), so one size is the only one to measure.
private let subtitlePointSize: CGFloat = 12
// B13: the longest form of a count is four digits.
private let mostScans = 9_999
private let mostSelected = 999

/// The width Core Text lays the line out at, in the system font (SF Pro) at the subtitle's size.
private func subtitleWidth(_ text: String) throws -> CGFloat {
    let system = try #require(CTFontCreateUIFontForLanguage(.system, subtitlePointSize, nil))
    let descriptor = CTFontDescriptorCreateCopyWithFeature(
        CTFontCopyFontDescriptor(system), kNumberSpacingType as CFNumber, kMonospacedNumbersSelector as CFNumber)
    let font = CTFontCreateWithFontDescriptor(descriptor, subtitlePointSize, nil)
    let attributed = NSAttributedString(
        string: text, attributes: [NSAttributedString.Key(kCTFontAttributeName as String): font])
    let line = CTLineCreateWithAttributedString(attributed)
    return CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
}

/// Each subtext and the room the bar leaves it.
private struct Subtext {
    let screen: String
    let text: String
    let room: CGFloat
}

@MainActor
private func everySubtext() -> [Subtext] {
    let clock = AppClock.fixed(Date(timeIntervalSince1970: 0), calendar: Calendar(identifier: .gregorian))
    let collections = CollectionsModel(library: FakeLibrary(), today: Today(clock: clock), calendar: clock.calendar)
    let besideSelect = [
        Subtext(screen: "Trash", text: TrashModel.countLine(mostScans), room: trashSlotBesideBackAndSelect),
        Subtext(
            screen: "Trash, selecting",
            text: TrashModel.selectedLine(mostSelected),
            room: trashSlotBesideBackAndSelect
        ),
    ]
    let grids = Lifespan.allCases.map { lifespan in
        Subtext(
            screen: "A collection's grid, \(lifespan)",
            text: CollectionText.scanCountAndKept(mostScans, lifespan),
            room: roomBesideBack
        )
    }
    let besideBack = [
        Subtext(screen: "Recent", text: CollectionText.lastThirtyDays, room: roomBesideBack),
        Subtext(screen: "All Scans", text: CollectionText.scanCount(mostScans), room: roomBesideBack),
        Subtext(screen: "Collections", text: collections.subtitle, room: roomBesideBack),
        Subtext(screen: "A collection's settings", text: CollectionText.scanCount(mostScans), room: roomBesideBack),
    ]
    return besideSelect + grids + besideBack
}

/// B13: the small title never drops or cuts its subtext, so every subtext, in its longest form, fits between the bar's
/// buttons.
@MainActor
@Test func everySubtextFitsTheBar() throws {
    for subtext in everySubtext() {
        let width = try subtitleWidth(subtext.text)
        #expect(
            width <= subtext.room,
            "\(subtext.screen): \"\(subtext.text)\" is \(width) pt wide, with \(subtext.room) pt of room")
    }
}

/// The measure itself: a longer line is wider, and digits are monospaced as in the caption token.
@Test func theMeasureGrowsWithTheText() throws {
    let short = try subtitleWidth("No scans")
    let long = try subtitleWidth("No scans · No scans")
    #expect(short > 0)
    #expect(long > short)
    #expect(try subtitleWidth("1111") == subtitleWidth("8888"))
}
