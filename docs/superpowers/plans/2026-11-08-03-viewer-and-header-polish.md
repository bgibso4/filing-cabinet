# Plan 3 · Viewer and header polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Every screen gets one shared, Passwords-style header: Home rests large and sits lower, while inner screens rest small, grow large when pulled and stay large until scrolled back. Details opens from the pill, the Info button or a swipe up as one smooth, interruptible motion, with the page resizing in step (#61, #62, #46).

**Architecture:** Two small pure models in `ScreenModels`, Fast-tested, carry all the maths. `HeaderMotion` covers the title's growth, the snap and the resting offset. `DetailsMotion` covers the sheet's progress, the page fit, chrome fade, settle target and a spring stepper. Two Screens components apply them. `HeaderScrollView` replaces each screen's hand-drawn title and `ScrollView`. `DetailsPanel` replaces the system `.sheet`, because the sheet exposes no live position and can't be dragged up from closed, and #61 needs both. One `progress` value in `ViewerRoute` drives the panel, the page's fit insets (every frame, so the UIKit page resizes in step) and the pill, strip and bar fading. A timeboxed spike (Task 1) settles how `HeaderScrollView` is built inside, and measures per-frame page resizing on a phone before any view work.

**Tech Stack:** Swift 6, SwiftUI (toolbar title placements, `onScrollGeometryChange`, `ScrollTargetBehavior`, `UIGestureRecognizerRepresentable`), UIKit (`ZoomableScrollView`), os (`OSSignposter`), Swift Testing, XCTest (UI), swift-snapshot-testing 1.19.7.

**Spec:** Issues #61, #62 and #46 (Ben's Plan 1 and 2 phone checks); Ben's answers recorded below; Ben's Passwords screen recording (2026-11-08; kept off the repo because it shows his network names; what it shows is under "Seen in Ben's recording" below); the mocks at https://claude.ai/artifact/PVTq63b8qbbGYijZjDLMx1 (source `.superpowers/plandoc/plan3-mocks.html`); `docs/superpowers/specs/2026-10-10-filing-cabinet-requirements.html` section 06 ("Viewing works like Photos", Accessibility, Haptics); `docs/superpowers/specs/2026-10-31-engineering-foundations-design.md` (how); `design/` (02-01, 05-01…06, 07-01…08, 09-01/02/09, 10-01…03). Executors read these, and Plan 2 (`docs/superpowers/plans/2026-11-07-02-editing-and-self-cleaning.md`) for the conventions this plan continues.

**Status:** Approved by Ben on 2026-11-08, with every question answered (B rows). Execution: subagent-driven (B12), in progress (see "Decided during execution").

---

## Questions for Ben

All answered by Ben on 2026-11-08; see the B rows.

---

## Decisions

### Agreed with Ben

| # | Decision | Where it lands |
|---|---|---|
| B1 | **Scope:** #61 and #62 are Plan 3. Apple Intelligence moves to Plan 4, and every later plan shifts by one (Roadmap). | whole plan |
| B2 | **The header pill fades out in step with the sheet rising, and back in as it falls** (07-01 has no pill with Details up). The strip and bottom bar do the same. | 7, 8 |
| B3 | **#46 folds in:** the small resting title beside the back button closes it. | 4 |
| B4 | **#63 is checked at the phone check only**, with no design work. Close it or keep it then. | 10 |
| B5 | **Empty screens don't scroll and rest with the large title and its subtext** (an empty collection, an empty Trash). | 2, 4, 5 |
| B6 | **Once pulled out, the large title stays** until you scroll back up, as in Apple's apps. A pull past halfway snaps large; less snaps back small. | 2, 3 |
| B7 | **Header text never sits under a bar button** (Trash's subtext under Select today). | 3, 5 |
| B8 | **Select on the collection grids** is filed as #68 for Plan 5, not built here. | none |
| B9 | **Home sits lower like Passwords:** the gear moves into the top bar on its own row, and "Filing Cabinet" starts below it (Ben's screenshot). | 6 |
| B10 | **Details is our own panel, not the system `.sheet`** (Ben chose it from the side-by-side mock, 2026-11-08). It follows the finger: a swipe up raises it under the thumb, the page shrinks with it, and a grab mid-motion stops it where it is. Same look as today's sheet and its snapshot stand-in: bg-surface, 34 pt corners, 8 pt inset, our grabber. It doesn't dim the viewer, and the back button keeps working. Fallback if the swipe-up gesture fights paging, zoom or back for more than one timeboxed fix round: keep the panel and let the swipe up open it on release (Task 9). | 8, 9 |
| B11 | **Reduce Motion:** Details fades in and out instead of sliding, and the page takes its new size at once under the fade. Swipe up still opens it. | 8 |
| B12 | **Execution: subagent-driven**, once Ben approves the plan. | all |
| B13 | **The small title never drops or cuts its subtext.** Every subtext is written short enough to fit between the bar's buttons, and a Fast test (`HeaderFitTests`) measures the longest form of each, with a 4-digit count, against the room the bar leaves (Task 1 measures it). | 1, 5 |
| B14 | **Trash's Select shows, disabled, when Trash is empty**, as Passwords' Recently Deleted does. | 5 |
| B15 | **Trash's subtext is "7 scans · Deleted after 30 days"**, and "No scans" when empty, under the large title (Passwords shows "0 Items"). "2 selected" while selecting is unchanged. | 5 |

### My calls (not discussed; veto any before its task starts)

| # | Call | Task |
|---|---|---|
| M2 | **No collection icon in any title**, small or large, on the grids and on Settings › Collections › a collection. Passwords has none, and Ben asked to try without. The badge stays in Home's rows and in Details. | 3, 4 |
| M3 | **One progress value drives the viewer**, from 0 (closed) to 1 (open). The panel's offset, the page's fit bottom and the chrome's opacity are pure functions of it in `DetailsMotion`. Our own spring stepper (stiffness 170, damping 24, the mock's) animates it, so grabbing mid-motion starts from where it really is. | 7, 8, 9 |
| M4 | **The page's fit insets update every frame** of the motion. `ZoomableScrollView` already lays out on change. Task 1 measures the cost on the phone. If a frame takes over 8 ms, Task 8 animates the page's frame in SwiftUI instead and sets UIKit's insets once at rest. | 1, 8 |
| M5 | **Swipe up opens Details only on a page at rest** (not zoomed), and only when the drag is mostly vertical. Sideways drags page, as now, and a zoomed page pans. Release past halfway, or a flick over 0.6 progress per second, opens; otherwise it settles back. | 7, 9 |
| M6 | **Both title sizes are one accessibility element** with the screen's header identifier and `.isHeader`: whichever size is showing. The hidden size is hidden from VoiceOver. | 3 |
| M7 | **The small title and subtext stay at the default text size**, as Apple's bars do, and show the large-content viewer on long press. The large title grows and wraps at any size. This is what lets B13's fit check work at one size. | 3 |
| M8 | **Short content still rests small:** inner screens' content is at least the viewport plus the large title's height, so a two-row Settings page rests small like a long grid. | 2, 3 |
| M10 | **`HeaderScrollView` owns the scroll view** of every screen that has a header. Screens keep their own toolbars (Select) and bottom bars. `BottomBarLayout`'s `.safeAreaInset` (#59) is not touched. | 3–6 |
| M11 | **Home rests large and collapses on scroll** like Passwords' root. The cleanup banner stays under the large title and scrolls with the content. | 6 |
| M12 | **Task 8 tries removing B1's Details audit exemption** (`textClipped` on the floating sheet's text). The panel isn't a system sheet, so the misread may be gone. If the audit passes, delete it and update #59; otherwise keep it unchanged. | 8 |

