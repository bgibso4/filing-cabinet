# Filing Cabinet · Plan 1: Scan to library · Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A working app you can scan into: capture with the document camera, review (title from the text, a collection you choose, an expiry), save safely to disk, see counts on Home, browse a collection as a grid, and open a scan to swipe and zoom its pages.

**Architecture:** Four units with narrow interfaces, as CLAUDE.md requires: Capture (VisionKit → `CapturedPages`), Understanding (Vision text → title, search text), Classification (Plan 3; this plan picks by hand), Library (SwiftData records, HEIC originals, thumbnails, expiry). Expiry rules are pure functions in `Domain/`. Views render and route intent; logic lives in `@Observable` models, which are what the tests drive.

**Tech Stack:** Swift 6 (strict concurrency), SwiftUI, SwiftData, VisionKit, Vision (`RecognizeTextRequest`), ImageIO, Swift Testing, XCUITest, XcodeGen.

**Spec:** `docs/superpowers/specs/2026-10-10-filing-cabinet-requirements.html` (sections 02, 03 stories 1–4 and 7, 04, 06), with screens in `design/` (`design/README.md` first). Section 06 wins over a screen where they differ.

## Roadmap

The spec is five subsystems, so it is five plans. Each one ends with an app you can use.

1. **Scan to library** (this plan): capture, review by hand, save, Home counts, collection grids, viewer.
2. **Editing and self-cleaning:** the details sheet (rename, move with the expiry rules and the "Move to …?" ask, expiry, Undo), Move to Trash, the Trash screen, purge on launch plus a background task, scheduled cleanup notifications, Settings › Collections lifespans with the shortening confirmation, the Home cleanup line, refreshing lists at the next expiry while the app is open.
3. **Apple Intelligence filing:** the image-first suggester with card shape before the model, the slim card, the shimmer and scan sweep, the 5-second fallback to the full sheet, the Settings switch, prewarming the model.
4. **Finding and sharing:** Favorites (Home row, sort menu, custom order), Search (ranked list, recents, filters, bold match), Share/Save to Photos/Save to Files, Copy Text.
5. **First launch and the system:** the welcome screens and notification ask, Scan control, Shortcuts and Siri, Spotlight, rating prompt, haptics, the save "flight" animation, app icon, launch screen colour, a full accessibility and largest-text pass.

## Global Constraints

- iOS 27.0 minimum, iPhone only, portrait only, English only. No `#available` branches.
- Swift 6 language mode with complete strict concurrency.
- Bundle id `com.cadre.filingcabinet`; display name "Filing Cabinet".
- `NSCameraUsageDescription`: "Filing Cabinet uses the camera to scan documents. Scans stay on this iPhone."
- No network calls. Scans are never written to Photos.
- Storage layout is exactly: `Application Support/Library.store`, `Application Support/Originals/<scan-id>/page-N.heic`, `Caches/Thumbnails/<scan-id>/page-N.jpg` (~400 px). The database never holds image data.
- SwiftData models stay CloudKit-ready: every stored property has a default or is optional, no `@Attribute(.unique)`, no relationships.
- Every user-facing string goes through the String Catalog (`Localizable.xcstrings`); plurals are catalog variations.
- Copy uses middots (" · "), never em dashes. The Scan button always says "Scan".
- Colours only from the asset catalog generated from `design/tokens.json`. Titles in New York (`.serif` design), everything else SF Pro. Radii 14 / 6 / pill. No shadows.
- `os.Logger` (subsystem `com.cadre.filingcabinet`), never `print()`. No `try?` where the caller needs to know about the failure.
- One primary type per file. Collaborators are injected through protocols; no singletons.
- Grid cells only ever decode thumbnails.
- Before claiming a task builds or passes, dispatch the `ios-verifier` agent.

## Review Focus

1. **The app dies between writing page files and saving the record.** On next launch the orphaned `Originals/<id>` folder and any `.partial` folder are deleted, and no half-scan shows anywhere. Test: Task 5 `cleanUpRemovesOrphansAndPartials`.
2. **The database save fails after the files are written** (full disk). No record exists, the files are removed, the review stays open with its pages, and Try again works. Tests: Task 5 `failedSaveLeavesNoFiles`, Task 8 `failedSaveKeepsPagesAndOffersRetry`.
3. **A page with no readable text** (a photo, a blank card back). The title falls back to "Scan · Oct 31" and Save still works once a collection is picked. Tests: Task 6 `noUsableLineGivesNil`, Task 8 `noTextUsesFallbackTitle`.
4. **The person clears the title field and saves.** The scan is saved with the text-derived (or fallback) title, never an empty title. Test: Task 8 `blankTitleSavesAutoTitle`.
5. **Rescan after editing the title.** New pages replace the old ones, but the person's title is kept; Rescan cancelled keeps the old pages. Tests: Task 8 `rescanKeepsEditedTitle`, `rescanCancelledKeepsPages`.

---

## File structure

```
project.yml                              XcodeGen: app, unit tests, UI tests
FilingCabinet/
  App/FilingCabinetApp.swift             @main; builds AppEnvironment; runs launch cleanup
  App/AppEnvironment.swift               composition root: container, paths, stores, library
  DesignSystem/Theme.swift               Color/Font/Radius/Spacing tokens as Swift names
  DesignSystem/CollectionBadge.swift     round badge + symbol view
  DesignSystem/ScanButton.swift          the floating "Scan" pill
  Domain/Lifespan.swift                  week · month · threeMonths · year · forever
  Domain/ExpiryOverride.swift            per-scan custom expiry
  Domain/ExpiryPolicy.swift              pure: expiresAt, trash entry, state
  Domain/TimeLeftFormatter.swift         pure: "2 months left", soon flag
  Domain/ExpiryLabel.swift               pure: "3 months · until Jan 10"
  Library/ScanCollection.swift           @Model
  Library/Scan.swift                     @Model
  Library/CollectionSeeder.swift         inserts the five collections once
  Library/ScanQueries.swift              predicates: active, active in collection, recent
  Library/LibraryPaths.swift             the folder layout
  Library/PageFileStore.swift            HEIC originals on disk
  Library/ThumbnailStore.swift           ~400 px JPEGs in Caches, regenerable
  Library/ScanLibrary.swift              all-or-nothing save; orphan cleanup
  Understanding/RecognizedLine.swift
  Understanding/TextRecognizing.swift    protocol + VisionTextRecognizer
  Understanding/TitleExtractor.swift     pure: lines → title
  Understanding/TextIndexer.swift        background OCR of every page after save
  Capture/CapturedPages.swift            Sendable HEIC page data
  Capture/DocumentCamera.swift           protocol + VisionKit representable
  Capture/FakeDocumentCamera.swift       DEBUG only: returns bundled sample pages
  Capture/CameraAccess.swift             authorization → .ready / .ask / .denied
  Capture/CameraAccessOffSheet.swift
  Review/ReviewModel.swift               @Observable state of one review
  Review/ReviewView.swift                full sheet over the page preview
  Review/CollectionMenu.swift
  Review/ExpiryMenu.swift
  Home/HomeModel.swift
  Home/HomeView.swift
  Browse/GridSource.swift                collection · recent · all
  Browse/CollectionGridModel.swift
  Browse/CollectionGridView.swift
  Browse/ScanTile.swift
  Browse/ThumbnailView.swift
  Viewer/ScanViewerModel.swift
  Viewer/ScanViewerView.swift
  Viewer/ZoomablePageView.swift          UIScrollView-backed pinch zoom
  Resources/Assets.xcassets              colours from tokens.json, collection symbols
  Resources/Localizable.xcstrings
  Debug/SampleScans/                     2 sample pages for the fake camera (Debug only)
FilingCabinetTests/…                     one test file per unit, named <Type>Tests.swift
FilingCabinetUITests/ScanToLibraryUITests.swift
```

Shared test helpers live in `FilingCabinetTests/Support/` (`TestCalendar.swift`: a Gregorian calendar fixed to `America/New_York`, and `date("2026-10-31 09:00")`; `InMemoryLibrary.swift`: an in-memory `ModelContainer` plus temp-dir `LibraryPaths`, with `insertScan(title:collection:capturedAt:expiresAt:trashedAt:pages:)` (defaults for everything but title and collection; `@discardableResult`, returns the `Scan`). Each task adds what it needs to this helper: `seeded()`, then `files`, `paths`, `indexer` (a recording fake), `scanLibrary` and `failNextSave()` in Task 5).

