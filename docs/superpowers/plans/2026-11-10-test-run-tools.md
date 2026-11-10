# Test run tools Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Agents verify a change by running only the simulator test classes it can affect, re-run without rebuilding while fixing, read audit failures in one command, re-record only the snapshots that fail, and fix the one audit that fails on every local run. The run policy is written down and the Makefile enforces it.

**Architecture:**
- One script, `scripts/sim-tests.sh`, runs every simulator test run. It works out the scope (named classes, the classes a diff touches, or everything), refuses an unscoped whole-suite run, builds once with `build-for-testing`, records a build fingerprint, runs `test-without-building`, and appends one line per run to a log.
- `make full`, `make affected` and `make retest` are thin wrappers around it.
- A committed map (`scripts/test-map.txt`) turns changed paths into test classes. Anything the map doesn't cover runs everything, so a gap in the map costs time, never coverage.
- Audits name each exemption and record when it is used. `scripts/audit-report.sh` prints the issues and exemption use straight from the result bundle.

**Tech Stack:** bash + jq (tested with bats, like `scripts/hooks/`), GNU Make, `xcodebuild` / `xcresulttool` (Xcode 27.2), XCTest (UI tests), swift-snapshot-testing 1.19.7.

**Spec:** Ben's approval relayed by the Plan 3 executor on 2026-11-10 (items 1 to 5 and the run policy). The design and the evidence behind it are in this session's notes to the executor:
- Plan 3's session spent its test time on whole-suite re-runs (UI suite 3 × ~460 s, snapshot suite 3 × ~165 s), 12 bisect runs that each paid generate + build + install, audit triage by hand, and a local-only audit failure.
- AGENTS.md (definition of done, hard rules) and CLAUDE.md (Verification) are the project rules.

**Status:** Draft for Ben's review. Branch `test-runs` off `origin/main` (50a00e2).

## Global Constraints

- Lint config, hook config (`.claude/settings.json`, `scripts/hooks/`) and test tolerances (including audit exemptions) change only with Ben's explicit OK.
- Never bypass git hooks. Changed snapshot references are named in the commit message, each with the reason.
- Every new piece of logic gets tests (bats for scripts); every bug fix gets a regression test.
- No known flaky tests: one green run per change; a streak only to prove a fix for a seen flake.
- Don't touch `Packages/FilingCabinetKit/Sources/Screens/` or `ScreenModels/` (Plan 4 runs in parallel), except where Task 6's root cause is there; if so, keep that change to the minimum and say so.
- Use your own simulator so you never collide with the Plan 4 executor's runs: `SIM_DEVICE='FC iPhone 17 (test-runs)'` (`make sim` creates it). Measurements note any concurrent load on the Mac.
- Measure before and after (Task 0 and Task 7). Report wall-clock seconds, not impressions.

## Run policy (Ben agreed 2026-11-10; Task 5 writes it into the docs)

| When | Command |
|---|---|
| While fixing (re-run a failing class or test, no source change since the last build, or a snapshot reference change) | `make retest ONLY=…` |
| At the end of a task | `make affected` (the classes the branch's diff touches; `BASE=<sha>` for the task's own commits) |
| Once before a PR goes ready for review | `make full ALL=1`, or let CI's Full suite run |

## Review Focus

1. **A change the map doesn't know about** (a new folder, a new test class): `affected` must run everything and say why, never run nothing. Test: `unmapped path runs everything` (Task 1).
2. **Retest after a source edit**: must refuse and name the command to rebuild, never test stale products. Test: `retest refuses after a Swift edit` (Task 2).
3. **Retest after only a snapshot reference changed**: must run without a rebuild (references are read from disk at test time). Test: `retest allows a reference-only change` (Task 2).
4. **A failed test run after a good build**: the fingerprint is still recorded so `retest` works next. Test: `fingerprint recorded when tests fail but build succeeds` (Task 2).
5. **A diff that only touches docs or Markdown**: `affected` runs nothing and exits 0 with a message. Test: `docs-only diff runs nothing` (Task 1).