### Seen in Ben's recording (Passwords, 2026-11-08)

- **Root:** the "•••" button has its own row; the large title starts under it and collapses into the bar on scroll, with the content blurring softly under the bar. Home follows this (B9, M11).
- **Recently Deleted, empty:** rests large ("Recently Deleted" over a small "0 Items") with the empty state centred, and doesn't move. Select is shown but greyed out (B5, B14).
- **Wi-Fi, 105 rows:** opens with the small title and subtext ("Wi-Fi" over "105 Networks") centred between back and Select. A pull shows the large title over its subtext, and it stays after release. Scrolling up collapses it again (B3, B6).
- All of this is the standard navigation bar opening collapsed. That makes Task 1's option A (our fonts in the system bar's title slots) the expected outcome, with the drawn header as the fallback.
- **Select mode** (back becomes Select All, a checkmark Done, row circles, a Trash button) is noted on #68 for Plan 5.

### Expected differences from the mocks

- No collection icon beside grid and collection-settings titles (M2): departs from 05-01…05 and 10-03.
- Home's title starts about 44 pt lower than 02-01, with the gear on the row above it (B9).
- Inner screens' titles rest small in the bar (B3), unlike 05-*, 09-01 and 10-*, which draw them large.
- Plan 1 and 2's hidden controls are still hidden (Search, Favorites, the sort button, More).

---

## Roadmap

| Plan | What you can do when it's merged |
|---|---|
| 0 · Foundation (done) | The loop. |
| 1 · Scan to library (done) | Scan, review, save, browse Home → collection → scan. |
| 2 · Editing and self-cleaning (done) | Details, Move to Trash, Trash, dates-based cleanup with notes and the banner, Settings › Collections. |
| **3 · Viewer and header polish (this plan)** | Passwords-style headers everywhere; Details opens from the pill, Info or a swipe up as one smooth motion. |
| 4 · Apple Intelligence | The suggestion card, shimmer and fallback, the Settings switch, an evaluation suite. |
| 5 · Favorites, search, share | Favorites (and their hearts in Trash), search, sort, share and export, the More menu, Select on the grids (#68). |
| 6 · First launch and system | Welcome and the notifications ask, Send feedback, the Scan control, Shortcuts, Spotlight, rating prompt, app icon. |

---

## Global Constraints

- Plan 1 and Plan 2's Global Constraints all still apply (see Plan 2's section). The lines below add to them.
- iOS 27.0 minimum, iPhone, portrait, English. No `#available`. Swift 6, Approachable Concurrency. Banned: `Task.detached`, `@unchecked Sendable`, disabling concurrency checking.
- Titles use New York (`.serif`) in both sizes; subtext is SF Pro. Colours, type and spacing come only from the generated tokens; screen measurements are named private constants citing their source (a mock line, Ben's screenshot, or this plan's decision row).
- Header maths lives only in `HeaderMotion` and viewer-motion maths only in `DetailsMotion`. No view computes a growth, snap, fit or opacity of its own.
- Full-size image decodes still go through `PageImageLoader`; nothing in this plan decodes a page.
- Snapshots: every changed reference is named in its commit message with the reason. Alerts, menus and the keyboard are never snapshotted.
- UI tests: waits go through `UITests/Support/Wait.swift` (`appears`, `disappears`, `satisfies`), never `waitForExistence` or `XCTNSPredicateExpectation`. Seeded tests wait through `UITests/Support/Seeding.swift`. Largest-text audits are named `testAuditAtLargestText…`. Classes launch once; `fresh: true` only when a cold process is the point.
- Prove logic in Fast, looks in snapshots, and only flows in UI tests. Never widen a threshold or timeout; never ship a known flake.
- No new accessibility-audit exemptions without Ben's OK. Any he approves is narrow and listed in #59.
- Every simulator run uses `SIM_DEVICE="FC iPhone 17"`. A task finishes on `make fast`, `make build`, `make lint`, `make unused` and `make full ONLY="…"` for the classes it lists. Draft PRs run only `checks` in CI; mark the PR ready for the simulator suite.
- Timebox: 45–60 minutes per fix round, then revert to the last green commit and report. Each task is well under 2 hours.
- Animation smoothness is judged on a phone (`make device`), never from the simulator.

