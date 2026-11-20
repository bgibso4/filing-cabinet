#if canImport(UIKit)
    import Core
    import Testing

    @testable import Screens

    @Test func aTappedCleanupNoteAsksForTrash() {
        #expect(CleanupNoteTaps.request(forNoteWithID: ScheduledNotice.idPrefix + "2026-10-12") == .trash)
    }

    @Test func anyOtherNoteAsksForNothing() {
        #expect(CleanupNoteTaps.request(forNoteWithID: "reminder-1") == nil)
    }
#endif