---

### Task 0: Project, toolchain and design tokens

**Files:**
- Create: `project.yml`, `FilingCabinet/App/FilingCabinetApp.swift`, `FilingCabinet/DesignSystem/Theme.swift`, `FilingCabinet/Resources/Assets.xcassets/**`, `FilingCabinet/Resources/Localizable.xcstrings`
- Modify: `CLAUDE.md` (Verification: the simulator destination), `.gitignore`
- Test: `FilingCabinetTests/ThemeTests.swift`

**Interfaces:**
- Produces: `Theme.Palette` static `Color`s named after tokens in camelCase (`bgGrouped`, `bgSurface`, `textPrimary`, `textSecondary`, `textTertiary`, `separator`, `chevron`, `tint`, `expirySoon`, `destructive`, `badgeNeutral`, `scanGround`, `bgFill`); `Theme.Palette.collection(_ colorName: String) -> Color` and `.badge(_ colorName: String) -> Color` (reads `coll-<name>` / `badge-<name>`); `Theme.Radius.surface = 14`, `.nested = 6`; `Theme.Spacing` s1…s8 from tokens; `Font.fcLargeTitle`, `.fcTitle1`, `.fcTitle2` (system serif, bold, scaled with Dynamic Type from the token sizes).

- [ ] **Step 1: Install the iOS 27 simulator runtime.** Run `xcodebuild -downloadPlatform iOS`, then `xcrun simctl list devices available | grep -i "iOS 27"`. Expected: at least one iPhone on iOS 27.x. Write its destination string into CLAUDE.md under Verification as `FC_DEST="platform=iOS Simulator,name=<name>,OS=27.1"`; every command below uses `$FC_DEST`.
- [ ] **Step 2: Write `project.yml`.** Targets `FilingCabinet` (application), `FilingCabinetTests` (unit, Swift Testing, host app), `FilingCabinetUITests`. `bundleIdPrefix: com.cadre`, deployment iOS 27.0, `SWIFT_VERSION: 6.0`, `SWIFT_STRICT_CONCURRENCY: complete`, `TARGETED_DEVICE_FAMILY: 1`, portrait only, `UILaunchScreen: { UIColorName: bg-grouped }`, the camera usage string from Global Constraints, `CFBundleDisplayName: Filing Cabinet`. Exclude `FilingCabinet/Debug/**` from Release with `EXCLUDED_SOURCE_FILE_NAMES`. Add `*.xcodeproj` to `.gitignore`.
- [ ] **Step 3: Generate the colour sets.** One colorset per token in `design/tokens.json` `color.tokens`, with `light` as the any-appearance value and `dark` as the dark value, named exactly as the token (`bg-grouped`, `coll-wallet`, …). Use a one-off script in the scratchpad; commit only the colorsets.
- [ ] **Step 4: Add the collection symbols.** Five template SVG image sets (`symbol-wallet`, `symbol-receipts`, `symbol-notes`, `symbol-documents`, `symbol-throwaways`), 24×24 viewBox, the paths from `tokens.json` `icons.collection-symbols`, `stroke="black" stroke-width="2.1" stroke-linecap="round" stroke-linejoin="round" fill="none"`, "Preserve Vector Data" on, rendering as template.
- [ ] **Step 5: Write the failing test.**

```swift
@Test(arguments: ["bg-grouped","bg-surface","bg-fill","scan-ground","text-primary","text-secondary",
                  "text-tertiary","separator","chevron","tint","expiry-soon","destructive","badge-neutral",
                  "coll-wallet","coll-receipts","coll-notes","coll-documents","coll-throwaways",
                  "badge-wallet","badge-receipts","badge-notes","badge-documents","badge-throwaways"])
func everyTokenHasAColourSet(name: String) {
    #expect(UIColor(named: name, in: .main, compatibleWith: nil) != nil)
}
@Test(arguments: ["wallet","receipts","notes","documents","throwaways"])
func everyCollectionHasASymbol(name: String) {
    #expect(UIImage(named: "symbol-\(name)") != nil)
}
```

- [ ] **Step 6: Implement `Theme.swift` and a placeholder `FilingCabinetApp` showing `Text("Filing Cabinet")` on `bg-grouped`.**
- [ ] **Step 7: Generate and run.** `xcodegen generate && xcodebuild test -scheme FilingCabinet -destination "$FC_DEST" -only-testing:FilingCabinetTests/ThemeTests`. Expected: all pass. Confirm with `ios-verifier`.
- [ ] **Step 8: Commit** `project.yml`, `.gitignore`, `CLAUDE.md`, `FilingCabinet/`, `FilingCabinetTests/` with message "Scaffold the app: XcodeGen project, design tokens, collection symbols".

---

### Task 1: Lifespans and the expiry policy

**Files:**
- Create: `FilingCabinet/Domain/Lifespan.swift`, `ExpiryOverride.swift`, `ExpiryPolicy.swift`, `FilingCabinetTests/Support/TestCalendar.swift`
- Test: `FilingCabinetTests/ExpiryPolicyTests.swift`

**Interfaces:**
- Produces:
  - `enum Lifespan: String, Codable, CaseIterable, Sendable { case week, month, threeMonths, year, forever }` with `func expiry(from start: Date, calendar: Calendar) -> Date?` (nil for forever), `var durationText: String?` ("1 week", "1 month", "3 months", "1 year", nil), `var keptText: String` ("Kept 1 week" … "Kept 3 months" … "Kept forever").
  - `enum ExpiryOverride: Codable, Equatable, Sendable { case lifespan(Lifespan); case date(Date) }`. `.date` holds the chosen calendar day; the scan expires at the start of the following day.
  - `enum ScanState: Equatable, Sendable { case active; case inTrash(purgeAt: Date); case purged }`
  - `enum ExpiryPolicy` with `static func expiresAt(capturedAt: Date, override: ExpiryOverride?, collectionLifespan: Lifespan, calendar: Calendar) -> Date?`, `static func trashEntry(expiresAt: Date?, trashedAt: Date?) -> Date?` (the earlier of the two), `static func state(trashEntry: Date?, now: Date, calendar: Calendar) -> ScanState` (Trash keeps 30 calendar days).

- [ ] **Step 1: Write the failing tests** (`cal` is the fixed test calendar; `date(_:)` parses "yyyy-MM-dd HH:mm" in it).

```swift
@Test func receiptsDefaultIsThreeMonthsFromCapture() {
    #expect(ExpiryPolicy.expiresAt(capturedAt: date("2026-10-10 14:00"), override: nil,
                                   collectionLifespan: .threeMonths, calendar: cal) == date("2027-01-10 14:00"))
}
@Test func foreverNeverExpires() {
    #expect(ExpiryPolicy.expiresAt(capturedAt: date("2026-10-10 14:00"), override: nil,
                                   collectionLifespan: .forever, calendar: cal) == nil)
}
@Test func overrideBeatsCollection() {
    #expect(ExpiryPolicy.expiresAt(capturedAt: date("2026-10-10 14:00"), override: .lifespan(.week),
                                   collectionLifespan: .forever, calendar: cal) == date("2026-10-17 14:00"))
}
@Test func customDateExpiresAtTheEndOfThatDay() {
    #expect(ExpiryPolicy.expiresAt(capturedAt: date("2026-10-10 14:00"), override: .date(date("2027-01-10 09:30")),
                                   collectionLifespan: .forever, calendar: cal) == date("2027-01-11 00:00"))
}
@Test func manualTrashBeforeExpiryWins() {
    #expect(ExpiryPolicy.trashEntry(expiresAt: date("2027-01-10 14:00"), trashedAt: date("2026-11-01 08:00"))
            == date("2026-11-01 08:00"))
}
@Test func statesAcrossTheTimeline() {
    let entry = date("2026-11-01 08:00")
    #expect(ExpiryPolicy.state(trashEntry: entry, now: date("2026-11-01 07:59"), calendar: cal) == .active)
    #expect(ExpiryPolicy.state(trashEntry: entry, now: date("2026-11-01 08:00"), calendar: cal)
            == .inTrash(purgeAt: date("2026-12-01 08:00")))
    #expect(ExpiryPolicy.state(trashEntry: entry, now: date("2026-12-01 08:00"), calendar: cal) == .purged)
    #expect(ExpiryPolicy.state(trashEntry: nil, now: .distantFuture, calendar: cal) == .active)
}
@Test func keptText() {
    #expect(Lifespan.threeMonths.keptText == "Kept 3 months")
    #expect(Lifespan.forever.keptText == "Kept forever")
    #expect(Lifespan.week.durationText == "1 week")
}
```