## Review Focus

1. **A short screen (two Settings rows, a grid with one scan) and a long one rest the same way.** Short content must still rest small and pull large. Tests: Task 2 `shortContentStillRestsSmall`; Task 3 snapshot `collections` (short) beside Task 4's `grid_receipts` (long).
2. **A long subtext, or large text, beside a trailing bar button.** Nothing overlaps Select or the back button, and nothing is clipped mid-word. Tests: Task 5 `HeaderFitTests.everySubtextFitsTheBar`, snapshot `trash_select` (light, dark, ax5), `testAuditAtLargestTextTrash`.
3. **Grabbing Details mid-motion, or flicking it.** It stops under the finger from where it really was, never jumping to its target first. A flick opens or closes against the halfway rule. Tests: Task 7 `retargetingKeepsPositionAndVelocity`, `flickBeatsHalfway`; Task 9 `testSwipeUpOpensDetailsAndSwipeDownCloses`.
4. **A zoomed page, a sideways swipe, or an edge swipe back while Details could open.** Swipe up must not steal paging, panning or back. Tests: Task 9 runs `BrowseJourneyTests` edge-swipe and zoom tests unchanged; Task 7 `zoomedPageNeverOpensDetails`.
5. **Renaming in Details with the keyboard up.** The panel rides above the keyboard, and Return commits as today. Test: `DetailsJourneyTests.testRenameMoveUndoAndExpiry` unchanged, run in Task 8.

---

## File Structure

No new module; dependencies unchanged (AGENTS.md).

```
Packages/FilingCabinetKit/Sources/
  Core/Accessibility/AccessibilityID.swift      modify: Home.header, Settings.header, Collections.header,
                                                        CollectionSettings.header
  ScreenModels/Shared/HeaderMotion.swift        create: HeaderRest, HeaderMotion
  ScreenModels/Viewer/DetailsMotion.swift       create: DetailsMotion, DetailsSpring
  Screens/DesignSystem/HeaderScrollView.swift   create: the shared header and its scroll view
  Screens/DesignSystem/HeaderTitle.swift        create: the small and large title views HeaderScrollView places
  Screens/Details/DetailsPanel.swift            create: the panel around DetailsSheet's content
  Screens/Details/DetailsSheet.swift            modify: content only (no presentation modifiers)
  Screens/Viewer/ViewerRoute.swift              modify: progress + spring driver instead of .sheet
  Screens/Viewer/ViewerView.swift               modify: detailsProgress replaces detailsHeight; chrome fades
  Screens/Viewer/DetailsSwipe.swift             create: the swipe-up recognizer (UIGestureRecognizerRepresentable)
  Screens/Grid/CollectionGridView.swift, Trash/TrashView.swift, Settings/*.swift, Home/HomeView.swift  modify
  Screens/Root/RootView.swift                   modify: Home's bar no longer hidden
Packages/FilingCabinetKit/Tests/ScreenModelsTests/ HeaderMotionTests.swift, HeaderFitTests.swift, DetailsMotionTests.swift
SnapshotTests/  Home, Grid, Trash, Settings, Details, Viewer snapshot tests (re-recorded per task)
SnapshotTests/ViewerBehaviourTests.swift        modify: the page follows progress
UITests/        BrowseJourneyTests, DetailsJourneyTests, Support/Sheet.swift
```

---

## Tasks

### Task 1: Spike: how the header is built, and what per-frame page resizing costs

**Unit:** Spike (throwaway; nothing from it merges)

**Files:** a throwaway branch `spike/plan-3` off `plan-3`; delete it when the task is done. The only lasting output is this plan's Decisions table (rows E1, E2) and a note in `.superpowers/for-ben.md`.

