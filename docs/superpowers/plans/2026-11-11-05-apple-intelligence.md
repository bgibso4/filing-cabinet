# Plan 5 · Apple Intelligence: smart filing and search Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** When the camera closes, Apple Intelligence reads the scan once and fills in a better title, a collection from the collections that exist, and hidden search words. The review card from the requirements (shimmer, "Reading your scan…", Save) shows it, and you still tap Save. Search finds a scan by what it is ("ID" finds a license that never prints "ID"), older scans get their words in the background, and every grid tile shows its scan date ("Nov 11 · 3 mo left"). Without Apple Intelligence everything works as today.

**Architecture:** `Understanding` gains a `ScanSuggester` seam: `ModelScanSuggester` runs the on-device `SystemLanguageModel` with a runtime schema whose collection field may only be one of the collection ids it was handed. `FakeScanSuggester` (TestSupport) scripts it for Fast and UI tests. `Library` stores the hidden words and the version of the read that made them (SchemaV4, lightweight). `ScreenModels` owns the review's card-or-sheet state, the tile's date line, hidden-word matching in `SearchMatch`, the background pass and the Settings switch. `Screens` draws the slim card, the shimmer and sweep, the growth into the sheet, the sparkle row and the Settings row. A made-up test set (75+ synthetic scans) and a macOS evaluation report, like `make compare-readers`, measure the model; they are not a CI gate.

**Tech Stack:** Swift 6, SwiftUI, SwiftData (`VersionedSchema`, lightweight stage), FoundationModels (`SystemLanguageModel`, `LanguageModelSession`, `DynamicGenerationSchema`, `Attachment` if Task 1 says so, `LanguageModelError`), Vision (as today), Core Image (degrading test scans), Swift Testing, XCTest (UI), swift-snapshot-testing 1.19.7.

**Spec:** `docs/superpowers/specs/2026-11-11-apple-intelligence-design.md` (approved by Ben 2026-11-11) and its demo https://claude.ai/artifact/E6NGvA4p6DxXM343GF3dmo; the requirements `docs/superpowers/specs/2026-10-10-filing-cabinet-requirements.html` (section 06 Scanning and review, Settings; section 04 Graceful fallback) as changed by the design's §8; `design/` (03-02, 03-03, 03-04, 03-05, 03-08, 12-03, 10-01, 10-06, 05-01, 08-03) and `Review.dc.html` (option G, lines 209–260), the loading mock https://claude.ai/artifact/SZ5Ntg5vThvnYN3KAgv14Q (option B) and the fallback mock https://claude.ai/artifact/ULgeFhB5rS6qNzMwLebT5N (option 3). Executors read Plan 4 (`docs/superpowers/plans/2026-11-09-04-favorites-search-share.md`) for the conventions this plan continues.

**Status:** Executed on branch `plan-5`, 2026-11-11 to 2026-11-12 (Tasks 1–11; the phone check and the PR follow). Tasks 4b, 4c and 4d (prompt tuning) were added during execution.

---

## Questions for Ben

None open. One decision is deliberately deferred to Task 1's stop: what to do if a suggestion takes well over 5 s on the phone (A7).

---

## Decisions

### Agreed with Ben