- [ ] **Step 2: Run** `xcodebuild test -scheme FilingCabinet -destination "$FC_DEST" -only-testing:FilingCabinetTests/ExpiryPolicyTests`. Expected: build failure, `ExpiryPolicy` not found.
- [ ] **Step 3: Implement the three files.** Use `calendar.date(byAdding:)` with `.day` 7, `.month` 1/3, `.year` 1; the custom date is `calendar.startOfDay(for:)` plus one day.
- [ ] **Step 4: Run the same command.** Expected: all pass.
- [ ] **Step 5: Commit** with message "Expiry policy: lifespans, overrides, trash timeline".

---

### Task 2: Time left and expiry labels

**Files:**
- Create: `FilingCabinet/Domain/TimeLeftFormatter.swift`, `FilingCabinet/Domain/ExpiryLabel.swift`
- Test: `FilingCabinetTests/TimeLeftFormatterTests.swift`, `FilingCabinetTests/ExpiryLabelTests.swift`

**Interfaces:**
- Consumes: `Lifespan`, `ExpiryOverride` (Task 1).
- Produces:
  - `struct TimeLeft: Equatable, Sendable { let text: String; let isSoon: Bool }`
  - `enum TimeLeftFormatter { static func timeLeft(capturedAt: Date, expiresAt: Date?, now: Date) -> TimeLeft }`
  - `enum ExpiryLabel { static func text(capturedAt: Date, override: ExpiryOverride?, collectionLifespan: Lifespan?, now: Date, calendar: Calendar) -> String }` for the review sheet's Expiry row.

