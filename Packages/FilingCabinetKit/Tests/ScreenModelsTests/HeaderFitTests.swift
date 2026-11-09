import Core
import CoreText
import Foundation
import Library
import Testing

@testable import ScreenModels
@testable import TestSupport

// Plan 3, E3: the bar's title slot on FC iPhone 17 is 314 pt beside the back button alone. The title is centred, so its
// room is what is left between the two sides' widest button: 258 pt.
private let roomBesideBack: CGFloat = 258
// Plan 3, E8 (from E3's 222 pt slot, measured in the Trash snapshots): beside back and Select, the bar keeps the title
// centred up to 176 pt of subtext ("7 scans · Deleted after 30 days", 176.4 pt, stayed centred; 184 pt didn't).
private let centredRoomBesideBackAndSelect: CGFloat = 176
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

/// A library holding `mostScans` documents, scanned on the clock's day, with `lifespan` for Documents.
@MainActor
private func fullLibrary(_ lifespan: Lifespan, clock: AppClock) throws -> FakeLibrary {
    let scans = (0..<mostScans).map { index in
        ScanSummary(
            id: ScanID(),
            title: "Scan \(index)",
            collection: .documents,
            scannedAt: clock.now(),
            expiryOverride: nil,
            pageCount: 1
        )
    }
    let library = FakeLibrary(scans: scans, clock: clock)
    try library.setLifespan(lifespan, for: .documents)
    return library
}

@MainActor
private func everySubtext() throws -> [Subtext] {
    let clock = AppClock.fixed(Date(timeIntervalSince1970: 0), calendar: Calendar(identifier: .gregorian))
    let today = Today(clock: clock)
    let collections = CollectionsModel(library: FakeLibrary(), today: today, calendar: clock.calendar)
    let besideSelect = [
        Subtext(screen: "Trash", text: TrashModel.countLine(mostScans), room: centredRoomBesideBackAndSelect),
        Subtext(
            screen: "Trash, selecting",
            text: TrashModel.selectedLine(mostSelected),
            room: centredRoomBesideBackAndSelect
        ),
    ]
    let grids = try Lifespan.allCases.map { lifespan in
        let grid = CollectionGridModel(
            kind: .collection(.documents),
            library: try fullLibrary(lifespan, clock: clock),
            today: today,
            calendar: clock.calendar
        )
        return Subtext(screen: "Documents' grid, \(lifespan)", text: grid.subtitle, room: roomBesideBack)
    }
    let allScans = CollectionGridModel(
        kind: .all, library: try fullLibrary(.forever, clock: clock), today: today, calendar: clock.calendar)
    let settings = CollectionSettingsModel(
        collection: .documents,
        library: try fullLibrary(.forever, clock: clock),
        today: today,
        calendar: clock.calendar,
        analytics: RecordingAnalytics()
    )
    let recent = CollectionGridModel(kind: .recent, library: FakeLibrary(), today: today, calendar: clock.calendar)
    let besideBack = [
        Subtext(screen: "Recent", text: recent.subtitle, room: roomBesideBack),
        Subtext(screen: "All Scans", text: allScans.subtitle, room: roomBesideBack),
        Subtext(screen: "Collections", text: collections.subtitle, room: roomBesideBack),
        Subtext(screen: "A collection's settings", text: settings.countLine, room: roomBesideBack),
    ]
    return besideSelect + grids + besideBack
}

/// B13: the small title never drops or cuts its subtext, so every subtext, in its longest form, fits between the bar's
/// buttons.
@MainActor
@Test func everySubtextFitsTheBar() throws {
    let subtexts = try everySubtext()
    // Built through the models: a grid of 9,999 reads its 4-digit count.
    #expect(subtexts.contains { $0.text.contains("9,999") })
    for subtext in subtexts {
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
