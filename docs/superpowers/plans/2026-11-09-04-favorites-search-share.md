# Plan 4 · Favorites, search and share Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Every control Plans 1 and 2 hid "for later plans" now works. You can favourite a scan from the viewer and find it one tap from Home (02-01), in a Favorites grid in your own order, new ones last (05-07, 05-09), and with its heart still on in Trash. Search finds any scan by its title or the words on it, with recent searches, recently viewed scans and collection filters (08-01…08-08). There is no sort control (B10): grids stay newest first, and Favorites keeps your own order, which you drag to change. The viewer shares a scan as a PDF and its More menu saves to Photos or Files or copies the text (06-01, 06-03). A selection (from #68) can be shared and favourited too.

**Architecture:** One new column, `favoriteOrder`, in a `SchemaV3` with a lightweight migration (nil means not a favourite; lower comes first in Favorites). Everything else is pure, Fast-tested logic in `ScreenModels`: `SearchMatch` ranks scans and cuts the bold snippet; `SearchHistory` keeps recent searches and recently viewed scans in `UserDefaults`; `FavoriteReorder` turns a drag into a new order. `Library` gains `ScanExport` (a PDF built page by page off the main actor, Mac-buildable so Fast tests it) and `ScanPDF`, a `Transferable` that `ShareLink` and `fileExporter` both take. Screens add the heart, the drag in Favorites, Home's Favorites row, the Search screen and the viewer's Share and More. Two timeboxed spikes (Task 1) settle how Search is presented and whether iOS 27's `reorderable()` grid drag lives with the tile's long-press menu, before any view work.

**Tech Stack:** Swift 6, SwiftUI (our own search field and `AppRoute.search`, E1; `reorderable()` and `reorderContainer(for:)` (iOS 27), `ShareLink`, `fileExporter`, `Menu`), SwiftData (`VersionedSchema`, lightweight stage), CoreGraphics and ImageIO (PDF), CoreTransferable, Photos (add-only), UIKit (`UIPasteboard`), Swift Testing, XCTest (UI), swift-snapshot-testing 1.19.7.

**Spec:** `docs/superpowers/specs/2026-10-10-filing-cabinet-requirements.html` (section 03 stories 3, 5, 6, 8, 9, 12; section 05 "Pinning becomes Favorites"; section 06 Search, Trash, Accessibility, Haptics); `design/` (02-01…02-07, 05-07…05-12, 06-01, 06-03, 06-05, 08-01…08-08, 09-01, 09-05, 12-01, 12-02) and the component sources `Home.dc.html`, `Collection.dc.html`, `ScanView.dc.html`, `Search.dc.html`, `Trash.dc.html`; `docs/superpowers/specs/2026-10-31-engineering-foundations-design.md` (how); issue #68 (Select on the grids) as merged. No separate design spec: the requirements and mocks settle the product, and the decision rows below settle the rest. Executors also read Plan 3 (`docs/superpowers/plans/2026-11-08-03-viewer-and-header-polish.md`) for the conventions this plan continues, and Plan 2 for the schema migration task.

**Status:** Approved by Ben on 2026-11-10, after his answers (B7–B11). No app code written yet. PR #76 (Plan 3) and PR #78 (#68 grid Select) merged on 2026-11-10. Execution starts after the test-improvements PR (`make affected`, `make retest`, the run policy in AGENTS.md) merges, because both share one simulator and Mac.

---

## Questions for Ben

None open. All four were answered on 2026-11-10 (B7–B10, under Agreed).

---

## Decisions

### Agreed with Ben