Rules (from section 06 "Time left" and `design/components/Collection.dc.html` `__left`): `days = ceil((expiresAt − now) / 86 400 s)`, at least 1. Years when `days ≥ 365` (`days / 365`), months when `days ≥ 60` (`days / 30`), otherwise days. Forever reads "Kept forever". **Soon** (orange): when the scan's whole span (`expiresAt − capturedAt`, in days) is more than 7, soon is `days ≤ 7`; for spans of a week or less it is `days ≤ 1`, so a new Throwaway isn't orange all week (this comes from the screen source, which refines the spec's "last week is orange").

- [ ] **Step 1: Write the failing tests.**

```swift
@Test func formats() {
    let now = date("2026-10-31 09:00")
    func left(_ d: Double) -> String {
        TimeLeftFormatter.timeLeft(capturedAt: date("2026-01-01 09:00"), expiresAt: now.addingTimeInterval(d * 86_400), now: now).text
    }
    #expect(left(400) == "1 year left")
    #expect(left(800) == "2 years left")
    #expect(left(89) == "2 months left")
    #expect(left(60) == "2 months left")
    #expect(left(59) == "59 days left")
    #expect(left(1) == "1 day left")
    #expect(left(0.2) == "1 day left")
}
@Test func foreverIsKeptForever() {
    #expect(TimeLeftFormatter.timeLeft(capturedAt: .now, expiresAt: nil, now: .now) == TimeLeft(text: "Kept forever", isSoon: false))
}
@Test func soonIsTheLastWeekForLongSpans() {
    let now = date("2026-10-31 09:00")
    let receipt = { (d: Double) in TimeLeftFormatter.timeLeft(capturedAt: date("2026-08-01 09:00"), expiresAt: now.addingTimeInterval(d * 86_400), now: now).isSoon }
    #expect(receipt(7) && !receipt(8))
}
@Test func soonIsTheLastDayForAWeekLongThrowaway() {
    let now = date("2026-10-31 09:00")
    let throwaway = { (d: Double) in TimeLeftFormatter.timeLeft(capturedAt: now.addingTimeInterval((d - 7) * 86_400), expiresAt: now.addingTimeInterval(d * 86_400), now: now).isSoon }
    #expect(throwaway(1) && !throwaway(2))
}
@Test func expiryRowLabels() {
    let captured = date("2026-10-10 14:00"), now = date("2026-10-31 09:00")
    #expect(ExpiryLabel.text(capturedAt: captured, override: nil, collectionLifespan: nil, now: now, calendar: cal) == "Set by the collection")
    #expect(ExpiryLabel.text(capturedAt: captured, override: nil, collectionLifespan: .threeMonths, now: now, calendar: cal) == "3 months · until Jan 10, 2027")
    #expect(ExpiryLabel.text(capturedAt: captured, override: .lifespan(.week), collectionLifespan: .threeMonths, now: now, calendar: cal) == "1 week · until Oct 17")
    #expect(ExpiryLabel.text(capturedAt: captured, override: nil, collectionLifespan: .forever, now: now, calendar: cal) == "Kept forever")
    #expect(ExpiryLabel.text(capturedAt: captured, override: .date(date("2026-12-24 00:00")), collectionLifespan: .forever, now: now, calendar: cal) == "Until Dec 24")
}
```

- [ ] **Step 2: Run** `-only-testing:FilingCabinetTests/TimeLeftFormatterTests -only-testing:FilingCabinetTests/ExpiryLabelTests`. Expected: build failure.
- [ ] **Step 3: Implement both.** Dates as "MMM d", with ", yyyy" added when the year differs from `now`'s. Plural strings ("%lld days left", "%lld months left", "%lld years left") as catalog plural variations.
- [ ] **Step 4: Run.** Expected: all pass.
- [ ] **Step 5: Commit** with message "Time-left and expiry-row labels".

---

### Task 3: SwiftData models, seeding and queries

**Files:**
- Create: `FilingCabinet/Library/ScanCollection.swift`, `Scan.swift`, `CollectionSeeder.swift`, `ScanQueries.swift`, `FilingCabinetTests/Support/InMemoryLibrary.swift`
- Test: `FilingCabinetTests/ScanQueriesTests.swift`, `FilingCabinetTests/CollectionSeederTests.swift`

**Interfaces:**
- Consumes: `Lifespan`, `ExpiryOverride` (Task 1).
- Produces:
  - `@Model final class ScanCollection { var key: String = ""; var name: String = ""; var colorName: String = ""; var symbolName: String = ""; var lifespanRaw: String = Lifespan.forever.rawValue; var gridColumns: Int = 3; var sortOrder: Int = 0 }` plus computed `var lifespan: Lifespan { get set }`.
  - `@Model final class Scan { var id: UUID = UUID(); var title: String = ""; var collectionKey: String = ""; var capturedAt: Date = Date.distantPast; var expiryOverride: ExpiryOverride? = nil; var expiresAt: Date? = nil; var trashedAt: Date? = nil; var isFavorite: Bool = false; var recognizedText: String = ""; var pageFileNames: [String] = [] }`. `expiresAt` is denormalized from `ExpiryPolicy.expiresAt` so lists can filter in a predicate; whoever changes the collection, override or lifespan recomputes it (here: only `ScanLibrary.save`).
  - `struct CollectionSummary: Equatable, Sendable { let key, name, colorName, symbolName: String; let lifespan: Lifespan; let gridColumns: Int }` and `ScanCollection.summary`.
  - `enum CollectionSeeder { static func seedIfNeeded(_ context: ModelContext) throws }`
  - `enum ScanQueries { static func active(now: Date) -> Predicate<Scan>; static func active(inCollection key: String, now: Date) -> Predicate<Scan>; static func recent(now: Date, calendar: Calendar) -> Predicate<Scan> }`. "Active" means `trashedAt == nil` and (`expiresAt == nil` or `expiresAt > now`). Recent means active and `capturedAt` within the last 30 days.

Seed values (key, name, colorName, symbolName, lifespan, gridColumns, sortOrder): `wallet`, "Wallet", `wallet`, `symbol-wallet`, forever, **2**, 0 · `receipts`, "Receipts", 3 months, 3, 1 · `notes`, "Notes", forever, 3, 2 · `documents`, "Documents", forever, 3, 3 · `throwaways`, "Throwaways", 1 week, 3, 4.

- [ ] **Step 1: Write the failing tests.**

```swift
@Test func seedsFiveCollectionsOnce() throws {
    let lib = try InMemoryLibrary()
    try CollectionSeeder.seedIfNeeded(lib.context)
    try CollectionSeeder.seedIfNeeded(lib.context)
    let all = try lib.context.fetch(FetchDescriptor<ScanCollection>(sortBy: [SortDescriptor(\.sortOrder)]))
    #expect(all.map(\.key) == ["wallet", "receipts", "notes", "documents", "throwaways"])
    #expect(all.map(\.lifespan) == [.forever, .threeMonths, .forever, .forever, .week])
    #expect(all.first?.gridColumns == 2)
}
@Test func activeExcludesExpiredAndTrashed() throws {
    let lib = try InMemoryLibrary(), now = date("2026-10-31 09:00")
    lib.insertScan(title: "live", collection: "receipts", expiresAt: date("2026-11-30 09:00"))
    lib.insertScan(title: "forever", collection: "wallet", expiresAt: nil)
    lib.insertScan(title: "expired", collection: "receipts", expiresAt: date("2026-10-31 08:59"))
    lib.insertScan(title: "trashed", collection: "wallet", expiresAt: nil, trashedAt: date("2026-10-30 09:00"))
    let titles = try lib.context.fetch(FetchDescriptor(predicate: ScanQueries.active(now: now))).map(\.title).sorted()
    #expect(titles == ["forever", "live"])
    #expect(try lib.context.fetchCount(FetchDescriptor(predicate: ScanQueries.active(inCollection: "receipts", now: now))) == 1)
}
@Test func recentIsTheLast30Days() throws {
    let lib = try InMemoryLibrary(), now = date("2026-10-31 09:00")
    lib.insertScan(title: "new", collection: "notes", capturedAt: date("2026-10-02 09:00"))
    lib.insertScan(title: "old", collection: "notes", capturedAt: date("2026-09-30 09:00"))
    #expect(try lib.context.fetch(FetchDescriptor(predicate: ScanQueries.recent(now: now, calendar: cal))).map(\.title) == ["new"])
}
```

- [ ] **Step 2: Run** `-only-testing:FilingCabinetTests/ScanQueriesTests -only-testing:FilingCabinetTests/CollectionSeederTests`. Expected: build failure.
- [ ] **Step 3: Implement the models, seeder and predicates.** If `#Predicate` rejects the optional comparison, express it as `scan.expiresAt == nil || scan.expiresAt! > now`, a form SwiftData supports; keep that detail inside `ScanQueries`.
- [ ] **Step 4: Run.** Expected: all pass.
- [ ] **Step 5: Commit** with message "SwiftData models, collection seeding, active and recent queries".

---

### Task 4: Page files and thumbnails

**Files:**
- Create: `FilingCabinet/Library/LibraryPaths.swift`, `PageFileStore.swift`, `ThumbnailStore.swift`
- Test: `FilingCabinetTests/PageFileStoreTests.swift`, `FilingCabinetTests/ThumbnailStoreTests.swift`

**Interfaces:**
- Produces:
  - `struct LibraryPaths: Sendable { let originals: URL; let thumbnails: URL; static func live() throws -> LibraryPaths; static func temporary() -> LibraryPaths }`
  - `protocol PageFileStoring: Sendable { func writeOriginals(_ heicPages: [Data], scanID: UUID) throws -> [String]; func originalURL(scanID: UUID, fileName: String) -> URL; func removeOriginals(scanID: UUID) throws; func scanIDsOnDisk() throws -> Set<UUID>; func removePartials() throws }`
  - `struct PageFileStore: PageFileStoring`. It writes into `Originals/.<id>.partial/`, then renames to `Originals/<id>/` in one move. File names are `page-1.heic` … `page-N.heic`.
  - `final class ThumbnailStore: Sendable { init(paths: LibraryPaths, files: PageFileStoring); func makeThumbnails(scanID: UUID, fileNames: [String]) throws; func thumbnail(scanID: UUID, page: Int) async -> CGImage?; func removeThumbnails(scanID: UUID) }`. JPEGs at a 400 px longest side, decoded with `CGImageSourceCreateThumbnailAtIndex` (`kCGImageSourceCreateThumbnailWithTransform`), quality 0.8. A missing thumbnail is regenerated from the original. Decoded images are held in an `NSCache` keyed by "id/page".

- [ ] **Step 1: Write the failing tests.** Use a helper `samplePageHEIC(width: 1200, height: 1600) -> Data` that renders a white page with black text through `UIGraphicsImageRenderer` and `heicData()`.

```swift
@Test func writesPagesAtomically() throws {
    let store = PageFileStore(paths: .temporary()), id = UUID()
    let names = try store.writeOriginals([samplePageHEIC(), samplePageHEIC()], scanID: id)
    #expect(names == ["page-1.heic", "page-2.heic"])
    #expect(try store.scanIDsOnDisk() == [id])
    #expect(FileManager.default.fileExists(atPath: store.originalURL(scanID: id, fileName: "page-2.heic").path))
}
@Test func partialsAreNotScansAndCanBeRemoved() throws {
    let paths = LibraryPaths.temporary(), store = PageFileStore(paths: paths)
    try FileManager.default.createDirectory(at: paths.originals.appending(path: ".\(UUID()).partial"), withIntermediateDirectories: true)
    #expect(try store.scanIDsOnDisk().isEmpty)
    try store.removePartials()
    #expect(try FileManager.default.contentsOfDirectory(atPath: paths.originals.path).isEmpty)
}
@Test func thumbnailsAre400pxAndRegenerate() async throws {
    let paths = LibraryPaths.temporary(), files = PageFileStore(paths: paths), id = UUID()
    let names = try files.writeOriginals([samplePageHEIC()], scanID: id)
    let thumbs = ThumbnailStore(paths: paths, files: files)
    try thumbs.makeThumbnails(scanID: id, fileNames: names)
    #expect(await thumbs.thumbnail(scanID: id, page: 1).map { max($0.width, $0.height) } == 400)
    thumbs.removeThumbnails(scanID: id)
    #expect(await thumbs.thumbnail(scanID: id, page: 1) != nil)
}
```

- [ ] **Step 2: Run** `-only-testing:FilingCabinetTests/PageFileStoreTests -only-testing:FilingCabinetTests/ThumbnailStoreTests`. Expected: build failure.
- [ ] **Step 3: Implement.** `live()` uses `.applicationSupportDirectory` and `.cachesDirectory` and creates `Originals/` and `Thumbnails/`. Don't exclude Originals from backup: scans must be in the iCloud backup. `temporary()` uses a fresh folder in `FileManager.default.temporaryDirectory`.
- [ ] **Step 4: Run.** Expected: all pass.
- [ ] **Step 5: Commit** with message "HEIC originals and regenerable thumbnails".

---

### Task 5: All-or-nothing save and launch cleanup

**Files:**
- Create: `FilingCabinet/Library/ScanLibrary.swift`
- Test: `FilingCabinetTests/ScanLibraryTests.swift`

**Interfaces:**
- Consumes: `Scan`, `ScanCollection` (Task 3), `PageFileStoring`, `ThumbnailStore` (Task 4), `ExpiryPolicy` (Task 1), `TextIndexing` (Task 6; in this task use a recording fake that conforms to a protocol you declare here: `protocol TextIndexing: Sendable { @MainActor func indexAllPages(of scanID: UUID, pages: [Data]) }`).
- Produces:
  - `struct ScanDraft: Equatable, Sendable { var title: String; var collectionKey: String; var expiryOverride: ExpiryOverride?; var capturedAt: Date; var firstPageText: String }`
  - `protocol ScanSaving { @MainActor func save(_ draft: ScanDraft, pages: [Data]) async throws }`
  - `@MainActor final class ScanLibrary: ScanSaving { init(context: ModelContext, files: PageFileStoring, thumbnails: ThumbnailStore, indexer: TextIndexing, calendar: Calendar); func cleanUpOrphans() throws }`

`save` order: (1) write the originals off the main actor; (2) make thumbnails, logging and continuing on failure since they regenerate; (3) insert the `Scan` with `expiresAt` from `ExpiryPolicy` and the collection's lifespan, `recognizedText = firstPageText`, then `context.save()`; (4) if step 3 throws, delete the inserted model, remove the originals and thumbnails, and rethrow; (5) on success call `indexer.indexAllPages`. `cleanUpOrphans` removes partials and every `Originals/<id>` with no `Scan` record.

- [ ] **Step 1: Write the failing tests.** `FailingFiles` is a `PageFileStoring` wrapper whose `writeOriginals` throws. `InMemoryLibrary.failNextSave()` makes the next `context.save()` fail; if SwiftData's in-memory context can't be made to fail, inject a `saveContext: @MainActor () throws -> Void` closure into `ScanLibrary` (default `context.save`) and fail that instead.

```swift
@Test func savesRecordFilesAndExpiry() async throws {
    let lib = try InMemoryLibrary.seeded()
    try await lib.scanLibrary.save(.init(title: "City Pharmacy", collectionKey: "receipts", expiryOverride: nil,
                                         capturedAt: date("2026-10-10 14:00"), firstPageText: "CITY PHARMACY"),
                                   pages: [samplePageHEIC()])
    let scan = try #require(try lib.context.fetch(FetchDescriptor<Scan>()).first)
    #expect(scan.expiresAt == date("2027-01-10 14:00"))
    #expect(scan.pageFileNames == ["page-1.heic"])
    #expect(try lib.files.scanIDsOnDisk() == [scan.id])
    #expect(lib.indexer.indexed == [scan.id])
}
@Test func failedFileWriteSavesNothing() async throws {
    let lib = try InMemoryLibrary.seeded(files: FailingFiles())
    await #expect(throws: (any Error).self) { try await lib.scanLibrary.save(.receiptDraft, pages: [samplePageHEIC()]) }
    #expect(try lib.context.fetchCount(FetchDescriptor<Scan>()) == 0)
}
@Test func failedSaveLeavesNoFiles() async throws {
    let lib = try InMemoryLibrary.seeded()
    lib.failNextSave()
    await #expect(throws: (any Error).self) { try await lib.scanLibrary.save(.receiptDraft, pages: [samplePageHEIC()]) }
    #expect(try lib.files.scanIDsOnDisk().isEmpty)
    #expect(try lib.context.fetchCount(FetchDescriptor<Scan>()) == 0)
}
@Test func cleanUpRemovesOrphansAndPartials() throws {
    let lib = try InMemoryLibrary.seeded()
    let kept = lib.insertScan(title: "kept", collection: "notes")
    _ = try lib.files.writeOriginals([samplePageHEIC()], scanID: kept.id)
    _ = try lib.files.writeOriginals([samplePageHEIC()], scanID: UUID())
    try FileManager.default.createDirectory(at: lib.paths.originals.appending(path: ".\(UUID()).partial"), withIntermediateDirectories: true)
    try lib.scanLibrary.cleanUpOrphans()
    #expect(try lib.files.scanIDsOnDisk() == [kept.id])
    #expect(try FileManager.default.contentsOfDirectory(atPath: lib.paths.originals.path) == [kept.id.uuidString])
}
```

- [ ] **Step 2: Run** `-only-testing:FilingCabinetTests/ScanLibraryTests`. Expected: build failure.
- [ ] **Step 3: Implement `ScanLibrary`.**
- [ ] **Step 4: Run.** Expected: all pass.
- [ ] **Step 5: Commit** with message "All-or-nothing scan save and orphan cleanup".

---

### Task 6: Reading the scan: title and search text

**Files:**
- Create: `FilingCabinet/Understanding/RecognizedLine.swift`, `TextRecognizing.swift`, `TitleExtractor.swift`, `TextIndexer.swift`
- Test: `FilingCabinetTests/TitleExtractorTests.swift`, `FilingCabinetTests/VisionTextRecognizerTests.swift`, `FilingCabinetTests/TextIndexerTests.swift`

**Interfaces:**
- Consumes: `TextIndexing` (declared in Task 5), `Scan`.
- Produces:
  - `struct RecognizedLine: Equatable, Sendable { let text: String; let height: Double; let top: Double }`, normalized 0…1 with `top` 0 at the top of the page.
  - `protocol TextRecognizing: Sendable { func recognizeLines(in heicPage: Data) async throws -> [RecognizedLine] }` and `struct VisionTextRecognizer: TextRecognizing`, which uses `RecognizeTextRequest` with `.accurate` and language correction on.
  - `enum TitleExtractor { static func title(from lines: [RecognizedLine]) -> String?; static func tidy(_ line: String) -> String; static func fallbackTitle(capturedAt: Date, calendar: Calendar) -> String; static func fullText(_ lines: [RecognizedLine]) -> String }`
  - `@MainActor final class TextIndexer: TextIndexing { init(context: ModelContext, recognizer: TextRecognizing) }`. It recognizes all pages concurrently in a `TaskGroup` and writes `recognizedText` as the pages' full text in page order, joined by a blank line.

Title rule (carried over from the filing experiment): among lines with at least 3 letters, at most 40 characters, and fewer digits than half the letters, take the tallest; break ties by nearest the top. `tidy` turns an all-caps line into title case ("CITY PHARMACY" → "City Pharmacy"), trims whitespace and trailing punctuation, and leaves mixed case alone. With no usable line the title is `"Scan · " + "MMM d"` of the capture date.

- [ ] **Step 1: Write the failing tests.**

```swift
@Test func picksTheTallestNameLikeLine() {
    let lines = [RecognizedLine(text: "00/00/2026 00:00", height: 0.05, top: 0.10),
                 RecognizedLine(text: "CITY PHARMACY", height: 0.04, top: 0.05),
                 RecognizedLine(text: "Batteries AA", height: 0.02, top: 0.20)]
    #expect(TitleExtractor.title(from: lines) == "City Pharmacy")
}
@Test func tieGoesToTheTopLine() {
    let lines = [RecognizedLine(text: "Second Line", height: 0.03, top: 0.5), RecognizedLine(text: "First Line", height: 0.03, top: 0.1)]
    #expect(TitleExtractor.title(from: lines) == "First Line")
}
@Test func noUsableLineGivesNil() {
    #expect(TitleExtractor.title(from: []) == nil)
    #expect(TitleExtractor.title(from: [RecognizedLine(text: "1234 5678 90", height: 0.1, top: 0)]) == nil)
    #expect(TitleExtractor.fallbackTitle(capturedAt: date("2026-10-31 09:00"), calendar: cal) == "Scan · Oct 31")
}
@Test func mixedCaseIsKept() { #expect(TitleExtractor.tidy("  Bluebird Café: ") == "Bluebird Café") }
@Test func visionReadsRenderedText() async throws {
    let lines = try await VisionTextRecognizer().recognizeLines(in: samplePageHEIC(text: "CORNER MARKET"))
    #expect(lines.contains { $0.text.localizedCaseInsensitiveContains("corner market") })
}
@Test func indexerStoresEveryPageInOrder() async throws {
    let lib = try InMemoryLibrary.seeded()
    let scan = lib.insertScan(title: "x", collection: "documents")
    let indexer = TextIndexer(context: lib.context, recognizer: StubRecognizer(pages: ["page one", "page two"]))
    await indexer.indexAllPagesAndWait(of: scan.id, pages: [Data([1]), Data([2])])
    #expect(scan.recognizedText == "page one\n\npage two")
}
```

`StubRecognizer` returns one line per page keyed by the page's first byte. `indexAllPagesAndWait` is the awaitable core that `indexAllPages` starts in a `Task`.

- [ ] **Step 2: Run** `-only-testing:FilingCabinetTests/TitleExtractorTests -only-testing:FilingCabinetTests/VisionTextRecognizerTests -only-testing:FilingCabinetTests/TextIndexerTests`. Expected: build failure.
- [ ] **Step 3: Implement.** If the scan was deleted before indexing finishes, the indexer drops the result quietly.
- [ ] **Step 4: Run.** Expected: all pass.
- [ ] **Step 5: Commit** with message "Title and full text from Vision; background indexing of every page".

---

### Task 7: Capture and camera access

**Files:**
- Create: `FilingCabinet/Capture/CapturedPages.swift`, `DocumentCamera.swift`, `FakeDocumentCamera.swift`, `CameraAccess.swift`, `CameraAccessOffSheet.swift`, `FilingCabinet/Debug/SampleScans/` (copy two images from `design/prototype/scans/`: one receipt, one letter page)
- Test: `FilingCabinetTests/CameraAccessTests.swift`, `FilingCabinetTests/CapturedPagesTests.swift`

**Interfaces:**
- Produces:
  - `struct CapturedPages: Equatable, Sendable { let heicPages: [Data]; let capturedAt: Date; static func encode(_ images: [UIImage], capturedAt: Date) async throws -> CapturedPages }`, which encodes off the main actor, one page at a time.
  - `enum DocumentCameraOutcome: Sendable { case captured(CapturedPages); case cancelled; case failed }`
  - `protocol DocumentCameraPresenting { @MainActor func makeCamera(onFinish: @escaping @MainActor (DocumentCameraOutcome) -> Void) -> AnyView }`. Use `LiveDocumentCamera` (a `UIViewControllerRepresentable` around `VNDocumentCameraViewController`) in normal runs. With the launch argument `-FakeCamera`, Debug builds use `FakeDocumentCamera`: a screen with a "Capture" button returning the sample pages and a "Cancel" button.
  - `enum CameraAccess { enum Decision: Equatable { case openCamera, showAccessOff }; static func decision(for status: AVAuthorizationStatus) -> Decision }`. `.notDetermined` and `.authorized` open the camera (VisionKit asks the first time); `.denied` and `.restricted` show the access-off sheet.
  - `CameraAccessOffSheet` uses the copy from `design/components/Home.dc.html`: title "Camera access is off", body "Filing Cabinet needs the camera to scan documents. Tap Open Settings, turn on Camera, then come back.", buttons "Open Settings" (opens `UIApplication.openSettingsURLString`) and "Not now".

- [ ] **Step 1: Write the failing tests.**

```swift
@Test func accessDecisions() {
    #expect(CameraAccess.decision(for: .notDetermined) == .openCamera)
    #expect(CameraAccess.decision(for: .authorized) == .openCamera)
    #expect(CameraAccess.decision(for: .denied) == .showAccessOff)
    #expect(CameraAccess.decision(for: .restricted) == .showAccessOff)
}
@Test func encodesEachPageAsHEIC() async throws {
    let pages = try await CapturedPages.encode([sampleUIImage(), sampleUIImage()], capturedAt: .now)
    #expect(pages.heicPages.count == 2)
    #expect(pages.heicPages.allSatisfy { CGImageSourceGetType(CGImageSourceCreateWithData($0 as CFData, nil)!) as String? == "public.heic" })
}
```

- [ ] **Step 2: Run** `-only-testing:FilingCabinetTests/CameraAccessTests -only-testing:FilingCabinetTests/CapturedPagesTests`. Expected: build failure.
- [ ] **Step 3: Implement.** A camera that returns zero pages counts as `.cancelled`.
- [ ] **Step 4: Run.** Expected: all pass.
- [ ] **Step 5: Commit** with message "Document camera, captured pages, camera access".

---

### Task 8: The review model

**Files:**
- Create: `FilingCabinet/Review/ReviewModel.swift`
- Test: `FilingCabinetTests/ReviewModelTests.swift`

**Interfaces:**
- Consumes: `CapturedPages` (Task 7), `TextRecognizing`, `TitleExtractor` (Task 6), `ScanSaving`, `ScanDraft` (Task 5), `CollectionSummary` (Task 3), `ExpiryLabel` (Task 2).
- Produces: `@MainActor @Observable final class ReviewModel` with
  - `init(pages: CapturedPages, collections: [CollectionSummary], preselectedKey: String?, recognizer: TextRecognizing, saver: ScanSaving, calendar: Calendar, now: @escaping () -> Date)`
  - state: `pages: CapturedPages`, `title: String`, `selectedKey: String?`, `expiryOverride: ExpiryOverride?`, `isSaving: Bool`, `saveFailed: Bool`, `isConfirmingDiscard: Bool`
  - derived: `canSave: Bool` (a collection is chosen and not saving), `saveButtonTitle: String` ("Save" / "Save to Receipts"), `collectionLabel: String` ("Choose a collection" / the name), `isExpiryEnabled: Bool` (only once a collection is chosen), `expiryText: String` (`ExpiryLabel.text`), `headerSubtitle: String` ("1 page" / "3 pages"), `pagePill(for index: Int) -> String` ("Page 2 of 3")
  - intents: `func readTitle() async` (recognizes page 1, sets `title` unless the person has edited it), `func editTitle(_:)`, `func chooseCollection(_ key: String)` (clears the expiry override so the collection's default applies), `func chooseExpiry(_ override: ExpiryOverride?)`, `func rescanFinished(_ outcome: DocumentCameraOutcome)`, `func requestDiscard()`, `func save() async -> Bool` (true closes the review)

- [ ] **Step 1: Write the failing tests.** `RecordingSaver` records drafts and can be told to throw once. `StubRecognizer` comes from Task 6.

```swift
@Test func startsWithNoCollectionAndSaveOff() async {
    let m = makeModel(text: "CITY PHARMACY")
    await m.readTitle()
    #expect(m.title == "City Pharmacy")
    #expect(m.collectionLabel == "Choose a collection" && !m.canSave && !m.isExpiryEnabled)
    #expect(m.expiryText == "Set by the collection" && m.saveButtonTitle == "Save")
}
@Test func choosingACollectionFillsExpiry() async {
    let m = makeModel(capturedAt: date("2026-10-10 14:00"), now: date("2026-10-10 14:05"))
    m.chooseCollection("receipts")
    #expect(m.canSave && m.saveButtonTitle == "Save to Receipts")
    #expect(m.expiryText == "3 months · until Jan 10, 2027")
}
@Test func scanningInsideACollectionPreselectsIt() { #expect(makeModel(preselected: "wallet").selectedKey == "wallet") }
@Test func noTextUsesFallbackTitle() async {
    let m = makeModel(text: nil, capturedAt: date("2026-10-31 09:00"))
    await m.readTitle()
    #expect(m.title == "Scan · Oct 31")
}
@Test func blankTitleSavesAutoTitle() async {
    let saver = RecordingSaver(), m = makeModel(text: "CITY PHARMACY", saver: saver)
    await m.readTitle(); m.editTitle("   "); m.chooseCollection("receipts")
    #expect(await m.save())
    #expect(saver.drafts.first?.title == "City Pharmacy")
}
@Test func rescanKeepsEditedTitle() async {
    let m = makeModel(text: "CITY PHARMACY")
    await m.readTitle(); m.editTitle("Meds")
    m.rescanFinished(.captured(threePages)); await m.readTitle()
    #expect(m.title == "Meds" && m.headerSubtitle == "3 pages" && m.pagePill(for: 1) == "Page 2 of 3")
}
@Test func rescanCancelledKeepsPages() {
    let m = makeModel(pages: onePage)
    m.rescanFinished(.cancelled)
    #expect(m.pages == onePage)
}
@Test func failedSaveKeepsPagesAndOffersRetry() async {
    let saver = RecordingSaver(failOnce: true), m = makeModel(saver: saver)
    m.chooseCollection("notes")
    #expect(await m.save() == false)
    #expect(m.saveFailed && m.pages == onePage)
    #expect(await m.save() == true)
}
@Test func closeAsksFirst() { let m = makeModel(); m.requestDiscard(); #expect(m.isConfirmingDiscard) }
```

- [ ] **Step 2: Run** `-only-testing:FilingCabinetTests/ReviewModelTests`. Expected: build failure.
- [ ] **Step 3: Implement `ReviewModel`.** `save()` builds a `ScanDraft`. When `title` is blank after trimming, the draft uses the last auto title. `firstPageText` is `TitleExtractor.fullText` of page 1.
- [ ] **Step 4: Run.** Expected: all pass.
- [ ] **Step 5: Commit** with message "Review model: title, collection, expiry, rescan, save and failure".

---

### Task 9: The review screen

**Files:**
- Create: `FilingCabinet/Review/ReviewView.swift`, `CollectionMenu.swift`, `ExpiryMenu.swift`
- Modify: `FilingCabinet/Resources/Localizable.xcstrings`

**Interfaces:**
- Consumes: `ReviewModel` (Task 8), `DocumentCameraPresenting` (Task 7), `Theme`, `CollectionBadge` (create it here in `DesignSystem/CollectionBadge.swift`: `CollectionBadge(colorName:symbolName:size:)`, a circle in `badge-<color>` with the white template symbol).

Match `design/screens/03-05`, `03-06`, `03-07` and `04-02`/`04-03`, plus `design/components/Review.dc.html` for sizes:
- Top bar: a close button (X, labelled "Close") on the left; a glass pill in the middle reading "New scan" over `headerSubtitle`; and Rescan (`arrow.counterclockwise`, labelled "Rescan") on the right, which presents the camera.
- The page preview fills the space above the sheet. With several pages it is a paged `TabView` with the page pill.
- The sheet has a title (New York, editable inline with a pencil affordance) and a grouped surface with two rows. **Collection** ("Collection · required" until chosen, with a dashed folder icon) opens `CollectionMenu`, listing each collection with its badge and its `durationText ?? "Kept forever"`. **Expiry** (hourglass) opens `ExpiryMenu` with 1 week, 1 month, 3 months, 1 year, Forever and "Custom date…" (a graphical `DatePicker` from tomorrow on), and is disabled with "Set by the collection" until a collection is chosen.
- A full-width pill button shows `saveButtonTitle`, filled with `tint` when enabled and `bg-fill` with tertiary text when disabled.
- Discard confirmation: "Discard this scan?" with "Discard" (destructive) and "Keep editing".
- Save failure alert: "Couldn’t save this scan", "Your iPhone is out of space. Free some up, then try again.", with "Not now" and "Try again" (calls `save()` again).

- [ ] **Step 1: Build the view with `#Preview`s** for: no collection, Receipts chosen, three pages, the failure alert. Previews use a `StubRecognizer` and `RecordingSaver`.
- [ ] **Step 2: Check the previews against the PNGs in light and dark** (render each preview with `RenderPreview` via the Xcode MCP, or screenshot them in the simulator). Expected: layout, copy and colours match; the only differences are the stand-in fonts noted in `design/screens/README.md`.
- [ ] **Step 3: Build.** `xcodebuild build -scheme FilingCabinet -destination "$FC_DEST"`. Expected: succeeds with no warnings in the new files. Confirm with `ios-verifier`.
- [ ] **Step 4: Commit** with message "Review screen: full sheet, collection and expiry menus, discard and failure".

---

### Task 10: Home

**Files:**
- Create: `FilingCabinet/Home/HomeModel.swift`, `HomeView.swift`, `FilingCabinet/DesignSystem/ScanButton.swift`, `FilingCabinet/App/AppEnvironment.swift`
- Modify: `FilingCabinet/App/FilingCabinetApp.swift`
- Test: `FilingCabinetTests/HomeModelTests.swift`

**Interfaces:**
- Consumes: `ScanQueries`, `ScanCollection`, `CollectionSeeder` (Task 3), `ScanLibrary` (Task 5), `TextIndexer`, `VisionTextRecognizer` (Task 6), `DocumentCameraPresenting`, `CameraAccess` (Task 7), `ReviewModel`/`ReviewView` (Tasks 8–9).
- Produces:
  - `struct HomeRow: Equatable, Identifiable { let id: String; let summary: CollectionSummary; let count: Int }`
  - `@MainActor @Observable final class HomeModel { init(context: ModelContext, calendar: Calendar, now: @escaping () -> Date); private(set) var collectionRows: [HomeRow]; private(set) var allCount: Int; func refresh() }`
  - `@MainActor final class AppEnvironment { let container: ModelContainer; let library: ScanLibrary; let thumbnails: ThumbnailStore; let files: PageFileStoring; let camera: DocumentCameraPresenting; let recognizer: TextRecognizing; static func live(arguments: [String]) throws -> AppEnvironment }`. It seeds the collections and runs `cleanUpOrphans()` once at launch. `-InMemoryStore` (Debug) uses an in-memory container and temporary paths.
  - `enum Route: Hashable { case collection(String), recent, all, scan(UUID) }` for the `NavigationStack` path.
  - `ScanButton(action:)`: a pill in `tint` with `text.viewfinder` and "Scan", floating at the bottom centre over a fade of the background.
  - `ScanFlow` (in `HomeView.swift` or its own file if it grows): checks `CameraAccess`, presents the camera full screen, then the review as a full-screen cover with a `ReviewModel`. It takes an optional preselected collection key.

Home matches `design/screens/02-02-no-favourites.png` without the search field, the Settings button and Favorites (later plans). Large title "Filing Cabinet" (`fcLargeTitle`). Section "Collections" (`fcTitle2`). A grouped surface of 60 pt rows: badge, name, count (tabular, secondary), chevron. A second surface with Recent (clock badge in `badge-neutral`, no count) and All Scans (grid badge, count). The floating Scan button. Counts refresh on appear, after a save, and when the scene becomes active.

- [ ] **Step 1: Write the failing tests.**

```swift
@Test func rowsInOrderWithActiveCounts() throws {
    let lib = try InMemoryLibrary.seeded(), now = date("2026-10-31 09:00")
    lib.insertScan(title: "a", collection: "receipts", expiresAt: date("2026-12-01 09:00"))
    lib.insertScan(title: "b", collection: "receipts", expiresAt: date("2026-10-30 09:00"))
    lib.insertScan(title: "c", collection: "wallet", expiresAt: nil)
    let home = HomeModel(context: lib.context, calendar: cal, now: { now }); home.refresh()
    #expect(home.collectionRows.map(\.id) == ["wallet", "receipts", "notes", "documents", "throwaways"])
    #expect(home.collectionRows.map(\.count) == [1, 1, 0, 0, 0])
    #expect(home.allCount == 2)
}
```

- [ ] **Step 2: Run** `-only-testing:FilingCabinetTests/HomeModelTests`. Expected: build failure.
- [ ] **Step 3: Implement `HomeModel`, `AppEnvironment`, `HomeView`, `ScanButton`, `ScanFlow`; wire `FilingCabinetApp`.**
- [ ] **Step 4: Run the test.** Expected: pass.
- [ ] **Step 5: Run the app** in the simulator with `-FakeCamera -InMemoryStore`. Tap Scan, then Capture, choose Receipts, Save. Expected: you're back on Home and Receipts reads 1. Confirm with `ios-verifier` (screenshot).
- [ ] **Step 6: Commit** with message "Home: collection rows with counts, Recent and All, the Scan flow".

---

### Task 11: Collection grids

**Files:**
- Create: `FilingCabinet/Browse/GridSource.swift`, `CollectionGridModel.swift`, `CollectionGridView.swift`, `ScanTile.swift`, `ThumbnailView.swift`
- Test: `FilingCabinetTests/CollectionGridModelTests.swift`

**Interfaces:**
- Consumes: `ScanQueries`, `CollectionSummary` (Task 3), `TimeLeftFormatter` (Task 2), `ThumbnailStore` (Task 4), `ScanFlow`, `Route` (Task 10).
- Produces:
  - `enum GridSource: Hashable { case collection(String), recent, all }`
  - `struct GridTile: Equatable, Identifiable { let id: UUID; let title: String; let timeLeft: TimeLeft; let dotColorName: String? }`. The dot is shown only in Recent and All, where collections mix.
  - `enum GridSort: String, CaseIterable { case newestFirst, oldestFirst }` (menu items "Newest first" / "Oldest first")
  - `@MainActor @Observable final class CollectionGridModel { init(source: GridSource, context: ModelContext, now: @escaping () -> Date, calendar: Calendar); var sort: GridSort; private(set) var title: String; private(set) var subtitle: String; private(set) var tiles: [GridTile]; private(set) var columns: Int; private(set) var emptyTitle: String; private(set) var emptyBody: String; private(set) var scanButtonTitle: String; var preselectedKey: String?; func refresh() }`

Copy, from `design/components/Collection.dc.html`:
- Subtitle: "23 scans · Kept 3 months" ("1 scan" singular); Recent "Last 30 days"; All "91 scans".
- Empty states (title / body / button):
  - wallet: "No cards yet" / "IDs and cards go here, like your license and insurance card. They’re kept forever." / "Scan a card"
  - receipts: "No receipts yet" / "Purchase receipts go here. Each one is kept 3 months, then moves to Trash." / "Scan a receipt"
  - throwaways: "No throwaways" / "Short-lived scraps go here, like a coat-check tag. Each one is kept a week." / "Scan a throwaway"
  - recent: "Nothing recent" / "Scans from the last 30 days show up here." / "Scan"
  - all: "No scans yet" / "Every scan shows up here, newest first." / "Scan"
  - Notes and Documents (and future custom collections) have no copy in the design, so use "No scans yet" / "Scans you file here show up here." / "Scan". **Raise this with Ben** when the task is reviewed.

The view matches `design/screens/05-01`, `05-02`, `05-04`, `05-06`: a glass back button and a sort button (`arrow.up.arrow.down`, a menu); the badge and a `fcTitle1` name; the subtitle; a `LazyVGrid` with `columns` columns and 8 pt gutters; tiles with a thumbnail (radius 6, `scan-ground` while loading), the title (one line), and time left (caption, tabular; `expiry-soon` semibold when soon, otherwise `text-tertiary`). The floating Scan button preselects the collection when the source is `.collection`. Tapping a tile pushes `.scan(id)`.

- [ ] **Step 1: Write the failing tests.**

```swift
@Test func receiptsHeaderTilesAndSort() throws {
    let lib = try InMemoryLibrary.seeded(), now = date("2026-10-31 09:00")
    lib.insertScan(title: "Older", collection: "receipts", capturedAt: date("2026-09-01 09:00"), expiresAt: date("2026-12-01 09:00"))
    lib.insertScan(title: "Newer", collection: "receipts", capturedAt: date("2026-10-30 09:00"), expiresAt: date("2026-11-06 09:00"))
    let m = CollectionGridModel(source: .collection("receipts"), context: lib.context, now: { now }, calendar: cal); m.refresh()
    #expect(m.title == "Receipts" && m.subtitle == "2 scans · Kept 3 months" && m.columns == 3)
    #expect(m.tiles.map(\.title) == ["Newer", "Older"])
    #expect(m.tiles.first?.timeLeft == TimeLeft(text: "6 days left", isSoon: true))
    #expect(m.tiles.first?.dotColorName == nil)
    m.sort = .oldestFirst; m.refresh()
    #expect(m.tiles.map(\.title) == ["Older", "Newer"])
}
@Test func walletUsesTwoColumnsAndOneScanSingular() throws {
    let lib = try InMemoryLibrary.seeded()
    lib.insertScan(title: "Library card", collection: "wallet")
    let m = CollectionGridModel(source: .collection("wallet"), context: lib.context, now: { .now }, calendar: cal); m.refresh()
    #expect(m.columns == 2 && m.subtitle == "1 scan · Kept forever" && m.preselectedKey == "wallet")
}
@Test func allShowsDotsAndEmptyCopy() throws {
    let lib = try InMemoryLibrary.seeded()
    let m = CollectionGridModel(source: .all, context: lib.context, now: { .now }, calendar: cal); m.refresh()
    #expect(m.tiles.isEmpty && m.emptyTitle == "No scans yet" && m.emptyBody == "Every scan shows up here, newest first.")
    lib.insertScan(title: "x", collection: "notes"); m.refresh()
    #expect(m.tiles.first?.dotColorName == "notes" && m.preselectedKey == nil)
}
```

- [ ] **Step 2: Run** `-only-testing:FilingCabinetTests/CollectionGridModelTests`. Expected: build failure.
- [ ] **Step 3: Implement the model and views.** `ThumbnailView` loads with `.task(id:)` from `ThumbnailStore` and never touches originals.
- [ ] **Step 4: Run the test.** Expected: pass.
- [ ] **Step 5: Commit** with message "Collection, Recent and All grids with time left and empty states".

---

### Task 12: Viewing a scan

**Files:**
- Create: `FilingCabinet/Viewer/ScanViewerModel.swift`, `ScanViewerView.swift`, `ZoomablePageView.swift`
- Test: `FilingCabinetTests/ScanViewerModelTests.swift`

**Interfaces:**
- Consumes: `Scan`, `ScanCollection` (Task 3), `PageFileStoring`, `ThumbnailStore` (Task 4), `TimeLeftFormatter` (Task 2), `Route.scan` (Task 10).
- Produces: `@MainActor @Observable final class ScanViewerModel { init(scanID: UUID, context: ModelContext, files: PageFileStoring, now: @escaping () -> Date); private(set) var title: String; private(set) var statusLine: String; private(set) var statusIsSoon: Bool; private(set) var dotColorName: String; private(set) var pageURLs: [URL]; var currentPage: Int; func pagePill() -> String }`. `statusLine` is "Documents · Kept forever" or "Receipts · 5 days left".

Matches `design/screens/06-01` and `06-02`: a back button; a glass pill with the title over a coloured dot and `statusLine` (the time-left part in `expiry-soon` semibold when soon); the pages edge to edge in a paged `TabView`; a page strip of thumbnails under multi-page scans, with the current one larger; and the page pill reading "Page 2 of 3" to VoiceOver. `ZoomablePageView` is a `UIScrollView` (max zoom 4×, double-tap to toggle) showing the full-resolution HEIC. Only the current page and its neighbours keep decoded images. The bottom toolbar (Share, Favorite, Details, Trash) belongs to Plans 2 and 4 and is not drawn yet.

- [ ] **Step 1: Write the failing tests.**

```swift
@Test func headerForAReceipt() throws {
    let lib = try InMemoryLibrary.seeded(), now = date("2026-10-31 09:00")
    let s = lib.insertScan(title: "Corner Market", collection: "receipts", capturedAt: date("2026-08-05 09:00"), expiresAt: date("2026-11-05 09:00"), pages: 3)
    let m = ScanViewerModel(scanID: s.id, context: lib.context, files: lib.files, now: { now })
    #expect(m.title == "Corner Market" && m.statusLine == "Receipts · 5 days left" && m.statusIsSoon)
    #expect(m.pageURLs.map(\.lastPathComponent) == ["page-1.heic", "page-2.heic", "page-3.heic"])
    m.currentPage = 1
    #expect(m.pagePill() == "Page 2 of 3")
}
@Test func foreverDocument() throws {
    let lib = try InMemoryLibrary.seeded()
    let s = lib.insertScan(title: "Lease 2026", collection: "documents", expiresAt: nil)
    #expect(ScanViewerModel(scanID: s.id, context: lib.context, files: lib.files, now: { .now }).statusLine == "Documents · Kept forever")
}
```

- [ ] **Step 2: Run** `-only-testing:FilingCabinetTests/ScanViewerModelTests`. Expected: build failure.
- [ ] **Step 3: Implement the model, the viewer and the zoom view.**
- [ ] **Step 4: Run the test.** Expected: pass.
- [ ] **Step 5: Commit** with message "Scan viewer: swipe pages, pinch to zoom, page strip".

---

### Task 13: End-to-end check

**Files:**
- Create: `FilingCabinetUITests/ScanToLibraryUITests.swift`

- [ ] **Step 1: Write the UI test.** Launch with `-FakeCamera -InMemoryStore`. Tap "Scan", then "Capture". Expect a title that isn't empty and "Save" disabled. Tap the Collection row, then "Receipts". Expect "Save to Receipts". Tap it. On Home, expect the Receipts row's count "1". Open Receipts and expect one tile. Tap it and expect the viewer's status to contain "Receipts". Second test: Scan, Capture, tap Close, and expect "Discard this scan?"; tap "Discard" and expect every Home count to stay 0.
- [ ] **Step 2: Run the whole suite.** `xcodebuild test -scheme FilingCabinet -destination "$FC_DEST"`. Expected: all unit and UI tests pass. Confirm with `ios-verifier`.
- [ ] **Step 3: Check on a real iPhone (manual, with Ben).** Scan a receipt and a three-page letter, save both, relaunch the app, and open each. Check that pages zoom sharply and that nothing appeared in Photos.
- [ ] **Step 4: Commit** with message "UI test: scan, review, save, browse, view".
