# Plan 2 · Editing and self-cleaning Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Change a scan's title, collection and expiry from a Details sheet; move scans to Trash and get them back; let expired scans move to Trash on their own, worked out from dates, with a morning note; and set each collection's lifespan in Settings › Collections.

**Architecture:** One new pure rule in `Core`, `Lifecycle`, says where a scan is on any day (library, Trash, gone) from its dates alone, so nothing a person sees depends on a background job. `Library` gains a versioned SwiftData schema (V1 → V2: a stored Trash day and per-collection lifespans) and the edits and Trash operations on `ScanStore`, which also freezes Trash membership whenever a rule changes. `ScreenModels` gets one model per new screen (Details, Trash, Settings, Collections, Collection) plus a pure notification planner; `Screens` gets the views, and a `UserNotifications` adapter beside the camera one. Everything stays behind the seams Plan 1 built (`ScanLibrary`, `AppClock`, `Today`, `Analytics`), plus one new seam for notifications.

**Tech Stack:** Swift 6, SwiftUI, Observation, SwiftData (`VersionedSchema`, `SchemaMigrationPlan`), UserNotifications, os (`Logger`, `OSSignposter`), Swift Testing, XCTest (UI), swift-snapshot-testing 1.19.7.

**Spec:** `docs/superpowers/specs/2026-10-10-filing-cabinet-requirements.html` (what: section 02 Expiry and Cleanup, stories 7, 8, 10–13, section 06 "Viewing and changing a scan", "Trash", "Collections and settings", "Notifications", "Time left", Accessibility, Haptics), `docs/superpowers/specs/2026-10-31-engineering-foundations-design.md` (how), `design/` (screens 02-04, 02-07, 06-04, 07-*, 09-*, 10-*, 11-01…04, 12-04, 12-05; components `ScanDetails`, `ScanView`, `Trash`, `Settings2`, `Notify`, `Home`). Executors read all three, and Plan 1 (`docs/superpowers/plans/2026-11-02-01-scan-to-library.md`) for the conventions this plan continues.

**Status:** Approved by Ben on 2026-11-07, with every recommendation in "Questions for Ben" accepted as drafted. Execution: subagent-driven. Not started.

---

## Questions for Ben

Each has my recommendation, and the plan is drafted as if he accepts it (marked **my call** in the Decisions table). Most important first. The same list is in `.superpowers/for-ben.md`.

1. **Trash membership freezes when a rule changes (M1).** Trash is worked out from dates, so without care, lengthening Receipts from 3 months to 1 year would pull last month's expired receipts back out of Trash, and shortening it would drop old receipts into Trash with only a day or two left of their 30. **Recommend:** when a lifespan or a scan's collection changes, every scan already in Trash stays there (its entry day is stored), and every scan the change sends to Trash enters it today, with a full 30 days. This is what the mocks' copy promises ("will go to Trash now. You can restore them for 30 days").
2. **Settings arrives in Plan 2, not Plan 5 (M2).** Settings › Collections needs a way in. **Recommend:** Home's gear opens the Settings list from 10-01 with only the rows that work today: Collections and Notifications, plus the footer. The Apple Intelligence row comes with Plan 3, Send feedback with Plan 5.
3. **Asking for notification permission before Plan 5's welcome (M3).** The designed ask is on the second first-launch screen (Plan 5). **Recommend:** until then, turning the Notifications switch on in Settings asks iOS. The switch starts off until iOS has said yes.
4. **When the Home banner shows (M4).** Story 11 says "with notifications off, Home shows a one-time banner after scans move"; section 06 says "after a cleanup" without the condition. **Recommend:** only when notifications are off or blocked; it clears when you tap View or leave the app.
5. **Collection nouns in copy (M5).** The mocks say "This receipt moves to Trash", "Cleaned up 3 receipts", "Keep receipts 1 month?". **Recommend:** card / cards (Wallet), receipt, note, document, throwaway, and "scan / scans" when collections are mixed.
6. **What a restore or delete from the Trash viewer does next (M6).** **Recommend:** Restore and Delete now both close the scan and land back on Trash.
7. **Home when every scan is in Trash (M7).** Plan 1 shows the first-launch rows when nothing is visible, which would hide the Trash row. **Recommend:** the views card still shows, with only the Trash row.
8. **#40, the "library couldn't be opened" screen.** Plan 2 adds the first schema migration, which is what makes #40 likely. It needs a design. **Recommend:** keep it out of Plan 2; Task 1 proves V1 → V2 on a real V1 store file instead.

---

## Decisions

### Agreed with Ben