- [ ] **Step 1: Header, option A (system bar).** On the Receipts grid and Settings › Collections, try `navigationTitle` + `navigationSubtitle` with our views in the `.title`, `.subtitle`, `.largeTitle` and `.largeSubtitle` toolbar placements (axiom-swiftui toolbars Pattern 14). Content starts scrolled to the collapsed position, with M8's minimum height. Expected to pass: the recording is this exact bar. Pass if all six hold on the simulator, side by side with Ben's recording: rests small on both screens; pulling past halfway snaps large and stays (B6); scrolling up collapses; serif titles in both sizes; one `grid.header` element at a time in the accessibility tree; nothing overlaps Select (put a Select item on the grid).
- [ ] **Step 2: Header, option B (drawn), only if A fails a check.** A `.principal` toolbar item for the small title, the large title as the scroll content's first view, `onScrollGeometryChange` feeding `HeaderMotion`'s growth, and a `ScrollTargetBehavior` calling its `settle`. Check the same six points.
- [ ] **Step 3: Per-frame page resize on the phone.** In the viewer, drive `pageFitBottom` from a display-link progress 0 → 1 → 0 over 0.4 s, with an `OSSignposter` interval around `ZoomableScrollView.layoutSubviews`. `make device`, record 10 cycles with Instruments (or `xcprof record`), and report the p95 layout time. Under 8 ms keeps M4; over it switches Task 8 to M4's fallback.
- [ ] **Step 4: Measure the small title's room** on `FC iPhone 17` (402 pt wide): the width the bar leaves the centred title beside the back button alone, and beside back and Select. Note the subtitle's font and point size as the bar draws it.
- [ ] **Step 5: Record the outcome** as E1 (header: A or B, and why), E2 (p95 and M4's path) and E3 (the two widths and the subtitle font from Step 4) in this plan's "Decided during execution" table, and add a one-line note for Ben in `.superpowers/for-ben.md`. Delete the spike branch. Timebox: 2 hours total; if neither header option passes, stop and ask Ben.

### Task 2: HeaderMotion

**Unit:** ScreenModels

**Files:**
- Create: `Sources/ScreenModels/Shared/HeaderMotion.swift`
- Test: `Tests/ScreenModelsTests/HeaderMotionTests.swift`

**Interfaces:**
- Produces (`package`; `public` only when a snapshot or app test first needs it, per Plan 2's B2):
  - `enum HeaderRest: Sendable { case small, large }`
  - `struct HeaderMotion: Sendable, Equatable { let largeHeight: CGFloat }`. Offsets are measured from the fully expanded position: 0 means the large title fully shows, `largeHeight` means collapsed.
    - `func growth(offset: CGFloat) -> CGFloat`: 1 at or above 0, 0 at or past `largeHeight`, linear between.
    - `func settle(proposedOffset: CGFloat) -> CGFloat`: a target inside `(0, largeHeight)` snaps to 0 when below `largeHeight / 2`, otherwise to `largeHeight` (B6). Anything outside that range is returned unchanged.
    - `func restingOffset(_ rest: HeaderRest) -> CGFloat`: `.small` → `largeHeight`, `.large` → 0.
    - `func minimumContentHeight(viewport: CGFloat) -> CGFloat`: `viewport + largeHeight` (M8).

- [ ] **Step 1: Write the failing tests** (`largeHeight: 52`): `growthIsOneFullyPulled` (offset −20 → 1, 0 → 1); `growthIsZeroCollapsed` (52 → 0, 300 → 0); `growthIsLinearBetween` (26 → 0.5); `settleBeforeHalfwayStaysLarge` (20 → 0); `settlePastHalfwayCollapses` (30 → 52); `settleLeavesContentScrollAlone` (400 → 400, −10 → −10); `innerScreensRestSmall` (`.small` → 52); `homeRestsLarge` (`.large` → 0); `shortContentStillRestsSmall` (viewport 700 → 752).
- [ ] **Step 2: Run `make fast`.** Expected: FAIL to compile.
- [ ] **Step 3: Implement** `HeaderMotion` as above.
- [ ] **Step 4: Run `make fast`.** Expected: PASS.
- [ ] **Step 5: Commit** `ScreenModels: HeaderMotion (growth, snap, resting offset)`.

### Task 3: HeaderScrollView, applied to Settings, Collections and a collection's settings

**Unit:** Screen · Settings (10-01, 10-02, 10-03)

**Files:**
- Create: `Sources/Screens/DesignSystem/HeaderScrollView.swift`, `HeaderTitle.swift`
- Modify: `Sources/Screens/Settings/SettingsView.swift`, `CollectionsView.swift`, `CollectionSettingsView.swift`, `Sources/Core/Accessibility/AccessibilityID.swift`
- Test: `SnapshotTests/SettingsSnapshotTests.swift`, `UITests/SettingsJourneyTests.swift`

**Interfaces:**
- Consumes: `HeaderMotion`, `HeaderRest`; E1's mechanism.
- Produces:
  - `HeaderScrollView<Content: View>(title: Text, subtitle: Text?, identifier: String, rest: HeaderRest, scrolls: Bool = true, @ViewBuilder content: () -> Content)`. It owns the `ScrollView` and the bar's title. The large title is `Tokens.Typography.largeTitle` serif with its tracking, with the subtitle in `subheadline` / `textSecondary` 2 pt below. The small title is `headline` serif over a `caption` subtitle, centred between the bar's items, never truncated (B13), at the default text size (M7). Growth comes from `HeaderMotion` (E1 decides how). `scrolls: false` means no scrolling or bouncing, with the large title shown (B5). The subtitle `Text` is passed in styled, so Trash's semibold "2 selected" keeps its look.
  - Exactly one accessibility element carries `identifier` and `.isHeader`: whichever size is showing (M6). The small title and subtitle never truncate (B13) and stay at the default text size (M7).
  - `AccessibilityID.Settings.header`, `.Collections.header`, `.CollectionSettings.header` (each added to its enum's `all`).

- [ ] **Step 1: UI test** `SettingsJourneyTests.testPullingDownGrowsTheTitleAndItStays`: open Settings › Collections. `Collections.header` is centred (its frame's midX within 2 pt of the window's). Drag down 200 pt from the list: the header is now leading-aligned (midX less than the window's midX − 40) and stays so once the drag ends. Drag up 300 pt: it's centred again. `assertIdentifiers` for the three new header IDs on their screens.
- [ ] **Step 2: Run it** (`make full ONLY="FilingCabinetUITests/SettingsJourneyTests/testPullingDownGrowsTheTitleAndItStays"`). Expected: FAIL.
- [ ] **Step 3: Implement** `HeaderScrollView` and `HeaderTitle`, and move the three Settings screens onto it. Each screen's own title `Text` and its title gap constants go; the content and footer stay.
- [ ] **Step 4: Re-record the snapshots** `settings`, `settings_blocked`, `collections`, `collection_receipts` (light, dark, ax5): titles rest small in the bar, with no badge on `collection_receipts` (M2). Add `collections_large`: the same screen with `rest: .large`, the state a pull reaches. Open each against 10-01…10-03 and list the paths. Expected differences: small resting title, no badge.
- [ ] **Step 5: Run** `make full ONLY="FilingCabinetSnapshotTests/SettingsSnapshotTests FilingCabinetUITests/SettingsJourneyTests"`. Expected: PASS, including `testAuditAtLargestTextSettings`.
- [ ] **Step 6: Commit** `Screens: shared Passwords-style header; Settings screens use it (#62)`, naming each re-recorded reference and why.

### Task 4: Collection grids, Recent and All Scans

**Unit:** Screen · Grid (05-01…05-06)

**Files:**
- Modify: `Sources/Screens/Grid/CollectionGridView.swift`
- Test: `SnapshotTests/GridSnapshotTests.swift`, `UITests/BrowseJourneyTests.swift`

**Interfaces:**
- Consumes: `HeaderScrollView` (`identifier: AccessibilityID.Grid.header`, `rest: .small`; when `model.isEmpty`, `rest: .large, scrolls: false`).
- Produces: nothing new. The grid's `header`, `icon` and `viewIcon` go (M2), along with the icon and badge constants. `EmptyCollectionView` stays centred in what the header leaves.

- [ ] **Step 1: UI test** `BrowseJourneyTests.testEmptyGridDoesNotScroll`: launch with no seed (every collection empty), open Receipts from Home, drag up 300 pt and down 300 pt; `Grid.header`'s frame is unchanged after each (B5). Run it. Expected: FAIL (today's empty grid scrolls).
- [ ] **Step 2: Implement.** The prefetcher's `onChange`/`onDisappear` move onto the `HeaderScrollView`.
- [ ] **Step 3: Re-record** `grid_receipts`, `grid_wallet`, `grid_throwaways`, `grid_recent`, `grid_all`, `grid_empty` (light, dark, ax5). Open each against its 05-* mock and list the paths. Expected differences: small resting title beside the back button, no icon; `grid_empty` shows the large title, still.
- [ ] **Step 4: Run** `make full ONLY="FilingCabinetSnapshotTests/GridSnapshotTests FilingCabinetSnapshotTests/GridPerformanceTests FilingCabinetUITests/BrowseJourneyTests FilingCabinetUITests/ScanJourneyTests"`. ScanJourneyTests finds `Grid.header` after a save. Expected: PASS, including `testAuditAtLargestTextOfAGrid`.
- [ ] **Step 5: Commit** `Grid: shared header, resting small; empty grids hold still (#62, #46)`, naming each reference.

### Task 5: Trash, and every subtext proven to fit

**Unit:** Screen · Trash (09-01, 09-02, 09-09); ScreenModels

**Files:**
- Modify: `Sources/Screens/Trash/TrashView.swift`, `Sources/ScreenModels/Trash/TrashModel.swift` (`subtitle`), `Sources/ScreenModels/Localizable.xcstrings`
- Create: `Tests/ScreenModelsTests/HeaderFitTests.swift`
- Test: `Tests/ScreenModelsTests/TrashModelTests.swift`, `SnapshotTests/TrashSnapshotTests.swift`, `UITests/TrashJourneyTests.swift`

**Interfaces:**
- Consumes: `HeaderScrollView` (`identifier: AccessibilityID.Trash.header`; the subtitle styled as today: semibold primary while selecting). When empty: `rest: .large, scrolls: false`. E3's two widths and the subtitle font.
- Produces: `TrashModel.subtitle` becomes non-optional `String` (B15). Select stays a `.topBarTrailing` toolbar item, always present and disabled while Trash is empty (B14). `BottomBarLayout` is untouched (M10).

- [ ] **Step 1: Write the failing tests.**
  - `TrashModelTests`: the two subtitle expectations become `"3 scans · Deleted after 30 days"` and `"1 scan · Deleted after 30 days"`; add `emptyTrashSaysNoScans` (`subtitle == "No scans"`).
  - `HeaderFitTests.everySubtextFitsTheBar` (B13): measure with Core Text (`CTLine` typographic width, system font at E3's subtitle size; Core Text is allowed in Fast) and expect each width ≤ its room. Beside back and Select (E3's narrower width): Trash at 9,999 scans and "999 selected". Beside back alone: each collection grid at 9,999 scans with each of the five lifespans, Recent's "Last 30 days", All Scans at 9,999, Collections' "How long each one keeps scans", a collection's settings at 9,999 scans. Build each string through the models' own text functions, never retyped. The two widths are named constants citing E3.
- [ ] **Step 2: Run `make fast`.** Expected: FAIL (Trash's copy is too long, and empty is nil).
- [ ] **Step 3: Implement** the copy in `TrashModel` and its `.xcstrings` entry. Run `make fast`. Expected: PASS.
- [ ] **Step 4: Change the journey.** In `TrashJourneyTests`' `emptyTrash(in:)`, replace `XCTAssertFalse(app.buttons[AccessibilityID.Trash.select].exists)` with: Select exists and `isEnabled` is false (B14).
- [ ] **Step 5: Implement** the view: Trash on `HeaderScrollView`, and Select always shown, disabled while empty.
- [ ] **Step 6: Re-record** `trash_list`, `trash_select`, `trash_empty` (light, dark, ax5) and `trash_under_bar` (light, dark). Open each, and in `trash_select` check that nothing touches Select or the back button at any size (B7, Review Focus 2). List the paths.
- [ ] **Step 7: Run** `make full ONLY="FilingCabinetSnapshotTests/TrashSnapshotTests FilingCabinetUITests/TrashJourneyTests"`. Expected: PASS. The #59 Trash exemptions are unchanged; a new audit failure goes to Ben, not into an exemption.
- [ ] **Step 8: Commit** `Trash: shared header, shorter subtext, Select always shown; every subtext proven to fit (#62)`, naming each reference.

### Task 6: Home sits lower, with the gear in the bar

**Unit:** Screen · Home (02-01, 02-04)

**Files:**
- Modify: `Sources/Screens/Home/HomeView.swift`, `Sources/Screens/Root/RootView.swift` (drop `.toolbar(.hidden, for: .navigationBar)`), `Sources/Core/Accessibility/AccessibilityID.swift` (`Home.header`)
- Test: `SnapshotTests/HomeSnapshotTests.swift` (host Home in a `NavigationStack`, as the grid tests do), `UITests/HomeJourneyTests.swift`, `UITests/CleanupJourneyTests.swift`

**Interfaces:**
- Consumes: `HeaderScrollView(title: "Filing Cabinet", subtitle: nil, identifier: AccessibilityID.Home.header, rest: .large)`.
- Produces: the gear becomes a `.topBarTrailing` toolbar button with the system's glass, keeping `AccessibilityID.Home.settings` and its "Settings" label. The `GlassCircleButton` use and `gearDiameter` go. The banner stays the first content under the title (M11).

- [ ] **Step 1: UI test** `HomeJourneyTests.testTitleCollapsesOnScroll`: with `-SeedScans 12`, `Home.header` is leading-aligned; drag up 300 pt and it's centred; drag down 300 pt and it's leading again. The gear still opens Settings. Run it. Expected: FAIL.
- [ ] **Step 2: Implement.**
- [ ] **Step 3: Re-record** `home_first`, `home_scans`, `home_banner` (light, dark, ax5). Open each against 02-01 / 02-04 and Ben's Passwords screenshot. Expected difference: the title about 44 pt lower, the gear on the row above (B9). List the paths.
- [ ] **Step 4: Run** `make full ONLY="FilingCabinetSnapshotTests/HomeSnapshotTests FilingCabinetUITests/HomeJourneyTests FilingCabinetUITests/CleanupJourneyTests FilingCabinetUITests/CaptureLayerContainmentTests"`. Expected: PASS, including both Home largest-text audits.
- [ ] **Step 5: Commit** `Home: large title below the gear, collapsing on scroll (#62)`, naming each reference.

### Task 7: DetailsMotion

**Unit:** ScreenModels

**Files:**
- Create: `Sources/ScreenModels/Viewer/DetailsMotion.swift`
- Test: `Tests/ScreenModelsTests/DetailsMotionTests.swift`

**Interfaces:**
- Produces (`package`):
  - `enum DetailsMotion`:
    - `static func pageFitBottom(progress: CGFloat, closed: CGFloat, open: CGFloat) -> CGFloat`: linear, with `progress` clamped to 0…1.
    - `static func chromeOpacity(progress: CGFloat) -> CGFloat`: `1 − progress`, clamped (B2).
    - `static func panelOffset(progress: CGFloat, travel: CGFloat) -> CGFloat`: `(1 − progress) × travel`.
    - `static func progress(dragStart: CGFloat, translation: CGFloat, travel: CGFloat) -> CGFloat`: an upward translation (negative) raises progress, clamped 0…1.
    - `static func target(progress: CGFloat, velocity: CGFloat) -> CGFloat`: a velocity of 0.6 progress per second or more toward open gives 1, toward closed gives 0 (M5); otherwise 1 when `progress ≥ 0.5`.
    - `static func swipeOpens(translation: CGSize, isPageZoomed: Bool, isFromTrash: Bool) -> Bool`: true only when not zoomed, not from Trash, `translation.height < 0` and `|height| > |width|` (M5; Plan 2's E6).
  - `struct DetailsSpring: Sendable, Equatable { var position: CGFloat; var velocity: CGFloat; var target: CGFloat }`, with stiffness 170 and damping 24 (M3):
    - `mutating func step(by seconds: Double)`: semi-implicit Euler, with `seconds` capped at 1/30.
    - `var isSettled: Bool`: within 0.001 of the target and slower than 0.01 per second; then `position == target`.

- [ ] **Step 1: Write the failing tests:** `pageFitFollowsProgress` (closed 130, open 260: 0 → 130, 0.5 → 195, 1 → 260, 1.4 → 260); `chromeFadesWithProgress`; `dragUpRaisesProgress` (start 0, translation −107, travel 214 → 0.5); `halfwayDecidesAtRest` (0.49 → 0, 0.5 → 1); `flickBeatsHalfway` (0.2 at +0.7/s → 1; 0.8 at −0.7/s → 0); `springSettlesOnTarget` (from 0 toward 1, stepping 1/60 s, settles within 1 s with no overshoot past 1.02); `retargetingKeepsPositionAndVelocity` (step 0.1 s toward 1, set the target to 0: position and velocity are unchanged at that instant, then it settles at 0); `largeStepsAreCapped` (one 1 s step moves no further than one 1/30 s step); `zoomedPageNeverOpensDetails` (`swipeOpens`: up (0, −40) → true; zoomed → false; from Trash → false; sideways (40, −10) → false; down (0, 40) → false).
- [ ] **Step 2: Run `make fast`.** Expected: FAIL to compile.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run `make fast`.** Expected: PASS.
- [ ] **Step 5: Commit** `ScreenModels: DetailsMotion and its spring`.

### Task 8: The Details panel: one motion from the pill and Info

**Unit:** Screen · Viewer and Details (06-01, 06-02, 07-01…07-08)

**Files:**
- Create: `Sources/Screens/Details/DetailsPanel.swift`
- Modify: `Sources/Screens/Details/DetailsSheet.swift` (drop the presentation modifiers; keep measuring its height), `Sources/Screens/Viewer/ViewerRoute.swift`, `ViewerView.swift`, `UITests/Support/Audit.swift` (only per M12)
- Test: `SnapshotTests/DetailsSnapshotTests.swift` (the real `ViewerView` + `DetailsPanel` replaces `DetailsOverViewer`), `SnapshotTests/ViewerSnapshotTests.swift`, `SnapshotTests/ViewerBehaviourTests.swift`, `UITests/DetailsJourneyTests.swift`, `UITests/Support/Sheet.swift`

**Interfaces:**
- Consumes: `DetailsMotion`, `DetailsSpring`, `DetailsSheet(model:height:)`.
- Produces:
  - `ViewerView(…, detailsProgress: CGFloat = 0, onDetails:, …)` replaces `detailsHeight`. The page's fit bottom is `DetailsMotion.pageFitBottom(progress:, closed: <today's at-rest value>, open: sheetBottomInset + panelHeight + pageSheetGap)`. The pill, strip and bar take `chromeOpacity`; they stop taking hits at progress > 0.5 and are hidden from VoiceOver at 1. The pill stays in the toolbar (it fades rather than being removed), so nothing blinks.
  - `DetailsPanel(model:, progress:, height: Binding<CGFloat>, onClose:)`: bg-surface, 34 pt continuous corners, 8 pt from the sides and bottom, offset by `panelOffset(progress:, travel: height + 8)`, riding above the keyboard. VoiceOver escape calls `onClose`.
  - `ViewerRoute` owns `@State var spring: DetailsSpring` and a `TimelineView(.animation)`-paced step while the spring isn't settled. `open()` and `close()` retarget the spring. The `DetailsModel` is made when it opens (as today) and released once it settles at 0. Under Reduce Motion (`\.accessibilityReduceMotion` or `forcesReduceMotion`), the panel's opacity follows the spring and its offset and the page fit jump to the target (B11).
  - If E2 took M4's fallback: the page is laid out at its at-rest fit and scaled and offset in SwiftUI by progress, with UIKit's insets set once the spring settles.

- [ ] **Step 1: Behaviour test** `ViewerBehaviourTests.pageFollowsDetailsProgress`: host `ViewerView` with `detailsProgress` 0, 0.5 and 1. The page's frame bottom at 0.5 lies strictly between its 0 and 1 values (within 1 pt of the midpoint), and the pill's opacity is 0.5.
- [ ] **Step 2: Run it.** Expected: FAIL to compile.
- [ ] **Step 3: Implement** the panel, the progress plumbing and the spring driver. Delete the `.sheet`.
- [ ] **Step 4: Snapshots.** `details_lease`, `details_receipt`, `details_moved`, `details_rename` now render the real panel at progress 1. Re-record only if pixels changed, and name each one with the reason. `viewer_lease`, `viewer_receipt` and `trash_viewer` must not change.
- [ ] **Step 5: UI test** `DetailsJourneyTests.testInfoOpensAndClosesDetails`: tap `Viewer.details`; `Details.sheet` appears and `Viewer.header` stops being hittable; `swipeDownOnSheet()`; `Viewer.header` is hittable again. Update `Sheet.swift`'s doc to the panel.
- [ ] **Step 6: M12.** Remove the B1 exemption (`details.titleText`, `details.scannedLine` `textClipped`) and run `testAuditAtLargestTextDetails` and `testRenameMoveUndoAndExpiry`. If both pass, keep it removed and edit #59's list. If not, restore it unchanged.
- [ ] **Step 7: Run** `make full ONLY="FilingCabinetSnapshotTests/DetailsSnapshotTests FilingCabinetSnapshotTests/ViewerSnapshotTests FilingCabinetSnapshotTests/ViewerBehaviourTests FilingCabinetUITests/DetailsJourneyTests FilingCabinetUITests/ScanJourneyTests/testScanEditTrashRestore"`. Expected: PASS.
- [ ] **Step 8: Commit** `Viewer: Details is one motion; the page resizes in step and the pill fades (#61)`, naming any reference and M12's outcome.

### Task 9: Swipe up to open, drag down to close, grab mid-motion

**Unit:** Screen · Viewer

**Files:**
- Create: `Sources/Screens/Viewer/DetailsSwipe.swift`
- Modify: `Sources/Screens/Viewer/ViewerRoute.swift`, `ViewerView.swift`, `Sources/Screens/Details/DetailsPanel.swift`
- Test: `SnapshotTests/ViewerBehaviourTests.swift`, `UITests/DetailsJourneyTests.swift`, `UITests/BrowseJourneyTests.swift` (unchanged; must stay green)

**Interfaces:**
- Consumes: `DetailsMotion.progress(dragStart:translation:travel:)`, `.target(progress:velocity:)`, `DetailsSpring`.
- Produces:
  - `DetailsSwipe: UIGestureRecognizerRepresentable` on the pager. Its pan begins only when `DetailsMotion.swipeOpens(translation:isPageZoomed:isFromTrash:)` (Task 7) says so. It never recognizes simultaneously with the pager's horizontal scroll or the system's edge-swipe back. It reports `.began / .changed(translation) / .ended(velocity)`.
  - The panel's own drag (grabber and body, not inside a menu or the title field) reports the same three phases.
  - On `.began`, `ViewerRoute` freezes the spring at its current `position` (that's the grab); `.changed` sets progress from the drag; `.ended` sets the spring's target from `DetailsMotion.target`, carrying the release velocity.
  - In the Trash viewer the swipe does nothing (Plan 2's E6: a trashed scan is read-only).
  - B10's fallback, only if the recognizer still breaks paging, zoom or edge-swipe back after one timeboxed fix round: the swipe up opens Details on release (`target` 1) without tracking the finger. The panel's own drag, the grab and the in-step page stay. Record it as an E row and tell Ben.

- [ ] **Step 1: UI test** `DetailsJourneyTests.testSwipeUpOpensDetailsAndSwipeDownCloses`: open a scan; drag from the page's centre up 300 pt; `Details.sheet` appears. `swipeDownOnSheet()`; it disappears and `Viewer.header` is hittable.
- [ ] **Step 2: Run it.** Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `make full ONLY="FilingCabinetSnapshotTests/ViewerBehaviourTests FilingCabinetUITests/DetailsJourneyTests FilingCabinetUITests/BrowseJourneyTests FilingCabinetUITests/TrashJourneyTests FilingCabinetUITests/ReviewZoomJourneyTests"`. Expected: PASS, with every edge-swipe and zoom test unchanged (Review Focus 4). #64's skipped test stays skipped.
- [ ] **Step 5: Commit** `Viewer: swipe up opens Details; drag and grab follow the finger (#61)`.

### Task 10: Docs, the full suite and the phone check

**Unit:** Docs · Device

**Files:**
- Modify: `AGENTS.md` (map: `HeaderScrollView` and `DetailsPanel` under Screens, `HeaderMotion` and `DetailsMotion` under ScreenModels), `CLAUDE.md` ("Where we are"), this plan's Decisions (everything decided during execution)

- [ ] **Step 1: Update the docs** listed above; check every path and command named in `AGENTS.md` exists.
- [ ] **Step 2: One local `make full`**, then push and mark the PR ready so CI runs the simulator suite. Dispatch `ios-verifier` for the evidence.
- [ ] **Step 3: Phone check with Ben** (`make device`, phone unpaired for camera use). (a) Details from the pill, Info and a swipe up; grab it mid-motion; flick it both ways; rename with the keyboard up. Does the page move with the sheet, with no jump (#61)? (b) Every header: Home sits lower; each inner screen rests small, pulls large and stays, and collapses when scrolled; empty Notes and an empty Trash hold still, large; nothing touches Select (#62, #46). (c) Settings › Collections against Home: close or keep #63 (B4). (d) Reduce Motion on: Details fades. (e) VoiceOver: each title reads once as a header; escape closes Details. (f) Dark mode on each screen. Note anything Ben changes in the Decisions table.
- [ ] **Step 4: Commit** `Docs: Plan 3 header and Details panel`. The PR body closes #46, #61 and #62 (and #63 if Ben closes it). It merges after CI's Full suite and the whole-branch review pass.

---

### Decided during execution

| # | Decision | Whose | Task |
|---|---|---|---|
| E1 | **Header: option A, the system bar.** On the simulator it rests small, snaps large past halfway and stays (UIKit's own snap matches B6), collapses on scroll, uses serif in both sizes and keeps clear of Select, on the Receipts grid and Settings › Collections, short content included. It needs three pieces of our own: rest small by starting at `ScrollPosition(y: largeHeight)` and calling `scrollTo(y: 0)` once the bar's top inset first reports; the `.title`/`.subtitle` items fade themselves with `HeaderMotion.growth`, fed by the scroll view's top-inset growth (`largeHeight` measured at runtime, 58.7 pt here); no custom `ScrollTargetBehavior`, because it fought UIKit's snap. M8's minimum height goes on an outer container, not the content. **M6 amended (Ben, 2026-11-08):** the small bar title carries the header identifier and `.isHeader` in both states. Task 3 checks with VoiceOver that each title reads once and hides a duplicate if not; UI tests check the small title's hittability instead of its position. | spike; M6 change is Ben's | 1, 3–6 |
| E2 | **Per-frame page resize is cheap: M4 stands.** On Ben's iPhone 16 Pro (2026-11-08), driving the page's fit bottom 0 → 1 → 0 over 0.4 s for 10 cycles gave 252 `ZoomableScrollView.layoutSubviews` intervals: p50 0.28 ms, **p95 0.46 ms**, max 0.98 ms, far under 8 ms. Task 8 updates the fit insets every frame. (The interval covers UIKit layout only, not SwiftUI's own update; Task 10's phone check judges the motion.) | spike (measured with Ben) | 1, 8 |
| E3 | **Room for the small title:** the bar's slot is 314 pt beside back alone and 222 pt beside back and Select, on FC iPhone 17. Centred, that leaves **258 pt** and **186 pt**, and `HeaderFitTests` uses these. The bar draws the subtitle in SF Pro Regular 12 pt (= `Tokens.Typography.caption`) and its own title in SF Pro Semibold 17 pt. | spike (measured); centred widths my call (executor) | 1, 5 |
| E4 | **`HeaderMotion.settle` is dropped** from Task 2 (and its three tests), because E1 leaves the snap to UIKit, so `settle` would be dead code. | my call (executor) | 2 |
| E5 | **`BottomBarLayout` keeps one structure across text sizes** (an amendment to M10's "not touched"). Its `if`/`else` at the accessibility boundary gave the content a new identity, which breaks `HeaderScrollView`'s one-instance contract, so a text-size change left the grid under the bar. Each size renders as before, and `.safeAreaInset`'s role (#59) is unchanged. As a knock-on, Trash's Select takes `.id(typeSize)`, since it no longer gets rebuilt by accident. | my call (executor), Task 4 | 4, 5 |
| E6 | **B5 at accessibility sizes:** empty screens hold still at every normal text size, but scroll at accessibility sizes, where the empty-state text would otherwise run under Scan. The same rule applies to an empty Trash. | Ben, 2026-11-08 | 4, 5 |
| E7 | **Trash's subtext keeps B15's copy, and may sit off-centre.** "9,999 scans · Deleted after 30 days" is 202 pt, wider than the 186 pt centred room beside back and Select. Once the subtext passes about 180 pt (from about 10 scans; the real centred room beside back and Select measured 176–184 pt in Task 5, not E3's estimated 186), the bar slides Trash's small title slightly off-centre, as Apple's bars do. It's never truncated and never under Select. `HeaderFitTests` checks Trash against the 222 pt slot; every other screen is checked against its centred room. | Ben, 2026-11-09 | 5 |
| E8 | **Trash follows Passwords' Recently Deleted** (supersedes B15's subtext and E7). The bar subtext is the count and the 30 days, "7 scans · 30 days" ("No scans" when empty, and "2 selected" while selecting), which fits centred. **The grid headers drop "Kept" in the same way:** "23 scans · 3 months", "6 scans · Forever", and "No scans · 1 week" when empty. The Settings › Collections rows keep their "Kept …" wording. A rounded notice sits first in the content, above the tiles, and scrolls with them: "Scans stay in Trash for 30 days, then they’re permanently deleted." It's hidden when Trash is empty, because the empty state already says it. | Ben, 2026-11-09 (from his Passwords screenshot) | 5 |