| # | Decision | Where it lands |
|---|---|---|
| B1 | **Scope (Ben's roadmap, 2026-11-09):** Plan 4 is favourites, search and share; Plan 5 is Apple Intelligence; Plan 6 is first launch and system, then TestFlight (Roadmap). | whole plan |
| B2 | **Select on the grids (#68) ships before this plan**, in the small batch with #74 and #75. Plan 4 builds on it: a selection can be shared and favourited (Task 12). | 12 |
| B3 | **Out of scope:** Apple Intelligence (Plan 5); the welcome, Send feedback, the Scan control, Shortcuts ("Find a scan"), Spotlight and the app icon (Plan 6). | none |
| B4 | **Plans 1–3's decisions stand**, including Plan 3's E9 (the header is the system bar's own titles, no custom views in title slots) and E8 (grid subtexts "23 scans · 3 months"). | all |
| B5 | **Motion and look are judged on Ben's phone** (`make device`), with fast build-to-phone rounds for small visual fixes, not long simulator checks. | 13 |
| B6 | **No new accessibility-audit exemptions without Ben's OK;** any he approves is narrow and listed in #59. | all |
| B7 | **Share sends a PDF** (was Q1; Ben, 2026-11-10): one PDF per scan; pages as pictures go through More › Save to Photos (M10, M11). | 10, 11, 12 |
| B8 | **New favourites go last, and there is no setting for it** (was Q3; Ben, 2026-11-10). At first Ben asked for a First/Last setting. Once Sort was dropped (B10), he dropped the setting too: "if you can drag the favorite into a different spot, I think we're totally fine without it… new favorites should probably be the last, not first." | 2 |
| B11 | **Two favourites never share a number, and nothing crashes if they somehow do** (Ben, 2026-11-10). The store enforces it (M3). If a tie ever turns up, the tied favourites are shown one after the other, and the next write renumbers them. | 2, 3 |
| B9 | **Search's presentation is decided after Task 1's spike** (was Q4; Ben, 2026-11-10). Keep 02-01's look, with the field under the title, for now. Ben may later move search to the bottom if Apple Intelligence makes search good. That is a later spike, not this plan, and not an issue yet. | 1, 9 |
| B10 | **No Sort** (was Q2; Ben, 2026-11-10, after the high-fidelity mocks: "I don't think we need the sort. I don't think it's gonna add much for us."). Neither 05-01's sort button nor 05-08's menu is built. Every grid stays newest first, and Favorites is always in your own order, dragged. The bar keeps #68's Select alone. | 3, 6 |
| B12 | **The Select bar is A1** (was P4; Ben, 2026-11-10, from the mock https://claude.ai/artifact/4ANmKiX4mA8oraWp4m3Vnm): Share in a 56 pt glass circle at the leading edge, Move to Trash in the middle as a regular Liquid Glass pill with ink text (not the filled black pill), Favorite in a 56 pt glass circle at the trailing edge. Ben: "I don't really like the dark and white buttons down there." Where "Move 387 to Trash" doesn't fit (thousands, larger text), the pill says "Move to Trash"; the count is under the title. | 12 |
| B13 | **Home's element-less contrast misread under Scan is exempted** (Ben, 2026-11-10, shown Home at the largest text before and after the search field: "Just exempt it."). The field and the Favorites row make Home taller, so a collection label lands under the opaque Scan pill and iOS 27's audit reports low contrast with no element. A narrow `home-scan-unresolved` exemption: contrast only, no element only, only while Home shows; listed in #59. #83 (the fade behind Scan) is the likely real fix later. | 9, 13 |

### My calls (not discussed; veto any before its task starts)

| # | Call | Task |
|---|---|---|
| M1 | **One column, `favoriteOrder: Int?`, in a new `SchemaV3`.** Nil means not a favourite; lower comes first in Favorites. One value can't disagree with itself, the way a flag and a separate rank could. V2 → V3 is a lightweight stage, proven on a real V2 store file as Plan 2 proved V1 → V2. | 2 |
| M2 | **Favourites follow the scan everywhere:** Move to Trash and Restore keep `favoriteOrder` (requirements 12: "come back as favourites"), so a restored favourite returns to its old place in Favorites. A favourite expires like any other scan. Delete now and Empty Trash drop it with the record. | 2 |
| M3 | **How `favoriteOrder` stays unique** (B8, B11). Only `ScanStore`, on the main actor, ever sets the number. A new favourite gets one more than the highest number held by any favourite, counting favourites in Trash, so a later Restore can't collide; favouriting several at once keeps their order on screen. A reorder renumbers every favourite, Trash included, 0…n−1: trashed favourites keep their places relative to the others, and the visible ones fill the visible slots in their new order. SwiftData's `.unique` can't guard it, because on a clash it overwrites the existing record instead of failing. So the rules above prevent ties, and a test checks them over random sequences of operations. Reading never trusts it: ties sort by scan date, newest first, then by ID, and the next favourite write renumbers 0…n−1. No `precondition`, no crash. | 2, 3 |
| M4 | **Recent searches and recently viewed scans live in `UserDefaults`** (`SearchHistory`), not the store: they are history, not documents, and keeping them out of `ScanSummary` means opening a scan doesn't refresh every grid. Recently viewed keeps the last 8 scan IDs opened in the viewer from anywhere (not from Trash); Search shows the first 4 still in the library. Recent searches keep the last 3, trimmed, without repeats (ignoring case). | 7 |
| M5 | **A search is saved** when you press Search on the keyboard or open a result (requirements 06), and never from Trash or an empty field. Clear empties recent searches only. | 7, 9 |
| M6 | **Favorites' order is the store's `favoriteOrder`**, lowest first (B10); every other grid stays newest first, as today. Trash keeps its soonest-gone order. | 3, 6 |
| M7 | **No sort control and no remembered order per grid** (B10), so `AppPreferences` gains nothing for ordering and the grid's top bar is #68's, unchanged: no `HeaderFitTests` re-measure. | 6 |
| M8 | **Favorites' order is dragged with iOS 27's `reorderable()`** on the Favorites grid, always on (05-09 without the menu). There's no separate mode: a long press lifts the tile and you drag it. Library grid tiles have no long-press menu (P1). Only Favorites reorders, because every other grid is ordered by date, and not while selecting (P5). The spike (Task 1) proves the drag coexists with scrolling, tapping and Select; if it doesn't, reordering moves into Select mode (drag while selecting), and I'll ask you. | 1, 6 |
| M9 | **Un-favouriting from inside Favorites leaves the tile in place with an empty heart** ("Not a favorite", Collection.dc.html's `unfav` state) until you leave the screen, so a slip is one tap to undo. Home's row and the count update at once. | 5 |
| M10 | **Share sends one PDF per scan** named after its title (Q1); an empty title becomes "Scan", "/" and ":" become "-", and a second "Receipt" in one share becomes "Receipt 2". Each page is the page's own shape, 612 pt (8.5 in) wide, and its image is stored as JPEG at quality 0.85 so the PDF stays small. Pages are drawn one at a time off the main actor, so a 20-page scan never holds more than one full-size page. | 10, 11 |
| M11 | **More holds Save to Photos, Save to Files and Copy Text** (06-03), in that order. Save to Photos adds each page as its own photo, from the original HEIC, asking iOS for add-only access the first time ("Filing Cabinet saves the scans you choose to Photos."). Denied shows an alert like the camera's ("Photos access is off", Open Settings, Cancel). Save to Files offers the same PDF as Share. Copy Text copies every page's recognized text, pages separated by a blank line, and is greyed out when the scan has none. More is hidden in the Trash viewer (a trashed scan is read-only). | 11 |
| M12 | **No note after Save to Photos, Save to Files or Copy Text** (the app's no-notes rule): a success haptic and a VoiceOver announcement ("Saved to Photos", "Copied"). A failure shows the existing edit alert's wording adapted ("Couldn't save to Photos"). | 11 |
| M13 | **Hearts on tiles are marks, not buttons** (Collection.dc.html draws them as labelled spans). You favourite from the viewer, from a selection (Task 12) and with VoiceOver's Favorite action on the tile (requirements 06). Library tiles have no long-press menu (P1). The tile reads "Corner Market, Receipts, 2 days left, favorite". | 4, 5 |
| M14 | **Search is our own field on Home, opening a Search screen** (E1, after Task 1's spike). Home draws the field in its content under the title, as 02-01, never at the bottom where Scan is (Q4). Tapping it pushes `AppRoute.search`: a screen with its own field (focused on arrival), an X that returns to Home, and the Search content (08-01…08-06); it has no Scan. Results push the viewer onto the same stack, and back returns to the results with the query kept. (The system's `.searchable` was tried first and rejected: E1.) | 1, 9 |
| M15 | **Search matches every word you type, anywhere in the title or the text,** ignoring case and accents ("cafe" finds "Café"), so "renew" finds "renewal" and "Renews" (08-03). Scans whose title has every word come first; then the rest; each group newest first. Only library scans are searched, never Trash or expired ones. Results update as you type. | 7, 9 |
| M16 | **The result's second line is the first line of text holding a match, with every match in bold** (08-03). A result found only by its title shows its first line of text, unbolded. The third line is the collection's dot, name and scan day ("Documents · Oct 1", with the year when it isn't this one, as Details does). | 7, 9 |
| M17 | **Copy when a filter has nothing but elsewhere does** (08-05): "No results in Wallet", then "1 scan in Notes mentions “bike”.", "3 scans in Notes and Receipts mention “bike”." or, across three or more collections, "5 scans in other collections mention “bike”.", and a "Search all scans" button that picks All. Result headers: "5 scans", "1 scan", "2 scans in Wallet". | 7, 9 |
| M18 | **Home's Favorites row shows the first 10 favourites** in Favorites' chosen order, scrolling sideways, under the search field (02-01). With 3 or more, "Favorites ›" opens the Favorites grid; with 1 or 2 the header is plain, as Home.dc.html draws it. With none the section is gone (02-02). | 5 |
| M19 | **Analytics stay content-free:** `favoritesChanged(isFavorite:count:)`, `scansExported(kind:count:)` (kind: share, photos, files, copyText) and `searchSaved(resultCount:)`, with the count bucketed (0, 1, 2–5, 6+). Never a title, a word searched or any text. | 3, 7, 11 |
| M20 | **Export files are temporary:** each PDF is written under the app's temporary folder in `Export/<uuid>/`, removed when the share or file export ends and, as a safety net, at launch. | 10, 11 |

### Expected differences from the mocks

- No icon in the Favorites grid's title (Plan 3's M2): 05-07 draws a heart beside "Favorites". Titles rest small in the bar (Plan 3's E9).
- Home's search field is our drawn field (02-01), and Search is a pushed screen with its own field (08-01). The field scrolls away with Home's content; it doesn't pin to the bar.
- No sort button (05-01, 05-07) and no sort menu (05-08): the grid's top bar has #68's Select alone (B10).
- 09-05's Trash viewer shows no heart, and none is added.

---

## Roadmap

| Plan | What you can do when it's merged |
|---|---|
| 0 · Foundation (done) | The loop. |
| 1 · Scan to library (done) | Scan, review, save, browse Home → collection → scan. |
| 2 · Editing and self-cleaning (done) | Details, Move to Trash, Trash, dates-based cleanup with notes and the banner, Settings › Collections. |
| 3 · Viewer and header polish (done) | Passwords-style headers everywhere; Details opens from the pill, Info or a swipe up as one smooth motion. |
| **4 · Favorites, search and share (this plan)** | Favourites on Home and in their own grid, hearts in Trash, your own order in Favorites, search, Share and the More menu, sharing and favouriting a selection. |
| 5 · Apple Intelligence | The suggestion card, shimmer and fallback, the Settings switch, an evaluation suite. |
| 6 · First launch and system | Welcome and the notifications ask, Send feedback, the Scan control, Shortcuts ("Scan a document", "Find a scan"), Spotlight, rating prompt, app icon. Then TestFlight. |

Before release, separately: the issues labelled before-release (#25, #26, #40, #45, #48, #49, #50, #52, #55).

---

## Global Constraints

- Plans 1–3's Global Constraints all still apply. The lines below add to them.
- iOS 27.0 minimum, iPhone, portrait, English. No `#available`. Swift 6, Approachable Concurrency. Banned: `Task.detached`, `@unchecked Sendable`, disabling concurrency checking.
- Headers stay the system bar's own titles (Plan 3 E9): nothing custom in a title slot. Bar buttons are toolbar items.
- Search ranking and snippets only in `SearchMatch`, favourite ordering only in the store and `FavoriteReorder`, PDF building only in `ScanExport`. No view sorts, matches or builds a file.
- Nothing decodes a full-size page on the main actor. Export reads originals through `PageFileStore`'s file URLs, one page at a time.
- Colours, type, spacing and radii only from the generated tokens; a missing one (the tile heart's circle) is added to `design/tokens.json` and generated, never hand-edited. Screen measurements are named private constants citing their mock line.
- Copy is localized in the owning module's `Localizable.xcstrings`, uses middots, never em dashes. Every new string a test measures is built through the model's own text function.
- Snapshots: every changed reference is named in its commit message with the reason. Alerts, menus, the share sheet and the keyboard are never snapshotted.
- UI tests: waits go through `UITests/Support/Wait.swift`; seeded tests through `UITests/Support/Seeding.swift`. Classes launch once; `fresh: true` only when a cold process is the point. Prove logic in Fast, looks in snapshots, and only flows in UI tests. Never widen a threshold or timeout; never ship a known flake.
- No document content in analytics or logs (`privacy: .private` for titles and text, as today).
- Every simulator run uses `SIM_DEVICE="FC iPhone 17"`. A task finishes on `make fast`, `make build`, `make lint`, `make unused`, `make full ONLY="…"` for the classes it lists and `make affected` (AGENTS.md run policy, P9). While fixing, re-run with `make retest ONLY="…"`. Every new UI or snapshot test class gets a line in `scripts/test-map.txt` on the Screens/ScreenModels rows its screen uses, and a new source folder gets its own row; `make test-scripts` checks it. Audit findings come from `make audit-report`.
- Timebox: 45–60 minutes per fix round, then revert to the last green commit and report. Each task is well under 2 hours.

## Review Focus

1. **A favourite goes to Trash and comes back.** Its heart shows on the Trash tile, it isn't on Home or in Favorites while in Trash, and Restore puts it back in its old place. Tests: Task 2 `restoreKeepsFavoriteOrder`; Task 3 `trashedFavoritesLeaveFavorites`; Task 5 `FavoritesJourneyTests.testFavoriteSurvivesTrashAndRestore`.
2. **No two favourites ever share a number** (B11): favouriting, reordering, Trash, Restore and Delete in any mix, and a tie made by hand still reads in a fixed order without crashing. Tests: Task 2 `numbersStayUniqueAcrossRandomOperations`, `tiesReadInAFixedOrder`, `nextWriteRepairsATie`.
3. **Dragging in Favorites.** A drag reorders and the new order shows on Home at once; scrolling, tapping and Select still work (P1, P5); the order survives a relaunch. Tests: Task 6 `FavoriteReorderTests`, `FavoritesJourneyTests.testDragReordersFavorites`.
4. **Search at scale and in odd text.** 2,000 scans with text, accents ("Café"), a scan still being read (empty text), a word in the title and in the text. Results come first by title, never include Trash, and stay quick enough to update per keystroke. Tests: Task 7 `SearchMatchTests`; Task 1's measurement on the phone.
5. **Sharing a 20-page scan.** The PDF is built page by page off the main actor, the share sheet stays responsive, and nothing is left in the temporary folder afterwards. Tests: Task 10 `ScanExportTests.pagesAreDrawnOneAtATime`, `exportFolderIsRemoved`; Task 13's phone check.
6. **Un-favouriting inside Favorites, then leaving.** The tile stays with an empty heart, the subtext count drops, and the tile is gone when you come back. Test: Task 5 `FavoritesGridModelTests.unfavoritedTileStaysUntilLeaving`.

---

## File Structure

No new module; dependencies unchanged (AGENTS.md).

```
Packages/FilingCabinetKit/Sources/
  Core/Accessibility/AccessibilityID.swift          modify: Home.favorites…, Viewer.favorite/share/more, Search.*
  Core/Analytics/AnalyticsEvent.swift               modify: favoritesChanged, scansExported, searchSaved (M19)
  Core/Launch/LaunchOptions.swift                   modify: -SeedFavorites <n>, -Photos authorized|denied
  Library/Records/SchemaV3.swift                    create: ScanRecord + favoriteOrder, CollectionRecord (copies)
  Library/Records/LibraryMigrationPlan.swift        modify: V2 → V3 lightweight stage
  Library/Records/ScanSummary.swift                 modify: favoriteOrder, isFavorite
  Library/Store/ScanLibrary.swift, ScanStore.swift  modify: setFavorite, reorderFavorites, searchTexts, searchText(for:)
  Library/Export/ScanExport.swift                   create: the PDF, page by page; the temporary folder
  Library/Export/ScanPDF.swift                      create: Transferable (FileRepresentation .pdf)
  ScreenModels/Shared/GridKind.swift                modify: .favorites
  ScreenModels/Grid/FavoriteReorder.swift           create: a drag's result as a new order
  ScreenModels/Grid/GridTile.swift, CollectionGridModel.swift, Trash/TrashTile.swift  modify: isFavorite, label
  ScreenModels/Home/HomeModel.swift                 modify: favorites row
  ScreenModels/Search/SearchMatch.swift             create: matching, ranking, snippet
  ScreenModels/Search/SearchHistory.swift           create: recent searches, recently viewed (UserDefaults)
  ScreenModels/Search/SearchModel.swift             create: query, filter, results, empty states
  ScreenModels/Viewer/ViewerModel.swift             modify: isFavorite, toggleFavorite, copyText, export
  Screens/DesignSystem/FavoriteMark.swift           create: the tile's heart
  Screens/Home/HomeFavoritesRow.swift               create: Home's Favorites section
  Screens/Search/SearchView.swift, SearchResultRow.swift, SearchFilterChips.swift  create
  Screens/Viewer/ViewerMoreMenu.swift               create: Save to Photos, Save to Files, Copy Text
  Screens/Viewer/PhotoSaving.swift                  create: the Photos seam (real and launch-flag fake)
  Screens/Viewer/ViewerBottomBar.swift, ViewerView.swift   modify: Share, the heart, More
  Screens/Grid/CollectionGridView.swift, GridTileView.swift, Trash/TrashTileView.swift, Home/HomeView.swift, Root/RootView.swift  modify
App/Info.plist                                      modify: NSPhotoLibraryAddUsageDescription
Packages/FilingCabinetKit/Tests/
  LibraryTests/  MigrationTests (+ Fixtures/LibraryV2.store), ScanStoreFavoriteTests, ScanExportTests
  ScreenModelsTests/  FavoriteReorderTests, FavoritesGridModelTests, SearchMatchTests,
                      SearchHistoryTests, SearchModelTests, ViewerModelTests
SnapshotTests/  Grid, Trash, Home, Viewer snapshot tests (re-recorded); SearchSnapshotTests (new)
UITests/        FavoritesJourneyTests, SearchJourneyTests, ExportJourneyTests (new); BrowseJourneyTests
```

---

## Tasks

### Task 1: Spikes: how Search is presented, and dragging tiles in a grid

**Unit:** Spike (throwaway; nothing from it merges)

**Files:** a throwaway branch `spike/plan-4` off `plan-4`; delete it when the task is done. The lasting output is this plan's "Decided during execution" table (rows E1–E3) and a line for Ben in `.superpowers/for-ben.md`.

- [ ] **Step 1: Search, option A (system).** On Home, `.searchable(text:placement: .navigationBarDrawer(displayMode: .always), prompt: "Search")` with a stand-in Search content shown while `isSearching` (read inside the searchable view). Pass if all hold on the simulator: the field sits under "Filing Cabinet" and collapses with it on scroll, never at the bottom over Scan; tapping it focuses with the keyboard, and the system's X or Cancel leaves search and restores Home; a row of chips can sit under the field (08-01); pushing a viewer from a result and coming back keeps the query and the results; Scan hides while searching (08-01 has none); the header audit stays clean. Note how close the field looks to 02-01 and 08-01 (screenshot both).
- [ ] **Step 2: Search, option B (ours), only if A fails a check.** A drawn field in Home's content (02-01) that pushes `AppRoute.search` with its own field focused and an X (08-01). Check the same points.
- [ ] **Step 3: Reorder.** In the Favorites grid stand-in (a `LazyVGrid` of 10 tiles), `ForEach(...).reorderable()` and `.reorderContainer(for: GridTile.self)`, with #68's Select on the bar (library tiles have no long-press menu, P1). Pass if: a long press lifts the tile and dragging reorders; a plain scroll still scrolls; a tap still opens; in Select mode a tap still ticks and nothing drags (P5); VoiceOver offers the system's move actions. If the drag fights scrolling or tapping, try the drag only from Select mode, and record which.
- [ ] **Step 4: Search speed on the phone.** Seed 2,000 scans with about 1.5 KB of text each (`-SeedScans 2000` with the text from Task 7's seed). Time one `SearchMatch` pass over every scan for a 1-, 3- and 6-letter query with an `OSSignposter` interval; `make device`, 20 runs each, report p95. Under 16 ms keeps M15's "as you type"; over it, Task 9 waits 150 ms after the last keystroke instead. While Ben's phone is away (P8), measure on the simulator and keep "as you type" only under 8 ms; Task 13's phone check confirms it.
- [ ] **Step 5: Record** E1 (Search: A or B, and why), E2 (reorder: in the grid or in Select mode) and E3 (search p95 and M15's path) in "Decided during execution", with a line for Ben in `.superpowers/for-ben.md`. Delete the spike branch. Timebox: 2 hours total; if neither Search option passes, stop and ask Ben.

### Task 2: Library: favourites in the store (SchemaV3)

**Unit:** Library

**Files:**
- Create: `Sources/Library/Records/SchemaV3.swift`, `Tests/LibraryTests/ScanStoreFavoriteTests.swift`, `Tests/LibraryTests/Fixtures/LibraryV2.store` (+ `-shm`, `-wal` if present)
- Modify: `Sources/Library/Records/LibraryMigrationPlan.swift`, `ScanSummary.swift`, `Sources/Library/Store/ScanLibrary.swift`, `ScanStore.swift`, `Sources/TestSupport/FakeLibrary.swift`, `LibrarySeed.swift`, `Sources/Core/Launch/LaunchOptions.swift`
- Test: `Tests/LibraryTests/MigrationTests.swift`, `ScanStoreFavoriteTests.swift`, `FakeLibraryTests.swift`, `Tests/CoreTests/LaunchOptionsTests.swift`

**Interfaces:**
- Produces:
  - `enum SchemaV3: VersionedSchema` (3.0.0): copies of V2's `ScanRecord` (plus `var favoriteOrder: Int? = nil`) and `CollectionRecord`; the typealiases move to V3. V2 stays frozen. `LibraryMigrationPlan` adds `.lightweight(fromVersion: SchemaV2.self, toVersion: SchemaV3.self)`; `makeContainer` builds from V3.
  - `ScanSummary.favoriteOrder: Int?` (`package var`), `isFavorite: Bool { favoriteOrder != nil }`.
  - `ScanLibrary`:
    - `func setFavorite(_ isFavorite: Bool, for ids: [ScanID]) throws(LibraryError)`: new favourites go last. Each takes one more than the highest number held by any favourite, Trash included, keeping the order of `ids` (B8, M3). Un-favouriting sets nil, and an unchanged scan is left alone. If it finds a tie, it renumbers every favourite 0…n−1 in reading order (M3) before adding.
    - `func reorderFavorites(_ ids: [ScanID]) throws(LibraryError)`: `ids` are the visible favourites in their new order. Every favourite, Trash included, is renumbered 0…n−1. Trashed favourites keep their places relative to the others, and the visible ones fill the visible slots in the new order (M3). An id that isn't a favourite is ignored. A visible favourite missing from `ids` keeps its place after them.
    - The reading order every caller uses: `favoriteOrder`, then scan date (newest first), then ID. It is defined once, as `ScanSummary.favoritesOrder` (a sort comparator), so a tie never crashes and always reads the same way (B11).
    - `func searchTexts() -> [ScanID: String]` and `func searchText(for id: ScanID) -> String?` (one fetch each; logged on failure, empty on failure).
  - `LibrarySeed` and `-SeedFavorites <n>`: the first `n` seeded scans are favourites, in seed order.

- [ ] **Step 1: Make the V2 fixture.** On `plan-4` before any change, save a store with three scans (one in Trash, one with a lifespan override) through the current code, as Plan 2's Task 1 made `LibraryV1.store`, and add it to the test resources.
- [ ] **Step 2: Write the failing tests.** `MigrationTests.v2StoreOpensAsV3WithEveryScan` (every scan, Trash day and override survive; no favourites); `v1StoreStillOpens` (the V1 fixture reaches V3). `ScanStoreFavoriteTests`: `favoritingPutsNewOnesLast`, `favoritingSeveralKeepsTheirOrder`, `newFavoriteSkipsNumbersHeldInTrash`, `reorderKeepsTrashedFavoritesInPlace`, `restoredFavoriteNeverSharesANumber`, `numbersStayUniqueAcrossRandomOperations` (a seeded random run of 500 favourite, un-favourite, reorder, trash, restore and delete steps; after each, no two favourites share a number), `tiesReadInAFixedOrder` (hand-made tie: both listed, newest first, no crash), `nextWriteRepairsATie`, `unfavoritingClearsOrder`, `favoritingTwiceChangesNothing`, `reorderSetsTheGivenOrder`, `reorderIgnoresNonFavorites`, `restoreKeepsFavoriteOrder` (Review Focus 1), `moveToTrashKeepsFavoriteOrder`, `deleteNowDropsTheFavorite`, `failedPersistChangesNothing` (inject a failing `persist`, as `ScanStoreEditTests` does), `searchTextsReturnsEveryScansText`. `FakeLibraryTests` mirrors the first four. `LaunchOptionsTests.parsesSeedFavorites`.
- [ ] **Step 3: Run `make fast`.** Expected: FAIL to compile.
- [ ] **Step 4: Implement** SchemaV3, the stage, the summary fields, the store and fake methods, the seed and the flag.
- [ ] **Step 5: Run `make fast`.** Expected: PASS.
- [ ] **Step 6: Commit** `Library: SchemaV3 with favourites; favourite, reorder and search-text reads`.

### Task 3: ScreenModels: Favorites' order and the heart in every grid model

**Unit:** ScreenModels

**Files:**
- Modify: `Sources/ScreenModels/Shared/GridKind.swift`, `Grid/GridTile.swift`, `Grid/CollectionGridModel.swift`, `Trash/TrashTile.swift`, `Trash/TrashModel.swift`, `Localizable.xcstrings`, `Sources/Core/Analytics/AnalyticsEvent.swift`, `ScreenModels/App/AppRoute.swift`
- Test: `Tests/ScreenModelsTests/CollectionGridModelTests.swift`, `TrashModelTests.swift`, `Tests/CoreTests/AnalyticsEventTests.swift`

**Interfaces:**
- Produces:
  - `GridKind.favorites`, `AppRoute.favorites`.
  - `CollectionGridModel` for `.favorites`: the library's favourites in `ScanSummary.favoritesOrder` (M3, M6), title "Favorites", subtitle "10 scans" (no lifespan), mixed dots, empty copy "No favorites yet" · "Tap the heart on a scan to keep it one tap from Home." (Collection.dc.html).
  - `GridTile.isFavorite`, `TrashTile.isFavorite`; each label ends ", favorite" when true (M13).
  - `CollectionGridModel.toggleFavorite(_ id: ScanID)` for the tile's VoiceOver action (P1): a failed write shows the edit alert; sends `favoritesChanged`.
  - `AnalyticsEvent.favoritesChanged(isFavorite:count:)`, `scansExported(kind:count:)`, `searchSaved(resultCount:)` with bucketed counts (M19).

- [ ] **Step 1: Write the failing tests.** `CollectionGridModelTests`: `favoritesGridShowsOnlyFavorites`, `favoritesFollowFavoriteOrder`, `tiedFavoritesBothShow`, `trashedFavoritesLeaveFavorites` (Review Focus 1), `favoritesSubtitleIsTheCount`, `tilesCarryTheirHeart`, `tileLabelSaysFavorite`, `toggleFavoriteFromATile`, `failedToggleShowsTheAlert`. `TrashModelTests.trashTilesKeepTheirHeart`. `AnalyticsEventTests` for the three events' parameters, with no text in any.
- [ ] **Step 2: Run `make fast`.** Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run `make fast`.** Expected: PASS.
- [ ] **Step 5: Commit** `ScreenModels: the Favorites grid in its own order; favourites in grid and Trash models`.

### Task 4: Hearts on tiles, in every grid and in Trash

**Unit:** Screen · Grid and Trash (05-07, 09-01)

**Files:**
- Create: `Sources/Screens/DesignSystem/FavoriteMark.swift`
- Modify: `Sources/Screens/Grid/GridTileView.swift`, `Sources/Screens/Trash/TrashTileView.swift`, `design/tokens.json` (only if the mark's circle colour has no token), `Sources/Core/Accessibility/AccessibilityID.swift`
- Test: `SnapshotTests/GridSnapshotTests.swift`, `SnapshotTests/TrashSnapshotTests.swift`

**Interfaces:**
- Consumes: `GridTile.isFavorite`, `TrashTile.isFavorite`.
- Produces: `FavoriteMark(isFilled: Bool)`: a 26 pt circle 5 pt in from the tile's top-right corner with a white heart (Collection.dc.html lines for the mark; cite them). Hidden from VoiceOver: the tile's label carries "favorite" (M13). The tile's VoiceOver actions gain Favorite / Remove from Favorites in the library grids (Trash keeps Restore and Delete now).

- [ ] **Step 1: Snapshots first.** Seed two favourites into the fixtures of `grid_receipts`, `grid_all` and `trash_list`, and record. Expected: FAIL (no hearts).
- [ ] **Step 2: Implement** the mark and place it on both tile views. Add the tile's VoiceOver favourite action, calling a closure the grid passes (`onToggleFavorite`), wired to `CollectionGridModel.toggleFavorite` (P2).
- [ ] **Step 3: Re-record** `grid_receipts`, `grid_all`, `trash_list` (light, dark, ax5). Open each against 05-07 and 09-01 and list the paths.
- [ ] **Step 4: Run** `make full ONLY="FilingCabinetSnapshotTests/GridSnapshotTests FilingCabinetSnapshotTests/TrashSnapshotTests"`. Expected: PASS.
- [ ] **Step 5: Commit** `Grid, Trash: hearts on favourite tiles`, naming each reference.

### Task 5: The heart in the viewer, Home's Favorites row and the Favorites grid

**Unit:** Screen · Viewer, Home, Grid (06-01, 02-01…02-03, 05-07)

**Files:**
- Create: `Sources/Screens/Home/HomeFavoritesRow.swift`, `Tests/ScreenModelsTests/FavoritesGridModelTests.swift`, `UITests/FavoritesJourneyTests.swift`
- Modify: `Sources/ScreenModels/Viewer/ViewerModel.swift`, `Home/HomeModel.swift`, `Grid/CollectionGridModel.swift`, `Sources/Screens/Viewer/ViewerBottomBar.swift`, `Home/HomeView.swift`, `Root/RootView.swift`, `Grid/CollectionGridView.swift`, `Sources/Core/Accessibility/AccessibilityID.swift`
- Test: `Tests/ScreenModelsTests/ViewerModelTests.swift`, `HomeModelTests.swift`, `SnapshotTests/ViewerSnapshotTests.swift`, `HomeSnapshotTests.swift`, `GridSnapshotTests.swift`

**Interfaces:**
- Consumes: `ScanLibrary.setFavorite`, Task 3's Favorites order.
- Produces:
  - `ViewerModel.isFavorite`, `toggleFavorite()` (a failed write shows the edit alert, as Move to Trash does; sends `favoritesChanged`).
  - The bottom bar's centre pill holds the heart left of Info (06-01): `heart` / `heart.fill`, labelled "Add to Favorites" / "Remove from Favorites" with the selected trait, a light haptic on change (requirements 06 Haptics). Not in the Trash viewer (09-05).
  - `HomeModel.favorites: [HomeFavorite]` (id, title) for the first 10 in Favorites' order, and `favoritesOpensGrid` (3 or more, M18). `HomeFavoritesRow`: "Favorites" (title2 serif) as a link with a chevron or plain, then the sideways row of 148 × 96 pt thumbnails with titles under them (Home.dc.html `cardW`, `cardH`; cite the lines). Tapping a card opens the viewer; the link opens `AppRoute.favorites`.
  - `CollectionGridModel` for `.favorites` keeps tiles un-favourited since the screen appeared, with an empty heart and "Not a favorite", until the screen goes (M9). The count in the subtitle is live.

- [ ] **Step 1: Write the failing model tests.** `ViewerModelTests.toggleFavoriteFlipsIt`, `failedFavoriteShowsTheAlert`. `HomeModelTests.favoritesRowFollowsFavoritesOrder`, `rowShowsAtMostTen`, `linkOnlyFromThree`, `noFavoritesNoRow`. `FavoritesGridModelTests.unfavoritedTileStaysUntilLeaving` (Review Focus 6), `subtitleCountIsLive`.
- [ ] **Step 2: Run `make fast`.** Expected: FAIL. Implement the models; `make fast` PASS.
- [ ] **Step 3: UI tests** in `FavoritesJourneyTests` (`-SeedScans 6`): `testHeartingAScanPutsItOnHome` (open a scan, tap the heart, back: Home shows the card; the grid tile has a heart); `testFavoriteSurvivesTrashAndRestore` (favourite, Move to Trash, Trash's tile has a heart, Restore, the card is back on Home) (Review Focus 1); `testFavoritesLinkOpensTheGrid` (`-SeedFavorites 3`); `testNewFavoriteGoesLast` (`-SeedFavorites 3`: favourite a fourth scan; it is the last card on Home and the last tile in Favorites). Run them. Expected: FAIL.
- [ ] **Step 4: Implement** the views.
- [ ] **Step 5: Snapshots.** Re-record `viewer_lease`, `viewer_receipt` (the heart, filled on the lease as 06-01), `home_scans` and add `home_favorites` (3 favourites, the link) and `home_two_favorites` (plain header), and add `grid_favorites` (05-07) and `grid_favorites_empty`, each light, dark, ax5. Open each against 06-01, 02-01, 02-03, 05-07, 05-12, 12-01 and list the paths.
- [ ] **Step 6: Run** `make full ONLY="FilingCabinetSnapshotTests/ViewerSnapshotTests FilingCabinetSnapshotTests/HomeSnapshotTests FilingCabinetSnapshotTests/GridSnapshotTests FilingCabinetUITests/FavoritesJourneyTests FilingCabinetUITests/HomeJourneyTests"`. Expected: PASS, with both Home largest-text audits.
- [ ] **Step 7: Commit** `Favourites: the viewer's heart, Home's row and the Favorites grid`, naming each reference.

### Task 6: Your own order in Favorites, by drag

**Unit:** Screen · Grid (05-09, without the sort menu: B10); ScreenModels

**Files:**
- Create: `Sources/ScreenModels/Grid/FavoriteReorder.swift`, `Tests/ScreenModelsTests/FavoriteReorderTests.swift`
- Modify: `Sources/Screens/Grid/CollectionGridView.swift`
- Test: `UITests/FavoritesJourneyTests.swift`

**Interfaces:**
- Consumes: `ScanLibrary.reorderFavorites`, E2. Read #68's grid, as merged, first (its long-press menu and Select mode). E2 was proven on plain rectangles: confirm the long-press lift still works on the real `GridTileView` (its button, overlays and accessibility element) before building on it.
- Produces:
  - `enum FavoriteReorder { static func order(_ ids: [ScanID], moving sources: [ScanID], before destination: ScanID?) -> [ScanID] }`: the moved ids keep their own order and land before `destination` (nil: at the end).
  - In Favorites (E2's path), the grid's `ForEach` is `.reorderable()` and the grid a `.reorderContainer(for: GridTile.self)` that applies `FavoriteReorder` and calls `reorderFavorites`. No other grid reorders, and Favorites doesn't while selecting (P5). A light haptic as a tile drops.

- [ ] **Step 1: Write the failing tests.** `FavoriteReorderTests`: `moveOneForward`, `moveOneToEnd`, `moveSeveralKeepsTheirOrder`, `moveOntoItselfChangesNothing`.
- [ ] **Step 2: Run `make fast`.** Expected: FAIL. Implement `FavoriteReorder`; `make fast` PASS.
- [ ] **Step 3: UI test.** `FavoritesJourneyTests.testDragReordersFavorites` (`-SeedFavorites 4`: drag the 3rd tile before the 1st; it's first, Home's first card matches, and after a relaunch it's still first) (Review Focus 3). Run. Expected: FAIL.
- [ ] **Step 4: Implement** the drag. VoiceOver (E2, not verified in the spike): with VoiceOver on in the simulator, check that a Favorites tile offers the system's move actions. If it offers none, add explicit `accessibilityAction`s ("Move earlier", "Move later") that call `FavoriteReorder`, with a UI test. Either way, Task 13's phone check (g) confirms.
- [ ] **Step 5: Run** `make full ONLY="FilingCabinetSnapshotTests/GridSnapshotTests FilingCabinetUITests/BrowseJourneyTests FilingCabinetUITests/FavoritesJourneyTests"`. Expected: PASS, including `testAuditAtLargestTextOfAGrid`; no snapshot changes.
- [ ] **Step 6: Commit** `Favorites: your own order, by drag`.

### Task 7: ScreenModels: search matching, history and the Search model

**Unit:** ScreenModels

**Files:**
- Create: `Sources/ScreenModels/Search/SearchMatch.swift`, `SearchHistory.swift`, `SearchModel.swift`, and their tests `Tests/ScreenModelsTests/SearchMatchTests.swift`, `SearchHistoryTests.swift`, `SearchModelTests.swift`
- Modify: `Sources/ScreenModels/Localizable.xcstrings`, `Sources/TestSupport/LibrarySeed.swift` (seeded scans get a few lines of synthetic text), `Sources/ScreenModels/Viewer/ViewerModel.swift` (records a view)

**Interfaces:**
- Consumes: `ScanLibrary.searchTexts()`, `LibraryShelf.visible`, `DayText`, `CollectionText`.
- Produces:
  - `struct SearchMatch: Sendable` with `static func terms(_ query: String) -> [String]` (split on whitespace, empties dropped) and `static func match(title: String, text: String, terms: [String]) -> SearchHit?`. `SearchHit { titleMatches: Bool; snippet: String; bold: [Range<String.Index>] }`. Every term must be in the title or the text, ignoring case and accents (M15); the snippet is per M16, trimmed to one line.
  - E3's matching: fold each title and text once (`folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)`), in memory, when the model reads the texts, and refold only the scans that change (an edit, a new scan, Trash). The fold is not persisted. Match each folded term with `memmem` over the folded UTF-8 bytes; never `range(of:options:)` per scan per keystroke (E3). Folding can change length (ß becomes ss, ligatures expand), so offsets in folded text don't map to the original: M16's snippet and bold ranges are computed on the original line with `range(of:options: [.caseInsensitive, .diacriticInsensitive])`, and only for the scans that matched. `match` takes the folded forms alongside the originals; the exact signature is the implementer's.
  - `@Observable final class SearchHistory` (`UserDefaults`): `recentSearches: [String]` (3, M4), `record(search:)`, `clearSearches()`, `recentlyViewed: [ScanID]` (8), `record(viewed:)`.
  - `@Observable final class SearchModel`: `query`, `filter: BuiltInCollection?` (nil is All), `results: [SearchResult]` (id, title, snippet with bold ranges, collection, day text), `header` ("5 scans", "2 scans in Wallet"), `state` (`.firstUse`, `.beforeTyping(viewed: [SearchViewed], searches: [String])`, `.results`, `.nothingHere(title:body:)`, `.nothingAnywhere(title:body:)`) with M17's copy, `searchAll()`, `submit()` and `opened(_:)` (both save the search, M5, and send `searchSaved`). Texts are read once when the model is made and again when the library's scans change.
  - `ViewerModel` records the scan in `SearchHistory` when it opens in library mode.

- [ ] **Step 1: Write the failing tests.** `SearchMatchTests`: `everyWordMustMatch`, `matchesInsideWords` ("renew" → "renewal", "Renews"), `ignoresCaseAndAccents` ("cafe" → "Café"), `foldsSharpS` ("strasse" finds "Straße", bolded on the original), `multiWordAcrossTitleAndText`, `snippetIsTheFirstMatchingLine`, `everyMatchIsBold`, `titleOnlyMatchShowsFirstLineUnbolded`, `emptyTextStillMatchesByTitle`. `SearchHistoryTests`: `keepsThreeNewestWithoutRepeats`, `ignoresCaseForRepeats`, `trimsAndSkipsEmpty`, `clearRemovesSearchesOnly`, `keepsEightViewed`. `SearchModelTests`: `titleMatchesComeFirst`, `newestFirstWithinEach`, `neverSearchesTrash`, `filterLimitsResults`, `headerCopy`, `nothingHereNamesWhereElse` (one, two and three collections, M17), `nothingAnywhereCopy`, `firstUseShowsOnlyFilters`, `beforeTypingShowsFourViewedStillInLibrary`, `submitSavesTheSearch`, `openingAResultSavesIt`, `noAnalyticsCarriesText`.
- [ ] **Step 2: Run `make fast`.** Expected: FAIL to compile.
- [ ] **Step 3: Implement.** Seed text: each synthetic scan gets the lines its synthetic page shows (from `SyntheticPages`), so UI tests can search for words that are really there.
- [ ] **Step 4: Run `make fast`.** Expected: PASS.
- [ ] **Step 5: Commit** `ScreenModels: search matching, history and the Search model`.

### Task 8: Search speed guard

**Unit:** ScreenModels · Library

**Files:**
- Create: `Tests/ScreenModelsTests/SearchScaleTests.swift`
- Modify: `Sources/ScreenModels/Search/SearchModel.swift` (only per E3), `Sources/ScreenModels/ScreenModelsLog.swift` (a `Search` signpost)

**Interfaces:**
- Consumes: E3.
- Produces: a signposted interval around each search pass, so a phone trace shows it. No timing assertion in Fast (timings flake on CI); the test proves the work is linear and bounded instead.

- [ ] **Step 1: Write the test** `SearchScaleTests.matchingVisitsEachScanOnce`: with 2,000 synthetic scans, a counting `SearchMatch` wrapper sees each scan's text exactly once per query change, and a filter change reuses the last pass rather than matching again.
- [ ] **Step 2: Run `make fast`.** Expected: FAIL. Implement the reuse (and E3's 150 ms wait only if E3 asked for it). `make fast` PASS.
- [ ] **Step 3: Commit** `ScreenModels: search visits each scan once per query; signposted`.

### Task 9: The Search screen

**Unit:** Screen · Search (08-01…08-08, 02-01)

**Files:**
- Create: `Sources/Screens/Search/SearchView.swift`, `SearchResultRow.swift`, `SearchFilterChips.swift`, `SnapshotTests/SearchSnapshotTests.swift`, `UITests/SearchJourneyTests.swift`
- Modify: `Sources/Screens/Home/HomeView.swift`, `Sources/Screens/Root/RootView.swift`, `Sources/Core/Accessibility/AccessibilityID.swift` (`Search.field`, `.close`, `.chip.<key>`, `.resultPrefix`, `.viewedPrefix`, `.recentPrefix`, `.clear`, `.searchAll`), `ScreenModels/App/AppRoute.swift` (a `search` case; `RootView.screen(_:)`, the only exhaustive switch over `AppRoute`, gets its destination)

**Interfaces:**
- Consumes: `SearchModel`, `SearchHistory`, E1, `ThumbnailView`, `CollectionDot`.
- Produces:
  - Home's drawn search field (02-01), under the title in Home's content, pushing `AppRoute.search` (M14, E1). The Search screen has its own field, focused on arrival (`@FocusState` set in `onAppear` worked during the push in the spike), and an X that pops back to Home; it has no Scan (08-01). Home must still rest with its large title where it does without the field: the spike's B rested it visibly lower than before (E1), so compare `home_scans` against 02-01 (title position and the gap under the gear) and treat a lower title as a header-rest bug.
  - `SearchFilterChips`: All, then each collection with its dot, pill-shaped, scrolling sideways (08-01); the chosen one ink-filled. Each is a button with the selected trait.
  - Before typing: "Recently viewed" (one row of up to 4 thumbnails with dot and title, 08-02) and "Recent searches" with Clear (rows with a clock). Tapping a search fills the field.
  - Results: the header line, then one card of rows (08-03): 52 × 58 pt thumbnail, title, snippet with bold, dot · collection · day, chevron. Each row is one VoiceOver element ("Lease 2026, Documents, October 1, Re: Lease renewal…").
  - The empty states (08-05, 08-06) with the magnifier, M17's copy and "Search all scans".

- [ ] **Step 1: UI tests** in `SearchJourneyTests` (`-SeedScans 12`): `testSearchFindsAScanByItsText` (type a word from one seeded scan's text; it's the first result; open it; back shows the results; leave search and come back: the word is a recent search, the scan is recently viewed); `testFilterAndSearchAll` (a word only in Notes, filter Wallet: "No results in Wallet", Search all scans shows it); `testClearRemovesRecentSearches`. Run. Expected: FAIL.
- [ ] **Step 2: Implement.**
- [ ] **Step 3: Snapshots** (never with the keyboard): `search_first_use`, `search_before_typing`, `search_results`, `search_filtered`, `search_nothing_here`, `search_nothing_anywhere`, each light, dark (08-07, 08-08) and ax5, hosted with a fixed query. Re-record `home_scans` and `home_favorites` for the search field. Open each against 08-01…08-08 and 02-01 and list the paths. Expected differences: no keyboard.
- [ ] **Step 4: Run** `make full ONLY="FilingCabinetSnapshotTests/SearchSnapshotTests FilingCabinetSnapshotTests/HomeSnapshotTests FilingCabinetUITests/SearchJourneyTests FilingCabinetUITests/HomeJourneyTests"`. Expected: PASS, with a new `testAuditAtLargestTextSearch` clean (a failure goes to Ben, not into an exemption). Audit with the keyboard down: the spike found the keyboard's own suggestion bar fails the audit while typing.
- [ ] **Step 5: Commit** `Search: recent searches, recently viewed, filters and ranked results`, naming each reference.

### Task 10: Library: a scan as a PDF

**Unit:** Library

**Files:**
- Create: `Sources/Library/Export/ScanExport.swift`, `ScanPDF.swift`, `Tests/LibraryTests/ScanExportTests.swift`
- Modify: `Sources/Library/Store/ScanStore.swift` (launch cleanup also clears `Export/`, M20)

**Interfaces:**
- Consumes: `PageFileStore` (page file URLs), `ImageCoding`.
- Produces:
  - `struct ScanExport: Sendable` with `@concurrent func pdf(for scan: ScanSummary, named: String) async throws(LibraryError) -> URL`: writes `tmp/Export/<uuid>/<name>.pdf`, drawing one page at a time (M10): read the HEIC, re-encode as JPEG 0.85, draw it through a JPEG data provider so the PDF keeps the JPEG, release it before the next page. `static func fileName(for title: String, taken: Set<String>) -> String` (M10's rules). `func removeAll()`.
  - `struct ScanPDF: Transferable` (`FileRepresentation(exportedContentType: .pdf)`, made lazily when the share sheet or file exporter asks; `suggestedFileName`), used by Share, Save to Files and a selection's Share.

- [ ] **Step 1: Write the failing tests** with `SyntheticPages`: `onePagePerScanPage`, `pageShapeFollowsTheImage` (612 pt wide, the image's aspect), `pagesAreJPEG` (the PDF's image streams use DCTDecode), `pagesAreDrawnOneAtATime` (a counting image source never has two pages open, Review Focus 5), `fileNames` ("", "a/b", "Receipt" twice), `exportFolderIsRemoved`, `launchCleanupClearsExports`, `missingPageFileThrows`.
- [ ] **Step 2: Run `make fast`.** Expected: FAIL to compile.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run `make fast`.** Expected: PASS.
- [ ] **Step 5: Commit** `Library: a scan as a PDF, page by page, in a temporary folder`.

### Task 11: The viewer's Share and More

**Unit:** Screen · Viewer (06-01, 06-03)

**Files:**
- Create: `Sources/Screens/Viewer/ViewerMoreMenu.swift`, `PhotoSaving.swift`, `UITests/ExportJourneyTests.swift`
- Modify: `Sources/Screens/Viewer/ViewerBottomBar.swift`, `ViewerView.swift`, `Sources/ScreenModels/Viewer/ViewerModel.swift`, `Sources/Core/Launch/LaunchOptions.swift` (`-Photos authorized|denied`), `App/Info.plist`, `Sources/Screens/Localizable.xcstrings`, `Sources/Core/Accessibility/AccessibilityID.swift`
- Test: `Tests/ScreenModelsTests/ViewerModelTests.swift`, `SnapshotTests/ViewerSnapshotTests.swift`

**Interfaces:**
- Consumes: `ScanPDF`, `ScanExport`, `ScanLibrary.searchText(for:)`.
- Produces:
  - Share at the bar's leading edge: a 56 pt glass `ShareLink(item: ScanPDF, preview:)` (06-01), labelled "Share". Not in the Trash viewer.
  - `ViewerMoreMenu`: a `.topBarTrailing` "•••" toolbar item (`ellipsis`, labelled "More") with Save to Photos, Save to Files and Copy Text, each with its symbol (06-03) (M11). Hidden from Trash.
  - `protocol PhotoSaving: Sendable { func save(pages: [URL]) async throws(PhotoSaveError) }` with the Photos add-only implementation and a launch-flag fake (UI tests never see a system prompt). A real seam: a test needs it.
  - `ViewerModel.copyText(to pasteboard: (String) -> Void) -> Bool`, `canCopyText`, and the announcements (M12); `scansExported` on each.
  - The header pill keeps its 240 pt cap and stays centred between back and More (check at the default size and ax5).

- [ ] **Step 1: Write the failing model tests:** `copyTextJoinsPagesWithABlankLine`, `copyTextDisabledWithoutText`, `exportsSendAnalyticsWithoutText`.
- [ ] **Step 2: Run `make fast`.** Expected: FAIL. Implement the model; `make fast` PASS.
- [ ] **Step 3: UI tests** `ExportJourneyTests`: `testShareOpensTheShareSheet` (the system share sheet appears with a PDF named after the scan; close it); `testMoreMenuOffersThreeActions`; `testSaveToPhotosDeniedShowsTheAlert` (`-Photos denied`); `testTrashViewerHasNoShareOrMore`. Run. Expected: FAIL.
- [ ] **Step 4: Implement** the views, the seam, `NSPhotoLibraryAddUsageDescription` ("Filing Cabinet saves the scans you choose to Photos.") and the denied alert.
- [ ] **Step 5: Re-record** `viewer_lease`, `viewer_receipt` (Share and More now shown) light, dark, ax5; `trash_viewer` must not change. Open each against 06-01, 06-02, 06-05 and list the paths.
- [ ] **Step 6: Run** `make full ONLY="FilingCabinetSnapshotTests/ViewerSnapshotTests FilingCabinetUITests/ExportJourneyTests FilingCabinetUITests/DetailsJourneyTests FilingCabinetUITests/TrashJourneyTests"`. Expected: PASS. CI's `SHARD=main` takes `ExportJourneyTests` by itself (P6); confirm with `make -n ci-sim SHARD=main`.
- [ ] **Step 7: Commit** `Viewer: Share as PDF; More saves to Photos or Files and copies the text`, naming each reference.

### Task 12: A selection can be shared and favourited

**Unit:** Screen · Grid (on #68's Select)

**Files:**
- Modify: `Sources/Screens/Grid/CollectionGridView.swift` (`moveBar`), `Sources/ScreenModels/Grid/CollectionGridModel.swift`, `Sources/ScreenModels/Shared/ScanSelection.swift` if needed, `Sources/Core/Accessibility/AccessibilityID.swift`
- Test: `Tests/ScreenModelsTests/CollectionGridModelTests.swift`, `UITests/FavoritesJourneyTests.swift`, `SnapshotTests/GridSnapshotTests.swift`

**Interfaces:**
- Consumes: #68's selection (the selected ids, its bottom bar), `ScanLibrary.setFavorite`, `ScanPDF`.
- Produces: the selection's bar per B12 (A1): Share (`ShareLink(items:)`, one PDF per scan, M10's names) in a glass circle leading, Move to Trash as a glass pill with ink text in the middle (no longer `FilledPillButton`; Scan keeps it), and Favorite in a glass circle trailing: "Favorite" when any selected scan isn't one, "Remove from Favorites" when all are. Favouriting ends select mode, as #68's other actions do. No long-press menu is added (P1).

- [ ] **Step 1: Read #68 as merged** and fit this task's names to it. #68's bar is one filled pill, Move to Trash, in Scan's place (`CollectionGridView.moveBar`). Ben chose the layout (B12, A1); no stop needed.
- [ ] **Step 2: Write the failing tests:** the selection model's `favoriteLabelFollowsTheSelection` and `favoritingSeveralKeepsScreenOrder`; `FavoritesJourneyTests.testFavoritingASelection` (select 3 in All Scans, Favorite, each tile has a heart and Home's row has 3 cards). Run. Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Re-record** `grid_select` (light, dark, ax5) with A1's bar, and add a model test that the pill's title drops the count when it doesn't fit (or the view picks "Move to Trash" via `ViewThatFits`); open them against the A1 mock and list the paths.
- [ ] **Step 5: Run** `make fast` and `make full ONLY="FilingCabinetSnapshotTests/GridSnapshotTests FilingCabinetUITests/FavoritesJourneyTests FilingCabinetUITests/BrowseJourneyTests"`. Expected: PASS.
- [ ] **Step 6: Commit** `Grid: share and favourite a selection`, naming each reference.

### Task 13: Docs, the full suite and the phone check

**Unit:** Docs · Device

**Files:**
- Modify: `AGENTS.md` (map: `Library/Export`, `ScreenModels/Search`, `Screens/Search`; launch flags `-SeedFavorites`, `-Photos`), `CLAUDE.md` ("Where we are"), this plan's Decisions (everything decided during execution)

- [ ] **Step 1: Update the docs** listed above; check every path and command named in `AGENTS.md` exists.
- [ ] **Step 2: One local `make full ALL=1`** (a bare `make full` refuses; P9), then push and mark the PR ready so CI runs the simulator suite. Dispatch `ios-verifier` for the evidence.
- [ ] **Step 3: Phone check with Ben** (`make device`, phone unpaired for camera use), fast rounds for small fixes (B5). (a) Heart a scan in the viewer: the light tap, the card on Home, the tile's heart. (b) Favorites: drag to reorder with a long press, check Home follows, un-favourite inside and leave. (c) Move a favourite to Trash, see its heart, restore it. (d) Search: type, filter, open a result and come back, recent searches and recently viewed, with about 200 seeded scans. (e) Share a 20-page scan to Files and to Messages; Save to Photos (the first-time ask), Copy Text and paste in Notes. (f) A selection: share and favourite. (g) VoiceOver: a tile reads "favorite" and offers Favorite; a Favorites tile can be moved (the system's move actions or Task 6's own, E2); the heart button's state; search rows. (h) Dark mode and the largest text on Home, Favorites and Search. Note anything Ben changes in the Decisions table.
- [ ] **Step 4: Commit** `Docs: Plan 4 favourites, search and share`. The PR body names what the plan made visible (Plan 1's A2 and Plan 2's M14 controls). It merges after CI's Full suite and the whole-branch review pass.

---

### Decided during execution

| # | Decision | Whose | Task |
|---|---|---|---|
| P1 | Library grid tiles get no long-press menu. #68 added none and the mocks draw one only in Trash (09-03). You favourite from the viewer, a selection and VoiceOver; the drag in Favorites is a plain long-press lift. | Mine, pre-flight 2026-11-10; Ben may veto | 1, 3, 6, 12 |
| P2 | A tile's VoiceOver Favorite calls `CollectionGridModel.toggleFavorite`, so the alert and analytics live in one place. | Mine, pre-flight | 4 |
| P3 | Three Review Focus numbers in Tasks 5, 6 and 10 corrected (6, 3, 5). | Mine, pre-flight | 5, 6, 10 |
| P4 | Task 12's bar needed Ben's choice: settled as B12 (A1). | Ben, 2026-11-10 | 12 |
| P5 | Favorites doesn't drag while selecting: a tap ticks, as #68. | Mine, pre-flight | 1, 6 |
| P6 | CI's `SHARD=main` already takes every class outside the scan and browse shards, so `ExportJourneyTests` needs no Makefile change. | Mine, pre-flight | 11 |
| P7 | (Withdrawn: Ben chose A1, B12, so Task 12 doesn't wait.) | Mine, pre-flight | 12 |
| P8 | With Ben's phone away, Task 1's search timing runs on the simulator with half the budget (8 ms) as margin; the phone number is taken in Task 13 and E3 updated. | Mine, pre-flight | 1, 8, 13 |
| P9 | PR #81 brought the run policy: `make retest` while fixing, `make affected` at each task's end, `make full ALL=1` once before the PR. New test classes and source folders go in `scripts/test-map.txt`. The two audit exemptions waiting on Ben (grid-select-pill, dark-viewer-unresolved) are left as they are. | Mine, at the merge of main | all |
| E1 | **Search is ours (option B): a drawn field in Home's content (02-01) pushes `AppRoute.search`, a screen with its own field focused on arrival, an X and the chips (08-01).** Option A (`.searchable` in the bar drawer) looked as close to 08-01 and handled focus, X, chips, Scan and back-from-viewer. It failed because our header doesn't know the drawer: on a cold launch Home rested with the small title (`HeaderSettling.arrive` pulls only during a push, and with the drawer UIKit doesn't open large by itself). A one-line spike change fixed that rest, but then left "Collections" under the field at the largest text (audit contrast). That second failure comes from the spike's change, not from A as such. Making A work means changing the header machinery every screen uses. B passed the checks without touching it (field, focus, X, chips, back keeps query and results, no Scan; audits clean at the default and largest text, per the audit report). One known gap: B's large title rests visibly lower than Home's does without the field, with a gap under the gear; the cause wasn't found, and Task 9 checks it against 02-01. | Mine, Task 1 spike 2026-11-10 | 9 |
| E2 | **Favorites reorders in the grid, always on (M8 stands): `ForEach(...).reorderable()` with `.reorderContainer(for:isEnabled: !isSelecting)`.** On the simulator a long press lifted a tile and dragging moved it (order changed); a plain drag scrolled without reordering; a tap opened; in Select mode a tap ticked and a long-press drag moved nothing (P5). Not verified: VoiceOver's move actions. The UI tree that XCUITest and XcodeBuildMCP can see doesn't list custom actions. Task 6 checks them with VoiceOver on and adds explicit move actions if the system offers none; Task 13's phone check confirms. The stand-in was plain rectangles, so Task 6 re-confirms the lift on the real tile. | Mine, Task 1 spike 2026-11-10 | 6, 13 |
| E3 | **Results update as you type (M15 stands), provided `SearchMatch` matches against text folded once ahead of time.** Simulator, Release build, 2,000 records of ~1.5 KB, 20 runs each, p95 for one full pass: folding the stored text once (case and diacritics) and matching its UTF-8 bytes with `memmem` gave 0.10 ms (1 letter), 0.98 ms (3), 0.79 ms (6) and 1.61 ms (a 6-letter miss, the worst case). All are under P8's 8 ms. Matching with `range(of:options: [.caseInsensitive, .diacriticInsensitive])` on every keystroke took 82–233 ms (p95, 3 letters or more), and plain `range(of:)` on folded strings 18–49 ms, so neither of those may be used. Not measured: the one-time fold of 2,000 texts, the SwiftData fetch of 2,000 texts, and the snippet pass over many hits. Task 7 carries the design; Task 13 confirms on the phone. | Mine, Task 1 spike 2026-11-10 | 7, 9, 13 |