| # | Decision | Where it lands |
|---|---|---|
| A1 | **No real-scan experiment; a made-up test set instead.** Ben: "I dont want to do the 20-30 scan test right now"; "that would be really cool if we could create made-up scans instead. down to try". | 2, 4 |
| A2 | **Scope: naming and collection "so that scans are seamless", plus search by what a scan is.** Ben: "inference of what the doc is especially if there is not much text on it". No sentence search: "not very often are you going to describe a doc ... with more than 1-2 words". | whole plan |
| A3 | **The model runs at scan time, never while searching.** Ben: "you would need to do it at scan time to have the app be able to scale properly and stay performative". | 3, 7, 8 |
| A4 | **Collections come from whatever exists.** Ben: "it should just easily support that in the future". The model is handed the list each time; no fixed five in the suggester. | 3 |
| A5 | **You still tap Save.** Ben: "you still should save though". | 8, 9 |
| A6 | **Tile second line: date, then short time left, two lines at the default size.** Ben: "i dont want to see it wrap to 3 usually"; "the d and mo and yr could be good abreviations". | 6 |
| A7 | **Measure first.** Ben: "lets measure first before making any decisions". Task 1 stops for Ben with the phone's numbers; nothing that depends on the timing starts before he answers. | 1 |
| A8 | **Test set size and quality.** Ben: "make a couple slightly lower quality and make sure youve got 15 at elast for each collection". | 2 |
| A9 | **The design and its calls.** Ben approved the design ("looks good"), including the calls listed in it (older scans keep titles, the switch's default and wording, saving early, opening the card early, scanning from a collection). | whole plan |

### My calls (not discussed; veto any before its task starts)

| # | Call | Task |
|---|---|---|
| M1 | Hidden words are stored as one newline-joined `String` column, `searchWords`, with `searchWordsVersion: Int?` (nil = never read by the model). Bumping `ScanSuggestion.promptVersion` makes the background pass re-read older versions. | 5, 10 |
| M2 | The suggester takes the recognized text of every page (trimmed to fit, page 1 first) and, if Task 1 shows it helps, page 1 downsampled to at most 1024 px on its long side. | 3 |
| M3 | Collections are given to the model as `id`, `name`, `about`; the built-ins' `about` is the requirements' wording ("IDs and cards: license, insurance, membership, business cards", …). | 3 |
| M4 | The model's output is cleaned in one pure place: title trimmed, collapsed and cut to 40 characters on a word boundary, dropped if under 3 letters; collection kept only if its id is in the list; words lowercased unless all caps (keeps "ID", "W-2"), deduplicated, 1–40 characters, at most 8. | 3 |
| M5 | In UI tests the default suggester is "unavailable", so every existing journey keeps today's full sheet. `-Suggestions arrives\|slow\|unavailable` picks a scripted outcome. | 8 |
| M6 | "Too slow" waits 5 s from when the card appears (`suggestionWaitLimit`), unless Task 1 changes it with Ben. | 8 |
| M7 | A hidden word matches when it starts with the query term ("lic" finds "license"); title and text keep Plan 4's substring match. Every term must match somewhere (title, text or words), as today. | 7 |
| M8 | The hidden-word row's second line is a sparkle (SF Symbol `sparkles`, secondary colour) and "Matches **‹query›**". | 7 |
| M9 | The background pass runs only while the app is in the foreground, one scan at a time, newest first (the scans you most likely search for), and pauses on leaving the foreground. | 10 |
| M10 | Analytics: `suggestionOutcome(arrived\|timedOut\|failed\|unavailable)` and `suggestionChanged(title: Bool, collection: Bool)` at save. No content, ever. | 8 |
| M11 | The haptic when a suggestion lands is `.selection`, like the app's other light taps; VoiceOver hears "Suggested: ‹title›, ‹collection›". | 9 |
| M12 | Trash tiles keep their days-left line; only library grids get the date line. | 6 |

### Expected differences from the mocks

- 03-02's card shows "City Pharmacy" (the text rule); with Apple Intelligence it shows "City Pharmacy receipt".
- 05-01's tiles show "3 months left"; they now show "Oct 30 · 3 mo left".
- 10-01's subtitle reads "Suggests titles and collections"; it now reads "Names, files and finds your scans".
- 08-03 has no hidden-word row; the demo's sparkle row is the source.

---

## Roadmap

| Plan | What you can do when it's merged |
|---|---|
| 0–4 · Foundation to search (done) | Scan, review, browse, edit, self-cleaning, viewer, favourites, search, share. |
| **5 · Apple Intelligence (this plan)** | Scans come out named and filed; search finds what a scan is; tiles show their date; older scans become findable. |
| 6 · First launch and system | Welcome and the notifications ask, Send feedback, the Scan control, Shortcuts, Spotlight, rating prompt, app icon. Then TestFlight. |

---

## Global Constraints

- Plans 1–4's Global Constraints all still apply. The lines below add to them.
- iOS 27.0 minimum, iPhone, portrait, English. No `#available`. Swift 6, Approachable Concurrency. Banned: `Task.detached`, `@unchecked Sendable`, disabling concurrency checking.
- On-device only: `SystemLanguageModel.default`. Never `PrivateCloudComputeLanguageModel` or any network call (requirements: "automatic filing runs on-device").
- Only `ModelScanSuggester` imports FoundationModels. Fast tests never touch the real model; they use `FakeScanSuggester`.
- No error is ever shown for the model: unavailable, refusal, guardrail, context, parsing, timeout all mean "no suggestion" (design §3 anti-goals).
- A suggestion never overwrites a title you typed or a collection you chose, and never changes a scan after Save except to add hidden words (design §5).
- Hidden words are never shown as a list anywhere (design §3).
- Search matching and snippets only in `SearchMatch`; no model at search time; Plan 4's speed budget holds (`SearchScaleTests`).
- No document content in analytics or logs (`privacy: .private` for titles, text and words).
- Copy is localized in the owning module's `Localizable.xcstrings`, middots, no em dashes. Prompt text sent to the model is not user copy: plain English constants in `Understanding`.
- No personal documents in the repo: every test scan is made up ("Sample State", "Alex Morgan").
- Every simulator run uses `SIM_DEVICE="FC iPhone 17"`. A task finishes on `make fast`, `make build`, `make lint`, `make unused`, `make full ONLY="…"` for the classes it lists and `make affected` (AGENTS.md run policy). While fixing, `make retest ONLY="…"`. Every new UI or snapshot test class gets a line in `scripts/test-map.txt`, a new source folder gets its own row; `make test-scripts` checks it. Audit findings come from `make audit-report`; new exemptions only with Ben's OK, shown with screenshots.
- Timebox: 45–60 minutes per fix round, then revert to the last green commit and report.

## Review Focus

1. **A suggestion that lands at the worst moment:** just after the timeout grew the sheet, just after you picked a collection, while you're typing the title, during Save, after a rescan. Nothing you touched changes, nothing jumps after the sheet grew, and the rescan's old read never lands. Tests: Task 8 `lateSuggestionAfterTimeoutIsDropped`, `pickedCollectionWins`, `typedTitleWins`, `rescanCancelsTheOldSuggestion`, `saveBeforeSuggestionAddsOnlyWords`.
2. **The model says something odd:** a collection id that isn't in the list, an empty or 200-character title, 30 words, duplicate words, a title in all caps. Tests: Task 3 `SuggestionCleanupTests`.
3. **Apple Intelligence flips while the app runs** (turned off in system Settings, model still downloading, our switch turned off mid-review): no error, and review falls back to the full sheet on the next scan. Tests: Task 8 `unavailableShowsTheSheetAtOnce`, `switchOffShowsTheSheet`; Task 10 `passStopsWhenSwitchedOff`.
4. **A long scan:** 20 pages of dense text. The prompt stays inside the context, page 1 first, and the read still returns or times out cleanly. Tests: Task 3 `SuggestionPromptTests.longTextIsTrimmedPageOneFirst`; Task 4's report includes a 12-page case.
5. **The background pass on a big library:** 2,000 older scans, the app backgrounded half-way, a scan deleted while queued. It resumes where it stopped, skips the deleted one, and Search stays responsive. Tests: Task 10 `resumesAfterPause`, `skipsDeletedScans`; Task 7's `SearchScaleTests` with words.

---

## File Structure

No new module; dependencies unchanged (AGENTS.md).

```
Packages/FilingCabinetKit/Sources/
  Core/Analytics/AnalyticsEvent.swift                 modify: suggestionOutcome, suggestionChanged (M10)
  Core/Launch/LaunchOptions.swift                     modify: -Suggestions arrives|slow|unavailable
  Core/Accessibility/AccessibilityID.swift            modify: Review.card…, Settings.appleIntelligence…
  Understanding/Suggesting/ScanSuggestion.swift       create: title, collectionID, searchWords; promptVersion
  Understanding/Suggesting/SuggestionInput.swift      create: pages' text, first page image, collections
  Understanding/Suggesting/SuggestionCollection.swift create: id, name, about; builtIns (M3)
  Understanding/Suggesting/ScanSuggester.swift        create: the seam (protocol) and SuggesterAvailability
  Understanding/Suggesting/SuggestionPrompt.swift     create: instructions and prompt text, trimming (pure)
  Understanding/Suggesting/SuggestionCleanup.swift    create: M4 (pure)
  Understanding/Suggesting/ModelScanSuggester.swift   create: the on-device model
  TestSupport/FakeScanSuggester.swift                 create: scripted outcomes
  Library/Records/SchemaV4.swift                      create: ScanRecord + searchWords, searchWordsVersion
  Library/Records/LibraryMigrationPlan.swift          modify: V3 → V4 lightweight
  Library/Store/ScanDraft.swift, ScanLibrary.swift, ScanStore.swift   modify: words in, words out, the queue
  ScreenModels/Shared/TileDateText.swift              create: "Nov 11 · 3 mo left"
  ScreenModels/Grid/CollectionGridModel.swift, GridTile.swift          modify: the date line
  ScreenModels/Search/SearchMatch.swift, SearchHit.swift, SearchModel.swift  modify: hidden words
  ScreenModels/Review/ReviewModel.swift               modify: suggestion flow
  ScreenModels/Review/ReviewPresentation.swift        create: card or sheet, and why
  ScreenModels/Suggestions/SearchWordsPass.swift      create: the background pass
  ScreenModels/Settings/AppPreferences.swift, SettingsModel.swift      modify: the switch, availability, footer
  Screens/DesignSystem/Shimmer.swift                  create: the shimmer modifier (Reduce Motion aware)
  Screens/Review/ReviewCard.swift, ScanSweep.swift    create: the slim card; the scanner bar
  Screens/Review/ReviewView.swift                     modify: card ↔ sheet
  Screens/Grid/GridTileView.swift, Search/SearchResultRow.swift, Settings/SettingsView.swift  modify
App/AppEnvironment.swift, FilingCabinetApp.swift      modify: suggester, pass, scene phase
project.yml, Makefile                                 modify: SuggestionEvaluation scheme, make eval-suggestions
Packages/FilingCabinetKit/Tests/
  UnderstandingTests/  SuggestionPromptTests, SuggestionCleanupTests, SuggestionCollectionTests
  LibraryTests/        MigrationTests (+ Fixtures/LibraryV3.store), ScanStoreSearchWordsTests
  ScreenModelsTests/   TileDateTextTests, SearchMatchWordsTests, ReviewModelSuggestionTests,
                       SearchWordsPassTests, SettingsModelIntelligenceTests
  SuggestionEvaluationTests/  Fixtures/ (scans + cases.json), EvaluationRun, EvaluationReport, the test
scripts/make-eval-scans.swift                         create: renders and degrades the made-up scans
SnapshotTests/  Review (card states), Grid (re-recorded), Search, Settings
UITests/        ReviewSuggestionJourneyTests (new), SettingsJourneyTests, SearchJourneyTests
```

---

## Tasks

### Task 1: Spike: the model on Ben's phone

**Unit:** Spike (throwaway; nothing merges)

**Files:** throwaway branch `spike/plan-5` off `plan-5`; a throwaway test class in `DeviceTests/` run with the `Device` scheme, as `make device-perf` does; deleted afterwards. Lasting output: "Decided during execution" rows E1–E3 and a note for Ben in `.superpowers/for-ben.md`.

- [ ] **Step 1: A bare suggester.** `SystemLanguageModel.default`, one `LanguageModelSession` per scan with short instructions, a `DynamicGenerationSchema` with `title: String`, `collection` as `anyOf` the five ids, `words: [String]`. Confirm the constrained choice compiles and never returns an id outside the list.
- [ ] **Step 2: Twelve cases.** Use 12 of `design/prototype/scans/` (at least two per collection, plus the card-like license, coat check and parking stub) with their text read by today's `ScanReader`.
- [ ] **Step 3: Measure on the phone** (`DEVICE=<Ben's iPhone>`), each case 5 times cold-session and warm (prewarmed session), text only and text + page 1 (`Attachment`, ≤1024 px; gate on `capabilities.contains(.vision)`): p50 and p95 seconds from the text being ready to the answer, plus the Vision read itself. Record collection right/wrong and the titles.
- [ ] **Step 4: Stop for Ben (A7).** Write the numbers into `.superpowers/for-ben.md` as a small table with a recommendation, and wait. His answer sets E1 (the wait limit), E2 (image in or out), E3 (prewarm at camera open or not). Timebox: 3 hours before the stop.

### Task 2: The made-up test set

**Unit:** Test fixtures and a generator (no app code)

**Files:**
- Create: `scripts/make-eval-scans.swift`, `Packages/FilingCabinetKit/Tests/SuggestionEvaluationTests/Fixtures/cases.json`, `Fixtures/scans/*.jpg`

**Interfaces:**
- Produces: `cases.json`, an array of `{ "id": String, "files": [String], "collection": String, "titles": [String], "searches": [String], "quality": "clean"|"low", "collections": [String]? }`. `titles` lists acceptable titles; `searches` are 2–4 one- or two-word queries that must find the scan by hidden words, not printed words; `collections` overrides the list handed to the model (the custom-collection cases).

- [ ] **Step 1: The generator.** `swift scripts/make-eval-scans.swift <out>` draws each document with CoreGraphics on paper-white (receipts in a monospace face, forms with boxes, cards at card aspect, notes in a handwriting-like face where the system has one) from a table in the script, then for `quality: low` applies one of: Gaussian blur 1.5–2.5 px, 4–8° rotation, contrast 0.6, a soft shadow gradient, JPEG quality 0.3. Deterministic (fixed seeds), so re-running reproduces the files.
- [ ] **Step 2: The cases.** At least 15 per collection (A8): Wallet (licenses from 3 made-up states, passport, work badge, insurance, gym, library, business cards, transit card, vaccination card), Receipts (grocery, café, gas, pharmacy, hardware, bookshop, restaurant, online-order printout, parking garage receipt), Notes (class notes in 3 subjects, to-do list, call notes, recipe card, meeting notes), Documents (lease, W-2, 1099, registration, letters, utility bill, bank statement, warranty, school form), Throwaways (coat check, parking stub, valet, wifi slip, raffle ticket, deli number, wristband). At least 2 `low` per collection. Plus 5 custom-collection cases (a "Taxes" list for the W-2, 1099 and a tax receipt). The 25 `design/prototype/scans/` images are reused and count. All names and numbers fake.
- [ ] **Step 3: Check.** A Fast test `CasesFileTests.everyCollectionHasFifteen` (decode `cases.json`; ≥15 per built-in collection, ≥2 low each, every file exists, every case has ≥2 searches). Commit the script, JSON and images (images ≤ ~150 KB each).

### Task 3: Understanding: the suggester

**Unit:** Understanding (+ TestSupport)

**Files:**
- Create: the seven `Understanding/Suggesting/` files above, `TestSupport/FakeScanSuggester.swift`
- Test: `Tests/UnderstandingTests/SuggestionPromptTests.swift`, `SuggestionCleanupTests.swift`, `SuggestionCollectionTests.swift`, `Tests/UnderstandingTests/FakeScanSuggesterTests.swift`

**Interfaces:**
- Produces:
  - `public struct ScanSuggestion: Sendable, Equatable { package let title: String?; package let collectionID: String?; package let searchWords: [String]; package static let promptVersion = 1 }`
  - `public struct SuggestionCollection: Sendable, Equatable { package let id: String; package let name: String; package let about: String; package static var builtIns: [SuggestionCollection] }` (ids = `BuiltInCollection.rawValue`, names English, M3)
  - `public struct SuggestionInput: Sendable { package let pageTexts: [String]; package let firstPage: CGImage?; package let collections: [SuggestionCollection] }`
  - `public enum SuggesterAvailability: Sendable, Equatable { case available, unavailable }`
  - `public protocol ScanSuggester: Sendable { var availability: SuggesterAvailability { get }; func suggest(_ input: SuggestionInput) async -> ScanSuggestion? }`: nil on any failure or cancellation; never throws.
  - `package enum SuggestionPrompt { static let instructions: String; static func prompt(for input: SuggestionInput, budget: Int) -> String }`: `budget` is a character budget for the page text (the caller derives it from `contextSize`).
  - `package enum SuggestionCleanup { static func clean(title: String?, collectionID: String?, words: [String], allowed: [SuggestionCollection]) -> ScanSuggestion }` (M4)
  - `public struct ModelScanSuggester: ScanSuggester` (`init(includesImage: Bool)` per E2)
  - `public final class FakeScanSuggester: ScanSuggester` with `enum Outcome { case arrives(ScanSuggestion, after: Duration), never, unavailable }`, `static func cityPharmacy() -> ScanSuggestion` ("City Pharmacy receipt", "receipts", ["receipt", "pharmacy", "purchase"]), and `var calls: [SuggestionInput]`.

- [ ] **Step 1: Failing tests.** `SuggestionCleanupTests`: `unknownCollectionIsDropped`, `titleIsCutAtFortyOnAWord`, `shortTitleIsDropped`, `wordsAreDedupedAndCapped` (30 in, 8 out), `allCapsWordsKeepTheirCase` ("ID", "W-2"), `emptyWordsAreDropped`. `SuggestionPromptTests`: `promptListsEveryCollectionIdNameAndAbout`, `longTextIsTrimmedPageOneFirst` (20 pages × 2,000 chars, budget 6,000: page 1 whole, later pages cut, total ≤ budget), `customCollectionsAppear` (a "taxes" entry). `SuggestionCollectionTests.builtInsMatchBuiltInCollection` (same ids, same order). `FakeScanSuggesterTests.arrivesAfterItsDelay`, `neverAnswersUntilCancelled` (returns nil on cancel).
- [ ] **Step 2: Run** `make fast` — the new tests fail (types missing).
- [ ] **Step 3: Implement** the types. `ModelScanSuggester.suggest`: checks `SystemLanguageModel.default.availability`; builds the schema from `input.collections` (`anyOf` their ids); a new session per call (prewarm per E3); `respond(…, schema:)`; reads the three properties; passes them through `SuggestionCleanup`. Catches `LanguageModelError`, `SystemLanguageModel.Error`, `GeneratedContent.ParsingError` and cancellation → nil, each logged with `UnderstandingLog.logger` (no content). Not unit-tested (real model); Task 4 measures it.
- [ ] **Step 4: Run** `make fast` — PASS; `make lint`, `make unused`.
- [ ] **Step 5: Commit** "Understanding: the scan suggester seam, prompt and cleanup".

### Task 4: The evaluation report

**Unit:** A macOS test scheme, like ReaderComparison (not a gate)

**Files:**
- Create: `Tests/SuggestionEvaluationTests/EvaluationRun.swift`, `EvaluationReport.swift`, `SuggestionEvaluationTests.swift`
- Modify: `Package.swift` (test target with `Fixtures` resources), `project.yml` (scheme `SuggestionEvaluation`, macOS), `Makefile` (`eval-suggestions`, listed in AGENTS.md's table), `scripts/test-map.txt` (NONE row)

**Interfaces:**
- Consumes: `cases.json` (Task 2), `ScanReader`, `ModelScanSuggester` (Task 3).
- Produces: `make eval-suggestions` → `build/suggestion-eval.md`.

- [ ] **Step 1: Pure parts first, failing tests.** `EvaluationReportTests` (Fast, with canned results): `collectionAccuracyPerCollection`, `searchRecallCountsPrefixMatches` (a query counts as found when it starts one of the returned words, case- and accent-insensitive: M7's rule, which Task 7 then builds into `SearchMatch`), `titleCountsAsRightWhenInTitles` (case- and whitespace-insensitive), `lowQualityShownSeparately`, `timingP50AndP95`.
- [ ] **Step 2: Implement** `EvaluationReport` (Markdown: overall and per-collection collection accuracy, clean vs low, title hits with every miss listed as expected/got, search recall with every missed query, p50/p95 timing, model unavailable → a single line saying so and no numbers).
- [ ] **Step 3: The run.** `SuggestionEvaluationTests.writesTheReport` reads every case with `ScanReader` then `ModelScanSuggester`, writes the report, and asserts nothing about accuracy (informs, never blocks). Run `make eval-suggestions` on the Mac; attach the report's summary to the task report.
- [ ] **Step 4: Commit** "Evaluation: the made-up test set's report (make eval-suggestions)".

### Task 5: Library: hidden words in the store (SchemaV4)

**Unit:** Library (+ TestSupport)

**Files:**
- Create: `Sources/Library/Records/SchemaV4.swift`, `Tests/LibraryTests/Fixtures/LibraryV3.store` (+ `-shm`, `-wal`), `Tests/LibraryTests/ScanStoreSearchWordsTests.swift`
- Modify: `LibraryMigrationPlan.swift`, `ScanDraft.swift`, `ScanLibrary.swift`, `ScanStore.swift`, `TestSupport/FakeLibrary.swift`, `LibrarySeed.swift`
- Test: `MigrationTests.swift`, `FakeLibraryTests.swift`

**Interfaces:**
- Produces:
  - `SchemaV4` (4.0.0): V3's records copied, `ScanRecord` plus `var searchWords: String = ""` and `var searchWordsVersion: Int? = nil` (M1); V3 frozen; `.lightweight(fromVersion: SchemaV3.self, toVersion: SchemaV4.self)`.
  - `ScanDraft.searchWords: [String]` and `searchWordsVersion: Int?` (both default empty/nil).
  - `ScanLibrary`: `func updateSearchWords(_ words: [String], version: Int, for id: ScanID)` (bumps `searchTextRevision`; ignores a missing scan); `func searchWords() -> [ScanID: [String]]`; `func scansNeedingWords(version: Int) -> [ScanID]` (library scans, not Trash, whose `searchWordsVersion` is nil or lower, newest first, M9).
  - `LibrarySeed`: seeded scans get words from a fixed table (so UI tests can search "ID").

- [ ] **Step 1: The V3 fixture** from `main` before any change, as Plan 4's Task 2 did (three scans, one in Trash, one favourite).
- [ ] **Step 2: Failing tests.** `MigrationTests.v3StoreOpensAsV4WithNoWords`, `v1AndV2StoresStillOpen`. `ScanStoreSearchWordsTests`: `savedDraftKeepsItsWords`, `updateSearchWordsBumpsTheRevision`, `updateForAMissingScanIsIgnored`, `needingWordsSkipsTrashAndCurrentVersion`, `needingWordsIsNewestFirst`, `olderVersionNeedsWordsAgain`. `FakeLibraryTests` mirrors the first three.
- [ ] **Step 3: Implement.** **Step 4:** `make fast` PASS, lint, unused. **Step 5: Commit** "Library: hidden search words (SchemaV4)".

### Task 6: The tile's date line

**Unit:** ScreenModels + Screens (independent of Tasks 3–5)

**Files:**
- Create: `ScreenModels/Shared/TileDateText.swift`, `Tests/ScreenModelsTests/TileDateTextTests.swift`
- Modify: `CollectionGridModel.swift` (`timeLeft` becomes the date line for library grids, M12), `GridTile.swift` (rename `timeLeft` → `detail`), `GridTileView.swift`, `ScreenModels/Localizable.xcstrings`
- Test: `CollectionGridModelTests`, `GridSnapshotTests` (re-record), `HomeSnapshotTests` if Favorites cards show it (they don't today; leave)

**Interfaces:**
- Produces: `enum TileDateText { static func text(scanDay: CalendarDay, left: TimeLeft, clock: AppClock) -> String }` → `"Nov 11 · 3 mo left"`, `"Sep 28 · 2 yr left"`, `"Sep 28 · 59d left"`, `"Mar 4 · Forever"`; `.expired` → `"Mar 4 · 0d left"`. Month-day from `DayText.monthDay(_:clock:)`. Rules as `TimeLeftText` (≥365 → years, ≥60 → months by /30, else days).

- [ ] **Step 1: Failing tests.** `TileDateTextTests`: `monthsUseMo`, `yearsUseYr`, `daysUseD`, `foreverHasNoLeft`, `expiredReadsZeroDays`. (That the widest line fits is checked by eye in Step 2's snapshots, not in Fast.) `CollectionGridModelTests.libraryTilesShowTheDateLine`, `trashTilesKeepDaysLeft`.
- [ ] **Step 2: Implement; re-record** `GridSnapshotTests` (`make snapshots-record ONLY=GridSnapshotTests`), open the new references, and name each in the commit with "tile shows the scan date (Plan 5 A6)". Confirm at the default size that no tile wraps to a third line; at accessibility sizes wrapping is fine.
- [ ] **Step 3: Run** `make fast`, `make full ONLY="SnapshotTests/GridSnapshotTests"`, `make affected`. **Commit** "Grids: the scan date on every tile".

### Task 7: Search: matching what a scan is

**Unit:** ScreenModels + Screens

**Files:**
- Modify: `SearchMatch.swift` (a third source), `SearchHit.swift`, `SearchModel.swift` (index folds words; rebuilds on `searchTextRevision`), `SearchResult.swift`, `Screens/Search/SearchResultRow.swift`, `ScreenModels/Localizable.xcstrings`
- Create: `Tests/ScreenModelsTests/SearchMatchWordsTests.swift`
- Test: `SearchModelTests`, `SearchScaleTests` (seed words too), `SearchSnapshotTests` (a new hidden-word row)

**Interfaces:**
- Consumes: `ScanLibrary.searchWords()` (Task 5).
- Produces: `SearchMatch.match(title:text:words:terms:) -> SearchHit?` where `words: [Folded]`; `SearchHit.matchedOnlyHiddenWords: Bool`; `SearchResult.secondLine` gives `.snippet(String, bold:)` or `.hiddenWord(query: String)`; the row draws `.hiddenWord` as the sparkle and "Matches **‹query›**" (M8).

- [ ] **Step 1: Failing tests.** `SearchMatchWordsTests`: `wordPrefixMatches` ("lic" → "license"), `wordMustStartWithTerm` ("cense" doesn't match "license"), `pageTextBeatsWord` (snippet shown, flag false), `titleBeatsWord`, `everyTermMustMatchSomewhere` ("ID sample": "ID" by word, "sample" by text → hit), `noWordsBehavesAsPlanFour`. `SearchModelTests.searchFindsANewScanByWordAfterUpdate`.
- [ ] **Step 2: Implement; re-run** `SearchScaleTests` with 2,000 scans × 8 words: still under Plan 4's budget.
- [ ] **Step 3: Snapshot** the hidden-word row (light, dark, largest text), open it, compare with the demo. **Commit** "Search: find a scan by what it is".

### Task 8: ScreenModels: the review's suggestion flow

**Unit:** ScreenModels + Core + App wiring

**Files:**
- Create: `ScreenModels/Review/ReviewPresentation.swift`, `Tests/ScreenModelsTests/ReviewModelSuggestionTests.swift`
- Modify: `ReviewModel.swift`, `Core/Launch/LaunchOptions.swift`, `Core/Analytics/AnalyticsEvent.swift`, `App/AppEnvironment.swift`, `ScreenModels/Localizable.xcstrings`
- Test: `ReviewModelTests` (existing, unchanged behaviour with an unavailable suggester), `LaunchOptionsTests.parsesSuggestions`

**Interfaces:**
- Consumes: `ScanSuggester`, `SuggestionInput`, `SuggestionCollection.builtIns` (Task 3); `ScanDraft.searchWords`, `updateSearchWords` (Task 5).
- Produces:
  - `ReviewModel.init(…, suggester: any ScanSuggester, suggestionsOn: Bool, suggestionWaitLimit: Duration)`.
  - `package enum ReviewPresentation: Equatable { case card(isReading: Bool), sheet }` and `ReviewModel.presentation`; `card` only when `suggestionsOn` and the suggester is available.
  - `ReviewModel.openSheet()` (tap or drag): sheet, still accepting the suggestion into untouched fields.
  - `ReviewModel.suggestionAnnouncement: String?` ("Suggested: City Pharmacy receipt, Receipts") set when it lands, for the view's VoiceOver and haptic.
  - `ReviewModel.canSave`: as today, and true at once on the card when a collection is pre-selected.
  - `LaunchOptions.suggestions: SuggestionsFlag?` (`arrives`, `slow`, `unavailable`); App builds `FakeScanSuggester` for it (`arrives` = City Pharmacy after 0.3 s, `slow` = never), `unavailable` by default under `-UITest` (M5), else `ModelScanSuggester`.

- [ ] **Step 1: Failing tests** (with `FakeScanSuggester` and a test clock): `arrivalFillsTitleAndCollection`, `typedTitleWins`, `pickedCollectionWins`, `preselectedCollectionWinsAndSaveIsOn`, `openedSheetStillFills`, `timeoutGrowsTheSheetWithTheRuleTitle`, `lateSuggestionAfterTimeoutIsDropped`, `rescanCancelsTheOldSuggestion` (`calls.count` 2, only the second applies), `saveBeforeSuggestionAddsOnlyWords` (record saved with the rule title; words written later; title and collection untouched), `unavailableShowsTheSheetAtOnce`, `switchOffShowsTheSheet`, `unknownCollectionIDIsIgnored`, `announcementNamesTitleAndCollection`, `analyticsCarryNoContent` (`RecordingAnalytics` sees `suggestionOutcome(.arrived)` and `suggestionChanged(title: false, collection: true)` only).
- [ ] **Step 2: Implement.** The suggestion starts after `ScanReader` finishes (it needs the text); the wait limit counts from the review's start. One `Task` per page set, cancelled by `replacePages` and `discard`. Words from a suggestion that lands after Save go through `updateSearchWords(version: ScanSuggestion.promptVersion)`.
- [ ] **Step 3: Run** `make fast`, `make build`; `make affected` (existing review journeys must be unchanged under M5). **Commit** "Review: the suggestion flow".

### Task 9: The review card

**Unit:** Screens

**Files:**
- Create: `Screens/Review/ReviewCard.swift`, `ScanSweep.swift`, `Screens/DesignSystem/Shimmer.swift`, `UITests/ReviewSuggestionJourneyTests.swift`
- Modify: `ReviewView.swift`, `Screens/Localizable.xcstrings`, `Core/Accessibility/AccessibilityID.swift`, `scripts/test-map.txt`
- Test: `SnapshotTests/ReviewSnapshotTests.swift` (new states)

**Interfaces:**
- Consumes: `ReviewModel.presentation`, `openSheet()`, `suggestionAnnouncement` (Task 8).

- [ ] **Step 1: The card** (Review.dc.html lines 234–260, 03-02, 03-03 with the page strip, 03-08, 12-03): title with the pencil, the collection dot and "Receipts · kept 3 months", Save. Reading state per mock SZ5N option B: one shimmering bar, a placeholder dot and "Reading your scan…", Save off, the sweep down the page. Landing: rows cross-fade (0.28 s), Save turns on, `.selection` haptic, `AccessibilityNotification.Announcement(suggestionAnnouncement)` (M11). Tap or drag up: the sheet (03-04). Timeout: the card grows into the sheet and the scan shrinks (mock ULgeF option 3). Reduce Motion (and `-ReduceMotion`): no shimmer or sweep, plain rows, a 0.15 s fade, no growth animation.
- [ ] **Step 2: Snapshots** (`ReviewSnapshotTests`): `cardReading`, `cardSuggested`, `cardSuggestedThreePages`, `cardSuggestedDark`, `cardAtLargestText` (12-03), `cardReadingReduceMotion`. Open each and `make compare SCREEN=03-02-review-the-card REF=…`; differences expected only in the title text.
- [ ] **Step 3: UI journeys** (`ReviewSuggestionJourneyTests`, `-FakeCamera 1 -Suggestions …`): `testSuggestionArrivesAndSaves` (card, Save on, saved to Receipts as "City Pharmacy receipt"), `testTapCardOpensSheet`, `testSlowGrowsIntoSheet` (sheet with "Choose a collection" after the limit), `testUnavailableShowsSheet`, and an audit at the default and largest text on the card. Add the class to `scripts/test-map.txt` on the Review rows.
- [ ] **Step 4: Run** `make full ONLY="SnapshotTests/ReviewSnapshotTests UITests/ReviewSuggestionJourneyTests"`, `make affected`. **Commit** "Review: the slim card, shimmer and sweep".

### Task 10: The background pass and the Settings switch

**Unit:** ScreenModels + Screens + App

**Files:**
- Create: `ScreenModels/Suggestions/SearchWordsPass.swift`, `Tests/ScreenModelsTests/SearchWordsPassTests.swift`, `SettingsModelIntelligenceTests.swift`
- Modify: `AppPreferences.swift` (`appleIntelligenceOn`, default true), `SettingsModel.swift`, `Screens/Settings/SettingsView.swift`, `App/AppEnvironment.swift`, `App/FilingCabinetApp.swift` (scene phase → `resume()`/`pause()`), `scripts/test-map.txt`
- Test: `SettingsSnapshotTests` (10-01, 10-06, the reading footer), `SettingsJourneyTests.testSwitchOffShowsSheetOnNextScan`

**Interfaces:**
- Consumes: `scansNeedingWords(version:)`, `updateSearchWords`, `searchText(for:)` (Task 5); `PageImageProviding.page(for:index:)` for page 1; `ScanSuggester` (Task 3).
- Produces: `@MainActor @Observable final class SearchWordsPass { init(library:, pages:, suggester:, preferences:); func resume(); func pause(); private(set) var progress: (done: Int, total: Int)? }` (nil when nothing is left); `SettingsModel.intelligence: IntelligenceRow` with `isAvailable`, `isOn`, `subtitle` ("Names, files and finds your scans"), `footer` (reading "Reading your older scans so search can find them · 12 of 91", unavailable, or the privacy line from the demo); `setIntelligence(_ isOn: Bool)`.

- [ ] **Step 1: Failing tests.** `SearchWordsPassTests`: `readsNewestFirstAndWritesOnlyWords` (titles and collections unchanged), `resumesAfterPause`, `skipsDeletedScans`, `passStopsWhenSwitchedOff`, `doesNothingWhenUnavailable`, `failedReadIsRetriedNextResume`, `progressCountsDown`. `SettingsModelIntelligenceTests`: `onByDefaultWhenAvailable`, `unavailableIsOffAndDisabled`, `footerShowsProgressWhileReading`, `switchingOffPersists`.
- [ ] **Step 2: Implement; wire** the pass in `AppEnvironment` (not under `-UITest` unless `-Suggestions` is given) and the scene phase in `FilingCabinetApp`.
- [ ] **Step 3: Snapshots and journey**, `make full ONLY="SnapshotTests/SettingsSnapshotTests UITests/SettingsJourneyTests"`, `make affected`. **Commit** "Settings: the Apple Intelligence switch; older scans get search words".

### Task 11: Docs, the full suite and the phone check

**Unit:** Docs

- [ ] **Step 1: Docs.** Write the design's §8 changes into the requirements (Automatic filing, Settings, Search, tiles; the experiment row replaced); AGENTS.md (`-Suggestions`, `make eval-suggestions`, the `Suggesting/` folder in the map); CLAUDE.md "Where we are".
- [ ] **Step 2: `make eval-suggestions`** on the Mac; put the summary in the PR body.
- [ ] **Step 3: `make full ALL=1`** once (or CI's Full suite).
- [ ] **Step 4: Phone check with Ben** (`make device`): scan a real receipt, card, note and letter of his own (never committed); search "ID"; watch the Settings footer count down; turn the switch off and scan again. Small visual fixes go through the phone loop.
- [ ] **Step 5:** whole-branch review (superpowers:requesting-code-review), then the PR.

### Decided during execution

| # | Decision | From |
|---|---|---|
| E1 | The wait limit: 5 s | Task 1, Ben |
| E2 | Page 1 image in | Task 1, Ben |
| E3 | Prewarm at camera open | Task 1, Ben |
| E4 | Split the read: title and collection for the card, words after Save, the background pass fills the rest | Task 4d, Ben |
