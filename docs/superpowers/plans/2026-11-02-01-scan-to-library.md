# Plan 1 · Scan to library Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Tap Scan, capture pages, name the scan and pick its collection, save it, and find it on Home, in its collection grid and in the viewer, on real on-device storage and without Apple Intelligence.

**Architecture:** Capture → Understanding → Library, wired through per-screen `@Observable` models. Two new Mac-buildable modules: `Understanding` (Vision text reading behind a swappable `TextReader` seam, plus a pure title rule) and `Library` (SwiftData records, HEIC originals, ~400px thumbnails, and an all-or-nothing save through the main `ModelContext` in `ScanStore`). Expiry maths lives in `Core`. Every screen is a `ScreenModels` model tested in Fast, plus a `Screens` view proven by snapshots against `design/screens/`. The app target stays thin: `AppEnvironment` builds everything from public types.

**Tech Stack:** Swift 6, SwiftUI, Observation, SwiftData, VisionKit (`VNDocumentCameraViewController`), Vision (`RecognizeTextRequest`, `RecognizeDocumentsRequest`), ImageIO, AVFoundation (camera permission), os (`Logger`, `OSSignposter`), Swift Testing, XCTest (UI, hosted performance and device timing), swift-snapshot-testing 1.19.7.

**Spec:** `docs/superpowers/specs/2026-10-10-filing-cabinet-requirements.html` (what; sections 02, 03 stories 1–4 and 7, 04, 06), `docs/superpowers/specs/2026-10-31-engineering-foundations-design.md` (how), `design/` (screens, components, tokens). Executors read all three.

**Status:** Revision 2, 2026-11-02, after an independent review (`.superpowers/plan1-review.md`, 40 findings, all addressed). For Ben's review. Not started.

---

## Decisions

### Agreed with Ben on 2026-11-02