| # | Decision | Where it lands |
|---|---|---|
| A1 | **Scope (Plan 1's roadmap):** Details sheet, Move to Trash, Trash, the dates-based cleanup, Settings › Collections, cleanup notifications. | whole plan |
| A2 | **Plan 1's decisions stand**, including its A2 (controls for later plans stay hidden), A7–A10 (expiry maths), M5's "Today" refresh and B10 (dark header pill). | all |
| A3 | **#55 comes first:** the schema is wrapped as `SchemaV1` with a migration plan before Plan 2's fields (Plan 1 final review). | Task 1 |

### My calls (not discussed; veto any before its task starts)

| # | Call | Task |
|---|---|---|
| M1 | **Trash freezes on rule changes** (question 1). A scan's Trash entry day is `trashedDay` when stored, otherwise the day after its last day. Before a lifespan or collection change, every scan already in Trash gets its entry day stored; every scan the change expires gets `trashedDay = today`. | 3, 4 |
| M2 | **Settings root in Plan 2** with Collections and Notifications rows and the footer only (question 2). | 11, 12 |
| M3 | **The Notifications switch asks iOS** the first time it's turned on; when iOS has blocked it, the switch is off, the note reads "Turned off in iPhone Settings" and tapping it opens the app's page in iPhone Settings (question 3). | 13, 14 |
| M4 | **The banner shows only with notifications off or blocked** and counts scans that expired on their own since it was last cleared. It clears on View or when the app goes to the background. First launch after updating starts the count at today (question 4). | 14 |
| M5 | **Collection nouns:** card/cards, receipt/receipts, note/notes, document/documents, throwaway/throwaways; "scan/scans" for mixed or unknown (question 5). | 5, 7, 11, 13 |
| M6 | **Trash viewer:** Restore and Delete now close the scan back to Trash (question 6). | 10 |
| M7 | **All scans in Trash:** Home keeps its first-launch collection rows but shows the views card with only Trash (question 7). | 9 |
| M8 | **Trash lasts 30 days counting the entry day:** a scan that enters Trash on Oct 19 shows "30 days left" that day and is gone from Oct 18 + 30 = Nov 18. Trash always shows days, orange in its last 7. Soonest-deleted first. | 2, 8 |
| M9 | **A natural expiry's note fires at 9:00 local on the day the scan enters Trash** (the mocks show 9:00), one per day, for the next 64 such days. Only natural expiries notify: a scan you moved, or a settings change sent, gets no note. | 13 |
| M10 | **Restore sets the expiry to Forever** (`.lifespan(.forever)`) and clears `trashedDay`; the collection is unchanged. | 3 |
| M11 | **Delete removes the record first, then the files.** A kill in between leaves files without a record, which Plan 1's launch orphan cleanup already removes. | 3 |
| M12 | **Collection lifespans are stored in the SwiftData store** (one `CollectionRecord` per changed collection), not `UserDefaults`, so they live and sync with the scans they govern. A collection without a record uses its built-in default. | 1, 4 |
| M13 | **The header pill opens Details** (#44). The Info button in the bottom bar does too. | 6 |
| M14 | **The bottom bar shows Details and Trash only:** Share and Favorite are Plan 4 (A2). The Info button sits alone in the centre glass pill. The More button stays hidden. | 6, 7 |
| M15 | **Details' expiry menu is Review's list** (the collection default, then all five lifespans), with any choice whose date has passed greyed and labelled "Oct 8 · passed". The mock 07-06 leaves out the choice equal to the default; one shared list is simpler and Review already ships it. | 5 |
| M16 | **A cleared title in Details** keeps the previous title. | 5 |
| M17 | **After a collection move,** the sheet shows "Expiry now follows Documents." with Undo (07-05); when the scan keeps its own expiry, "Keeps its own expiry." with Undo. Undo lasts until the sheet closes or the next edit. | 5 |
| M18 | **An edit that fails to save** rolls back and shows one alert, "Couldn’t save this change" / "Something went wrong. Try again." with OK. Not designed; database writes this small should almost never fail. | 5, 8, 11 |
| M19 | **Move to Trash from the viewer** pops back to where you opened the scan, with a warning haptic before the confirmation and the VoiceOver announcement "Moved to Trash". Restore announces "Restored to Throwaways" (or "Restored 2 scans"); Delete announces "Deleted" (or "Deleted 2 scans"). | 7, 9, 10 |
| M20 | **No background task:** purging and file removal run at launch and when the app becomes active. The requirements allow "when the app next opens or gets background time". | 14 |
| M21 | **Edits run on the main context** and are synchronous (`throws(LibraryError)`), like Plan 1's `updateSearchText`; only `deleteNow`, `emptyTrash` and `purgeTrash` are `async`, for file removal. | 3, 4 |
| M22 | **`-Notifications <state>`** (Debug only; `authorized`, `denied` or `notDetermined`) swaps in a fake notification centre, so UI tests reach every switch state. **`-SeedTrash <n>`** seeds `n` scans already in Trash, moved by you on staggered days. | 9, 14 |
| M23 | **#56 (GridRoute) and #52 (one fetch for orphan cleanup) are folded in**: Trash reuses the grid route, and the purge pass sits next to orphan cleanup. | 1, 9 |
| M24 | **Select mode with nothing selected** reads "0 selected" and shows "Delete" and "Restore" disabled. | 9 |
| M25 | **Notification lists join without an Oxford comma** ("City Pharmacy, Bluebird Café and Corner Market"), as the mocks write them, so they don't use `ListFormatter` (en_US adds the comma). | 13 |

### Decided during execution

From the execution ledger. B rows are Ben's; E rows are my calls (executor).

| # | Decision | Whose | Task |
|---|---|---|---|
| B1 | **Details audit exemption:** `textClipped` on `details.titleText` and `details.scannedLine` only (iOS 27 floating-sheet false positive), dated 2026-11-08. | Ben | 6 |
| B2 | **R4 kept:** a plan-`public` declaration stays `package` until a task's app or test code first uses it. | Ben | all |
| B3 | **Glass contrast:** CI on Xcode 27.2 decides; a local-only Xcode 27.1 failure changes nothing. | Ben | 9, 10 |
| B4 | **Custom black-and-white switch** per 10-01 / 10-07 (dark knob in dark mode); the system switch is unusable in dark mode. | Ben | 12 |
| B5 | **Deeper red for destructive text on light glass** (new token). Superseded by B6: the audit still failed at 5.89:1. | Ben | 9, 10 |
| B6 | **Trash's delete buttons follow Photos:** Empty Trash, Delete N and Delete now are neutral glass buttons; each confirmation comes up from the tapped button with the red action inside; the grid and page run under the bar. Departs from 09-01 / 09-02 / 09-04. | Ben | 9, 10 |
| B7 | **Trash audit exemptions, tracked in #59:** contrast on `trash.emptyTrash`, `trash.deleteSelected` and `trashViewer.deleteNow`, and element-less contrast only while the Trash screen shows; standing call: exempt to unblock as long as it is tracked; revisit on newer Xcode. | Ben | 9, 10 |
| E1 | Undo of a collection move counts as a `.scanEdited(.collection)` edit. | my call (executor) | 5 |
| E2 | Details' red journeys stay parked until Ben rules on the exemption (test tolerances need his OK). | my call (executor) | 6 |
| E3 | No warning haptic on Details' "Move to Throwaways?" alert: M19 names it only for Move to Trash from the viewer. | my call (executor) | 6, 7 |
| E4 | Task 9 commits with its Trash audits on, parked red for Ben, rather than adding an unapproved exemption. | my call (executor) | 9 |
| E5 | `BrowseJourneyTests.testViewerAuditInDarkMode` is not a Plan 2 regression: it fails on `main` with local Xcode 27.1 and passes on CI's 27.2. | my call (executor) | 9 |
| E6 | In the Trash viewer the header pill doesn't open Details: a trashed scan is read-only until restored. | my call (executor) | 10 |
| E7 | Task 10's Minors 1–4 fixed at once: the Restore haptic sat on chrome that left in the same update, so it never played. | my call (executor) | 10 |
| E8 | Under `-UITest`, `AppPreferences` uses a volatile defaults suite, so UI tests never read or leak real preferences. | my call (executor) | 12 |
| E9 | Task 12's journey shortens Receipts, not Throwaways: with `-SeedScans 12` the only old Throwaway is already in Trash (M1). | my call (executor) | 12 |
| E10 | At accessibility sizes a Settings row puts its value or switch on its own line, so names don't break mid-word. | my call (executor) | 12 |
| E11 | Ben's decisions (switch, red, the CI-only Trash viewer failure) go to one fix job after Task 13. | my call (executor) | 12, 13 |
| E12 | Task 13's Minors 1, 2, 4 and 5 fixed (a repeated `Lifecycle` boundary; notes now fire on non-Gregorian calendars). | my call (executor) | 13 |
| E13 | Trash redesign fix round: the long-press Delete now proven, stale confirmations, VoiceOver anchoring; the Trash viewer's page stops above the bar at rest, as in Photos. | my call (executor) | 9, 10 |
| E14 | `trash.select` joins the named Trash glass exemption (same misread, same screen) and #59. | my call (executor) | 9 |
| E15 | Task 14's Minors 1, 4, 5 and 6 fixed: notes re-plan on a time-zone change and today refreshes before the first frame back. | my call (executor) | 14 |
| E16 | Pre-flight R2: Task 12, not 13 and 14, creates `SystemNotificationCenter` and the `-Notifications` flag, since its screen and UI test need both. No behaviour change. | my call (executor) | 12, 13, 14 |
| E17 | Pre-flight R3: `-SeedTrash` seeds through a `package` `ScanStore.moveToTrash(_:on:)`, which the public `moveToTrash` calls with today, so the `ScanLibrary` seam stays as planned. | my call (executor) | 9 |
| E18 | Pre-flight R4: M1 covers `setExpiry` too, not only `move` and `setLifespan`. An expiry change that expires a library scan stores today as its Trash day (full 30 days); a scan already in Trash keeps its entry day. One shared rule serves all three edits. | my call (executor) | 3, 4, 5 |
| E19 | Any Trash action (Restore, Delete) ends select mode. | my call (executor) | 8 |
| E20 | Empty Trash acts on what is in Trash when it runs, not on the ids captured at confirm time; a confirmation whose scans have all left Trash shows nothing. | my call (executor) | 8 |

### Expected differences from the mocks

- Hidden controls for later plans (Plan 1 A2): Search, Favorites, Share, Favorite, More, the Apple Intelligence row, Send feedback, favourite hearts on Trash tiles.
- The receipt mocks (07-02, 07-07) show Jul 19 → "Oct 17". By Plan 1's A10 (scan day is day 1, 90 days) it is **Oct 16**. Fixtures use our maths.
- 07-06's expiry list omits Forever when it is the default (M15).

---

## Roadmap

| Plan | What you can do when it's merged |
|---|---|
| 0 · Foundation (done) | The loop. |
| 1 · Scan to library (done) | Scan, review, save, browse Home → collection → scan. |
| **2 · Editing and self-cleaning (this plan)** | Details, Move to Trash, Trash, dates-based cleanup with notes and the banner, Settings › Collections. |
| 3 · Apple Intelligence | The suggestion card, shimmer and fallback, the Settings switch, an evaluation suite. |
| 4 · Favorites, search, share | Favorites (and their hearts in Trash), search, sort, share and export, the More menu. |
| 5 · First launch and system | Welcome and the notifications ask, Send feedback, the Scan control, Shortcuts, Spotlight, rating prompt, app icon. |

---

## Global Constraints

- Plan 1's Global Constraints all still apply (copied in `.superpowers/sdd/2026-11-02-01-scan-to-library/global-constraints.md`; the executor copies them into Plan 2's folder). The lines below add to them.
- iOS 27.0 minimum, iPhone, portrait, English. Swift 6, Approachable Concurrency. Banned: `Task.detached`, `@unchecked Sendable`, disabling concurrency checking.
- Full-size image decodes never run on Swift's cooperative pool: anything new that shows a page uses `PageImageLoader` (its `ImageDecodeQueue`), never `CGImageSourceCreateImageAtIndex` directly (Plan 1's CI deadlock).
- SwiftData: a default on every property, no `@Attribute(.unique)`, no relationships, every schema change a new `VersionedSchema` with a migration stage. All writes through the main `ModelContext`; records never leave `ScanStore`.
- Everything about where a scan is (library, Trash, gone) comes from `Lifecycle` (Task 2). No other code compares expiry or Trash dates.
- A collection's lifespan always comes from `CollectionLifespans` (Task 2); `BuiltInCollection.defaultLifespan` is read only by `CollectionLifespans`.
- Copy is copied exactly from the components named in each task; middots, never em dashes; curly apostrophes as the components write them (’).
- Analytics events carry only `.int`, `.bool` and `.token`. A notification's text (titles) never goes into analytics or logs; log notification counts and days only.
- Alerts, confirmation dialogs, context menus, the keyboard and notifications are never snapshotted; their journeys attach `XCTAttachment(screenshot:)` and the agent opens it.
- Every simulator run uses `SIM_DEVICE="FC iPhone 17"`. While fixing, run only the affected tests; a task finishes on `make fast`, `make build`, `make lint`, `make unused` and the snapshot and UI tests for the screens it touched. One local `make full` before the PR; CI runs Full on each push.
- UI tests (after test-speed's PR #43): call `launchApp` as usual; name each largest-text audit test `testAuditAtLargestText…` (e.g. `testAuditAtLargestTextDetails`); pass `fresh: true` only when a cold process is the point of the test.
- Timebox: about 45 minutes per fix round; if a round fails, revert to the last green commit and report. UI tests are the slow layer (issue #42): prove logic in Fast, looks in snapshots, and only flows in UI tests.

## Review Focus

1. **A lifespan change or collection move while scans sit in Trash, or one that expires old scans.** Lengthening must not pull anything out of Trash; shortening must give each newly expired scan a full 30 days from today. Tests: Task 3 `movingToAShorterCollectionTrashesTodayWithThirtyDays`; Task 4 `lengtheningKeepsTrashedScansInTrash`, `shorteningSendsOldScansToTrashToday`.
2. **Midnight passes while a scan is open in Details or the viewer, or selected in Trash.** The viewer and its sheet close when the scan leaves; a selection drops scans that are gone; Trash's days tick down. Tests: Task 5 `detailsCloseWhenTheScanExpires`; Task 8 `selectionDropsScansThatLeaveTrash`.
3. **More than 64 days with expiries, and a scan renamed, moved or restored after its note was scheduled.** Only the next 64 days are scheduled; every change replaces every pending note, so no note names a scan by an old title or mentions one no longer leaving. Tests: Task 13 `onlyTheNext64DaysAreScheduled`, `renamedScanIsNamedByItsNewTitle`, `manualTrashAndRestoredScansAreNotAnnounced`; Task 14 `libraryChangeReschedules`.
4. **The app is killed in the middle of deleting, or a page file can't be removed.** The record goes first; leftover files are orphans launch cleanup removes; no scan is ever left half there. Tests: Task 3 `deleteNowRemovesRecordThenFiles`, `fileRemovalFailureLeavesNoRecord`; Task 1 `orphanCleanupFetchesOnce`.
5. **An existing Plan 1 library on the phone opening under the new schema.** Every scan, title, override and page must survive V1 → V2. Test: Task 1 `v1StoreOpensAsV2WithEveryScan` on a store file written by the V1 schema.

---

## File Structure

### Module dependencies

Unchanged from Plan 1 (see AGENTS.md). No new module.

### Files

```
Packages/FilingCabinetKit/Sources/
  Core/
    Collections/BuiltInCollection.swift   modify: lifespan → defaultLifespan; noun(_:) lives in ScreenModels
    Collections/CollectionLifespans.swift create
    Collections/Lifespan.swift            modify: AnalyticsToken
    Lifecycle/ScanPlace.swift, Lifecycle.swift create
    Notifications/NotificationAuthorization.swift, CleanupNotifying.swift, ScheduledNotice.swift create
    Analytics/AnalyticsEvent.swift, AnalyticsKey.swift, EditEventTokens.swift  modify/create
    Accessibility/AccessibilityID.swift   modify: Details, Trash, TrashViewer, Settings, Collections, Collection
    Launch/LaunchOptions.swift            modify: -Notifications, -SeedTrash
  Library/
    Records/SchemaV1.swift, SchemaV2.swift, LibraryMigrationPlan.swift create; ScanRecord.swift moves into them
    Records/CollectionRecord.swift        create (inside SchemaV2)
    Records/ScanSummary.swift             modify: trashedDay
    Store/ScanLibrary.swift, ScanStore.swift modify: edits, Trash, lifespans, purge
  ScreenModels/
    Shared/LibraryShelf.swift             modify: lifespans, Trash, TrashItem
    Shared/CollectionText.swift           modify: nouns, kept/older-than phrases
    Shared/ExpiryChoices.swift            create (moved out of ReviewModel)
    Details/DetailsModel.swift, MovedNote.swift, EditAlert.swift  create
    Trash/TrashModel.swift, TrashTile.swift, TrashConfirmation.swift create
    Settings/SettingsModel.swift, CollectionsModel.swift, CollectionSettingsModel.swift, AppPreferences.swift create
    Cleanup/CleanupNotices.swift, CleanupNotifier.swift, CleanupBanner.swift create
    Viewer/ViewerModel.swift              modify: Trash mode, actions
    Home/HomeModel.swift, HomeViewRow.swift modify: Trash row, banner
    App/AppRoute.swift                    modify: trash, settings, collections, collectionSettings(_)
  Screens/
    Details/DetailsSheet.swift, DetailsTitleEditor.swift, DetailsRows.swift create
    Viewer/ViewerView.swift, ViewerBottomBar.swift, TrashViewerChrome.swift modify/create
    Trash/TrashView.swift, TrashTileView.swift, TrashEmptyView.swift create
    Settings/SettingsView.swift, CollectionsView.swift, CollectionSettingsView.swift create
    Notifications/SystemNotificationCenter.swift create
    Grid/GridRoute.swift                  create (#56)
    Home/HomeView.swift, HomeViewRowView.swift modify: gear, banner, Trash row
    Root/RootView.swift, RootDependencies.swift modify
  TestSupport/ FakeLibrary.swift (modify), FakeNotificationCenter.swift, LibrarySeed.swift (modify: seedTrash)
Packages/FilingCabinetKit/Tests/
  CoreTests/ LifecycleTests, CollectionLifespansTests, LaunchOptionsTests, AnalyticsEventTests
  LibraryTests/ MigrationTests (+ Fixtures/LibraryV1.store*), ScanStoreEditTests, ScanStoreTrashTests, ScanStoreLifespanTests
  ScreenModelsTests/ LibraryShelfTests, ExpiryChoicesTests, DetailsModelTests, TrashModelTests, SettingsModelTests,
                     CollectionSettingsModelTests, CleanupNoticesTests, CleanupNotifierTests, CleanupBannerTests,
                     HomeModelTests, ViewerModelTests
SnapshotTests/  DetailsSnapshotTests, TrashSnapshotTests, SettingsSnapshotTests, HomeSnapshotTests, ViewerSnapshotTests, Fixtures
UITests/        DetailsJourneyTests, TrashJourneyTests, SettingsJourneyTests, CleanupJourneyTests
App/            AppEnvironment.swift, FilingCabinetApp.swift
```

---

## Tasks

### Task 1: Versioned schema (#55), V2 fields and one-fetch orphan cleanup (#52)

**Unit:** Library

**Files:**
- Create: `Sources/Library/Records/SchemaV1.swift`, `SchemaV2.swift`, `CollectionRecord.swift`, `LibraryMigrationPlan.swift`; `Tests/LibraryTests/MigrationTests.swift`; `Tests/LibraryTests/Fixtures/LibraryV1.store` (+ `-shm`, `-wal` if present)
- Modify: `Sources/Library/Records/ScanRecord.swift` (becomes `SchemaV2.ScanRecord`, a typealias keeps call sites), `Sources/Library/Records/ScanSummary.swift`, `Sources/Library/Store/ScanStore.swift` (`makeContainer`, `removeOrphanedFiles`), `Package.swift` (test resources)
- Test: `Tests/LibraryTests/MigrationTests.swift`, `Tests/LibraryTests/ScanStoreTests.swift`

**Interfaces:**
- Produces:
  - `enum SchemaV1: VersionedSchema` (version 1.0.0) holding today's `ScanRecord` exactly as on `plan-1`.
  - `enum SchemaV2: VersionedSchema` (2.0.0): `ScanRecord` plus `trashedDay: Int? = nil` (`CalendarDay.storageValue`), and `@Model final class CollectionRecord { var collectionKey: String = ""; var lifespanKey: String = "" }`.
  - `enum LibraryMigrationPlan: SchemaMigrationPlan` with one `.lightweight(fromVersion: SchemaV1.self, toVersion: SchemaV2.self)` stage.
  - `ScanStore.makeContainer(storeURL:)` builds from `SchemaV2` with `migrationPlan: LibraryMigrationPlan.self`.
  - `ScanSummary` gains `package let trashedDay: CalendarDay?` (init parameter with default `nil`, so fixtures keep compiling).
  - `removeOrphanedFiles()` fetches every `scanID` once into a `Set<UUID>` (#52), then removes folders not in it and not in flight.

- [ ] **Step 1: Make the V1 fixture.** On `plan-1`'s schema (before any edit), write a throwaway test (not committed) that saves 3 scans into a store at a temp URL: a receipt with no override, a Wallet card with `.lastDay(Mar 3, 2027)`, a note with `.lifespan(.year)`, searchText set. Copy the store files into `Tests/LibraryTests/Fixtures/`. Synthetic titles only.
- [ ] **Step 2: Write the failing tests:** `v1StoreOpensAsV2WithEveryScan` (copy the fixture to a temp dir, open with `makeContainer`; 3 summaries with the same titles, collections, overrides, `trashedDay == nil`); `newStoreIsV2` (insert a `CollectionRecord`, reopen, read it back); `orphanCleanupFetchesOnce` (100 folders, 99 orphans; a counting `persist`-style hook or a fetch counter shows one fetch; the real scan survives).
- [ ] **Step 3: Run `make fast`.** Expected: FAIL to compile.
- [ ] **Step 4: Implement** the schemas, the plan and the one-fetch cleanup. Keep `ScanRecord`'s field names and defaults byte for byte in V1.
- [ ] **Step 5: Run `make fast`.** Expected: PASS, with every existing `ScanStoreTests` test still green.
- [ ] **Step 6: Commit** `Library: SchemaV1 and V2 with a migration plan (#55); orphan cleanup fetches once (#52)`. Close #52 and #55 in the PR body.

### Task 2: Lifecycle and collection lifespans

**Unit:** Core

**Files:**
- Create: `Sources/Core/Lifecycle/ScanPlace.swift`, `Lifecycle.swift`, `Sources/Core/Collections/CollectionLifespans.swift`
- Modify: `Sources/Core/Collections/BuiltInCollection.swift` (`lifespan` → `defaultLifespan`; update every caller to go through `CollectionLifespans`), `Sources/Core/Collections/Lifespan.swift` (`AnalyticsToken`)
- Test: `Tests/CoreTests/LifecycleTests.swift`, `Tests/CoreTests/CollectionLifespansTests.swift`

**Interfaces:**
- Produces (`public` where fixtures or the app build them):
  - `public struct CollectionLifespans: Sendable, Hashable` with `public static let defaults`, `public subscript(_ collection: BuiltInCollection) -> Lifespan`, `public func setting(_ lifespan: Lifespan, for collection: BuiltInCollection) -> CollectionLifespans`.
  - `package enum ScanPlace: Sendable, Hashable { case library(TimeLeft); case trash(daysLeft: Int, entered: CalendarDay); case gone }`.
  - `package enum Lifecycle`:
    - `static let trashDays = 30`
    - `static func entryDay(lastDay: CalendarDay?, trashedDay: CalendarDay?, in calendar: Calendar) -> CalendarDay?`: `trashedDay`, else `lastDay + 1`, else nil (forever and never trashed).
    - `static func place(lastDay: CalendarDay?, trashedDay: CalendarDay?, today: CalendarDay, in calendar: Calendar) -> ScanPlace`. In the library while `today < entryDay` (with `TimeLeft.on(today, lastDay:)`); in Trash from the entry day through `entry + 29`, `daysLeft = (entry + 29) − today + 1`; gone after.
    - `static func isTrashSoon(daysLeft: Int) -> Bool` (`daysLeft <= 7`).

- [ ] **Step 1: Write the failing tests** (`Calendar(identifier: .gregorian)`, New York; reuse `NewYorkCalendar.swift`):
  - `throwawayEntersTrashTheDayAfterItsLastDay`: scanned Oct 12, last day Oct 18; Oct 18 → `.library(.days(1))`; Oct 19 → `.trash(daysLeft: 30, entered: Oct 19)`.
  - `trashLastsThirtyDaysCountingTheEntryDay`: entered Oct 19; Nov 17 → `daysLeft: 1`; Nov 18 → `.gone`.
  - `storedTrashDayWins`: forever scan with `trashedDay` Oct 20; Oct 19 → library `.forever`; Oct 20 → trash 30.
  - `foreverNeverEntersTrashOnItsOwn`.
  - `trashAcrossDaylightSavingCountsCalendarDays`: entered Oct 30 2026; Nov 3 → 26.
  - `trashSoonIsTheLastSeven`.
  - `defaultsMatchTheRequirements`: Wallet forever, Receipts 3 months, Notes forever, Documents forever, Throwaways 1 week.
  - `settingOneCollectionLeavesTheOthers`.
- [ ] **Step 2: Run `make fast`.** Expected: FAIL to compile.
- [ ] **Step 3: Implement.** Replace each `collection.lifespan` read (LibraryShelf, ReviewModel, ExpiryText, HomeModel, CollectionText users) with a `CollectionLifespans` value: pass `.defaults` for now; Task 4 makes the library supply it.
- [ ] **Step 4: Run `make fast`.** Expected: PASS; every Plan 1 test unchanged.
- [ ] **Step 5: Commit** `Core: Lifecycle (library, Trash, gone from dates) and CollectionLifespans`.

### Task 3: Store edits and Trash operations

**Unit:** Library

**Files:**
- Modify: `Sources/Library/Store/ScanLibrary.swift`, `ScanStore.swift`, `Sources/Library/Store/LibraryError.swift` (only if a case is missing), `Sources/TestSupport/FakeLibrary.swift`, `App/AppEnvironment.swift` (pass the clock)
- Test: `Tests/LibraryTests/ScanStoreEditTests.swift`, `Tests/LibraryTests/ScanStoreTrashTests.swift`, `Tests/LibraryTests/FakeLibraryTests.swift`

**Interfaces:**
- Consumes: `Lifecycle`, `CollectionLifespans`, `SchemaV2`.
- Produces: `ScanLibrary` gains (all `@MainActor`, M21):
  - `var lifespans: CollectionLifespans { get }` (Task 4 makes it editable)
  - `func rename(_ id: ScanID, to title: String) throws(LibraryError)`
  - `func move(_ id: ScanID, to collection: BuiltInCollection) throws(LibraryError)`: keeps the override; if the new last day is before today, sets `trashedDay = today` (M1).
  - `func setExpiry(_ override: ExpiryOverride?, for id: ScanID) throws(LibraryError)`
  - `func moveToTrash(_ ids: [ScanID]) throws(LibraryError)`: `trashedDay = today`.
  - `func restore(_ ids: [ScanID]) throws(LibraryError)`: `trashedDay = nil`, override `.lifespan(.forever)` (M10).
  - `func deleteNow(_ ids: [ScanID]) async throws(LibraryError)`: deletes records and persists, then removes files (M11).
  - `ScanStore.init` gains `clock: AppClock` (today = `CalendarDay(clock.now(), in: clock.calendar)`); every write persists, rolls back on failure and throws `.writeFailed`; `scans` reloads after each.
  - `FakeLibrary` implements every method with the same rules (Liskov), plus `failNextEdit: LibraryError?`.

- [ ] **Step 1: Write the failing tests** (in-memory store, fixed clock Oct 12 2026):
  - `renameChangesOnlyTheTitle`
  - `moveKeepsACustomExpiry`
  - `moveFollowsTheNewDefault`: receipt → Documents: override nil, `Lifecycle.place` is `.library(.forever)`.
  - `movingToAShorterCollectionTrashesTodayWithThirtyDays` (Review Focus 1): a receipt scanned Jul 19 moved to Throwaways: `trashedDay == Oct 12`, place `.trash(daysLeft: 30, …)`.
  - `setExpiryStoresTheOverride`
  - `moveToTrashStampsToday`; `restoreKeepsForeverAndClearsTrash`
  - `deleteNowRemovesRecordThenFiles` (Review Focus 4): a recording `FileSystem` sees the record gone before `removeItem` runs.
  - `fileRemovalFailureLeavesNoRecord`: a `FileSystem` whose `removeItem` throws; the record is gone, files remain, and `removeOrphanedFiles()` removes them.
  - `failedPersistRollsBack`: `persist` throws on rename; title unchanged; throws `.writeFailed`.
  - `FakeLibraryTests.fakeFollowsTheSameTrashRules`: the moved-to-Throwaways case above on the fake.
- [ ] **Step 2: Run `make fast`.** Expected: FAIL.
- [ ] **Step 3: Implement.** Log scan IDs and counts (public), titles private.
- [ ] **Step 4: Run `make fast`.** Expected: PASS.
- [ ] **Step 5: Commit** `Library: rename, move, expiry, Move to Trash, Restore, Delete now`.

### Task 4: Collection lifespans in the store and the purge pass

**Unit:** Library

**Files:**
- Modify: `Sources/Library/Store/ScanLibrary.swift`, `ScanStore.swift`, `Sources/TestSupport/FakeLibrary.swift`
- Test: `Tests/LibraryTests/ScanStoreLifespanTests.swift`, `Tests/LibraryTests/ScanStoreTrashTests.swift`

**Interfaces:**
- Produces:
  - `func setLifespan(_ lifespan: Lifespan, for collection: BuiltInCollection) throws(LibraryError)`: in one persist, (1) stores `trashedDay = entry day` for every scan in Trash without one, (2) writes or updates the `CollectionRecord`, (3) sets `trashedDay = today` for every scan on the collection default whose new last day is before today (M1).
  - `func scansExpiring(ifLifespan lifespan: Lifespan, for collection: BuiltInCollection) -> Int`: how many in-library scans step (3) would send to Trash (the "18 receipts" count).
  - `func emptyTrash() async throws(LibraryError) -> Int`
  - `public func purgeTrash() async -> Int`: deletes every `.gone` scan (record, then files); returns the count. The app runs it after `removeOrphanedFiles()` at launch and on becoming active (Task 14).
  - `lifespans` loads from `CollectionRecord`s at init and after `setLifespan`.

- [ ] **Step 1: Write the failing tests:**
  - `lengtheningKeepsTrashedScansInTrash` (Review Focus 1): a Throwaway expired Oct 10 (in Trash, no `trashedDay`); set Throwaways to 1 year; it is still `.trash` with its original entry day.
  - `shorteningSendsOldScansToTrashToday`: receipts scanned 40 and 10 days ago; Receipts → 1 month; the 40-day one is in Trash with 30 days left, the 10-day one isn't.
  - `shorteningSkipsCustomExpiries`
  - `countMatchesWhatShorteningDoes`
  - `lifespansSurviveReopening` (on-disk store)
  - `purgeDeletesOnlyGoneScans`; `emptyTrashDeletesEveryTrashedScan`
- [ ] **Step 2: Run `make fast`.** Expected: FAIL.
- [ ] **Step 3: Implement**, inside the `"Lifespan change"` and `"Purge"` signposts. FakeLibrary mirrors it.
- [ ] **Step 4: Run `make fast`.** Expected: PASS.
- [ ] **Step 5: Commit** `Library: collection lifespans with frozen Trash, purge and Empty Trash`.

### Task 5: Details model

**Unit:** ScreenModels (07-01 … 07-07)

**Files:**
- Create: `Sources/ScreenModels/Shared/ExpiryChoices.swift`, `Sources/ScreenModels/Details/DetailsModel.swift`, `MovedNote.swift`, `EditAlert.swift`
- Modify: `Sources/ScreenModels/Review/ReviewModel.swift` (uses `ExpiryChoices`), `Sources/ScreenModels/Shared/CollectionText.swift` (nouns, M5), `Sources/ScreenModels/Shared/LibraryShelf.swift` (lifespans, Trash), `Sources/ScreenModels/Localizable.xcstrings`
- Test: `Tests/ScreenModelsTests/ExpiryChoicesTests.swift`, `DetailsModelTests.swift`, `LibraryShelfTests.swift`, `ReviewModelTests.swift` (unchanged expectations)

**Interfaces:**
- Consumes: `ScanLibrary` edits (Task 3), `Today`, `AppClock`, `CollectionText`, `ExpiryText`.
- Produces:
  - `struct ExpiryChoices` (internal) with `static func options(collection:, override:, scanDay:, today:, lifespans:, clock:) -> [ExpiryOption]`. `ExpiryOption` gains `isPassed: Bool`; a passed option's detail is "Oct 8 · passed". Review's options are unchanged (its scan day is today, so nothing passes).
  - `LibraryShelf.init(scans:lifespans:today:calendar:)`: `visible` is `.library` scans only; new `trash: [ScanSummary]`, soonest-gone first, and `trashDaysLeft(_:) -> Int`.
  - `CollectionText.noun(_ collection: BuiltInCollection, count: Int) -> String` and `CollectionText.scansNoun(count:)` (M5).
  - `@MainActor @Observable public final class DetailsModel` with `public init(id: ScanID, library: any ScanLibrary, today: Today, clock: AppClock, analytics: any Analytics)`:
    - read: `title`, `scannedLine` ("Scanned Oct 1, 2026 · 3 pages"; always with the year, as 07-01), `collection`, `collectionName`, `expiryValue` ("Kept forever", "Oct 16 · 5 days left"), `isExpirySoon`, `collectionOptions`, `expiryOptions`, `isMissing`.
    - edit: `rename(_ text: String)` (blank keeps the old title, M16), `choose(_ collection:)`, `undoMove()`, `chooseExpiry(_ override: ExpiryOverride?)`, `chooseExpiryDate(_ date: Date)`.
    - `choose` that would send the scan to Trash sets `pendingTrashMove: TrashMoveAlert?` instead of moving; `confirmTrashMove()` / `cancelTrashMove()`.
    - `TrashMoveAlert { title: "Move to Throwaways?"; message: "Throwaways are kept 1 week from the scan date. This receipt is from Jul 19, so it goes to Trash now. You can restore it for 30 days." }`, built from the collection name, its `kept` phrase, the noun and the scan date.
    - `movedNote: MovedNote?` (M17): `.follows(collectionName)` → "Expiry now follows Documents."; `.keepsOwn` → "Keeps its own expiry.".
    - `editAlert: EditAlert?` (M18).
    - Analytics: `.scanEdited(field: .title | .collection | .expiry)`.

- [ ] **Step 1: Write the failing tests** (`FakeLibrary`, clock Oct 12 2026):
  - `ExpiryChoicesTests.passedChoicesAreGreyed`: lease scanned Oct 1 → "1 week" detail "Oct 7 · passed", `isPassed`; "1 month" "Oct 30".
  - `LibraryShelfTests.trashIsSoonestGoneFirstAndNotVisible`; `lifespansComeFromTheLibrary`.
  - `receiptReadsItsExpiryInOrange`: Jul 19 receipt → "Oct 16 · 5 days left", soon.
  - `leaseReadsKeptForever`; `scannedLineHasYearAndPages`.
  - `renameTrimsAndBlankKeepsTitle`
  - `moveToDocumentsFollowsAndCanUndo`: note `.follows("Documents")`; `undoMove()` puts it back in Receipts and clears the note.
  - `moveWithCustomExpiryKeepsIt`: note `.keepsOwn`.
  - `moveThatWouldTrashAsksFirst`: exact alert copy above; nothing changes until `confirmTrashMove()`; then the scan is in Trash and `isMissing`.
  - `detailsCloseWhenTheScanExpires` (Review Focus 2): advance `Today` past the last day; `isMissing`.
  - `passedExpiryCannotBeChosen`; `dateBeforeTodayIsRefused`.
  - `failedEditShowsTheAlert`: `failNextEdit`; `editAlert` set; title unchanged.
  - `editsSendAnalytics`
- [ ] **Step 2: Run `make fast`.** Expected: FAIL.
- [ ] **Step 3: Implement.** Move Review's option building into `ExpiryChoices` without changing its output.
- [ ] **Step 4: Run `make fast`.** Expected: PASS, Review tests unchanged.
- [ ] **Step 5: Commit** `ScreenModels: Details model, shared expiry choices, collection nouns`.

### Task 6: The Details sheet and the viewer's bottom bar

**Unit:** Screen · Details (07-01, 07-02, 07-03, 07-05, 07-08, 12-04), Viewer (06-02)

**Files:**
- Create: `Sources/Screens/Details/DetailsSheet.swift`, `DetailsTitleEditor.swift`, `DetailsRows.swift`, `Sources/Screens/Viewer/ViewerBottomBar.swift`
- Modify: `Sources/Screens/Viewer/ViewerView.swift`, `ViewerRoute.swift`, `Sources/Screens/Root/RootDependencies.swift` (`makeDetails`), `Sources/Core/Accessibility/AccessibilityID.swift`, `App/AppEnvironment.swift`
- Test: `SnapshotTests/DetailsSnapshotTests.swift`, `SnapshotTests/ViewerSnapshotTests.swift`, `UITests/DetailsJourneyTests.swift`

**Interfaces:**
- Consumes: `DetailsModel`, Plan 1's `CollectionMenu`, `ExpiryMenu`, `ExpiryDateSheet`, `CollectionBadge`, `GlassCircleButton`, `MenuButton`.
- Produces:
  - `DetailsSheet(model:)`: a sheet sized to its content (`.presentationDetents([.height(measured)])`, grabber visible). Rows per `ScanDetails.dc.html` lines 37–141: serif title 24/30 bold with a pencil (taps into `DetailsTitleEditor`), the scanned line 13/18 secondary, a 20-radius well with the Collection row (31 pt badge, "Collection" 13/17 over the name 17/22, up-down chevron) and the Expiry row (hourglass, value in `expirySoon` semibold when soon), the moved note row with Undo. Largest text puts each label above its value (12-04).
  - `DetailsTitleEditor`: "Title" label, a 50 pt field with a clear button, the hint "Suggested from the scan’s text. Search finds it by title and text."; Return or dismissing commits.
  - The viewer: the header pill becomes a button opening Details (M13), hidden while the sheet is up (07-01); the page area shrinks above the sheet (via `PageAxisInsets`). `ViewerBottomBar`: a centre glass pill with the Info button (52 pt, `info.circle`) and a 56 pt glass Trash button at the trailing edge (ScanView.dc.html lines 263–268). Trash does nothing until Task 7.
  - `AccessibilityID.Details { sheet, title, titleField, collection, expiry, undo }`, `AccessibilityID.Viewer` gains `details`, `trash`. The pill's label is "\(title), details".

- [ ] **Step 1: Snapshots** `details_lease` (07-01), `details_receipt` (07-02, Oct 16), `details_moved` (07-05), `details_rename` (07-03, field focused state without the keyboard), each light, dark (07-08 for the receipt) and ax5 (12-04). Record, run, open `make compare` for each against its mock and list the paths. Expected differences: hidden More (A2), Oct 16 (A10).
- [ ] **Step 2: Viewer snapshot** `viewer_receipt` re-recorded with the bottom bar (06-02 minus Share and Favorite). Name the changed reference and why.
- [ ] **Step 3: UI test** `DetailsJourneyTests.testRenameMoveUndoAndExpiry` (`-UITest -SeedScans 12 -FixedDate 2026-10-12 -FakeReader`): open a Receipts scan → tap the pill → rename → choose Documents → see the note → Undo → choose "1 year" → close. `assertIdentifiers(AccessibilityID.Details.all)`; audit default size, and one `testAuditAtLargestTextDetails`. Attach a screenshot of the expiry menu and open it.
- [ ] **Step 4: Run** the Details and Viewer snapshot tests and both journeys (`-only-testing`). Expected: PASS.
- [ ] **Step 5: Commit** `Details: the sheet, rename, collection move with Undo, expiry; header pill opens it (#44)`, naming each reference.

### Task 7: Move to Trash from the viewer, and moving into Trash from Details

**Unit:** Screen · Viewer (06-04), Details (07-07)

**Files:**
- Modify: `Sources/ScreenModels/Viewer/ViewerModel.swift`, `Sources/Screens/Viewer/ViewerView.swift`, `ViewerBottomBar.swift`, `Sources/Screens/Details/DetailsSheet.swift`, `Sources/Core/Analytics/AnalyticsEvent.swift`, `EditEventTokens.swift`
- Test: `Tests/ScreenModelsTests/ViewerModelTests.swift`, `Tests/CoreTests/AnalyticsEventTests.swift`, `UITests/DetailsJourneyTests.swift`

**Interfaces:**
- Produces:
  - `ViewerModel.trashMessage` ("This receipt moves to Trash. You can restore it for 30 days.", noun per M5) and `moveToTrash() -> Bool` (false on failure, with `editAlert`).
  - `AnalyticsEvent.scanMovedToTrash(collection:)`, `.scanEdited(field: EditedField)`.
  - The Trash button: warning haptic, then a `.confirmationDialog` anchored to it (iOS 27 shows it as the popover in 06-04) with the message and one "Move to Trash" button. Confirming moves, announces "Moved to Trash" (M19) and pops.
  - Details' trash-move alert: a centred `.alert` "Move to Throwaways?" with Cancel / Move (07-07). Move closes the sheet and pops the viewer, with the same announcement.

- [ ] **Step 1: Write the failing tests:** `trashMessageUsesTheNoun` (receipt → "This receipt…", lease → "This document…"); `moveToTrashLeavesTheViewer` (`isMissing` after); `analyticsForTrashCarriesCollection`.
- [ ] **Step 2: Run `make fast`.** Expected: FAIL. Implement; expect PASS.
- [ ] **Step 3: UI test** `testMoveToTrashFromTheViewer`: open a scan, Trash, confirm; back on the grid, one fewer tile. `testMovingToThrowawaysAsksFirst`: an old receipt (seed index ≥ 7) → Details → Throwaways → alert → Move → back on the grid. Attach and open screenshots of the popover and the alert.
- [ ] **Step 4: Run** the affected UI tests. Expected: PASS.
- [ ] **Step 5: Commit** `Viewer: Move to Trash asks first; a move that expires a scan asks first`.

### Task 8: Trash model

**Unit:** ScreenModels (09-01 … 09-11)

**Files:**
- Create: `Sources/ScreenModels/Trash/TrashModel.swift`, `TrashTile.swift`, `TrashConfirmation.swift`
- Modify: `Sources/Core/Analytics/AnalyticsEvent.swift`, `Localizable.xcstrings`
- Test: `Tests/ScreenModelsTests/TrashModelTests.swift`

**Interfaces:**
- Consumes: `LibraryShelf.trash`, `ScanLibrary.restore / deleteNow / emptyTrash`.
- Produces: `@MainActor @Observable public final class TrashModel` with `public init(library:today:clock:analytics:)`:
  - `tiles: [TrashTile]` (`id`, `title`, `collection`, `daysLeftText` "2 days left", `isSoon`), soonest first.
  - `subtitle`: "7 scans · each is deleted after 30 days here" ("1 scan · …"); in select mode "2 selected" (M24); empty → nil.
  - `isEmpty`; `isSelecting`; `selected: Set<ScanID>`; `toggleSelecting()`, `toggle(_ id:)`; `deleteTitle` "Delete 2" / "Delete"; `restoreTitle` "Restore 2" / "Restore"; `canAct`.
  - `restoreLine(for:)`: "To Throwaways, kept forever" (09-03).
  - `restore(_ ids:)` → announcement text (M19); `confirmDelete(_ ids:)` and `confirmEmpty()` set `confirmation: TrashConfirmation?` with exact copy: one → "Delete permanently?" / "Coat check will be deleted. This can’t be undone." / "Delete"; several → "Delete 2 scans permanently?" / "They’ll be deleted. This can’t be undone." / "Delete"; empty → "Empty Trash?" / "Deletes 7 scans permanently. This can’t be undone." / "Empty Trash". `performConfirmation() async`.
  - Analytics: `.scansRestored(count:)`, `.scansDeleted(count:)`, `.trashEmptied(count:)`.

- [ ] **Step 1: Write the failing tests:** `tilesAreSoonestFirstWithDaysLeft`; `subtitleCountsScans`; `selectingTwoReadsDelete2AndRestore2`; `nothingSelectedDisablesActions`; `confirmationCopyForOneSeveralAndEmpty`; `restoreNeedsNoConfirmation`; `selectionDropsScansThatLeaveTrash` (Review Focus 2: advance `Today` past one scan's 30 days; it leaves `selected`); `emptyTrashDeletesAll`; `analyticsCounts`.
- [ ] **Step 2: Run `make fast`.** Expected: FAIL. Implement; expect PASS.
- [ ] **Step 3: Commit** `ScreenModels: Trash model with select, confirmations and restore`.

### Task 9: Trash screen, Home's Trash row and the grid route (#56)

**Unit:** Screen · Trash (09-01, 09-02, 09-03, 09-09, 09-10, 09-11), Home (02-05 views card)

**Files:**
- Create: `Sources/Screens/Trash/TrashView.swift`, `TrashTileView.swift`, `TrashEmptyView.swift`, `Sources/Screens/Grid/GridRoute.swift`, `Sources/TestSupport/` seed additions
- Modify: `Sources/ScreenModels/App/AppRoute.swift` (`.trash`), `Sources/ScreenModels/Home/HomeModel.swift`, `HomeViewRow.swift`, `Sources/Screens/Home/HomeViewRowView.swift`, `Sources/Screens/Root/RootView.swift`, `RootDependencies.swift`, `Sources/Core/Launch/LaunchOptions.swift` (`-SeedTrash`), `Sources/TestSupport/LibrarySeed.swift`, `Sources/Core/Accessibility/AccessibilityID.swift`, `App/AppEnvironment.swift`
- Test: `Tests/ScreenModelsTests/HomeModelTests.swift`, `Tests/CoreTests/LaunchOptionsTests.swift`, `SnapshotTests/TrashSnapshotTests.swift`, `SnapshotTests/HomeSnapshotTests.swift`, `UITests/TrashJourneyTests.swift`

**Interfaces:**
- Produces:
  - `HomeViewRow.Kind.trash`; `HomeModel.viewRows` adds Trash after All Scans, always, with its count (an empty Trash shows no number); with no visible scans but a non-empty Trash, only the Trash row (M7). The badge is neutral with `trash`.
  - `GridRoute` (#56): holds the grid model in `@State`, like `ViewerRoute`; `RootView` uses it for every grid.
  - `TrashView(model:thumbnails:onOpen:)`: the header (glass back, glass "Select"/"Cancel", serif "Trash" 34/41, subtitle 15/20), a 3-column grid (`gap 16 × 8`, tiles 136 pt, 6 radius, dot + 13/18 semibold title, 12/16 days left), `.contextMenu` with Open, Restore (subtitle line, `arrow.uturn.backward`), Delete now (destructive, `trash`) with the system lift; the bottom "Empty Trash" glass pill in `destructive` 17 semibold; in select mode the check circles (24 pt) and the two bottom buttons (Delete N glass in `destructive`, Restore N filled `textPrimary` on `bgGrouped`). Confirmations are `.alert`s with the copy from Task 8; a warning haptic precedes each. Empty: the 44 pt trash symbol, "Trash is empty", "Scans land here when they expire or you move them here. Each one stays 30 days, then it’s deleted."
  - `-SeedTrash <n>`: `LibrarySeed.seedTrash(_:count:clock:)` saves `n` scans and moves them to Trash on days `today − index`.
  - `AccessibilityID.Trash { header, select, emptyTrash, deleteSelected, restoreSelected, tilePrefix, tile(_:) }`, `AccessibilityID.Home.trashRow`.
  - VoiceOver: a tile reads "Coat check, Throwaways, 5 days left" with actions Restore and Delete now (requirements 06 Accessibility).

- [ ] **Step 1: Write the failing tests:** `HomeModelTests.trashRowShowsItsCount`; `allInTrashShowsOnlyTheTrashRow` (M7); `LaunchOptionsTests.parsesSeedTrash`.
- [ ] **Step 2: Run `make fast`.** Expected: FAIL. Implement the model parts; expect PASS.
- [ ] **Step 3: Snapshots** `trash_list` (09-01 data, 7 scans), `trash_select` (09-02), `trash_empty` (09-09), each light, dark (09-10, 09-11) and ax5; `home_scans` re-recorded with the Trash row. Compare with the mocks and list the paths. Expected differences: no favourite hearts (Plan 4).
- [ ] **Step 4: UI test** `TrashJourneyTests.testRestoreSelectDeleteAndEmpty` (`-UITest -SeedScans 6 -SeedTrash 5 -FixedDate 2026-10-12`): Home Trash row → long-press a tile → Restore (no alert) → Select two → Delete 2 → confirm → Empty Trash → confirm → empty state. Attach and open the context menu and alert screenshots. Audit default and largest text.
- [ ] **Step 5: Run** the affected snapshot and UI tests. Expected: PASS.
- [ ] **Step 6: Commit** `Trash: the grid, select, long-press, Empty Trash; Home's Trash row; GridRoute (#56)`.

### Task 10: The Trash viewer

**Unit:** Screen · Trash (09-04, 09-06)

**Files:**
- Create: `Sources/Screens/Viewer/TrashViewerChrome.swift`
- Modify: `Sources/ScreenModels/Viewer/ViewerModel.swift`, `Sources/Screens/Viewer/ViewerView.swift`, `Sources/ScreenModels/App/AppRoute.swift` (`.trashedScan(ScanID)`), `Sources/Screens/Root/RootView.swift`, `AccessibilityID.swift`
- Test: `Tests/ScreenModelsTests/ViewerModelTests.swift`, `SnapshotTests/ViewerSnapshotTests.swift`, `UITests/TrashJourneyTests.swift`

**Interfaces:**
- Produces:
  - `ViewerModel` gains `mode: .library | .trash`. In Trash mode the pill reads the title over "29 days left" (orange when `isTrashSoon`), `isMissing` means "no longer in Trash", and `restore()` / `deleteNow()` exist (Delete confirms with Task 8's one-scan copy).
  - `TrashViewerChrome`: glass Close (×) top left, the pill, and the two 54 pt bottom buttons Delete now / Restore (Trash.dc.html lines 160–170). Same pager and zoom as the viewer. After either action, back to Trash (M6), with M19's announcement and a success haptic on Restore.
  - `AccessibilityID.TrashViewer { close, header, deleteNow, restore }`.

- [ ] **Step 1: Write the failing tests:** `trashModeReadsDaysLeftInTrash`; `restoreLeavesTrashMode` (`isMissing`); `deleteNowAsksWithTheTitle`.
- [ ] **Step 2: Run `make fast`.** Expected: FAIL. Implement; expect PASS.
- [ ] **Step 3: Snapshot** `trash_viewer` (09-04: Coat check, 5 days left, orange) light, dark, ax5. Compare and list.
- [ ] **Step 4: UI test** `testOpenATrashedScanAndRestoreIt` (opens from a tile, Restore, lands on Trash with one fewer tile; Home's Throwaways count up by one). Audit both sizes.
- [ ] **Step 5: Commit** `Trash: open a scan with Restore and Delete now`.

### Task 11: Settings models

**Unit:** ScreenModels (10-01 … 10-06)

**Files:**
- Create: `Sources/ScreenModels/Settings/AppPreferences.swift`, `SettingsModel.swift`, `CollectionsModel.swift`, `CollectionSettingsModel.swift`; `Sources/Core/Notifications/NotificationAuthorization.swift`, `CleanupNotifying.swift`, `ScheduledNotice.swift`; `Sources/TestSupport/FakeNotificationCenter.swift`
- Modify: `Sources/ScreenModels/Shared/CollectionText.swift` (`olderThan`, `keepTitle`), `Sources/Core/Analytics/AnalyticsEvent.swift`, `Localizable.xcstrings`
- Test: `Tests/ScreenModelsTests/SettingsModelTests.swift`, `CollectionSettingsModelTests.swift`

**Interfaces:**
- Produces:
  - Core: `public enum NotificationAuthorization: Sendable { case authorized, denied, notDetermined }`; `public struct ScheduledNotice: Sendable, Equatable { public let id: String; public let fireDate: DateComponents; public let title: String; public let body: String }`; `public protocol CleanupNotifying: Sendable { func authorization() async -> NotificationAuthorization; func requestAuthorization() async -> Bool; func replacePending(with notices: [ScheduledNotice]) async }`. TestSupport: `FakeNotificationCenter` (scripted authorization, records every `replacePending`).
  - `@MainActor @Observable public final class AppPreferences` with `public init(defaults: UserDefaults)`: `notificationsOn: Bool` (default true), `cleanupSeenThrough: CalendarDay?`.
  - `SettingsModel(preferences:notifications:library:analytics:)`: `collectionsCount` (5), `notificationsSwitchIsOn` (`notificationsOn && authorized`), `notificationsNote` ("A note when scans move to Trash" / "Turned off in iPhone Settings" when denied), `refreshAuthorization() async`, `setNotifications(_ on: Bool) async -> SettingsAction?` (asks iOS when not determined, M3; returns `.openSystemSettings` when denied), `footer` "Filing Cabinet \(version) · Private by design".
  - `CollectionsModel(library:today:)`: rows `Wallet` / "Kept forever · 8 scans"; footer "Counted from each scan’s date."; subtitle "How long each one keeps scans".
  - `CollectionSettingsModel(collection:library:today:analytics:)`: `title`, `countLine` "23 scans", `lifespanValue` "3 months", `choices` (`Lifespan.allCases`: "1 week", "1 month", "3 months", "1 year", "Forever"), `note` "Applies to receipts you already have. Scans you gave their own expiry keep it.", `choose(_ lifespan:)`: when `scansExpiring(…) > 0` sets `confirmation` ("Keep receipts 1 month?" / "18 receipts are older than a month and will go to Trash now. You can restore them for 30 days." / Cancel / "Change"), else applies at once; `confirm()`; `.lifespanChanged(collection:lifespan:)` analytics.
  - `CollectionText.olderThan(_ lifespan:)` "a week", "a month", "3 months", "a year"; plural nouns per M5 ("1 receipt is older…", "is"/"are" by count).

- [ ] **Step 1: Write the failing tests:** `collectionsCountIsFive`; `switchIsOffUntilAuthorized`; `turningOnAsksWhenNotDetermined`; `deniedOpensSystemSettings`; `turningOffStopsNotes` (preference false); `collectionRowsReadKeptAndCount`; `shorteningAsksWithTheCount` (exact copy); `oneReceiptReadsIs`; `lengtheningAppliesAtOnce`; `shorteningWithNothingToTrashAppliesAtOnce`; `cancelLeavesTheLifespan`.
- [ ] **Step 2: Run `make fast`.** Expected: FAIL. Implement; expect PASS.
- [ ] **Step 3: Commit** `ScreenModels: Settings, Collections and a collection's lifespan with the shortening ask`.

### Task 12: Settings screens and Home's gear

**Unit:** Screen · Settings (10-01 … 10-07, 12-05)

**Files:**
- Create: `Sources/Screens/Settings/SettingsView.swift`, `CollectionsView.swift`, `CollectionSettingsView.swift`
- Modify: `Sources/Screens/Home/HomeView.swift` (gear, 44 pt glass, top right as 02-04), `Sources/ScreenModels/App/AppRoute.swift` (`.settings`, `.collections`, `.collectionSettings(BuiltInCollection)`), `Sources/Screens/Root/RootView.swift`, `RootDependencies.swift`, `AccessibilityID.swift`, `App/AppEnvironment.swift`
- Test: `SnapshotTests/SettingsSnapshotTests.swift`, `SnapshotTests/HomeSnapshotTests.swift`, `UITests/SettingsJourneyTests.swift`

**Interfaces:**
- Produces: the three screens per `Settings2.dc.html` (grouped rounded 14 lists on `bgGrouped`, serif 34 titles, the Collections row with its value "5" and chevron, the Notifications row with the bell, a black-and-white switch, the note under the name; the Collections list with 31 pt badges and two-line rows; the collection screen with its badge beside the title, "Expiry" section header, "Keep scans for" row with the value and an up-down chevron opening a menu with a check on the current choice, the note). The shortening confirmation is an `.alert` with Cancel / Change (destructive). With notifications denied, tapping the switch opens `UIApplication.openNotificationSettingsURLString`.
  - `AccessibilityID.Settings { collections, notifications }`, `Collections { row(_:) }`, `CollectionSettings { keepScansFor }`, `Home.settings`.

- [ ] **Step 1: Snapshots** `settings` (10-01 minus the AI and feedback rows), `settings_blocked` (10-06's notifications state), `collections` (10-02), `collection_receipts` (10-03), each light, dark (10-07) and ax5 (12-05); `home_scans` re-recorded with the gear. Compare and list.
- [ ] **Step 2: UI test** `SettingsJourneyTests.testShorteningAsksThenSendsToTrash` (`-SeedScans 12 -FixedDate 2026-10-12 -Notifications denied`): gear → Collections → Throwaways → Keep scans for → 1 week is current, choose 1 month (no ask), then back to 1 week (ask, count), Change → back to Home, Trash count up. Attach and open the menu and alert screenshots. Audit both sizes.
- [ ] **Step 3: Run** the affected tests. Expected: PASS.
- [ ] **Step 4: Commit** `Settings: Collections and Notifications; each collection's Keep scans for`.

### Task 13: Cleanup notes: the planner and the system adapter

**Unit:** ScreenModels · Screens (11-01 … 11-04)

**Files:**
- Create: `Sources/ScreenModels/Cleanup/CleanupNotices.swift`, `Sources/Screens/Notifications/SystemNotificationCenter.swift`
- Modify: `Localizable.xcstrings`
- Test: `Tests/ScreenModelsTests/CleanupNoticesTests.swift`

**Interfaces:**
- Produces:
  - `enum CleanupNotices { static func plan(scans: [ScanSummary], lifespans: CollectionLifespans, today: CalendarDay, clock: AppClock, limit: Int = 64) -> [ScheduledNotice] }`. Groups scans that will enter Trash on their own (no `trashedDay`, finite last day, entry day after today) by entry day; takes the first `limit` days; fires at 9:00 local on that day (M9); `id` is `cleanup-yyyymmdd`. Copy (Notify.dc.html, `after`):
    - one: "Cleaned up" / "Moved the City Pharmacy receipt to Trash. It’s there for 30 days if you need it."
    - 2–3, one collection: "Cleaned up 3 receipts" / "City Pharmacy, Bluebird Café and Corner Market moved to Trash. They’re there for 30 days if you need them."
    - 2–3, mixed: "Cleaned up 3 scans" / "Parking stub, Coat check and City Pharmacy moved to Trash. They’re there for 30 days if you need them."
    - 4 or more: "Cleaned up 8 scans" / "Expired scans moved to Trash. They’re there for 30 days if you need one back."
    Names in title order within the day (soonest scanned first), joined per M25.
  - `struct SystemNotificationCenter: CleanupNotifying` (Screens, beside `SystemCameraAccess`): `UNUserNotificationCenter`, `UNCalendarNotificationTrigger(repeats: false)`; `replacePending` removes every pending request whose id starts with `cleanup-`, then adds the new ones. No badge, default sound off (a favour, not an alarm: my call), `threadIdentifier` "cleanup".

- [ ] **Step 1: Write the failing tests:** `oneScanNamesItWithItsNoun`; `threeReceiptsAreCountedByNoun`; `mixedAreCalledScans`; `fourOrMoreShowOnlyTheCount`; `oneNotePerDayAtNine`; `onlyTheNext64DaysAreScheduled` (Review Focus 3: 70 days of expiries → 64 notices, the earliest); `renamedScanIsNamedByItsNewTitle`; `manualTrashAndRestoredScansAreNotAnnounced`; `foreverScansNeverNotify`; `customLifespansMoveTheDay`.
- [ ] **Step 2: Run `make fast`.** Expected: FAIL. Implement; expect PASS.
- [ ] **Step 3: Build** `make build`. Expected: SUCCEEDED (the adapter has no Fast test; Task 15's phone check delivers a real note).
- [ ] **Step 4: Commit** `Cleanup: notes planned from dates, one a day at 9:00, the next 64 days`.

### Task 14: Cleanup at launch, rescheduling and the Home banner

**Unit:** App · Home (02-04, 02-07)

**Files:**
- Create: `Sources/ScreenModels/Cleanup/CleanupNotifier.swift`, `CleanupBanner.swift`
- Modify: `Sources/ScreenModels/Home/HomeModel.swift`, `Sources/Screens/Home/HomeView.swift`, `Sources/Core/Launch/LaunchOptions.swift` (`-Notifications`), `Sources/Core/Analytics/AnalyticsEvent.swift` (`cleanupRan`), `App/AppEnvironment.swift`, `App/FilingCabinetApp.swift`, `AccessibilityID.swift`
- Test: `Tests/ScreenModelsTests/CleanupNotifierTests.swift`, `CleanupBannerTests.swift`, `HomeModelTests.swift`, `Tests/CoreTests/LaunchOptionsTests.swift`, `SnapshotTests/HomeSnapshotTests.swift`, `UITests/CleanupJourneyTests.swift`

**Interfaces:**
- Produces:
  - `@MainActor final class CleanupNotifier` with `init(library:today:preferences:center:clock:)` and `func run() async`: while running, it watches `library.scans`, `library.lifespans`, `today.day` and `preferences.notificationsOn` with `Observations` and calls `center.replacePending(with:)` with the plan, or `[]` when notes are off or not authorized. One instance, started by the app at launch.
  - `CleanupBanner(library:today:preferences:notifications:)` (M4): `text` "4 scans moved to Trash" ("1 scan moved to Trash"), shown when notes are off or blocked and the count of natural entries in `(cleanupSeenThrough, today]` still in Trash is above 0; `clear()` sets `cleanupSeenThrough = today`. First run with no stored day sets it to today without showing.
  - `HomeModel.banner: String?`; HomeView shows "4 scans moved to Trash · View" under the title (15/20 secondary, View 600 primary, 44 pt tap target), View opens Trash and clears; the app clears it on `scenePhase == .background`.
  - Launch order in `AppEnvironment`: `removeOrphanedFiles()`, then `purgeTrash()`, then seeding, then Scan enabled; on becoming active, `today.refresh()` then `purgeTrash()`. `.cleanupRan(deleted:)` once per pass that deleted anything.
  - `-Notifications authorized|denied|notDetermined` swaps in `FakeNotificationCenter` (M22).

- [ ] **Step 1: Write the failing tests:** `CleanupNotifierTests.libraryChangeReschedules` (Review Focus 3: rename → a new plan naming the new title); `turningNotesOffClearsPending`; `newDayReschedules`; `CleanupBannerTests.countsNaturalEntriesSinceLastSeen`; `hiddenWhenNotesAreOn`; `firstRunStartsAtToday`; `clearHidesIt`; `manualTrashDoesNotCount`; `LaunchOptionsTests.parsesNotifications`.
- [ ] **Step 2: Run `make fast`.** Expected: FAIL. Implement; expect PASS.
- [ ] **Step 3: Snapshots** `home_banner` (02-04 data minus Search and Favorites) light, dark (02-07), ax5. Compare and list.
- [ ] **Step 4: UI test** `CleanupJourneyTests.testExpiredScansReachTrashAndTheBannerShows`: launch `-UITest -SeedScans 12 -FixedDate 2026-10-25 -Notifications denied`. Under `-UITest`, seeding sets `cleanupSeenThrough` to 14 days before the fixed date, so the Throwaways that expired since then count: the banner reads their number, and View opens Trash showing them. Audit both sizes.
- [ ] **Step 5: Run** the affected tests. Expected: PASS.
- [ ] **Step 6: Commit** `Cleanup: purge at launch and on return, notes rescheduled on every change, the Home banner`.

### Task 15: End to end, docs and the phone check

**Unit:** Docs · Device

**Files:**
- Modify: `AGENTS.md` (launch flags `-Notifications`, `-SeedTrash`; map: `Lifecycle`, Settings, Trash, Cleanup), `CLAUDE.md` ("Where we are"), `docs/superpowers/specs/2026-10-10-filing-cabinet-requirements.html` (section 02 Cleanup gains M1's sentence: "A scan already in Trash stays there when a lifespan or its collection changes; a scan a change sends to Trash gets the full 30 days from that day."), this plan's Decisions (anything decided during execution)
- Test: `UITests/ScanJourneyTests.swift`

- [ ] **Step 1: End-to-end journey** `testScanEditTrashRestore`: scan (fake camera, fake reader) → save to Receipts → open it → Details → rename → Move to Trash → Home Trash row → open → Restore → it is back in Receipts, kept forever.
- [ ] **Step 2: Update the docs** listed above; check every command and path in `AGENTS.md` exists.
- [ ] **Step 3: Run `make ci` locally** (or, per Plan 1's R21, let CI's identical `make ci` stand in if local UI runs are blocked, and say so). Dispatch `ios-verifier` for the evidence.
- [ ] **Step 4: Phone check with Ben** (`make device`; the phone **unpaired** from the Mac for camera use). (a) Details: rename, move with Undo, expiry, a custom date. (b) Move to Trash, Trash, Restore, Delete now, Empty Trash, long-press lift. (c) Settings › Notifications asks iOS. (d) A real note: give a Throwaway a custom expiry of today, set the phone's clock to tomorrow 8:59, wait for 9:00, then restore the clock. (e) VoiceOver: a Trash tile reads as one item with Restore and Delete now; the shortening alert. (f) Dark mode on each new screen. Note anything Ben changes in the Decisions table.
- [ ] **Step 5: Commit** `Docs: Plan 2 flags, modules and the Trash freeze rule`, then open the PR. It merges after CI's Full suite and the whole-branch review pass.