---

### Task 0: Baseline measurements (before any change)

**Files:** Create `.superpowers/test-runs/measurements.md` (gitignored; copied into the PR description at the end).

- [ ] **Step 1:** On a clean checkout of `origin/main`, run `make setup SIM_DEVICE='FC iPhone 17 (test-runs)'`, then `make build` once so the build is warm.
- [ ] **Step 2: M1, the bisect run.** Run `time make full ONLY=FilingCabinetUITests/BrowseJourneyTests/testTileOpensAScan` twice with no change in between. Record the wall clock, and the test-execution time from the result bundle's summary; the difference is generate + build + install.
- [ ] **Step 3: M2, the whole UI suite.** Run `time make full ONLY=FilingCabinetUITests` once. Record the wall clock.
- [ ] **Step 4: M3, snapshot recording.** Run `make snapshots-record` on unchanged main. Record `git status --porcelain SnapshotTests/__Snapshots__ | wc -l` (references rewritten with no real change), then `git checkout -- SnapshotTests/__Snapshots__`.
- [ ] **Step 5: M4, selection size.** List the files changed by PR #76 and PR #78 (`gh pr diff <n> --name-only`) and by plan-3 commit `3859cd9` (a Trash change). Task 7 compares the classes `affected` picks against "whole suite".
- [ ] **Step 6: M5, the dark-mode audit.** Run `make full ONLY=FilingCabinetUITests/BrowseJourneyTests/testViewerAuditInDarkMode`. Record pass or fail and save the result bundle path (Task 6's starting evidence).

### Task 1: `affected`: changed paths → test classes

**Files:**
- Create: `scripts/test-map.txt`, `scripts/affected-tests.sh`, `scripts/tests/affected.bats`
- Modify: `Makefile` (a `test-scripts` target running `bats scripts/tests`; add it to `ci-checks` next to `test-hooks`)

**Interfaces:**
- Produces: `scripts/affected-tests.sh [BASE]` prints the test identifiers to run, one per line (`FilingCabinetUITests/<Class>` or `FilingCabinetSnapshotTests/<Class>`), or the single line `ALL`, or nothing. It prints its reasoning on stderr (`<path> → <classes>`, `no rule for <path>: running everything`). Changed paths are the union of `git diff --name-only $(git merge-base BASE HEAD)`, the working tree (staged and unstaged) and untracked non-ignored files. `BASE` defaults to `origin/main`.

**Map format (`scripts/test-map.txt`):** one rule per line, `<path prefix> <Class>…` or `<path prefix> ALL` or `<path prefix> NONE`; `#` comments. A path takes the union of every rule whose prefix matches. Class names are bare; the script finds the target by where `<Class>.swift` lives (`UITests/` → `FilingCabinetUITests`, `SnapshotTests/` → `FilingCabinetSnapshotTests`).

**Automatic rules (no map entry needed):**
- `UITests/<Class>.swift` and `UITests/<Class>+<anything>.swift` map to that class.
- `SnapshotTests/<Class>.swift`, when the file declares an `XCTestCase` subclass, maps to that class.
- `SnapshotTests/__Snapshots__/<Class>/…` maps to `<Class>`.

**Starting map.** Rules are by folder, same name under `Screens/` and `ScreenModels/`. Before committing, check each row by grepping which test classes use that screen's `AccessibilityID` namespace (or its view or model types), and add any class that does. When unsure, include the class.

| Prefix | Runs |
|---|---|
| `docs/`, `*.md` anywhere, `.github/`, `DeviceTests/`, `design/` (except `design/tokens.json`), `scripts/` (except `generate-tokens.swift`), `Packages/FilingCabinetKit/Tests/`, `.claude/` | NONE |
| `App/`, `project.yml`, `Package.resolved`, `Packages/FilingCabinetKit/Package.swift`, `Packages/FilingCabinetKit/Sources/Core/`, `…/Library/`, `…/Screens/DesignSystem/`, `…/Screens/Root/`, `…/Screens/Resources/`, `…/ScreenModels/App/`, `…/ScreenModels/Shared/`, any `Localizable.xcstrings`, `design/tokens.json`, `scripts/generate-tokens.swift`, `UITests/Support/`, `SnapshotTests/` files that aren't test classes | ALL |
| `Trash/` | TrashJourneyTests TrashSnapshotTests |
| `Grid/` | BrowseJourneyTests GridSelectJourneyTests GridSnapshotTests GridPerformanceTests ThumbnailRedrawTests |
| `Home/` | HomeJourneyTests BrowseJourneyTests CleanupJourneyTests HomeSnapshotTests |
| `Viewer/` | BrowseJourneyTests ReviewZoomJourneyTests ViewerSnapshotTests ViewerBehaviourTests |
| `Details/` | DetailsJourneyTests DetailsSnapshotTests |
| `Settings/`, `Notifications/` | SettingsJourneyTests SettingsSnapshotTests |
| `Capture/` | ScanJourneyTests CameraAccessJourneyTests CaptureLayerContainmentTests CameraOffSnapshotTests |
| `Review/`, `Save/` | ScanJourneyTests ReviewZoomJourneyTests ReviewSnapshotTests |
| `Cleanup/` | CleanupJourneyTests HomeSnapshotTests |
| `…/Sources/Understanding/` | ScanJourneyTests ReviewSnapshotTests |

- [ ] **Step 1: Write the failing bats tests** in `scripts/tests/affected.bats`. Use a temporary git repo fixture (as in `scripts/hooks/tests/hooks.bats`) holding a copy of the real `scripts/test-map.txt` and empty files at `UITests/TrashJourneyTests.swift`, `UITests/ScanJourneyTests+EditTrashRestore.swift` and `SnapshotTests/TrashSnapshotTests.swift` (with `final class TrashSnapshotTests: XCTestCase {}`). Tests:
  - `a Trash screen change picks the Trash classes`: change `Packages/FilingCabinetKit/Sources/Screens/Trash/TrashView.swift` → output is exactly `FilingCabinetUITests/TrashJourneyTests` and `FilingCabinetSnapshotTests/TrashSnapshotTests`.
  - `a test file change picks its own class`: `UITests/ScanJourneyTests+EditTrashRestore.swift` → `FilingCabinetUITests/ScanJourneyTests`.
  - `a reference change picks its class`: `SnapshotTests/__Snapshots__/TrashSnapshotTests/trash_list.light.png` → `FilingCabinetSnapshotTests/TrashSnapshotTests`.
  - `a shared change runs everything`: `…/Screens/DesignSystem/Tokens.swift` → `ALL`.
  - `unmapped path runs everything`: `NewFolder/X.swift` → `ALL`, and stderr contains `no rule for NewFolder/X.swift`.
  - `docs-only diff runs nothing`: `docs/x.md` and `README.md` → empty output, exit 0.
  - `untracked and uncommitted files count`: an untracked `…/Screens/Trash/New.swift` alone → the Trash classes.
  - `the map names only classes that exist`: run against the real repo (`$BATS_TEST_DIRNAME/../..`): every class in `test-map.txt` has a `UITests/<Class>.swift` or `SnapshotTests/<Class>.swift`.
  - `every test class is reachable`: run against the real repo: every `XCTestCase` subclass under `UITests/` and `SnapshotTests/` appears in the map or is reached by an automatic rule only. If not, the test fails and names it, so a new class gets mapped.
- [ ] **Step 2:** Run `make test-scripts`. Expected: these tests FAIL (script missing).
- [ ] **Step 3:** Implement `scripts/affected-tests.sh` and `scripts/test-map.txt` as specified. Match prefixes literally; `*.md` is the only glob.
- [ ] **Step 4:** Run `make test-scripts`. Expected: all pass.
- [ ] **Step 5:** Commit: `Scripts: affected-tests picks the simulator test classes a diff touches`.

### Task 2: `sim-tests.sh` and `make full` / `affected` / `retest`

**Files:**
- Create: `scripts/sim-tests.sh`, `scripts/build-fingerprint.sh`, `scripts/tests/sim-tests.bats`
- Modify: `Makefile` (`full`, `full-run`, new `affected` and `retest`; `.PHONY`)

**Interfaces:**
- Consumes: `scripts/affected-tests.sh [BASE]` (Task 1).
- Produces:
  - `scripts/build-fingerprint.sh [print|current|record FP]`, with the same contract as `scripts/hooks/swift-fingerprint.sh` (don't modify that one: it's hook behaviour). It hashes every tracked and untracked non-ignored file except `docs/`, `*.md`, `SnapshotTests/__Snapshots__/`, `.github/`, `.claude/` and `design/` other than `design/tokens.json`. It stores the value in `.build/fc-test-build`. It must take under 2 s on this repo; measure and note.
  - `scripts/sim-tests.sh <full|affected|retest>`, which reads `ONLY`, `SKIP`, `ALL`, `BASE`, `SIM_DEST`, `XCB_FLAGS`, `PROJECT` and `DERIVED` from the environment (exported by Make). `FC_XCODEBUILD` (default `xcodebuild`) and `FC_AFFECTED_CMD` (default `scripts/affected-tests.sh`) are seams for the bats stubs.

**Behaviour:**
- **`full`:** scope = `ONLY`/`SKIP`. If `ONLY` is empty, or any entry in it is a whole target (no `/`, for example `FilingCabinetUITests`), it refuses unless `ALL=1`. The refusal exits 2 and prints the run-policy table.
- **`affected`:** scope = the output of `affected-tests.sh "$BASE"`. If empty, print `nothing to run: the diff touches no app code or tests` and exit 0. `ALL` means whole suite (no refusal: the map decided).
- **`retest`:** scope = `ONLY` if given, else the affected scope. Skips the build. Refuses (exit 2) unless `build-fingerprint.sh current`, naming `make affected` / `make full ONLY=…` as the way to rebuild. Also refuses if there is no `.xctestrun` in `$DERIVED/Build/Products`.
- **Build (full, affected):** take the fingerprint before building. Run `generate`, then `xcodebuild build-for-testing` for `SIM_DEST`. On success, record the fingerprint, even if the tests then fail.
- **Test:** `xcodebuild test-without-building -destination "$SIM_DEST"` with `-only-testing:`/`-skip-testing:` from the scope. The exit status is the tests' status.
- **Run log:** append one tab-separated line to `.build/test-runs.log`: ISO time, mode, scope (space-joined, or `ALL`), build seconds (0 for retest), test seconds, exit status. Every mode also prints this as its last line (`test-runs: affected · 4 classes · build 38 s · tests 112 s · exit 0`).

- [ ] **Step 1: Write the failing bats tests** in `scripts/tests/sim-tests.bats`, with a stub `FC_XCODEBUILD` that logs its arguments and exits with `$STUB_BUILD_STATUS` / `$STUB_TEST_STATUS`, and a stub `FC_AFFECTED_CMD` that prints `$STUB_AFFECTED`:
  - `full refuses with no ONLY`: exit 2, output contains `make affected`, `make retest` and `ALL=1`; the stub was not called.
  - `full refuses a whole target`: `ONLY=FilingCabinetUITests` → exit 2.
  - `full ALL=1 runs everything`: the stub saw `build-for-testing` then `test-without-building` with no `-only-testing`.
  - `full runs named classes`: `ONLY="FilingCabinetUITests/TrashJourneyTests"` → `-only-testing:FilingCabinetUITests/TrashJourneyTests`.
  - `affected runs what the map picks`: `STUB_AFFECTED` = two classes → both passed as `-only-testing`.
  - `docs-only diff runs nothing`: empty `STUB_AFFECTED` → exit 0, no stub call, message printed.
  - `retest refuses with no build`: no `.build/fc-test-build` → exit 2.
  - `retest refuses after a Swift edit`: build, then edit a `.swift` file → exit 2, `test-without-building` not called.
  - `retest allows a reference-only change`: build, then change a file under `SnapshotTests/__Snapshots__/` → runs `test-without-building` only.
  - `fingerprint recorded when tests fail but build succeeds`: `STUB_TEST_STATUS=1` → exit 1 and `build-fingerprint.sh current` succeeds.
  - `no fingerprint when the build fails`: `STUB_BUILD_STATUS=1` → `current` fails.
  - `each run appends one log line`: two runs → two lines in `.build/test-runs.log` with six tab-separated fields.
- [ ] **Step 2:** Run `make test-scripts`. Expected: FAIL.
- [ ] **Step 3:** Implement both scripts and point the Make targets at them. `full: sim` (generate happens inside the script); keep `ONLY=`/`SKIP=` usage unchanged for scoped runs. Update the Makefile comment above `TEST_ARGS`.
- [ ] **Step 4:** Run `make test-scripts`. Expected: PASS.
- [ ] **Step 5: Check on the simulator.** Run `make affected` on a branch with a one-line Trash change, then `make retest ONLY=FilingCabinetUITests/TrashJourneyTests/<one test>`. Expected: the second run does no build, and its log line shows `build 0 s`. Confirm `test-without-building` accepts the `.xctestrun` that `build-for-testing` produced.
- [ ] **Step 6:** Commit: `Make: affected and retest; full refuses an unscoped suite (run policy)`.

### Task 3: Audits that explain themselves

**Files:**
- Create: `UITests/Support/AuditExemption.swift`, `scripts/audit-report.sh`, `scripts/tests/audit-report.bats`, `scripts/tests/fixtures/audit-activities.json`
- Modify: `UITests/Support/Audit.swift`, `Makefile` (`audit-report` target)

**Interfaces:**
- Produces:
  - `struct AuditExemption { let name: String; let matches: @MainActor (XCUIApplication, XCUIAccessibilityAuditIssue) -> Bool }` (one per file, as AGENTS.md requires).
  - `Audit.swift`'s list becomes `[AuditExemption]`, each named from its comment (`deep-text-under-scan-fade`, `camera-off-sheet-clipped`, `details-sheet-clipped`, `dark-viewer-header`, `trash-glass-buttons`, `fixed-size-bar-titles`, `trash-bar-unresolved`). Matching logic and comments are unchanged.
  - Activity titles that `audit(_:)` writes, which the report parses:
    - `Audit issue · <type> · id '<identifier>' · label '<label>' · frame <frame>` (the existing attachment stays inside it)
    - `Audit exemption used · <name> · <type> · id '<identifier>'`
    - `Audit exemptions declared · <name>, <name>, …` (once per `audit` call)
  - `scripts/audit-report.sh [RESULT]` (default: the newest `.build/DerivedData/Logs/Test/*.xcresult`). For each test with audit activity it prints the test name and its unexempted issues. Then it prints the exemptions used (name and count), and the declared exemptions never used in this run, prefixed `not used in this run (<n> audits ran):`. Seam: `FC_XCRESULTTOOL`.

- [ ] **Step 1: Capture a fixture.** Run one audit test with a deliberately failing state, or reuse Task 0's M5 bundle after Step 4 below. Save `xcresulttool get test-results tests` and `… activities` output, trimmed to two tests, as the fixture. (Order: write the Swift change first, run once, capture, then TDD the script.)
- [ ] **Step 2: Swift change.** Add `AuditExemption`, rename the list's entries as above, and write the three activity kinds in `audit(_:)`. Run `make lint` and `make full ONLY=FilingCabinetUITests/HomeJourneyTests` with your simulator. Expected: the tests pass as before, and the result bundle shows the new activity titles.
- [ ] **Step 3: Write the failing bats tests** in `scripts/tests/audit-report.bats` against the fixture:
  - `prints each unexempted issue under its test`
  - `counts exemption use`
  - `lists declared exemptions not used`
  - `says so when the bundle has no audits`: exit 0, `no audits in <bundle>`.
- [ ] **Step 4:** Implement `scripts/audit-report.sh` (jq over the JSON) and `make audit-report` (`RESULT=` optional). Run `make test-scripts`. Expected: PASS.
- [ ] **Step 5:** Commit: `UI tests: audits name their exemptions; make audit-report reads issues from the result`.

### Task 4: Snapshot recording rewrites only failing references

**Files:** Modify `Makefile` (`snapshots-record`), and AGENTS.md's Commands row (in Task 5).

- [ ] **Step 1:** Change `TEST_RUNNER_SNAPSHOT_TESTING_RECORD=all` to `TEST_RUNNER_SNAPSHOT_TESTING_RECORD=$(SNAPSHOT_RECORD)` with `SNAPSHOT_RECORD ?= failed`. In swift-snapshot-testing 1.19.7, `failed` writes a reference only when the comparison (our `SnapshotConfig.strategy`, tolerances unchanged) fails or the reference is missing. `SNAPSHOT_RECORD=all` stays available for a deliberate full re-record. Update the comment above the target.
- [ ] **Step 2: Verify.** On unchanged code, run `make snapshots-record`. Expected: `git status --porcelain SnapshotTests/__Snapshots__` is empty (compare with M3). Then change one pixel-visible thing locally (for example a token colour in a scratch edit), record, and confirm only that class's references changed. Revert.
- [ ] **Step 3:** Commit: `Make: snapshots-record rewrites only failing or missing references`.

### Task 5: Adoption: docs, briefs and the verifier

**Files:**
- Modify: `AGENTS.md` (Commands table, definition of done, a new "Run policy" section), `CLAUDE.md` (Verification), `.superpowers/plan4-brief.md` and any Plan 4 execution brief under `.superpowers/` (gitignored: local only)
- Modify (arsenal repo, `~/projects/arsenal`): `agents/ios-verifier.md` (the file `~/.claude/agents/ios-verifier.md` links to)

- [ ] **Step 1: AGENTS.md.**
  - Add the run-policy table above, under "Definition of done".
  - Definition of done item 3 becomes: "`make affected` passes (the snapshot and UI tests for what the task touched)".
  - Commands table: rows for `make affected`, `make retest`, `make audit-report`; `make full` now reads "everything on the simulator, scoped: `ONLY=`/`SKIP=`; an unscoped run needs `ALL=1` (once before a PR)"; `snapshots-record` says it rewrites only failing or missing references.
  - One line under the policy: "Don't call `xcodebuild test` or XcodeBuildMCP's test tools directly: the Make targets keep the build fingerprint and the run log."
- [ ] **Step 2: CLAUDE.md Verification.** Replace the `make full ONLY=…` paragraph with a pointer to the run policy, and a line that `ios-verifier` should be asked for `make affected` (task end) or `make retest ONLY=…` (while fixing).
- [ ] **Step 3: ios-verifier (arsenal).** Under Steps, change step 3 to: "Run the project's documented commands (Makefile targets) when it has them; XcodeBuildMCP or raw `xcodebuild` only when it doesn't." Add step 2b: "If the project documents a test run policy, follow it, and never widen the scope beyond what was asked (no whole-suite run unless the caller asks for one)." Then run `bats tests/` in arsenal if code changed (it didn't), review `git diff`, commit, push, and run `arms doctor`.
- [ ] **Step 4: Briefs.** Add the run-policy table and "use `make retest` while fixing; `make affected` at task end; `make full ALL=1` only before the PR" to `.superpowers/plan4-brief.md` and the Plan 4 SDD task/implementer briefs, if they exist yet. Tell the Plan 4 executor (pane via herdr) once that the targets exist after the merge.
- [ ] **Step 5:** Commit (filing-cabinet): `Docs: the test run policy (retest, affected, full once before a PR)`.

### Task 6: Fix `BrowseJourneyTests.testViewerAuditInDarkMode` locally

REQUIRED SUB-SKILL: superpowers:systematic-debugging. It fails on every local run, on unchanged plan-3 and main, and passes on CI.

**Files:** Decided by the root cause. The evidence comes from `make audit-report` (Task 3) on Task 0's M5 bundle.

- [ ] **Step 1: Evidence.** Run the test with your simulator, then `make audit-report`. Record the exact issue (type, identifier, frame) and whether an exemption nearly matched (for example, `dark-viewer-header` reported under a different identifier than CI's).
- [ ] **Step 2: Compare environments.** Check iOS runtime builds (`xcrun simctl list runtimes` locally vs the CI log's runtime), device model, and appearance state before the test (`XCUIDevice.shared.appearance`, and whether an earlier test left the sim dark). Compare the CI result bundle from run 42821491355 (`timing-sim-browse` artifact) for the same test's activities.
- [ ] **Step 3: One hypothesis at a time,** each tested with one run. Stop when the cause is shown, not guessed.
- [ ] **Step 4: Fix the cause.**
  - If the app is wrong (a real contrast problem only some renderers show), fix the app with the smallest change, and add a snapshot or unit test that fails without it.
  - If the test environment is wrong (state leaking between tests, a different runtime), fix the test setup.
  - If the only fix is a new or wider exemption, stop and ask Ben with the evidence: that's a test tolerance.
- [ ] **Step 5: Verify.** One green local run of `BrowseJourneyTests`, plus green CI on the PR. Record before (M5: fail) and after.
- [ ] **Step 6:** Commit with the cause in the message.

### Task 7: After measurements, PR

- [ ] **Step 1: M1′.** `make affected` once to build, then `time make retest ONLY=FilingCabinetUITests/BrowseJourneyTests/testTileOpensAScan` twice. Compare with M1.
- [ ] **Step 2: M4′.** Run `scripts/affected-tests.sh` against each Task 0 diff (check out the PR's head commit, `BASE` = its merge base). Report classes picked vs the whole suite. For the Trash change, time `make affected` vs M2.
- [ ] **Step 3: M3′.** `make snapshots-record` on unchanged code: references rewritten (expected 0) vs M3.
- [ ] **Step 4: M5′.** The dark-mode audit, locally: pass.
- [ ] **Step 5:** Whole-branch review (fresh reviewer). Run `make ci-checks`, then `make full ALL=1` once (the policy's pre-PR run). Open the PR with the measurements table and the policy. Merge only with Ben's OK.

---

## Proposed, needs Ben's OK (hook config)

**P1: a guard on direct test runs.** A PreToolUse hook (a new `scripts/hooks/guard-test-runs.sh`, with bats tests in `hooks.bats`) blocks Bash commands that run `xcodebuild` with `test` / `test-without-building` and XcodeBuildMCP's `test_sim`. The message names `make retest` / `make affected` / `make full ALL=1`.
- **Why:** the Makefile refusal only covers runs that go through Make. `ios-verifier` defaults to XcodeBuildMCP, which would skip the fingerprint, the scope and the log.
- **Cost:** one more hook, and `ci-sim` is unaffected (CI doesn't run hooks).
- If Ben agrees, this is a Task 5b. If not, Task 5's verifier change and the docs carry it alone.

**Not proposed:** changing the Stop gate. It runs Fast only and is cheap; making it run simulator tests would put the slow suite back in the inner loop, which is the problem this plan solves.