| # | Decision | Where it lands |
|---|---|---|
| A1 | **Scope:** capture, the review full sheet (manual pick only), the library and save, Home with scans, collection grids (each collection, Recent, All), the read-only viewer, expiry maths, analytics for these flows. The Apple Intelligence card is Plan 3. | whole plan |
| A2 | **Controls for later plans are hidden** until their plan builds them: Home's Search field and Settings gear, Home's Trash row, the grid's sort button, the viewer's More menu and bottom bar (Share, Favorite, Details, Trash). Snapshots differ from the mocks only there. | Tasks 12, 16, 17 |
| A3 | **The full save moment** is in Plan 1: review slides down, then the collection's count on Home pops as it ticks up; success haptic; VoiceOver announcement; Reduce Motion is a quick fade with no pop. *(Changed 2026-11-07: the page no longer flies into its collection, B5 and B6.)* | Tasks 18, 20 |
| A4 | **"Scan saved" carries its collection** (as a token) and its page count. | Task 13 |
| A5 | **No-text title:** `Scan · Oct 31` (the word Scan, a middot, the scan date). | Task 14 |
| A6 | **Empty states for Notes and Documents:** "No notes yet" / "Handwritten and class notes go here. They’re kept forever." and "No documents yet" / "Forms, letters and anything else go here. They’re kept forever." | Task 11 |
| A7 | **Orange rule:** orange in the last 7 days; when a scan's whole lifespan is 7 days or less, orange only on its last day. The requirements get this line. | Tasks 3, 19 |
| A8 | **Expiry units are fixed days:** 1 week = 7, 1 month = 30, 3 months = 90, 1 year = 365. | Task 3 |
| A9 | **Every expiry ends at the end of its last day** (local time). A custom date of Mar 3 means it is there all of Mar 3 and shows "1 day left" that day. | Task 3 |
| A10 | **The scan day is day 1:** a 1-week Throwaway scanned Oct 12 shows "7 days left" on Oct 12 and its last day is Oct 18. A receipt scanned Oct 12 lasts until Jan 9 (the review mock's "Jan 10" is superseded). | Task 3 |
| A11 | **Both Vision readers are built** behind one `TextReader` seam (SOLID: swap by configuration, nothing else changes): `RecognizeTextRequest` and `RecognizeDocumentsRequest`. | Tasks 4, 5 |
| A12 | **The bake-off:** a comparison suite runs both readers on the 27 synthetic scans in `design/prototype/scans/` (the 3-page lease scored as one scan) and writes a report (not a gate); a Device timed test measures each on the iPhone; a debug-only launch flag picks the reader. `RecognizeTextRequest` is the default until Ben picks a winner. | Tasks 6, 10 |
| A13 | **Foundation follow-ups folded in:** #6 (lint rule gaps, approved lint-config change), #24 (drift check), #22 (snapshot window teardown), #12 (audit at the largest text), #7 (hairline). | Tasks 1, 2 |
| A14 | **OCR cold start is measured on the iPhone before Save's behaviour is fixed.** Vision's first read took 14–26 s on a Mac (warm: ~0.2 s). Task 6 measures cold and warm reads per reader on Ben's phone and stops for Ben; he sets `readingWaitLimit` (M2) from the numbers before Task 14 starts. | Tasks 6, 14 |
| A15 | **Task 6's checkpoint (2026-11-03).** On Ben's iPhone 16 Pro: `text` reads 447 ms cold and 151 ms per page warm; `documents` 553 ms cold and 194 ms per page. Both got 19/25 titles and 99% recall on the synthetic scans. **`readingWaitLimit` is 1 s.** **The default reader is not decided:** Ben wants more testing first, so `text` stays the provisional default (A12) and the `-TextReader` flag / `READER=` keep both available. | Tasks 10, 14, 19 |

### Decided with Ben during execution (2026-11-05 to 2026-11-07)

These came up while the plan was being built, most at the 2026-11-07 phone check. Where one changes a row above, that row says so.

| # | Decision | Where it lands |
|---|---|---|
| B1 | **The grid prefetches** beyond the visible tiles (the visible ones first, then the next batches up to a bound) rather than lowering the first-screen bound of 18. (2026-11-05) | Task 16 |
| B2 | **Camera off is the mock's compact sheet**, with a `textClipped` audit exemption scoped to that sheet only. (2026-11-06) | Task 18 |
| B3 | **An empty Recent or All shows a neutral badge.** (2026-11-06) | Task 12 |
| B4 | **Discard and the camera's Cancel** first cut straight back (2026-11-06); since B6 they slide down like Save. | Tasks 18, 20 |
| B5 | **No save flight** (P1). The page doesn't fly into its collection; Save closes review like Discard. The haptic and the announcement stay. Replaces A3's flight and M13. (2026-11-07) | Task 20 |
| B6 | **Save feedback is a slide and a pop** (P5). Save, Discard and the first camera's Cancel slide the capture layer down like a closing sheet (about 0.3 s), revealing where you were; then the collection's count on Home pops as it ticks up. Reduce Motion: a quick cross-fade and no pop (`-ReduceMotion` forces it in UI tests). (2026-11-07) | Task 20 |
| B7 | **Zoom fills the whole screen** (P2): a zoomed page runs under the header and the strip, and the glass controls float over it. Viewer only for now. (2026-11-07) | Task 20 |
| B8 | **A multi-page scan's page strip sits on a glass bar** (P3), more prominent, and readable over a zoomed page. (2026-11-07) | Task 20 |
| B9 | **Pages swipe like Photos** (P4): the page follows the finger, a quick flick goes to the next page, and at a zoomed page's edge a swipe goes on to the next page. (2026-11-07) | Task 20 |
| B10 | **In dark mode the header pill's detail line is `textPrimary`**, all of it (a soon expiry keeps its orange). The title still leads by weight and size. (2026-11-07) | Task 20 |

### My calls (not discussed; veto any before its task starts)

| # | Call | Task |
|---|---|---|
| M1 | **Title rule:** the tallest line in the top 40% of page 1 with at least 3 letters; ties go to the higher line. An all-caps line is title-cased ("CITY PHARMACY" → "City Pharmacy", as the review mock shows), except words containing digits, which stay as printed ("UNIT 4B"). Whitespace is collapsed and the title is cut to 60 characters. | 5 |
| M2 | **While reading:** the title field shows the fallback title and is replaced by the read title when it arrives, unless you've typed. Save waits at most `readingWaitLimit` for reading (1 s, set by Ben from Task 6's numbers, A15). If reading isn't done, the scan saves with the title showing and its search text is written when reading finishes. | 14 |
| M3 | **A cleared title** saves as the fallback title. | 14 |
| M4 | **A save failure that isn't a full disk** uses the same alert with the body "Something went wrong. Your pages are still here." (The design only has the out-of-space copy.) | 14 |
| M5 | **Expired scans are hidden** from Home counts, grids and the viewer. By the requirements they are in Trash, which Plan 2 builds. Nothing is deleted in Plan 1. "Today" refreshes when the app becomes active and at midnight. | 10, 11 |
| M6 | **Dates show a year only when it isn't the current year** ("until Jan 9, 2027" in Nov 2026), following the details mock (07-06). All dates are formatted in `en_US` (the app is English only), never the device region. | 11 |
| M7 | **A custom expiry reads "Until Mar 3"** on the review sheet. | 11 |
| M8 | **No `CollectionRef` yet.** The foundations spec puts it in Core, but with no custom collections it would have one case. `BuiltInCollection` becomes the analytics token; `.custom` arrives with custom collections (#29). | 13 |
| M9 | **Test doubles are Debug-only.** `TestSupport` is linked into the app, but every launch flag is parsed only in Debug builds and every use of `TestSupport` in the app is inside `#if DEBUG`. A Release build ignores all test flags. | 10 |
| M10 | **The viewer header uses the requirements' time-left text** ("5 days left"), not the mock's "Expires in 5 days". The requirements win (story 7). | 17 |
| M11 | **The VoiceOver announcement** after a save is "Saved to Receipts", posted once review has slid away. | 18, 20 |
| M12 | **Originals are HEIC at quality 0.8.** Thumbnails are JPEG at quality 0.8, 400px on the long edge. | 7 |
| M13 | ~~The save flight falls back to a fade when its target isn't on screen.~~ Withdrawn 2026-11-07: there is no flight (B5). | 18 |
| M14 | **Home shows the first-launch rows** (descriptions, no Recent/All) whenever no scan is visible, not only on first launch. | 12 |
| M15 | **All Scans subtitle:** "91 scans", "1 scan", "No scans". **Recent** is scans whose scan day is within the last 30 days, today included. | 11 |
| M16 | **UI tests use a fake camera screen** (Finish and Cancel buttons that return injected synthetic pages) and, except in one opt-in journey, a fake reader (`-FakeReader`), so cold Vision never times a journey out. | 10, 13, 15 |
| M17 | **Access: a public surface, not `package`, for everything the app, snapshot or UI tests touch.** Xcode targets can't see `package` declarations. Each task's Interfaces block marks those types `public`; everything else stays `package` or internal. `AppEnvironment` stays in the app (foundations: the app target is wiring only). | all |
| M18 | **`Screens` never depends on `TestSupport`.** The fake camera view takes its pages from an injected closure the app supplies in Debug. | 10, 13 |
| M19 | **Pages travel as `[CGImage]`** instead of the foundations spec's `CapturedPages` type: `CGImage` is `Sendable` in the iOS 27 SDK, so a wrapper adds nothing. | 13 |
| M20 | **One full-screen capture layer.** Camera, review and rescan swap content inside a single `fullScreenCover`, so Home never flashes between them. | 13 |
| M21 | **The store class is `ScanStore`**, not `Library`, so it doesn't share the `Library` module's name. | 8 |
| M22 | **Discard asks with an alert** (centred, Keep editing / Discard side by side, as 04-03), not a confirmation dialog, which presents as a popover on iOS 27. | 15 |
| M23 | **The bake-off also reports Vision's own document title** (`DocumentObservation.Container.title`) as an extra column, to inform Plan 3. | 6 |

---

## Roadmap

| Plan | What you can do when it's merged |
|---|---|
| 0 · Foundation (done) | The loop: project, package, lint, hooks, five test layers, CI, the first-launch Home. |
| **1 · Scan to library (this plan)** | Scan, review, save, browse Home → collection → scan, with expiry text everywhere. |
| 2 · Editing and self-cleaning | Details sheet, Move to Trash, Trash, the dates-based cleanup, Settings › Collections, cleanup notifications. |
| 3 · Apple Intelligence | The suggestion card, the shimmer and the 5-second fallback, the Settings switch, an evaluation suite. |
| 4 · Favorites, search, share | Favorites on Home and their grid, full-text search, sort, share and export. |
| 5 · First launch and system | Welcome, the notifications ask, the Settings root, the Scan control, Shortcuts and Siri, Spotlight, the rating prompt, the app icon. |

Before release (issues, not plans): TelemetryDeck (#3), hand-written classification (#25), document lock (#26), the phone checklist with 2,000 scans, TestFlight.

---

## Global Constraints

- iOS 27.0 minimum, iPhone only, portrait only, English only. No `#available` branches.
- Swift 6 language mode, Approachable Concurrency. Default isolation `MainActor` for `ScreenModels`, `Screens` and the app; `nonisolated` for `Core`, `Understanding`, `Library`, `TestSupport`. Banned: `Task.detached`, `@unchecked Sendable`, turning off concurrency checking.
- Slow work (OCR, HEIC encoding, thumbnail decoding, every file-system call) is `@concurrent`. SwiftData objects never cross isolation: pass `ScanID` or `ScanSummary`. All SwiftData writes go through the main `ModelContext`.
- Mac-buildable modules (`Core`, `Understanding`, `Library`, `ScreenModels`, `TestSupport`) never import SwiftUI, UIKit or VisionKit. When `Understanding` and `Library` are created, extend `no_ui_imports_in_mac_modules.included` to their `Sources/` and `Tests/…Tests/` folders.
- Access (M17): `public` for what the app target, `SnapshotTests`, `UITests` or `DeviceTests` use; `package` between package modules; internal otherwise. Each Interfaces block says which.
- Module dependencies are exactly the table under File Structure. Adding an edge not listed there is a plan change.
- SwiftData: a default on every property, no `@Attribute(.unique)`, no relationships.
- Colours, spacing, radii and type only from `Tokens`; screen measurements are named private constants with a comment citing the `design/components/*.dc.html` line. No shadows; floating controls use Liquid Glass (`.glassEffect`). Header pills (the viewer title, "New scan") are SF Pro as the mocks show: they are labels, not titles.
- Copy: every string in its module's `Localizable.xcstrings`, read with `bundle: #bundle`, copied exactly from the components; middots, never em dashes. The Scan button always says "Scan". Titles use `.serif`.
- Dates are formatted with the injected `AppClock.locale` (`en_US`), never `Locale.current`.
- Analytics events carry only `.int`, `.bool` and `.token` of our own enums. Never a title, page text, file name or date.
- Logging: one `Logger(subsystem: "com.cadre.filingcabinet", category: <module>)` per module. Titles, recognized text and file names use `privacy: .private`. Never `print()`. Page images and OCR text are never logged.
- Signposts (`OSSignposter`, subsystem as above), per foundations §6 and §8: "OCR page" (Understanding), "Scan to saved" (ScanStore.save), "Thumbnail decode" (ThumbnailLoader), "Grid first frame" (CollectionGridView).
- No personal documents. Fixtures are `design/prototype/scans/*.jpg` (synthetic) or pages rendered in code.
- Time and locale are injected (`AppClock`); no test reads the real clock, time zone or locale.
- Page indexes are 0-based everywhere in code; page files are named `page-(index+1)`.
- Every new identifier lives in `AccessibilityID`; every new control has one; each journey checks its screen's identifiers with `assertIdentifiers` (Task 2).
- Snapshots only show what renders synchronously: images come from injected providers that answer synchronously in tests. System alerts, confirmation dialogs and menus are never snapshotted; their journeys attach a screenshot (`XCTAttachment(screenshot:)`) that the agent opens and lists.
- Each task ends with the definition of done in `AGENTS.md`. Commits name every changed snapshot reference with the reason.

## Review Focus

1. **A scan whose expiry falls on a day the clocks change, or saved just before midnight.** Days left must count calendar days in the injected calendar, never `86_400`-second steps. Test: Task 3 `daysLeftAcrossDaylightSavingChange` and `scanAtOneMinuteToMidnightCountsThatDay`.
2. **Saving while the disk fills mid-way** (page 2 of 3 written, page 3 fails), or the database save failing after the files are written. Nothing may be left behind and the pages must still be on the review sheet. Tests: Task 7 `failedThirdPageLeavesNoFiles`; Task 8 `contextSaveFailureRemovesFilesAndRecord`; Task 14 `diskFullKeepsPagesAndOffersTryAgain`.
3. **The app is killed between writing files and inserting the record, or cleanup runs while a save is in flight.** Launch must remove true orphans and never a scan being saved. Test: Task 8 `orphanedFoldersAreRemovedAtLaunch`, `cleanupSkipsASaveInFlight`.
4. **Rescan, then cancel the camera.** The original pages and any typed title must survive; finishing replaces the pages and re-reads only an untouched title. Test: Task 14 `cancelledRescanKeepsPagesAndTitle`, `rescanReplacesPagesAndRereadsUntouchedTitle`.
5. **A grid of 2,000 scans, scrolled end to end.** It must never decode a full-resolution original, must request thumbnails only near the screen, and must request at least the first screenful. Test: Task 9 `missingThumbnailIsRebuiltAtThumbnailSize`; Task 16 `gridWithTwoThousandScansStaysBoundedWhileScrolling`. A long scan's memory (20 pages) is checked on the phone in Task 19.

---

## File Structure

### Module dependencies

| Target | Depends on |
|---|---|
| `Core` | nothing |
| `Understanding` | `Core` |
| `Library` | `Core` |
| `ScreenModels` | `Core`, `Understanding`, `Library` |
| `Screens` | `Core`, `ScreenModels`, `Library` |
| `TestSupport` | `Core`, `Understanding`, `Library` |
| `UnderstandingTests`, `LibraryTests` | their module, `TestSupport` |
| `ReaderComparisonTests` | `Understanding` |
| `ScreenModelsTests` | `ScreenModels`, `TestSupport` |
| `ScreensTests` | `Screens`, `Core` (unchanged) |
| App `FilingCabinet` | `Core`, `Understanding`, `Library`, `ScreenModels`, `Screens`, `TestSupport` (used only under `#if DEBUG`, M9) |
| `FilingCabinetSnapshotTests` (hosted) | the app, `SnapshotTesting` (reaches `TestSupport` through the host) |
| `FilingCabinetDeviceTests` (hosted, new) | the app |

### Files

```
App/
  AppEnvironment.swift                  modify: builds every service and model from LaunchOptions
  FilingCabinetApp.swift                modify: RootView, launch cleanup, Today refresh
Packages/FilingCabinetKit/
  Package.swift                         modify: Understanding, Library, their tests, ReaderComparisonTests
  Sources/Core/
    Accessibility/AccessibilityID.swift modify: one nested enum per screen, each with `all`
    Analytics/AnalyticsEvent.swift      modify: scanning events
    Analytics/AnalyticsKey.swift        create (moved out of AnalyticsEvent.swift)
    Analytics/ScanEventTokens.swift     create: ScanSource, CancelStage, FailureReason
    Camera/CameraAccess.swift           create: permission seam
    Camera/CameraMode.swift             create: vision | fake
    Collections/Lifespan.swift          modify: month, year, days
    Collections/BuiltInCollection.swift modify: AnalyticsToken
    Time/AppClock.swift                 create: now, calendar, locale
    Time/CalendarDay.swift              create
    Expiry/ExpiryOverride.swift         create
    Expiry/Expiry.swift                 create: last-day rule
    Expiry/TimeLeft.swift               create: days left and the orange rule
    Launch/LaunchOptions.swift          create: parses launch flags (Debug only)
    Launch/ReaderKind.swift             create: text | documents
    Scans/ScanID.swift                  create
  Sources/Understanding/
    Reading/TextLine.swift, PageText.swift, TextReader.swift, UnderstandingError.swift
    Reading/TextRecognitionReader.swift      RecognizeTextRequest
    Reading/DocumentRecognitionReader.swift  RecognizeDocumentsRequest
    Reading/ReaderKind+Reader.swift          makes the reader a ReaderKind names
    Title/TitleRule.swift                    pure title rule
    Scan/ScanReading.swift, ScanReader.swift reads every page, joins search text
  Sources/Library/
    Records/ScanRecord.swift            @Model
    Records/ScanSummary.swift           Sendable snapshot
    Files/LibraryLocation.swift, FileSystem.swift, PageFileStore.swift, ImageCoding.swift
    Images/ThumbnailProviding.swift, ThumbnailLoader.swift, PageImageProviding.swift, PageImageLoader.swift
    Store/ScanDraft.swift, LibraryError.swift, ScanLibrary.swift, ScanStore.swift
  Sources/ScreenModels/
    App/AppRoute.swift, Today.swift
    Shared/TimeLeftText.swift, ExpiryText.swift, CollectionText.swift, LibraryShelf.swift, GridKind.swift
    Home/HomeModel.swift, HomeRow.swift, HomeViewRow.swift
    Capture/ScanFlowModel.swift, ReviewInput.swift, FlightDestination.swift
    Review/ReviewModel.swift, ExpiryOption.swift, SaveAlert.swift
    Grid/CollectionGridModel.swift, GridTile.swift
    Viewer/ViewerModel.swift
    Save/SavedScan.swift
  Sources/Screens/
    DesignSystem/Hairline.swift, GlassCircleButton.swift, CollectionDot.swift, PagePill.swift, ThumbnailView.swift
    Root/RootView.swift, RootDependencies.swift
    Home/HomeView.swift, HomeRowView.swift, HomeViewRowView.swift
    Capture/CaptureContainer.swift, DocumentCameraView.swift, FakeCameraView.swift, CameraOffSheet.swift, SystemCameraAccess.swift
    Review/ReviewView.swift, ReviewSheet.swift, CollectionMenu.swift, ExpiryMenu.swift, PageStrip.swift
    Grid/CollectionGridView.swift, GridTileView.swift, EmptyCollectionView.swift
    Viewer/ViewerView.swift, ZoomablePage.swift
    Save/FlightOverlay.swift, FlightTarget.swift
  Sources/TestSupport/
    FakeLibrary.swift, FakeTextReader.swift, FakeCameraAccess.swift, FakeThumbnails.swift, FakePageImages.swift
    FailOnceFileSystem.swift            makes the real store fail one save (-FailSave)
    SyntheticPages.swift                renders pages with known text
    LibrarySeed.swift                   seeded scans for -SeedScans
  Tests/CoreTests/ ExpiryTests, TimeLeftTests, CalendarDayTests, LaunchOptionsTests, AnalyticsEventTests
  Tests/UnderstandingTests/ ReaderTests, TitleRuleTests, ScanReaderTests
  Tests/LibraryTests/ PageFileStoreTests, ScanRecordTests, ScanStoreTests, ThumbnailLoaderTests, FailOnceFileSystemTests
  Tests/ScreenModelsTests/ TimeLeftTextTests, ExpiryTextTests, LibraryShelfTests, TodayTests, HomeModelTests,
                           ScanFlowModelTests, ReviewModelTests, CollectionGridModelTests, ViewerModelTests
  Tests/ReaderComparisonTests/ ReaderComparisonTests.swift, expected.json
SnapshotTests/  SnapshotHost.swift, Fixtures.swift, GridPerformanceTests.swift, Home/CameraOff/Review/Grid/Viewer snapshot tests
UITests/        ScanJourneyTests, BrowseJourneyTests, CameraAccessJourneyTests, Support/Identifiers.swift (+ existing)
DeviceTests/    ReaderTimingTests.swift
project.yml, Makefile, .swiftlint.yml, scripts/lint-fixtures, scripts/lint-negatives, AGENTS.md, CLAUDE.md
```

---

## Tasks

### Task 1: Lint gaps (#6) and the drift check (#24)

**Unit:** Tooling

**Files:**
- Modify: `.swiftlint.yml`, `Makefile` (`ci` target), `scripts/test-lint-rules.sh` (rule list)
- Test: `scripts/lint-fixtures/localized_needs_bundle_button.swift`, `…_label.swift`, `…_menu.swift`, `…_navigation_title.swift`, `…_alert.swift`, `…_date_picker.swift`; `scripts/lint-negatives/localized_needs_bundle_text_bundle.swift`, `scripts/lint-negatives/no_print_member.swift`

**Interfaces:**
- Produces: `localized_needs_bundle` also flags a string literal passed straight to `Button(`, `Label(`, `Toggle(`, `Section(`, `TextField(`, `Menu(`, `Picker(`, `DatePicker(`, `ContentUnavailableView(`, `LabeledContent(`, `Link(`, `.navigationTitle(`, `.accessibilityLabel(`, `.alert(` and `.confirmationDialog(` inside `Packages/` (these take a `LocalizedStringKey` and would read the main bundle). `no_print` no longer flags `.print(` member calls or matches in comments and strings. `make ci` fails on untracked generated files too.

Ben approved changing the lint config for #6 on 2026-11-02. Change only these two rules (plus Task 4 and Task 7's path additions to `no_ui_imports_in_mac_modules`).

- [ ] **Step 1: Write the positive fixtures** (one violation each, e.g. `Button("Save") {}`, `Label("Wallet", systemImage: "creditcard")`, `Menu("Collection") {}`, `.navigationTitle("Receipts")`, `.alert("Couldn’t save this scan", isPresented: $x) {}`, `DatePicker("Expiry", selection: $d)`) and the negatives (`Button { } label: { Text("Save", bundle: #bundle) }`; `formatter.print(value)`; `// print(` in a comment).
- [ ] **Step 2: Run `make test-lint`.** Expected: the new positive fixtures FAIL, `no_print_member` FAILS as a negative.
- [ ] **Step 3: Update the two regexes in `.swiftlint.yml`.** For `no_print`, add `match_kinds: [identifier]` and a negative lookbehind for `.`; for `localized_needs_bundle`, add the initializers above with a literal first argument.
- [ ] **Step 4: Run `make test-lint` and `make lint`.** Expected: all PASS, and the existing sources are still clean.
- [ ] **Step 5: Make the drift check see new files.** In `ci`, replace `git diff --exit-code -- <generated paths>` with a check that `git status --porcelain -- <same paths>` is empty, keeping the same error message.
- [ ] **Step 6: Prove it.** With Bash (`touch`; the generated-file guard blocks Edit and Write there), create `Packages/FilingCabinetKit/Sources/Screens/DesignSystem/Generated/Untracked.swift`, run the drift check, expect failure, delete the file, expect success.
- [ ] **Step 7: Commit** `Lint: localized_needs_bundle covers Button, Label, Menu and friends; no_print ignores members (#6). Drift check sees untracked files (#24)`. Close #6 and #24 in the PR body.

### Task 2: Test plumbing (#22, #12, #7) and per-screen identifiers

**Unit:** Tooling

**Files:**
- Create: `SnapshotTests/SnapshotHost.swift`, `UITests/Support/Identifiers.swift`, `Packages/FilingCabinetKit/Sources/Screens/DesignSystem/Hairline.swift`
- Modify: `SnapshotTests/HomeSnapshotTests.swift`, `UITests/Support/Launch.swift`, `UITests/HomeJourneyTests.swift`, `UITests/AccessibilityCoverageTests.swift`, `Packages/FilingCabinetKit/Sources/Core/Accessibility/AccessibilityID.swift`, `Packages/FilingCabinetKit/Sources/Screens/Home/HomeRowView.swift`
- Test: `Packages/FilingCabinetKit/Tests/CoreTests/AccessibilityIDTests.swift`

**Interfaces:**
- Produces:
  - `@MainActor enum SnapshotHost { static func assertScreen(_ view: some View, testName: String, variants: [SnapshotConfig.Variant] = SnapshotConfig.variants, file: StaticString = #filePath, line: UInt = #line) throws }`. It makes a new `UIWindow` per variant in the host scene, snapshots it, then sets `rootViewController = nil` and `isHidden = true`. Every snapshot test uses only this.
  - `func launchApp(_ flags: [String] = [], largestText: Bool = false) -> XCUIApplication`, where `largestText` adds `-UIPreferredContentSizeCategoryName UICTContentSizeCategoryAccessibilityXXXL`. `audit(_:)` is unchanged. Each journey audits each screen in a default-size launch and in a largest-text launch.
  - `func assertIdentifiers(_ ids: [String], in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line)`: every id exists, and no element of `app.buttons` has an empty identifier. Each journey calls it once per screen it reaches.
  - `struct Hairline: View` (internal), 1 device pixel tall (`1 / displayScale` from the environment) in `Tokens.Color.separator`.
  - `AccessibilityID` becomes one nested `public enum` per screen, each with `public static var all: [String]`: `AccessibilityID.Home { scan, collectionRow(_:), recentRow, allRow }` now; later tasks add `Camera`, `CameraOff`, `Review`, `Grid`, `Viewer`. `AccessibilityID.all` concatenates every screen's `all` and must stay unique.

- [ ] **Step 1: Write the failing test** `everyScreensIdentifiersAreUniqueAndPrefixed`: every ID in `AccessibilityID.Home.all` starts with `home.`, and the IDs in `AccessibilityID.all` are unique.
- [ ] **Step 2: Run `make fast`.** Expected: FAIL to compile (`Home` is not a member).
- [ ] **Step 3: Restructure `AccessibilityID`.** Keep the literal strings (`home.scan`, `home.collection.<raw>`); add `home.recent` and `home.all`. `AccessibilityCoverageTests` uses `assertIdentifiers` on Home with the IDs that exist on an empty library (Recent and All are checked from Task 12's seeded launch).
- [ ] **Step 4: Run `make fast`.** Expected: PASS.
- [ ] **Step 5: Snapshot host.** Move `HomeSnapshotTests` onto `SnapshotHost.assertScreen(HomeView(…), testName: "home_first")`.
- [ ] **Step 6: Hairline.** Replace `HomeRowView`'s fixed `0.5` with `Hairline()`.
- [ ] **Step 7: Largest-text audit.** Add `testHomeAuditAtLargestText` (`launchApp(largestText: true)`, then `audit(app)`). Any new false positive gets an `ignoredIssues` entry with its reason, and the hand-off names it.
- [ ] **Step 8: Run `make full`.** Expected: PASS with the Home references unchanged. If the hairline moves pixels, re-record with `make snapshots-record`, open `make compare SCREEN=01-06-empty-home REF=SnapshotTests/__Snapshots__/HomeSnapshotTests/home_first.light.png`, and name the change.
- [ ] **Step 9: Commit** `Tests: snapshot host tears down its window (#22); audit at the largest text (#12); hairline is one device pixel (#7); identifiers per screen`.

### Task 3: Expiry maths

**Unit:** Core

**Files:**
- Create: `Sources/Core/Time/CalendarDay.swift`, `Sources/Core/Time/AppClock.swift`, `Sources/Core/Expiry/ExpiryOverride.swift`, `Sources/Core/Expiry/Expiry.swift`, `Sources/Core/Expiry/TimeLeft.swift`
- Modify: `Sources/Core/Collections/Lifespan.swift`, `Sources/ScreenModels/Home/HomeModel.swift` (new lifespan cases), `Sources/ScreenModels/Localizable.xcstrings` (`\(1) years`)
- Test: `Tests/CoreTests/CalendarDayTests.swift`, `Tests/CoreTests/ExpiryTests.swift`, `Tests/CoreTests/TimeLeftTests.swift`, `Tests/CoreTests/BuiltInCollectionTests.swift`

(Paths under `Sources/` and `Tests/` are inside `Packages/FilingCabinetKit/` from here on.)

**Interfaces:**
- Produces (all `public`; the app and snapshot fixtures build them):
  - `enum Lifespan: String, Sendable, CaseIterable { case week, month, threeMonths, year, forever }` with `var days: Int?`. The values are 7, 30, 90, 365 and nil. `allCases` is shortest first, Forever last (the order of the "Keep scans for" choices).
  - `struct CalendarDay: Sendable, Hashable, Comparable { let year: Int, month: Int, day: Int }` with:
    - `init(year:month:day:)`, `init(_ date: Date, in calendar: Calendar)`
    - `func adding(days: Int, in calendar: Calendar) -> CalendarDay`
    - `func days(until other: CalendarDay, in calendar: Calendar) -> Int` (calendar days, never seconds)
    - `var storageValue: Int` (yyyymmdd), `init?(storageValue: Int)`
    - `func date(in calendar: Calendar) -> Date` (the start of the day)
  - `struct AppClock: Sendable { let now: @Sendable () -> Date; let calendar: Calendar; let locale: Locale }` with `static let system` (current calendar, `Locale(identifier: "en_US")`) and `static func fixed(_ date: Date, calendar: Calendar, locale: Locale = Locale(identifier: "en_US")) -> AppClock`. `var today: CalendarDay`.
  - `enum ExpiryOverride: Sendable, Hashable { case lifespan(Lifespan), lastDay(CalendarDay) }`. A nil override means the collection default.
  - `enum Expiry { static func lastDay(scanDay: CalendarDay, collectionLifespan: Lifespan, override: ExpiryOverride?, in calendar: Calendar) -> CalendarDay? }`. Nil means forever. A lifespan of N days gives `scanDay + (N − 1)`; a custom `lastDay` is used as is.
  - `enum TimeLeft: Sendable, Equatable { case forever, days(Int), expired }` with `static func on(_ today: CalendarDay, lastDay: CalendarDay?, in calendar: Calendar) -> TimeLeft`. Days left is `today.days(until: lastDay) + 1`; 0 or below is `.expired`.
  - `TimeLeft.isSoon(daysLeft: Int, spanDays: Int) -> Bool`, where span = `scanDay.days(until: lastDay) + 1`. It is `spanDays > 7 ? daysLeft <= 7 : daysLeft <= 1`.

- [ ] **Step 1: Write the failing tests.** Use `Calendar(identifier: .gregorian)` with `TimeZone(identifier: "America/New_York")`.

```swift
@Test func receiptFromOct12LastsUntilJan9() {
    let oct12 = CalendarDay(year: 2026, month: 10, day: 12)
    #expect(Expiry.lastDay(scanDay: oct12, collectionLifespan: .threeMonths, override: nil, in: cal)
        == CalendarDay(year: 2027, month: 1, day: 9))
}
@Test func throwawayShowsSevenDaysOnItsScanDayAndOneOnItsLast() {
    let oct12 = CalendarDay(year: 2026, month: 10, day: 12)
    let last = Expiry.lastDay(scanDay: oct12, collectionLifespan: .week, override: nil, in: cal)
    #expect(last == CalendarDay(year: 2026, month: 10, day: 18))
    #expect(TimeLeft.on(oct12, lastDay: last, in: cal) == .days(7))
    #expect(TimeLeft.on(CalendarDay(year: 2026, month: 10, day: 18), lastDay: last, in: cal) == .days(1))
    #expect(TimeLeft.on(CalendarDay(year: 2026, month: 10, day: 19), lastDay: last, in: cal) == .expired)
}
@Test func customDateLastsThroughThatDay() { /* override .lastDay(Mar 3); on Mar 3 → .days(1); Mar 4 → .expired */ }
@Test func overrideBeatsCollection() { /* Wallet (forever) + .lifespan(.month) → scanDay + 29 */ }
@Test func foreverHasNoLastDay() { /* Wallet, nil override → nil; TimeLeft == .forever */ }
@Test func daysLeftAcrossDaylightSavingChange() { /* Oct 30 → Nov 3 2026 (US DST ends Nov 1) = 5 days left incl. today */ }
@Test func scanAtOneMinuteToMidnightCountsThatDay() { /* CalendarDay(Oct 12 23:59 local) == Oct 12 */ }
@Test func orangeRule() {
    #expect(TimeLeft.isSoon(daysLeft: 7, spanDays: 90)); #expect(!TimeLeft.isSoon(daysLeft: 8, spanDays: 90))
    #expect(!TimeLeft.isSoon(daysLeft: 2, spanDays: 7)); #expect(TimeLeft.isSoon(daysLeft: 1, spanDays: 7))
}
@Test func lifespanDays() { #expect(Lifespan.allCases.map(\.days) == [7, 30, 90, 365, nil]) }
@Test func storageValueRoundTrips() { /* 20270109 ↔ Jan 9 2027; invalid 20271340 → nil */ }
```

- [ ] **Step 2: Run `make fast`.** Expected: FAIL to compile.
- [ ] **Step 3: Implement the five types and extend `Lifespan`.** Use `calendar.dateComponents([.day], from:to:)` on the start of each day for `days(until:)`. Give `HomeModel.text(for:)` the new cases (`\(1) months`, `\(1) years`, plural keys in the catalog).
- [ ] **Step 4: Run `make fast`.** Expected: PASS, including the existing `lifespansMatchTheRequirements`.
- [ ] **Step 5: Commit** `Core: expiry maths (fixed days, end-of-day, scan day is day 1)`.

### Task 4: Two text readers behind one seam

**Unit:** Understanding

**Files:**
- Create: `Sources/Core/Launch/ReaderKind.swift`; `Sources/Understanding/Reading/TextLine.swift`, `PageText.swift`, `TextReader.swift`, `UnderstandingError.swift`, `TextRecognitionReader.swift`, `DocumentRecognitionReader.swift`, `ReaderKind+Reader.swift`; `Sources/TestSupport/SyntheticPages.swift`, `Sources/TestSupport/FakeTextReader.swift`
- Modify: `Package.swift` (target `Understanding`; `UnderstandingTests`; `TestSupport` gains `Understanding`, per the dependency table), `project.yml` (`UnderstandingTests` in the `Fast` and `FilingCabinet` schemes), `.swiftlint.yml` (`no_ui_imports_in_mac_modules.included` gains `Sources/Understanding` and `Tests/UnderstandingTests`)
- Test: `Tests/UnderstandingTests/ReaderTests.swift`

**Interfaces:**
- Produces:
  - `public enum ReaderKind: String, Sendable, CaseIterable { case text, documents }` in **Core** (so `LaunchOptions` can parse it). In Understanding: `extension ReaderKind { public func makeReader() -> any TextReader }`.
  - `public struct TextLine: Sendable, Equatable { public let text: String; public let box: CGRect }`. The box is normalized with the origin at the **top-left** (convert from Vision's bottom-left once, here). `public` because `FakeTextReader` scripts are built in the app's Debug wiring.
  - `public struct PageText: Sendable, Equatable { public let lines: [TextLine] }`
  - `public protocol TextReader: Sendable { func read(_ page: CGImage) async throws(UnderstandingError) -> PageText }`
  - `public enum UnderstandingError: Error, Equatable { case recognitionFailed }`
  - `struct TextRecognitionReader: TextReader` (internal): `RecognizeTextRequest` with `recognitionLevel = .accurate`, `usesLanguageCorrection = true`, `recognitionLanguages = [Locale.Language(identifier: "en-US")]`; `read` is `@concurrent`.
  - `struct DocumentRecognitionReader: TextReader` (internal): `RecognizeDocumentsRequest` with `textRecognitionOptions.useLanguageCorrection = true` and the same languages (it has no recognition level), mapping `document.text.lines`. It also has `package func documentTitle(_ page: CGImage) async -> String?` from `DocumentObservation.Container.title`, for the bake-off only (M23). `read` is `@concurrent`.
  - Both readers take an `onPerform: @Sendable () -> Void = {}` hook, called right before Vision runs (for the off-main test).
  - TestSupport (`public`; the app's Debug wiring uses it): `enum SyntheticPages { static func page(lines: [(String, CGFloat)], size: CGSize = CGSize(width: 2480, height: 3508)) -> CGImage }` renders black text on white with Core Text (the CGFloat is the point size, top to bottom; the default is an A4 page at 300 dpi, close to a VisionKit page). `static func receipt() -> CGImage` gives "CITY PHARMACY" at 160pt, then "Batteries AA" and "TOTAL 12.40" at 60pt. `static func blank() -> CGImage`. `final class FakeTextReader: TextReader` returns scripted `PageText` per call (optionally after a scripted delay) or throws; `static func readsCityPharmacy() -> FakeTextReader`.

- [ ] **Step 1: Write the failing tests**, parameterized over `ReaderKind.allCases`:
  - `readsTheBigLineOfASyntheticReceipt`: some line's text, uppercased, contains `CITY PHARMACY`, and that line's `box.minY < 0.3`.
  - `blankPageReadsNoLines`: `lines.isEmpty`.
  - `readingRunsOffTheMainThread`: called from a `@MainActor` test; the `onPerform` hook records `Thread.isMainThread == false` (foundations §5).
- [ ] **Step 2: Run `make fast`.** Expected: FAIL to compile.
- [ ] **Step 3: Add the module and the types.** Both readers live in their own file and share nothing but `TextLine`/`PageText`. Each logs page timing and line count (public), never text. Vision's first call can take tens of seconds (cold model load): give these tests `.timeLimit(.minutes(2))`.
- [ ] **Step 4: Run `make fast`.** Expected: PASS on macOS for both readers. If `RecognizeDocumentsRequest` is unavailable in the macOS test host, stop and report it: don't skip the test.
- [ ] **Step 5: Commit** `Understanding: TextRecognitionReader and DocumentRecognitionReader behind TextReader`.

### Task 5: Title rule and the scan reader

**Unit:** Understanding

**Files:**
- Create: `Sources/Understanding/Title/TitleRule.swift`, `Sources/Understanding/Scan/ScanReading.swift`, `Sources/Understanding/Scan/ScanReader.swift`
- Test: `Tests/UnderstandingTests/TitleRuleTests.swift`, `Tests/UnderstandingTests/ScanReaderTests.swift`

**Interfaces:**
- Consumes: `TextReader`, `PageText`, `TextLine`, `FakeTextReader`.
- Produces:
  - `package enum TitleRule { static func title(from pages: [PageText]) -> String? }` (M1).
  - `public struct ScanReading: Sendable, Equatable { public let title: String?; public let searchText: String; public let failedPages: Int }`
  - `public struct ScanReader: Sendable { public init(reader: any TextReader); @concurrent public func read(_ pages: [CGImage]) async -> ScanReading }`. Pages are read in order. `searchText` is every line of every page joined by `"\n"`. A page that throws counts in `failedPages` and adds nothing. Each page is wrapped in the `"OCR page"` signpost.

- [ ] **Step 1: Write the failing tests** with hand-built `PageText`:
  - `tallestLineInTheTopWins`: lines at y 0.05 h 0.03 "Receipt #4471", y 0.10 h 0.06 "City Pharmacy", y 0.8 h 0.09 "THANK YOU" → `"City Pharmacy"`.
  - `allCapsIsTitleCased`: "CITY PHARMACY" → "City Pharmacy"; "Bio 210 · Oct 10" is unchanged.
  - `wordsWithDigitsKeepTheirCase`: "LEASE RENEWAL UNIT 4B" → "Lease Renewal Unit 4B".
  - `tieGoesToTheHigherLine`
  - `linesWithFewerThanThreeLettersAreSkipped`: "00.00", "#4" are skipped.
  - `onlyPageOneCounts`
  - `nothingReadableIsNil`: `[]` and `[PageText(lines: [])]` → nil.
  - `longTitleIsCutTo60`
  - `whitespaceIsCollapsed`
  - `ScanReaderTests`: `joinsSearchTextInPageOrder`; `failedPageIsCountedAndSkipped`; `titleComesFromPageOne`.
- [ ] **Step 2: Run `make fast`.** Expected: FAIL to compile.
- [ ] **Step 3: Implement** `TitleRule` and `ScanReader`.
- [ ] **Step 4: Run `make fast`.** Expected: PASS.
- [ ] **Step 5: Commit** `Understanding: title rule and ScanReader`.

### Task 6: The reader bake-off: report, device timing, and a checkpoint with Ben

**Unit:** Understanding · Device (A12, A14)

**Files:**
- Create: `Tests/ReaderComparisonTests/ReaderComparisonTests.swift`, `Tests/ReaderComparisonTests/expected.json`, `DeviceTests/ReaderTimingTests.swift`
- Modify: `Package.swift` (test target `ReaderComparisonTests`), `project.yml` (scheme `ReaderComparison`, macOS, only this target; the app-hosted `FilingCabinetDeviceTests` target with resources `design/prototype/scans/scan-r-pharmacy.jpg`, `scan-lease.jpg`, `scan-lease-p2.jpg`, `scan-note-bio.jpg`, `scan-insurance.jpg`, and a `Device` scheme testing only it; neither is in `Fast` or `FilingCabinet`), `Makefile` (`compare-readers`, `device-perf`), `AGENTS.md` (command table)

**Interfaces:**
- Consumes: `ReaderKind`, `ScanReader`, `TitleRule`, `DocumentRecognitionReader.documentTitle`.
- Produces:
  - `make compare-readers` writes `build/reader-comparison.md`. Totals at the top: titles hit and mean recall per reader. Then a table per fixture: file(s), expected title, each reader's title with ✓/✗, word recall %, warm ms per page, and Vision's own document title (M23). Each reader's cold first read is reported once, separately; warm timings start after one warm-up read. Mac timings are labelled "relative only". The suite fails only if a fixture can't be loaded or a reader throws on every page. It is a report, not a gate (A12).
  - `make device-perf DEVICE=<name>` runs `xcodebuild test -scheme Device -destination 'platform=iOS,name=$(DEVICE)'`. It is not part of `make full` or CI. Tests:
    - `testTextReaderColdFirstRead` and `testDocumentsReaderColdFirstRead`: one read by a fresh reader on the pharmacy page, timed with `ContinuousClock`; the duration is attached (`XCTAttachment(string:)`), never asserted. Each runs first in a fresh app launch (separate test classes, so each gets its own process).
    - `testTextReaderPerPage` and `testDocumentsReaderPerPage`: one warm-up read, then `measure(metrics: [XCTClockMetric(), XCTOSSignpostMetric(subsystem: "com.cadre.filingcabinet", category: "Understanding", name: "OCR page")])` over the five fixtures, each upscaled at load to about 2480 × 3508 (the fixtures are 360–720 px wide; a VisionKit page is far larger).

- [ ] **Step 1: Write `expected.json`.** Open each of the 27 images in `design/prototype/scans/` and record `{"files": ["scan-r-pharmacy.jpg"], "title": "City Pharmacy", "words": [five distinctive words printed on it]}`. The lease is one entry with `files` `scan-lease.jpg`, `scan-lease-p2.jpg`, `scan-lease-p3.jpg`, scored as a 3-page scan (25 entries in all). The expected title is what the title rule should find (the largest printed text near the top of page 1, cased per M1). Every image is synthetic sample art; none is a real document.
- [ ] **Step 2: Write the suite.** Load each image through ImageIO from `#filePath`-relative `design/prototype/scans/`, warm each reader once, run both `ScanReader`s, score them (a title hit is a case-insensitive exact match after whitespace collapse; recall is the share of `words` found in `searchText`, case-insensitive), and write the report.
- [ ] **Step 3: Run `make compare-readers`.** Expected: PASS, with the report at `build/reader-comparison.md`. Open it.
- [ ] **Step 4: Write the device tests.** Then run `xcodebuild build-for-testing -scheme Device -destination 'generic/platform=iOS'`. Expected: BUILD SUCCEEDED.
- [ ] **Step 5: Commit** `Understanding: reader bake-off report and device timing`.
- [ ] **Step 6: Checkpoint with Ben (stop here).** Ask Ben to run `make device-perf DEVICE=<his iPhone>`. Bring him the report's totals and his phone's cold and warm numbers per reader. He decides (a) `readingWaitLimit` for M2 (A14) and (b) whether `documents` should be the default instead of `text` (A12). Record both in this plan's Decisions table before Task 14 starts. If his phone isn't available yet, Tasks 7–13 may continue; Task 14 may not start.

### Task 7: Records and page files

**Unit:** Library

**Files:**
- Create: `Sources/Library/Records/ScanRecord.swift`, `ScanSummary.swift`; `Sources/Library/Store/LibraryError.swift`; `Sources/Library/Files/LibraryLocation.swift`, `FileSystem.swift`, `ImageCoding.swift`, `PageFileStore.swift`; `Sources/Core/Scans/ScanID.swift`
- Modify: `Package.swift` (target `Library`; `LibraryTests`; `TestSupport` gains `Library`), `project.yml` (`LibraryTests` in both schemes), `.swiftlint.yml` (`no_ui_imports_in_mac_modules.included` gains `Sources/Library` and `Tests/LibraryTests`)
- Test: `Tests/LibraryTests/PageFileStoreTests.swift`, `Tests/LibraryTests/ScanRecordTests.swift`

**Interfaces:**
- Consumes: `CalendarDay`, `ExpiryOverride`, `BuiltInCollection`, `SyntheticPages`.
- Produces:
  - `public struct ScanID: Sendable, Hashable, Codable { public let uuid: UUID }`, with `init()` and `init(uuid:)`.
  - `@Model final class ScanRecord` (internal) with these fields:
    - `scanID: UUID = UUID()`
    - `title: String = ""`
    - `collectionKey: String = ""` (a `BuiltInCollection.rawValue`)
    - `scannedAt: Date = Date.distantPast`
    - `overrideLifespan: String? = nil` (a `Lifespan.rawValue`)
    - `overrideLastDay: Int? = nil` (`CalendarDay.storageValue`)
    - `pageFileNames: [String] = []`
    - `searchText: String = ""`

    It also has `var expiryOverride: ExpiryOverride? { get set }` and `var summary: ScanSummary?` (nil when `collectionKey` is unknown).
  - `public struct ScanSummary: Sendable, Hashable, Identifiable { public let id: ScanID; title: String; collection: BuiltInCollection; scannedAt: Date; expiryOverride: ExpiryOverride?; pageCount: Int }`, with a public memberwise init (snapshot fixtures build them).
  - `public struct LibraryLocation: Sendable { public let root: URL; public let caches: URL }` with `public init(root:caches:)`, `storeURL` (`root/Library.store`, requirements 04 · Storage), `originals(for: ScanID) -> URL` (`root/Originals/<uuid>/`), `thumbnails(for:) -> URL` (`caches/Thumbnails/<uuid>/`), and `public static func standard() throws -> LibraryLocation` (Application Support and Caches; nothing is excluded from the device backup).
  - `public protocol FileSystem: Sendable` with `createDirectory(at:) throws`, `write(_ data: Data, to: URL) throws`, `removeItem(at:) throws`, `contentsOfDirectory(at:) throws -> [URL]`, `fileExists(at:) -> Bool`. Implemented by `public struct LocalFileSystem: FileSystem`. (`public` because the app's Debug wiring wraps it, Task 8.)
  - `enum ImageCoding` (internal): `static func heic(_ image: CGImage, quality: Double) throws -> Data`, `static func jpegThumbnail(_ image: CGImage, maxPixel: Int) throws -> Data`. ImageIO only (M12).
  - `public struct PageFileStore: Sendable` with `public init(location: LibraryLocation, fileSystem: any FileSystem)`, and:
    - `@concurrent func write(_ pages: [CGImage], for id: ScanID) async throws(LibraryError) -> [String]`, which returns `["page-1.heic", …]`, writes `page-N.jpg` thumbnails, and on any failure removes both folders before throwing;
    - `@concurrent func remove(_ id: ScanID) async`;
    - `@concurrent func storedScanIDs() async -> [ScanID]`.
  - `public enum LibraryError: Error, Equatable { case diskFull, writeFailed }`. ENOSPC and `CocoaError.fileWriteOutOfSpace` map to `.diskFull`.

- [ ] **Step 1: Write the failing tests:**
  - `writesHeicOriginalsAndSmallThumbnails`: in a temp root, write 3 synthetic pages. The three `.heic` files exist and decode, and each thumbnail's long edge is ≤ 400.
  - `heicEncodingIsAvailable`: `CGImageDestinationCopyTypeIdentifiers()` contains `public.heic`.
  - `failedThirdPageLeavesNoFiles` (Review Focus 2), with a test-local `FileSystem` that throws ENOSPC on the 3rd original: it throws `.diskFull`, and both folders are gone.
  - `recordRoundTripsTheOverride`: `.lifespan(.month)`, `.lastDay(Mar 3)` and `nil` round-trip through `expiryOverride`.
  - `unknownCollectionHasNoSummary`
- [ ] **Step 2: Run `make fast`.** Expected: FAIL to compile.
- [ ] **Step 3: Implement.** HEIC uses quality 0.8, thumbnails JPEG at 0.8 (M12).
- [ ] **Step 4: Run `make fast`.** Expected: PASS.
- [ ] **Step 5: Commit** `Library: ScanRecord, ScanSummary and PageFileStore`.
- [ ] **Step 6: Confirm HEIC on CI's simulator.** Everything after this saves HEIC, and CI runs in a VM. Ask Ben for the go-ahead to push `plan-1` and check the CI run's `heicEncodingIsAvailable` (it runs in the simulator package tests). If it fails there, stop and bring Ben the options before Task 8.

### Task 8: The store: all-or-nothing save and orphan cleanup

**Unit:** Library

**Files:**
- Create: `Sources/Library/Store/ScanDraft.swift`, `ScanLibrary.swift`, `ScanStore.swift`; `Sources/TestSupport/FakeLibrary.swift`, `Sources/TestSupport/FailOnceFileSystem.swift`
- Test: `Tests/LibraryTests/ScanStoreTests.swift`, `Tests/LibraryTests/FailOnceFileSystemTests.swift`

**Interfaces:**
- Consumes: `ScanRecord`, `PageFileStore`, `LibraryLocation`, `LibraryError`.
- Produces:
  - `public struct ScanDraft: Sendable { public let id: ScanID; title: String; collection: BuiltInCollection; scannedAt: Date; expiryOverride: ExpiryOverride?; pages: [CGImage]; searchText: String? }` (nil search text means "reading not finished", M2).
  - `@MainActor public protocol ScanLibrary: AnyObject { var scans: [ScanSummary] { get }; func save(_ draft: ScanDraft) async throws(LibraryError); func updateSearchText(_ text: String, for id: ScanID) }`. `scans` is every record, newest `scannedAt` first.
  - `@MainActor @Observable public final class ScanStore: ScanLibrary` (M21) with:
    - `public init(container: ModelContainer, files: PageFileStore, persist: ((ModelContext) throws -> Void)? = nil)`, which loads `scans`. `persist` defaults to `context.save()`; tests inject a failure.
    - `save`: inside the `"Scan to saved"` signpost, adds the ID to `inFlight: Set<ScanID>`, writes files, inserts the record and persists. If persisting throws, it calls `context.rollback()`, removes the files and throws `.writeFailed`. It always removes the ID from `inFlight`. On success it updates `scans`.
    - `updateSearchText`: sets the record's text and persists (a failure is logged; the scan stays saved without it).
    - `public func removeOrphanedFiles() async`: removes folders in `Originals` and `Thumbnails` that have no record and are not in `inFlight`.
    - `public func pageFileURLs(for: ScanID) -> [URL]`.
    - `public static func makeContainer(storeURL: URL?) throws -> ModelContainer` (nil means in memory).
  - TestSupport (`public`): `@MainActor @Observable final class FakeLibrary: ScanLibrary` with `init(scans: [ScanSummary] = [])`, `var failNextSave: LibraryError?` (it throws exactly what the real store does, per Liskov), `private(set) var saved: [ScanDraft]` and `private(set) var searchTextUpdates: [ScanID: String]`. `struct FailOnceFileSystem: FileSystem` wraps another `FileSystem` and throws ENOSPC on the first `write` only (state behind a `Mutex`); the app uses it for `-FailSave`.

- [ ] **Step 1: Write the failing tests** (temp dirs; in memory unless stated):
  - `savedScanAppearsNewestFirst`
  - `saveWritesFilesBeforeTheRecord`: a recording `FileSystem` and the `persist` hook show the files exist when persisting.
  - `diskFullOnFilesInsertsNothing`
  - `contextSaveFailureRemovesFilesAndRecord` (Review Focus 2): `persist` throws; no record, no files, `.writeFailed`.
  - `orphanedFoldersAreRemovedAtLaunch` (Review Focus 3): plant `Originals/<uuid>/page-1.heic` with no record. After `removeOrphanedFiles()` it is gone, and a real scan's files remain.
  - `cleanupSkipsASaveInFlight` (Review Focus 3): a `FileSystem` that suspends after writing (a continuation the test resumes); run cleanup while suspended, then resume. The files exist and the record is there.
  - `searchTextCanArriveAfterSave`
  - `reopeningTheStoreKeepsScans`: on-disk `storeURL` in a temp dir, closed and reopened.
  - `FailOnceFileSystemTests.firstWriteFailsThenSucceeds`
- [ ] **Step 2: Run `make fast`.** Expected: FAIL to compile.
- [ ] **Step 3: Implement `ScanStore`, `FakeLibrary` and `FailOnceFileSystem`.** The store logs scan IDs and page counts (public) and titles (private).
- [ ] **Step 4: Run `make fast`.** Expected: PASS.
- [ ] **Step 5: Commit** `Library: ScanStore with all-or-nothing save and orphan cleanup`.

### Task 9: Thumbnails and page images

**Unit:** Library

**Files:**
- Create: `Sources/Library/Images/ThumbnailProviding.swift`, `ThumbnailLoader.swift`, `PageImageProviding.swift`, `PageImageLoader.swift`; `Sources/TestSupport/FakeThumbnails.swift`, `Sources/TestSupport/FakePageImages.swift`
- Test: `Tests/LibraryTests/ThumbnailLoaderTests.swift`

**Interfaces:**
- Produces (all `public`; views and snapshot fixtures use them):
  - `protocol ThumbnailProviding: Sendable { func cachedThumbnail(for id: ScanID, page: Int) -> CGImage?; func thumbnail(for id: ScanID, page: Int) async -> CGImage? }`. `cachedThumbnail` answers synchronously from memory (nil when not loaded); views render it first, so tests with a preloaded fake render images on the first frame.
  - `struct ThumbnailLoader: ThumbnailProviding` with `init(location: LibraryLocation, fileSystem: any FileSystem)`. It keeps a small in-memory LRU of up to 200 thumbnails behind a `Mutex` (my call: bounded memory). Its `@concurrent` `thumbnail` reads the cached JPEG inside the `"Thumbnail decode"` signpost. If the JPEG is missing, it rebuilds it from the original with `CGImageSourceCreateThumbnailAtIndex` (`kCGImageSourceThumbnailMaxPixelSize: 400`, `kCGImageSourceCreateThumbnailFromImageAlways: true`), writes it to the cache and returns it. It never calls `CGImageSourceCreateImageAtIndex`.
  - `protocol PageImageProviding: Sendable { func cachedPage(for id: ScanID, index: Int) -> CGImage?; func page(for id: ScanID, index: Int) async -> CGImage? }`, implemented by `struct PageImageLoader` (decodes the original at full size; only the viewer uses it; keeps the 3 most recent pages).
  - TestSupport: `final class FakeThumbnails: ThumbnailProviding` and `final class FakePageImages: PageImageProviding`. Both serve preloaded images from both methods and record every request `(ScanID, page)` behind a `Mutex`.

- [ ] **Step 1: Write the failing tests:** `cachedThumbnailIsReturned`; `missingThumbnailIsRebuiltAtThumbnailSize` (Review Focus 5): delete the cache for a 3000 × 4000 synthetic original, then the result's long edge is ≤ 400 and the cache file exists again; `missingOriginalReturnsNil`; `memoryCacheAnswersSynchronouslyAfterALoad`.
- [ ] **Step 2: Run `make fast`.** Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run `make fast`.** Expected: PASS.
- [ ] **Step 5: Commit** `Library: thumbnail and page loaders`.

### Task 10: App wiring, launch options and the root view

**Unit:** App

**Files:**
- Create: `Sources/Core/Launch/LaunchOptions.swift`, `Sources/Core/Camera/CameraAccess.swift`, `Sources/Core/Camera/CameraMode.swift`, `Sources/TestSupport/LibrarySeed.swift`, `Sources/TestSupport/FakeCameraAccess.swift`, `Sources/ScreenModels/App/AppRoute.swift`, `Sources/ScreenModels/App/Today.swift`, `Sources/Screens/Root/RootView.swift`, `Sources/Screens/Root/RootDependencies.swift`
- Modify: `App/AppEnvironment.swift`, `App/FilingCabinetApp.swift`, `Package.swift` (`ScreenModels` gains `Understanding`, `Library`; `Screens` gains `Library`), `project.yml` (the app links `Understanding`, `Library`, `TestSupport`), `Makefile` (`run`/`run-fake`/`device` pass `-TextReader $(READER)` when `READER` is set)
- Test: `Tests/CoreTests/LaunchOptionsTests.swift`, `Tests/ScreenModelsTests/TodayTests.swift`

**Interfaces:**
- Produces:
  - `public struct LaunchOptions: Sendable, Equatable` with `public init(arguments: [String], isDebugBuild: Bool)`. The app passes `true` under `#if DEBUG` and `false` otherwise; when it is false every field keeps its default (M9). Fields:
    - `isUITest` (`-UITest`): in-memory store, temp `LibraryLocation`, no animations
    - `fakeCameraPages: Int?` (`-FakeCamera <1…3>`)
    - `cameraDenied` (`-CameraDenied`)
    - `fixedDate: Date?` (`-FixedDate 2026-10-12`, noon UTC)
    - `seedScans: Int?` (`-SeedScans <n>`)
    - `failNextSave` (`-FailSave`)
    - `fakeReader` (`-FakeReader`): `FakeTextReader.readsCityPharmacy()` (M16)
    - `reduceMotion` (`-ReduceMotion`): forces the save flight's Reduce Motion path (Task 18)
    - `reader: ReaderKind` (`-TextReader text|documents`), default `.text` (A12; Task 6's checkpoint may change the default)

    Unknown flags and missing values are ignored.
  - `public enum CameraAuthorization: Sendable { case authorized, notDetermined, denied }` (restricted maps to denied) and `public protocol CameraAccess: Sendable { var status: CameraAuthorization { get }; func requestAccess() async -> Bool }`. TestSupport: `public struct FakeCameraAccess: CameraAccess` with `init(status:grantsOnRequest:)`.
  - `public enum CameraMode: Sendable { case vision; case fake(pages: @Sendable () -> [CGImage]) }` (M18: the app builds the closure from `SyntheticPages` in Debug).
  - `public enum LibrarySeed { @MainActor static func seed(_ store: ScanStore, count: Int, clock: AppClock) async throws }`: saves `count` scans with synthetic pages, cycling through the five collections, scan dates going back one day each.
  - `public enum AppRoute: Hashable { case collection(BuiltInCollection), recent, all, scan(ScanID) }`
  - `@MainActor @Observable public final class Today` with `public init(clock: AppClock)`, `public private(set) var day: CalendarDay` and `public func refresh()`. The app calls `refresh()` when the scene becomes active and on `.NSCalendarDayChanged` (M5). Models read `today.day`, so they update.
  - `public struct RootDependencies` (in Screens): every model and provider the root needs (`home`, `flow`, `makeGrid: (GridKind) -> CollectionGridModel`, `makeViewer: (ScanID) -> ViewerModel`, `thumbnails: any ThumbnailProviding`, `pages: any PageImageProviding`, `cameraMode`), with a public memberwise init. Later tasks add their fields. `public struct RootView: View` with `public init(dependencies: RootDependencies)`: a `NavigationStack(path:)` over `HomeView` with `navigationDestination(for: AppRoute.self)`.
  - `AppEnvironment` (app target) builds: `analytics`, `clock`, `today`, `store: ScanStore` (on disk at `LibraryLocation.standard().storeURL`, or in memory for `-UITest`; files over `FailOnceFileSystem` for `-FailSave`), `thumbnails`, `pages`, `scanReader`, `cameraAccess`, `cameraMode`, `lifecycle`, and the `RootDependencies`. At launch it **awaits** `store.removeOrphanedFiles()` and only then seeds (`-SeedScans`) and enables Scan.

- [ ] **Step 1: Write the failing tests:** `parsesEveryFlagInDebug`; `releaseIgnoresEveryFlag`; `unknownFlagsAreIgnored`; `fixedDateIsNoonUTC`; `readerDefaultsToText`; `missingValueIsIgnored` (`-FakeCamera` with nothing after it); `TodayTests.refreshPicksUpANewDay` (a clock whose `now` advances past midnight).
- [ ] **Step 2: Run `make fast`.** Expected: FAIL.
- [ ] **Step 3: Implement** `LaunchOptions`, the camera types, `Today` and `LibrarySeed`, then wire `AppEnvironment.make(arguments:)` and `RootView`. Every use of `TestSupport` in the app is inside `#if DEBUG`. `make run-fake` passes `-UITest -FakeCamera 1 -SeedScans 12`.
- [ ] **Step 4: Run `make fast` and `make build`.** Expected: PASS. Then `make run-fake`: the app launches to Home (still the first-launch look until Task 12).
- [ ] **Step 5: Commit** `App: launch options, store wiring and the root navigation stack`.

### Task 11: Time-left text, expiry text, collection copy and the shelf

**Unit:** ScreenModels

**Files:**
- Create: `Sources/ScreenModels/Shared/TimeLeftText.swift`, `ExpiryText.swift`, `CollectionText.swift`, `LibraryShelf.swift`, `GridKind.swift`
- Modify: `Sources/ScreenModels/Home/HomeModel.swift` (use `CollectionText`), `Localizable.xcstrings`
- Test: `Tests/ScreenModelsTests/TimeLeftTextTests.swift`, `ExpiryTextTests.swift`, `LibraryShelfTests.swift`

**Interfaces:**
- Produces (internal unless noted):
  - `enum TimeLeftText { static func text(_ left: TimeLeft) -> String }`: "Kept forever"; "1 year left" / "N years left" when ≥ 365 days (`days / 365`, rounded down); "N months left" from 60 days (`days / 30`, rounded down); "1 day left" / "N days left" below 60. (Expired never reaches it: M5.)
  - `enum ExpiryText`, with `static func untilDate(_ day: CalendarDay, today: CalendarDay, clock: AppClock) -> String` ("Jan 9", or "Jan 9, 2027" when the year isn't today's, M6; formatted with `clock.locale` and `clock.calendar`), and `static func reviewValue(collection: BuiltInCollection, override: ExpiryOverride?, scanDay: CalendarDay, today: CalendarDay, clock: AppClock) -> String`: for a lifespan "3 months · until Jan 9"; for Forever "Kept forever"; for a custom date "Until Mar 3" (M7).
  - `enum CollectionText` holding every collection string, from `HomeModel` and the components: `name(_:)`, `description(_:)`, `lifespanShort(_ Lifespan)` ("Kept forever", "1 week", "1 month", "3 months", "1 year"; the menu subtitle on 03-06), `kept(_ Lifespan)` ("Kept 1 week", "Kept 3 months", "Kept forever"), `emptyTitle(_ GridKind)`, `emptyBody(_ GridKind)` (copy below).
  - `public enum GridKind: Hashable { case collection(BuiltInCollection), recent, all }` (`RootDependencies.makeGrid` takes it) with `var preselection: BuiltInCollection?` (the collection, or nil).
  - `struct LibraryShelf` with `init(scans: [ScanSummary], today: CalendarDay, calendar: Calendar)`, `visible` (M5, newest first), `count(in:) -> Int`, `recent` (M15), `in(_ collection:) -> [ScanSummary]`, `func timeLeft(_ scan:) -> TimeLeft`, `func isSoon(_ scan:) -> Bool`.

Empty-state copy, verbatim (Collection.dc.html lines 239–246, plus A6):

| Grid | Title | Body |
|---|---|---|
| Wallet | No cards yet | IDs and cards go here, like your license and insurance card. They’re kept forever. |
| Receipts | No receipts yet | Purchase receipts go here. Each one is kept 3 months, then moves to Trash. |
| Notes | No notes yet | Handwritten and class notes go here. They’re kept forever. |
| Documents | No documents yet | Forms, letters and anything else go here. They’re kept forever. |
| Throwaways | No throwaways | Short-lived scraps go here, like a coat-check tag. Each one is kept a week. |
| Recent | Nothing recent | Scans from the last 30 days show up here. |
| All Scans | No scans yet | Every scan shows up here, newest first. |

- [ ] **Step 1: Write the failing tests:**
  - `timeLeftBoundaries`: 1 → "1 day left", 59 → "59 days left", 60 → "2 months left", 364 → "12 months left", 365 → "1 year left", 730 → "2 years left"; forever → "Kept forever".
  - `reviewValueForAReceiptScannedOct12`: "3 months · until Jan 9, 2027" with today Oct 12, 2026.
  - `yearHiddenWhenSameYear`
  - `customDateReadsUntil`
  - `dateTextIgnoresHostLocale`: a clock with `en_US` gives "Jan 9, 2027" whatever `Locale.current` is (and a `fr_FR` clock gives something else, proving the clock's locale is used).
  - `shelfHidesExpiredAndCountsPerCollection`
  - `recentIsThirtyDaysIncludingToday` (day 29 is in, day 30 is out)
  - `soonUsesTheScansOwnSpan`
  - `everyGridHasEmptyCopy`
- [ ] **Step 2: Run `make fast`.** Expected: FAIL.
- [ ] **Step 3: Implement**, with plural catalog keys for counts.
- [ ] **Step 4: Run `make fast`.** Expected: PASS, and `HomeModelTests` still passes.
- [ ] **Step 5: Commit** `ScreenModels: time-left and expiry text, collection copy, the shelf`.

### Task 12: Home with scans

**Unit:** Screen · Home (02-02, 02-05, 12-01, 01-06)

**Files:**
- Create: `Sources/ScreenModels/Home/HomeViewRow.swift`, `Sources/Screens/Home/HomeViewRowView.swift`, `SnapshotTests/Fixtures.swift`, `UITests/BrowseJourneyTests.swift`
- Modify: `Sources/ScreenModels/Home/HomeModel.swift`, `HomeRow.swift`, `Sources/Screens/Home/HomeView.swift`, `HomeRowView.swift`, `Sources/Screens/Root/RootView.swift`, `SnapshotTests/HomeSnapshotTests.swift`, `UITests/AccessibilityCoverageTests.swift`, `project.yml` (snapshot target resources: `design/prototype/scans/*.jpg`)
- Test: `Tests/ScreenModelsTests/HomeModelTests.swift`

**Interfaces:**
- Consumes: `ScanLibrary`, `Today`, `LibraryShelf`, `CollectionText`, `AppRoute`.
- Produces:
  - `public HomeModel` with `public init(library: any ScanLibrary, today: Today, calendar: Calendar)` and `var isEmpty: Bool` (M14). `rows: [HomeRow]`, where `HomeRow { collection; name; detail: Detail }` and `enum Detail: Equatable { case subtitle(String), count(Int) }`. `viewRows: [HomeViewRow]`: empty when `isEmpty`, otherwise Recent (no count) and All Scans (the visible count); `HomeViewRow { kind: .recent | .all; name; count: Int? }`.
  - `HomeView(model:onScan:onOpen: (AppRoute) -> Void)`: rows are buttons. Rows are 60 pt (Home.dc.html line 324: `row: '60px'` unless compact or large). The views card sits 16 pt below the collections (line 175) and uses `Tokens.Color.badgeNeutral` badges with `clock` and `square.grid.2x2` symbols. Counts are `.monospacedDigit()` with `.contentTransition(.numericText())`. Per A2 there is no Search, Settings or Trash row.
  - `SnapshotTests/Fixtures.swift`: `@MainActor enum Fixtures` with `static func library(_ set: FixtureSet) -> FakeLibrary`, `static let thumbnails: FakeThumbnails`, `static let pages: FakePageImages` (preloaded from `design/prototype/scans/*.jpg`), titles and ages matching the mocks (Receipts: Corner Market, Bluebird Café, Harbor Gas, …), and `static let clock`, fixed at Oct 12, 2026, `en_US`.

- [ ] **Step 1: Write the failing tests:** `emptyLibraryShowsDescriptionsAndNoViews` (today's first-launch strings); `countsPerCollectionAndViews` (Wallet 6, Receipts 23, … → `.count`; All Scans 91; Recent has no count); `expiredScansAreNotCounted`; `countsUpdateWhenTodayMovesPastAnExpiry`.
- [ ] **Step 2: Run `make fast`.** Expected: FAIL.
- [ ] **Step 3: Implement the model, then the views.** Follow the `hasScans` branch of `Home.dc.html` for a library with scans and the `first` branch for empty.
- [ ] **Step 4: Snapshots.** `home_first` (unchanged) and `home_scans` (02-02 data), each in light, dark and ax5. Run `make snapshots-record`, then `make full`. Open `make compare` against `02-02-no-favourites` (light), `02-05-home-dark` (dark) and `12-01-home` (ax5). Expected differences (A2): the hidden Search, Settings, Favorites and Trash.
- [ ] **Step 5: UI test** `BrowseJourneyTests.testHomeRowsOpenTheirDestinations`: launch with `-SeedScans 12 -FixedDate 2026-10-12` and tap each row; until Task 16 the destination is a placeholder `Text(name)` carrying `AccessibilityID.Grid.header`, which Task 16 replaces. `assertIdentifiers(AccessibilityID.Home.all, in: app)`; audit at both sizes.
- [ ] **Step 6: Run `make full`.** Expected: PASS.
- [ ] **Step 7: Commit** `Home: counts, Recent and All Scans`, naming each new snapshot reference.

### Task 13: Capture: camera access, the capture layer and the camera-off sheet

**Unit:** Screen · Capture (03-01, 04-01, 04-04)

**Files:**
- Create: `Sources/ScreenModels/Capture/ScanFlowModel.swift`, `ReviewInput.swift`; `Sources/Core/Analytics/AnalyticsKey.swift`, `ScanEventTokens.swift`; `Sources/Screens/Capture/CaptureContainer.swift`, `DocumentCameraView.swift`, `FakeCameraView.swift`, `CameraOffSheet.swift`, `SystemCameraAccess.swift`
- Modify: `Sources/Core/Analytics/AnalyticsEvent.swift`, `Sources/Core/Collections/BuiltInCollection.swift`, `Sources/Core/Accessibility/AccessibilityID.swift`, `Sources/Screens/Root/RootView.swift`, `RootDependencies.swift`, `App/Info.plist` (`NSCameraUsageDescription`: "Filing Cabinet uses the camera to scan documents. Scans stay on this iPhone."), `App/PrivacyInfo.xcprivacy` (only if a required-reason API is added: check and state it)
- Test: `Tests/ScreenModelsTests/ScanFlowModelTests.swift`, `Tests/CoreTests/AnalyticsEventTests.swift`, `SnapshotTests/CameraOffSnapshotTests.swift`, `UITests/CameraAccessJourneyTests.swift`

**Interfaces:**
- Consumes: `CameraAccess`, `CameraMode`, `AppClock`, `AppRoute`.
- Produces:
  - `public enum AnalyticsKey: String { case source, stage, pageCount, collection, reason, failedPages }`. Tokens in `ScanEventTokens.swift` (`public enum … : String, AnalyticsToken`): `ScanSource { home, grid }`, `CancelStage { camera, review }`, `FailureReason { diskFull, writeFailed }`. `BuiltInCollection` gains `AnalyticsToken` on its declaration (M8).
  - New `AnalyticsEvent` cases (names are the case names):
    - `scanStarted(source: ScanSource)`
    - `cameraDenied`
    - `cameraFailed` (VisionKit reported an error; foundations §8: one event per failure)
    - `scanCancelled(stage: CancelStage)`
    - `scanSaved(pageCount: Int, collection: BuiltInCollection)` (A4)
    - `saveFailed(reason: FailureReason)`
    - `textReadingFailed(failedPages: Int)`
  - `public struct ReviewInput: Equatable { pages: [CGImage]; preselected: BuiltInCollection?; scannedAt: Date; source: ScanSource }` (M19).
  - `@MainActor @Observable public final class ScanFlowModel` with `public init(cameraAccess: any CameraAccess, clock: AppClock, analytics: any Analytics)`. `public enum Phase: Equatable { case idle, camera(isRescan: Bool), cameraOff, review }`, `private(set) var phase`, `private(set) var reviewInput: ReviewInput?`, and:
    - `func scan(from source: ScanSource, preselected: BuiltInCollection?) async`: sends `scanStarted`; authorized → camera; notDetermined → request, then camera or cameraOff; denied → cameraOff. Every cameraOff sends `cameraDenied`.
    - `func cameraFinished(_ pages: [CGImage])`: sets or replaces `reviewInput`; phase review.
    - `func cameraCancelled()`: from the first camera → idle and `scanCancelled(.camera)`; from a rescan → review, pages kept.
    - `func cameraFailed()`: sends `cameraFailed`, then behaves as `cameraCancelled()`.
    - `func rescan()`, `func dismissCameraOff()`, `func reviewEnded()`.
  - `CaptureContainer` (M20): the one `fullScreenCover` content, shown while `phase` is `.camera` or `.review`. It switches between the camera view and the review view (Task 15) without dismissing. `cameraOff` is a separate `.sheet` on the root.
  - `DocumentCameraView` (`UIViewControllerRepresentable` over `VNDocumentCameraViewController`): `[CGImage]` on finish, `onCancel` on cancel, `onFail` on `didFailWithError` (logged with the error's domain and code). `FakeCameraView(pages: @Sendable () -> [CGImage])` has Finish and Cancel buttons (`AccessibilityID.Camera.fakeFinish`/`fakeCancel`) (M16, M18).
  - `CameraOffSheet(onOpenSettings:onClose:)`, copy from `Home.dc.html` `camoff`: "Camera access is off" / "Filing Cabinet needs the camera to scan documents. Tap Open Settings, turn on Camera, then come back." / "Open Settings". Open Settings opens `UIApplication.openSettingsURLString` through `@Environment(\.openURL)`.
  - `AccessibilityID.Camera { fakeFinish, fakeCancel }`, `AccessibilityID.CameraOff { openSettings, close }`.

- [ ] **Step 1: Write the failing tests:**
  - `authorizedGoesStraightToCamera`
  - `notDeterminedAsksThenOpensCamera`
  - `deniedShowsCameraOffAndSendsCameraDenied`
  - `refusedRequestShowsCameraOff`
  - `cancellingTheFirstCameraSavesNothingAndSendsCancelled`
  - `cameraFailureSendsCameraFailedAndReturnsHome`
  - `finishingOpensReviewWithThePages`
  - `finishedRescanReplacesTheInput`
  - `scanStartedCarriesItsSource`
  - Event payload tests: `scanSaved` payload is `[.pageCount: .int(3), .collection: .token(.init(BuiltInCollection.receipts))]`; every new case has a name and only typed values.
- [ ] **Step 2: Run `make fast`.** Expected: FAIL.
- [ ] **Step 3: Implement the model, events and views.** Home's Scan calls `scan(from: .home, preselected: nil)`.
- [ ] **Step 4: Snapshot** `camera_off` in light, dark and ax5: `CameraOffSheet` rendered as the root view inside a container reproducing the sheet chrome (corner radius, grabber) over `Tokens.Color.bgGrouped`. Compare with `04-01-camera-access-off` and `04-04-camera-access-off-dark`; the expected difference is the dimmed Home behind the sheet.
- [ ] **Step 5: UI tests** `testDeniedCameraShowsOpenSettings` (`-CameraDenied`; attach a screenshot of the presented sheet and list it) and `testCancelledCameraReturnsHome` (`-FakeCamera 1`: Scan, Cancel, Home again). `assertIdentifiers` for `Camera` and `CameraOff`; audit the sheet at both sizes.
- [ ] **Step 6: Run `make full`.** Expected: PASS.
- [ ] **Step 7: Commit** `Capture: camera access, document camera and the camera-off sheet`.

### Task 14: The review model

**Unit:** ScreenModels · Review

Do not start before Task 6's checkpoint has set `readingWaitLimit` (A14).

**Files:**
- Create: `Sources/ScreenModels/Review/ReviewModel.swift`, `ExpiryOption.swift`, `SaveAlert.swift`, `Sources/ScreenModels/Save/SavedScan.swift`
- Modify: `Sources/ScreenModels/Capture/ScanFlowModel.swift` (gains `makeReview: @escaping (ReviewInput) -> ReviewModel` in its init and `private(set) var review: ReviewModel?`, created when `reviewInput` is first set; a finished rescan calls `review.replacePages`)
- Test: `Tests/ScreenModelsTests/ReviewModelTests.swift`

**Interfaces:**
- Consumes: `ScanReader` (with `FakeTextReader` in tests), `ScanLibrary`, `ExpiryText`, `CollectionText`, `AppClock`, `Analytics`, `ReviewInput`.
- Produces: `@MainActor @Observable public final class ReviewModel`, with `public init(input: ReviewInput, reader: ScanReader, library: any ScanLibrary, clock: AppClock, analytics: any Analytics, readingWaitLimit: Duration)`.
  - **Pages:** `pages: [CGImage]`, `currentPage: Int` (0-based), `pageCountText` ("1 page" / "Page 2 of 3"), `pageAccessibilityLabel` ("Page 2 of 3").
  - **Title:** `title: String`, `func editTitle(_:)` (marks it edited), `fallbackTitle` ("Scan · Oct 12", A5).
  - **Collection:** `collection: BuiltInCollection?` (the preselection, if any), `func choose(_:)`. `collectionLabel` is "Collection · required" or "Collection"; `collectionValue` is "Choose a collection" or the name; `collectionOptions: [(collection, name, lifespanShort)]`.
  - **Expiry:** `expiryOverride: ExpiryOverride?`, `isExpiryEnabled` (true once a collection is chosen), `expiryValue` ("Set by the collection" before that; then `ExpiryText.reviewValue`). `expiryOptions: [ExpiryOption]`, where `ExpiryOption { label; detail; override: ExpiryOverride?; isSelected }`: "<Collection> default" first, then 1 week, 1 month, 3 months, 1 year and Forever, each with its until-date or "Never expires" (07-06). (No "passed" state: on the review sheet the scan day is today.) `func chooseExpiry(_ override: ExpiryOverride?)`, `func chooseExpiryDate(_ date: Date)` (stores `.lastDay(CalendarDay(date))`, refuses a day before today) and `var earliestCustomDate: Date`.
  - **Save:** `canSave` (a collection is chosen and nothing is saving), `isSaving`, `saveTitle` ("Save" / "Save to Receipts"), `saveAlert: SaveAlert?` (`SaveAlert { title: "Couldn’t save this scan"; message }`: the disk-full copy or M4's), `func save() async -> SavedScan?`, `func retrySave() async -> SavedScan?`, `func dismissSaveAlert()`. `save` waits for reading at most `readingWaitLimit`; then it saves with `searchText` (or nil if reading isn't done), and when reading later finishes it calls `library.updateSearchText` (M2).
  - **Discard:** `discardMessage` ("The page you just scanned won’t be saved." / "The 3 pages you just scanned won’t be saved."), `func discard()` (sends `scanCancelled(.review)`).
  - **Reading:** `func startReading() async`, `func replacePages(_ pages: [CGImage]) async` (rescan).
  - `public struct SavedScan: Equatable { id: ScanID; collection: BuiltInCollection; source: ScanSource; preselected: BuiltInCollection?; announcement: String }` (M11: "Saved to Receipts").

Copy, verbatim from `Review.dc.html` option G: disk full "Your iPhone is out of space. Free some up, then try again. Your pages are still here."; buttons "Not now", "Try again", "Keep editing", "Discard".

- [ ] **Step 1: Write the failing tests** (`FakeTextReader` with a scripted delay where noted):
  - `titleStartsAsFallbackThenTakesTheReadTitle` (M2)
  - `typedTitleIsNeverOverwritten`
  - `clearedTitleSavesAsFallback` (M3)
  - `noReadableTextKeepsFallback` (A5: "Scan · Oct 12")
  - `saveIsOffUntilACollectionIsChosen`
  - `preselectedCollectionIsChosen`
  - `choosingACollectionFillsExpiry` ("3 months · until Jan 9, 2027")
  - `expiryOptionsListDefaultFirstThenChoicesAndForever`
  - `customDateBeforeTodayIsRefused`
  - `fastReadingIsSavedWithTheScan`: reading finishes inside the limit; the draft has the search text.
  - `slowReadingSavesFirstAndAddsTextLater` (M2): reading takes longer than the limit; the draft's `searchText` is nil, and `searchTextUpdates` gets the text when reading ends.
  - `savedDraftCarriesEverything`: title, collection, override, `scannedAt` = clock now, pages.
  - `scanSavedEventCarriesPagesAndCollection` (A4)
  - `diskFullKeepsPagesAndOffersTryAgain` (Review Focus 2): `saveAlert` has the disk copy, the pages are untouched, `saveFailed(.diskFull)` is sent, and `retrySave()` succeeds after `failNextSave` clears.
  - `otherFailureUsesTheGenericMessage` (M4)
  - `failedReadingPagesAreReported`: `textReadingFailed(failedPages: 1)`.
  - `cancelledRescanKeepsPagesAndTitle` (Review Focus 4)
  - `rescanReplacesPagesAndRereadsUntouchedTitle`
  - `discardMessageCountsPages`
  - `discardSendsCancelledReview`
- [ ] **Step 2: Run `make fast`.** Expected: FAIL.
- [ ] **Step 3: Implement.** Reading runs once per page set. Keep the reading `Task` so `save()` can wait on it with a limit (race its value against `ContinuousClock().sleep(for: readingWaitLimit)` in a task group), and cancel it when pages are replaced.
- [ ] **Step 4: Run `make fast`.** Expected: PASS.
- [ ] **Step 5: Commit** `Review: the review model (title, collection, expiry, save, discard, rescan)`.

### Task 15: The review sheet

**Unit:** Screen · Review (03-05, 03-06, 03-07, 03-09, 04-02, 04-03)

**Files:**
- Create: `Sources/Screens/Review/ReviewView.swift`, `ReviewSheet.swift`, `CollectionMenu.swift`, `ExpiryMenu.swift`, `PageStrip.swift`; `Sources/Screens/DesignSystem/GlassCircleButton.swift`, `PagePill.swift`, `CollectionDot.swift`
- Modify: `Sources/Screens/Capture/CaptureContainer.swift`, `Sources/Core/Accessibility/AccessibilityID.swift`
- Test: `SnapshotTests/ReviewSnapshotTests.swift`, `UITests/ScanJourneyTests.swift`

**Interfaces:**
- Consumes: `ReviewModel`, `ScanFlowModel`.
- Produces:
  - `ReviewView(model: ReviewModel, onClose: () -> Void, onRescan: () -> Void, onSaved: (SavedScan, CGRect) -> Void)` (the rect is page 1's frame in `.global` coordinates at the moment of Save, for Task 18). Layout from `Review.dc.html` option G, sheet state: an X at top left, the "New scan" pill with `pageCountText`, Rescan (`arrow.counterclockwise`) at top right, the page (or a paged `TabView` plus `PageStrip` when there are several), and the bottom sheet with the editable serif title and pencil, the Collection row (a dashed folder when empty, a `CollectionDot` once chosen, ⌃⌄), the Expiry row (hourglass, dimmed until a collection is chosen) and a full-width Save.
  - Collection opens `CollectionMenu`, a `Menu` with name and `lifespanShort` per row and the badge on the right (03-06). Expiry opens `ExpiryMenu`, a `Menu` of `expiryOptions` plus "Choose a date…", which opens a sheet with a graphical `DatePicker` (`in: earliestCustomDate...`). Choosing from either menu plays `.sensoryFeedback(.selection, trigger:)` (requirements 06 · Haptics).
  - X shows an `.alert` (M22): "Discard this scan?", `discardMessage`, "Keep editing" (`.cancel`) and "Discard" (`.destructive`). A failed save shows an `.alert` with `saveAlert`, Not now and Try again.
  - At the largest text the sheet scrolls and Save stays full width (requirements 06 · Accessibility).
  - `AccessibilityID.Review { close, rescan, pagePill, title, titleField, collection, expiry, save }`. Icon buttons have labels ("Close", "Rescan").

- [ ] **Step 1: Snapshot tests first** (they fail with no references), over a `ReviewModel` built on `Fixtures` with the pharmacy receipt page, a fixed clock and a `FakeTextReader`:
  - `review_sheet` (03-05)
  - `review_picked` (03-07)
  - `review_three_pages`

  Each in light, dark and ax5. Menus and alerts are not snapshotted (Global Constraints).
- [ ] **Step 2: Implement the views.**
- [ ] **Step 3: Record and compare.** Run `make snapshots-record` and `make full`. Open the comparisons against 03-05, 03-07 and 03-09 (dark). Expected difference: "until Jan 9, 2027" where 03-07 shows "until Jan 10" (A10, M6). The ax5 sheet has no mock (12-03 is the Apple Intelligence card): judge it against the requirements' large-text rules and say so in the hand-off.
- [ ] **Step 4: UI journeys** `ScanJourneyTests` (all with `-FakeReader` except the last):
  - `testScanReviewSaveShowsOnHome`: `-FakeCamera 1 -FixedDate 2026-10-12`. Scan → Finish → the title becomes "City Pharmacy" → Save is disabled → choose Receipts (attach a screenshot of the open menu; compare it by eye with 03-06 and list it) → Expiry reads "3 months · until Jan 9, 2027" → Save to Receipts → Home shows Receipts 1.
  - `testDiscardAsksFirst`: attach the alert screenshot (compare with 04-03; expected difference: the mock draws it over the Apple Intelligence card).
  - `testRescanCancelKeepsTitle`
  - `testFailedSaveOffersTryAgain` (`-FailSave`): attach the alert screenshot (compare with 04-02, same expected difference); Try again saves.
  - `testRealVisionReadsTheTitle`: no `-FakeReader`; waits up to 90 s for "City Pharmacy". If it proves flaky in CI, raise it with Ben rather than widening the wait.

  `assertIdentifiers(AccessibilityID.Review.all, in: app)`; audit the sheet at both sizes.
- [ ] **Step 5: Run `make full`.** Expected: PASS.
- [ ] **Step 6: Commit** `Review: the review sheet`, naming each reference.

### Task 16: Collection grids, Recent and All Scans

**Unit:** Screen · Grid (05-01 to 05-06, 05-10, 05-11, 12-02)

**Files:**
- Create: `Sources/ScreenModels/Grid/CollectionGridModel.swift`, `GridTile.swift`; `Sources/Screens/Grid/CollectionGridView.swift`, `GridTileView.swift`, `EmptyCollectionView.swift`; `Sources/Screens/DesignSystem/ThumbnailView.swift`; `SnapshotTests/GridPerformanceTests.swift`
- Modify: `Sources/Screens/Root/RootView.swift`, `RootDependencies.swift`, `Sources/Core/Accessibility/AccessibilityID.swift`, `UITests/BrowseJourneyTests.swift`
- Test: `Tests/ScreenModelsTests/CollectionGridModelTests.swift`, `SnapshotTests/GridSnapshotTests.swift`

**Interfaces:**
- Consumes: `GridKind`, `LibraryShelf`, `Today`, `TimeLeftText`, `CollectionText`, `ThumbnailProviding`, `ScanFlowModel`.
- Produces:
  - `@MainActor @Observable public final class CollectionGridModel` with `public init(kind: GridKind, library: any ScanLibrary, today: Today, calendar: Calendar)`. It has:
    - `title`, and a `subtitle`: "23 scans · Kept 3 months", "1 scan · Kept forever", "No scans · Kept 1 week"; Recent: "Last 30 days"; All: "91 scans" / "No scans" (M15);
    - `tiles: [GridTile]`, newest first. `GridTile { id: ScanID; title; timeLeft: String; isSoon; dot: BuiltInCollection? }`; the dot appears only in Recent and All (05-04);
    - `isEmpty`, `emptyTitle`, `emptyBody`;
    - `tileShape: .card | .page` (Wallet `.card`, aspect 1.55; otherwise `.page`, 3:4 cropped from the top; Collection.dc.html line 317);
    - `func columns(largeText: Bool) -> Int`: 3, or 2 at large text; Wallet 2, or 1 (12-02; requirements 06 · Accessibility).
  - `public CollectionGridView(model:thumbnails:onOpen:(ScanID) -> Void, onScan: () -> Void)`: a `LazyVGrid` with a 16 pt row gap and 8 pt column gap (Collection.dc.html line 59), a glass back button, the badge (or the Recent `clock` / All `square.grid.2x2` badge) with a serif title and the subtitle, and a floating Scan. Scan calls `scan(from: .grid, preselected: model.kind.preselection)`, following the requirements' decision log. Per A2 there is no sort button. The `"Grid first frame"` signpost ends on the grid's first `onAppear`.
  - `GridTileView` reads as one VoiceOver element: "Corner Market, Receipts, 2 days left" (requirements 06 · Accessibility, minus favorite and actions, which come in later plans). `ThumbnailView(id:page:provider:)` renders `provider.cachedThumbnail` first, then loads in `.task(id:)`, showing `Tokens.Color.scanGround` while loading.
  - `AccessibilityID.Grid { back, header, scan, tile(ScanID) }`. `all` lists the static ones; tiles are checked by prefix `grid.tile.`.

- [ ] **Step 1: Write the failing model tests:**
  - `receiptsSubtitleAndTilesNewestFirst`
  - `emptyReceiptsCopy` (verbatim)
  - `emptyNotesAndDocumentsCopy` (A6)
  - `recentShowsDotsAndLastThirtyDays`
  - `allCountsEverythingVisible`
  - `walletIsCardShapedWithTwoColumnsThenOne`
  - `expiredScansAreHidden`
  - `soonTileIsFlagged` (a Throwaway on its last day; a receipt with 7 days left)
- [ ] **Step 2: Run `make fast`.** Expected: FAIL. Implement the model; expect PASS.
- [ ] **Step 3: Implement the views.**
- [ ] **Step 4: Performance test** `GridPerformanceTests.gridWithTwoThousandScansStaysBoundedWhileScrolling` (Review Focus 5), in the app-hosted snapshot target: host `CollectionGridView` for `.all` over 2,000 `FakeLibrary` scans in a `UIHostingController` that is the root of a real `UIWindow` in the host scene (402 × 874). Wait for idle. Assert `FakeThumbnails` requests are `>= 18` (the first screenful) and `<= 60`. Scroll to the end and back programmatically (find the `UIScrollView`, set `contentOffset` in screen-sized steps, spinning the run loop each step). Assert every request is for page 0, and that the distinct IDs requested since the previous step never exceed 60.
- [ ] **Step 5: Snapshots** `grid_receipts`, `grid_wallet`, `grid_throwaways`, `grid_recent`, `grid_all` and `grid_empty`, each in light, dark and ax5, with `Fixtures.thumbnails` preloaded so tiles render on the first frame. Record, then compare with 05-01 to 05-06, 05-10, 05-11 and 12-02.
- [ ] **Step 6: UI test** `testOpenReceiptsThenScanPreselectsReceipts` (`-SeedScans 12 -FakeCamera 1 -FakeReader`): the review shows "Collection" and "Receipts", and Save is enabled. `assertIdentifiers(AccessibilityID.Grid.all, in: app)`; audit the grid at both sizes. Replace Task 12's placeholder destination.
- [ ] **Step 7: Run `make full`.** Expected: PASS.
- [ ] **Step 8: Commit** `Grids: collections, Recent and All Scans`, naming each reference.

### Task 17: The viewer

**Unit:** Screen · Viewer (06-01, 06-02, 06-05)

**Files:**
- Create: `Sources/ScreenModels/Viewer/ViewerModel.swift`, `Sources/Screens/Viewer/ViewerView.swift`, `ZoomablePage.swift`
- Modify: `Sources/Screens/Root/RootView.swift`, `RootDependencies.swift`, `Sources/Core/Accessibility/AccessibilityID.swift`, `UITests/BrowseJourneyTests.swift`
- Test: `Tests/ScreenModelsTests/ViewerModelTests.swift`, `SnapshotTests/ViewerSnapshotTests.swift`

**Interfaces:**
- Consumes: `LibraryShelf`, `Today`, `TimeLeftText`, `CollectionText`, `PageImageProviding`, `ThumbnailProviding`.
- Produces:
  - `@MainActor @Observable public final class ViewerModel` with `public init(id: ScanID, library: any ScanLibrary, today: Today, calendar: Calendar)`. It has `title`, `collection`, `collectionName`, `timeLeftText` (M10), `isSoon`, `pageCount`, `currentPage` (0-based), `pageLabel` ("Page 2 of 3"), `showsStrip` (`pageCount > 1`) and `isMissing` (the scan is gone or expired; the view then pops).
  - `public ViewerView(model:pages: any PageImageProviding, thumbnails: any ThumbnailProviding)`: a paged `TabView` of `ZoomablePage` (a `UIScrollView`-backed representable: pinch 1×–4×, double-tap toggles 2×, at full resolution; it renders `pages.cachedPage` first, then loads), a glass back button and a glass header pill (SF Pro headline title; a line with the `CollectionDot`, the name, " · " and the time left, in `expirySoon` semibold when soon). The page strip shows thumbnails, the current one larger (ScanView.dc.html). Per A2 there is no More button and no bottom bar.
  - `AccessibilityID.Viewer { back, header, page, strip }`.

- [ ] **Step 1: Write the failing tests:** `leaseHeaderReadsKeptForever`; `receiptFiveDaysLeftIsSoon`; `pageLabelCounts`; `singlePageHasNoStrip`; `expiredScanIsMissing`.
- [ ] **Step 2: Run `make fast`.** Expected: FAIL. Implement; expect PASS.
- [ ] **Step 3: Snapshots** `viewer_lease` (3 pages) and `viewer_receipt` (5 days left), each in light, dark and ax5, with `Fixtures.pages` and `Fixtures.thumbnails` preloaded. Compare with 06-01, 06-02 and 06-05. Expected differences: the hidden controls (A2), and "5 days left" in place of "Expires in 5 days" (M10).
- [ ] **Step 4: UI test** `testOpenAScanFromAGridAndSwipePages` (`-SeedScans 12`). `assertIdentifiers(AccessibilityID.Viewer.all, in: app)`; audit at both sizes.
- [ ] **Step 5: Run `make full`.** Expected: PASS.
- [ ] **Step 6: Commit** `Viewer: pages, zoom and the header`, naming each reference.

### Task 18: The save moment

**Unit:** Screen · Save (A3)

**Files:**
- Create: `Sources/ScreenModels/Capture/FlightDestination.swift`, `Sources/Screens/Save/FlightTarget.swift`, `Sources/Screens/Save/FlightOverlay.swift`
- Modify: `Sources/ScreenModels/Capture/ScanFlowModel.swift`, `Sources/Screens/Root/RootView.swift`, `RootDependencies.swift`, `HomeRowView.swift`, `GridTileView.swift`, `CaptureContainer.swift`
- Test: `Tests/ScreenModelsTests/ScanFlowModelTests.swift`, `UITests/ScanJourneyTests.swift`

**Interfaces:**
- Consumes: `SavedScan`, `ScanFlowModel`, `LaunchOptions.reduceMotion`.
- Produces:
  - `public enum FlightDestination: Hashable { case badge(BuiltInCollection), tile(ScanID) }` and `static func ScanFlowModel.flightDestination(for saved: SavedScan) -> FlightDestination`: `.tile(saved.id)` when the scan started in a grid that shows it (`source == .grid` and `preselected` is nil, meaning Recent or All, or equals `saved.collection`); `.badge(saved.collection)` otherwise.
  - `ScanFlowModel` replaces `reviewEnded()` with `reviewEnded(saved: SavedScan?, from rect: CGRect?)`, which ends the capture layer without animation and sets `private(set) var flight: Flight?` (`Flight: Equatable { saved; from: CGRect; destination }`). `func flightFinished() -> String?` clears it and returns the announcement to post.
  - `func flightTarget(_ destination: FlightDestination) -> some View`: a modifier publishing the destination's frame in `.global` coordinates through a preference the root reads.
  - `FlightOverlay`: a root overlay that animates page 1's image from `flight.from` to the destination frame with a 0.45 s spring (my call; Review.dc.html has no timing), shrinking to the badge or tile, then fades. If the destination has no frame, it fades in place (M13). With `accessibilityReduceMotion` or `-ReduceMotion`, it is a 0.2 s cross-fade. The style comes from a pure `FlightStyle.choose(reduceMotion:hasDestination:)`, tested in Fast.
  - After the overlay ends: post `AccessibilityNotification.Announcement(announcement)` (M11). The success haptic is `.sensoryFeedback(.success, trigger: flight) { _, new in new != nil }`, so it fires once.

- [ ] **Step 1: Write the failing tests:** `savingFromHomeTargetsTheBadge`; `savingFromTheSameCollectionTargetsTheTile`; `savingFromRecentTargetsTheTile`; `savingFromAnotherCollectionTargetsTheBadge`; `announcementNamesTheCollection`; `flightStyleIsAFadeWithReduceMotionOrNoDestination`.
- [ ] **Step 2: Run `make fast`.** Expected: FAIL. Implement the model part; expect PASS.
- [ ] **Step 3: Implement the overlay and the modifiers.**
- [ ] **Step 4: UI test** `testSaveReturnsHomeAndCountTicks` (`-FakeReader`): after Save, the overlay is gone within 2 s, Receipts shows 1, and no element named `flight` remains. Run it again with `-ReduceMotion`.
- [ ] **Step 5: Record a simulator video** of a save from Home and from inside Receipts (`mcp__XcodeBuildMCP__record_sim_video`, or `xcrun simctl io booted recordVideo`), watch it, and list the paths in the hand-off.
- [ ] **Step 6: Run `make full`.** Expected: PASS.
- [ ] **Step 7: Commit** `Save: the page flies into its collection`.

### Task 19: End to end, docs and the branch check

**Unit:** Docs

**Files:**
- Modify: `AGENTS.md` (map: the `Understanding`, `Library`, `DeviceTests` and `ReaderComparisonTests` targets and the dependency table; commands `compare-readers`, `device-perf`, `READER=`; launch flags), `CLAUDE.md` ("Where we are"), `docs/superpowers/specs/2026-10-10-filing-cabinet-requirements.html` (section 06 · Time left gains A7's sentence: "When a scan's whole lifespan is a week or less, only its last day is orange."), `.periphery.yml` (only if new macro output needs it; per-declaration `periphery:ignore` otherwise)
- Test: `UITests/ScanJourneyTests.swift`

- [ ] **Step 1: Write the end-to-end journey** `testScanToViewer` (`-FakeCamera 3 -FakeReader -FixedDate 2026-10-12`, fresh in-memory library): Scan → read title → choose Documents → Save → open Documents → open the scan → swipe to page 3 → back to Home. `assertIdentifiers` and audit each screen.
- [ ] **Step 2: Update the docs** listed above. Check every command and path in `AGENTS.md` exists.
- [ ] **Step 3: Run `make ci` locally.** Expected: PASS (lint, hooks, lint rules, macOS slice, full, Periphery, changed snapshots, resolved). Dispatch `ios-verifier` for the evidence.
- [ ] **Step 4: Phone check with Ben.** `make device`: scan a synthetic printout or a blank page (no personal documents), save, browse, view. Then a 20-page scan of blank or synthetic pages under Instruments' Allocations: note the peak memory in the hand-off (Review Focus 5). `make device READER=documents` for a by-eye comparison if Ben wants one.
- [ ] **Step 5: Commit** `Docs: Plan 1 modules, commands and the orange rule`, then open the PR. It merges after CI's Full suite and the whole-branch review pass.
