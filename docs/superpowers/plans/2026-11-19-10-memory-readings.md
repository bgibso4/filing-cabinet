# Memory Readings Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Debug builds on an iPhone record the app's memory at six points of a scan to a file, so #50's numbers can be read off the phone after an unplugged scan.

**Architecture:** Two small types in `Core/Diagnostics`: `MemoryReading` asks the system for the numbers, `MemoryLog` formats a line, appends it to a file and logs it. Six one-line calls in the scan flow, the viewer and the app. `MemoryLog.record` does nothing outside a debug build on iOS.

**Tech Stack:** Swift 6, Darwin `task_info` (`TASK_VM_INFO`), `os_proc_available_memory`, `os.Logger`, Swift Testing.

**Spec:** `docs/superpowers/specs/2026-11-19-memory-readings-design.md`

## Global Constraints

- Release builds behave exactly as today: `record` compiles to nothing unless `DEBUG && os(iOS)`.
- Lines hold a time, a stage name, a page count and numbers only. No titles, text or images.
- The file is `Library/Caches/memory-readings.txt` in the app's container; appended to, never cleared.
- `Core` stays Mac-buildable; `left` is nil on macOS.
- Log with `os.Logger` (category `Core`); `try?` only with a comment; `public` only for what the app target calls.
- No lint, hook or tolerance changes. No fix for anything the numbers show.
- Ruling (Claude): `MemoryLog` is a static enum like the modules' `…Log` enums, not an injected collaborator. It is a debug diagnostic with no behaviour to swap; injecting it would thread a parameter through four models for six calls.

## Review Focus

- The Caches folder or file cannot be written: logged once per call, the scan carries on. Test in Task 1.
- `task_info` fails: `current()` is nil, the line says `unavailable`, nothing crashes. Test in Task 1.
- Fast tests on the Mac must not write a file into the developer's own Caches: `record` is a no-op on macOS. Checked in Task 2 (no file appears after `make fast`).
- UI tests on the simulator do write the file; it is a few lines in a throwaway container. Accepted.
- Two calls at once (a save finishing while the app goes to the background): appends go through one `FileHandle` write each, so lines never interleave mid-line. Test in Task 1 with concurrent appends.

---

### Task 1: The reading and the log line

**Files:**
- Create: `Packages/FilingCabinetKit/Sources/Core/Diagnostics/MemoryReading.swift`
- Create: `Packages/FilingCabinetKit/Sources/Core/Diagnostics/MemoryStage.swift`
- Create: `Packages/FilingCabinetKit/Sources/Core/Diagnostics/MemoryLog.swift`
- Create: `Packages/FilingCabinetKit/Sources/Core/CoreLog.swift` (only if `Core` has no logger yet)
- Test: `Packages/FilingCabinetKit/Tests/CoreTests/MemoryReadingTests.swift`, `MemoryLogTests.swift`

**Interfaces:**
- Produces:
  - `package struct MemoryReading: Equatable, Sendable { let now: UInt64; let peak: UInt64; let left: UInt64? }` (bytes) with `package static func current() -> MemoryReading?`
  - `public enum MemoryStage: String, Sendable` with raw values `app opened`, `camera finished`, `review ready`, `saved`, `viewer closed`, `app in background`
  - `public enum MemoryLog` with
    - `public static func record(_ stage: MemoryStage, pages: Int? = nil)`
    - `package static func line(_ stage: MemoryStage, pages: Int?, reading: MemoryReading?, at date: Date) -> String`
    - `package static func append(_ line: String, to file: URL) throws`
    - `package static let fileName = "memory-readings.txt"`

- [ ] **Step 1: Write the failing tests**

`MemoryReadingTests`:
- `aReadingOnThisMachineHasMemoryAndAPeakAtLeastAsHigh`: `current()` is not nil, `now > 0`, `peak >= now`.

`MemoryLogTests` (date fixed at 2026-11-19 09:14:02 UTC):
- `aLineHasTheTimeStagePagesAndNumbers`: stage `.cameraFinished`, pages 20, reading (512 MB, 540 MB, 2420 MB) →
  `2026-11-19T09:14:02Z  camera finished  pages 20  now 512 MB  peak 540 MB  left 2420 MB`
- `aLineWithoutPagesOrLeftLeavesThemOut`: `.appOpened`, nil pages, left nil →
  `2026-11-19T09:14:02Z  app opened  now 41 MB  peak 44 MB`
- `megabytesAreRoundedToTheNearest`: 1_572_864 bytes prints `2 MB`; 524_287 prints `0 MB`.
- `aLineWithNoReadingSaysUnavailable`: reading nil → `2026-11-19T09:14:02Z  saved  pages 3  unavailable`
- `appendingTwiceKeepsBothLines`: a new file in a temporary folder ends up as `first\nsecond\n`.
- `appendingCreatesTheFolder`: the file's folder does not exist beforehand.
- `appendingToAnUnwritablePlaceThrows`: the "file" path is an existing folder.
- `linesAppendedAtOnceStayWhole`: 50 concurrent appends of distinct lines; the file has 50 lines, each one of the inputs.

- [ ] **Step 2: Run to see them fail**

Run: `make fast`
Expected: compile failure, `MemoryReading` / `MemoryLog` not found.

- [ ] **Step 3: Implement**

- `MemoryReading.current()`: `task_info(mach_task_self_, TASK_VM_INFO, …)` into `task_vm_info_data_t`; `now = phys_footprint`, `peak = ledger_phys_footprint_peak`; nil unless `KERN_SUCCESS`. `left` is `os_proc_available_memory()` under `#if os(iOS)`, nil otherwise.
- `MemoryLog.line`: fields joined by two spaces; time from `Date.ISO8601FormatStyle()` (UTC, seconds); MB = `(bytes + 524_288) / 1_048_576`.
- `MemoryLog.append`: create the folder with intermediates; create the file if missing; `FileHandle(forWritingTo:)`, `seekToEnd`, write `line + "\n"`, close. Serialised by a private `Mutex<Void>` or equivalent lock-free of `@unchecked Sendable`.
- `MemoryLog.record`: under `#if DEBUG && os(iOS)`: read, build the line with `Date.now`, log it at `.notice` (public, numbers only), append to `Caches/fileName`; a thrown error is logged with `.error`. Otherwise an empty body.

- [ ] **Step 4: Run to see them pass**

Run: `make fast`
Expected: PASS, the nine new tests among them.

- [ ] **Step 5: Lint and commit**

Run: `make lint`
Expected: clean.

```bash
git add Packages/FilingCabinetKit/Sources/Core Packages/FilingCabinetKit/Tests/CoreTests
git commit -m "Diagnostics: read the app's memory and format a log line (#50)"
```

### Task 2: Record at the six stages

**Files:**
- Modify: `App/FilingCabinetApp.swift` (app opened in `init` or the first scene task; `app in background` in the existing `scenePhase` change)
- Modify: `Packages/FilingCabinetKit/Sources/ScreenModels/…/ScanFlowModel.swift` (`cameraFinished`: `.cameraFinished`, pages = the count handed over)
- Modify: `Packages/FilingCabinetKit/Sources/ScreenModels/Review/ReviewModel.swift` (`readingFinished`: `.reviewReady`; `save`, after `library.save` succeeds: `.saved`; both with `pages.count`)
- Modify: `Packages/FilingCabinetKit/Sources/Screens/Viewer/ViewerView.swift` (`.onDisappear`: `.viewerClosed`)
- Modify: `AGENTS.md` (map: `Core/Diagnostics/`; one sentence on the file and how to copy it off a phone)

**Interfaces:**
- Consumes: `MemoryLog.record(_:pages:)`, `MemoryStage` from Task 1.

- [ ] **Step 1: Add the six calls**, one line each, no `#if` at the call sites.

- [ ] **Step 2: Fast tests and the Mac stay clean**

Run: `make fast && ls ~/Library/Caches/memory-readings.txt`
Expected: tests PASS; `ls` reports no such file.

- [ ] **Step 3: Simulator check**

Run: `make run-fake`, then in the simulator: Scan, save, open the scan, close it, go to the Home Screen. Read the file from the app's container (`xcrun simctl get_app_container "FC iPhone 17" <bundle id> data`, then `Library/Caches/memory-readings.txt`).
Expected: six lines in stage order; `peak` never falls; `left` present.

- [ ] **Step 4: Evidence through `ios-verifier`**

Run: `make build`, `make lint`, `make unused`, `make affected`
Expected: all pass.

- [ ] **Step 5: Commit, push, open the PR and leave it for Ben**

```bash
git add App Packages AGENTS.md
git commit -m "Diagnostics: debug builds record memory at six points of a scan (#50)"
```

### Task 3: The runs on the phone (with Ben)

No code. Each step waits for Ben.

- [ ] **Step 1: One page.** `make device` installs the build. Ben unplugs, scans one page, saves, opens it, closes it, leaves the app, plugs back in.

Run: `xcrun devicectl device copy from --device iPhone --domain-type appDataContainer --domain-identifier <bundle id> --source Library/Caches/memory-readings.txt --destination build/memory-readings.txt`
Expected: six lines for the run. If the camera is black or the copy fails, stop and report: the approach needs changing before the 20-page run.

- [ ] **Step 2: Twenty pages.** Ben force-quits and reopens the app, scans 20 pages, saves, opens the scan, swipes through every page, closes it, leaves the app, plugs back in. Copy the file the same way.

- [ ] **Step 3: Report.** Post the lines of the 20-page run on #50 with the verdict from the spec (peak under half of `now + left`), and the memory after the viewer closed beside the "app opened" figure. Closing #50 or opening fix work is Ben's call.
