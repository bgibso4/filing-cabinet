# Test Suite Restructure Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Load the `principal-engineer` skill before the first edit (CLAUDE.md).

**Goal:** Short local runs and a short PR gate: journeys and audits leave both and run nightly on `main`, except an approved smoke set.

**Architecture:** A new UI test target holds every accessibility audit. `scripts/smoke-tests.txt` names the 11 smoke journeys; `affected-tests.sh` turns a shared change into snapshots + package tests + smoke instead of everything. Local runs draw two snapshot variants (an environment variable), CI three. CI's gate becomes three jobs (two snapshot halves, smoke); a push to `main` skips them when a PR already passed on the same tree. A new nightly workflow runs journeys and audits and files issues.

**Tech Stack:** XCTest UI tests, XcodeGen (`project.yml`), GNU make, bash + bats, GitHub Actions, `gh`, `xcrun xcresulttool`.

**Spec:** `docs/superpowers/specs/2026-11-22-test-suite-restructure-design.md` (approved 2026-11-22).

## Global Constraints

- Timeouts, waits, snapshot precision, the 1 s settle, audit exemptions, lint config and hook config: unchanged. Any need to touch one stops the task and goes to Ben.
- No snapshot reference changes. If one changes, stop: something drew differently.
- Never hand-edit `FilingCabinet.xcodeproj` or `Generated/`: change `project.yml`, run `make generate`.
- Swift 6 mode; one primary type per file; no `print()`; `try?` only with a comment.
- Never bypass git hooks; never commit `.claude/` (except `settings.json`), `.herdr/`, `.superpowers/`.
- Run simulator tests only through `make` targets; build and test evidence through the `ios-verifier` agent.
- Every changed script gets bats tests (`make test-scripts`); every new class a `SELF` line or rule in `scripts/test-map.txt`.
- Commits end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`; the PR body ends with `🤖 Generated with [Claude Code](https://claude.com/claude-code)`. Open the PR and leave it open; merging is Ben's.
- Before long runs: `pmset -g log | grep -E "Sleep|Wake"` afterwards if anything stalls; tell Ben if the lid is closed.

## Review Focus

1. `SNAPSHOT_VARIANTS` names a variant that doesn't exist (a typo such as `lite`): every snapshot test must fail loudly, never pass having drawn nothing. Task 2.
2. A push to `main` whose tree matches a PR run that ran checks only (a draft or docs-only run), or when the GitHub API call fails: the gate must run, not be skipped. Task 5.
3. A smoke id whose class or test was renamed or deleted: `--check-map` must fail, since `-only-testing` of a missing test runs nothing and passes. Task 3.
4. The same nightly test failing on consecutive nights, or two tests whose names share a prefix (`testFoo`, `testFooBar`): one issue per test, found by exact title, commented on rather than duplicated. Task 6.
5. A nightly job that fails before any test runs (build error, no result bundle): one issue saying the run failed before testing, not silence. Task 6.

---

### Task 1: The audit target, with the 23 audit tests moved

**Files:**
- Create: `AuditTests/<Screen>AuditTests.swift`, one file per screen: `HomeAuditTests`, `GridAuditTests`, `ViewerAuditTests`, `ReviewAuditTests`, `SearchAuditTests`, `SettingsAuditTests`, `TrashAuditTests`, `WelcomeAuditTests`, `CameraOffAuditTests`, `LibraryFailureAuditTests`, `LockAuditTests`
- Modify: `project.yml` (new target, scheme), `Makefile` (`SWIFT_DIRS`), `scripts/affected-tests.sh` (`test_dirs`), `scripts/test-map.txt`, every `UITests/*JourneyTests.swift` that held an audit test
- Test: the moved tests themselves; `scripts/tests/affected.bats`

**Interfaces:**
- Produces: test target `FilingCabinetAuditTests` (later tasks skip or select it by that name); directory `AuditTests/`.

- [ ] **Step 1:** In `project.yml`, add `FilingCabinetAuditTests` as a copy of `FilingCabinetUITests` with sources `AuditTests` and `UITests/Support`, bundle id `$(APP_BUNDLE_ID).audittests`, and add it to the `FilingCabinet` scheme's test targets after `FilingCabinetUITests`. Add `AuditTests` to `SWIFT_DIRS` and to `test_dirs` in `affected-tests.sh` (so `target_of` names `FilingCabinetAuditTests`).
- [ ] **Step 2:** Move each test whose name contains `Audit` (23, listed in the spec's recon; `grep -n "func test.*Audit" UITests`) into the matching `AuditTests/` file, unchanged in body. Copy into each audit class, as `private` members, the helpers its tests call (`seededApp`, `openReceipts`, `tiles`, …), as the journey classes already each keep their own. Delete moved tests and any helper left unused from the journeys.
- [ ] **Step 3:** Add one `SELF` line to `scripts/test-map.txt` listing the 11 audit classes. Add a bats test to `affected.bats`: `"an audit test file change picks its audit class"`: a fixture `AuditTests/HomeAuditTests.swift` declaring `final class HomeAuditTests`, changed on `work`, prints `FilingCabinetAuditTests/HomeAuditTests`.
- [ ] **Step 4:** Run `make test-scripts` and `bats scripts/tests/affected.bats`. Expected: all pass, including `the map names only classes that exist` with `--check-map` on the real repo (`scripts/affected-tests.sh --check-map` exits 0).
- [ ] **Step 5:** `make generate && make build` via `ios-verifier`, then `make full ALL=1 ONLY=FilingCabinetAuditTests` and `make full ONLY="<every journey class you edited>"`. Expected: all pass; `make audit-report` lists the same exemptions used as before the move (compare with a pre-move `make audit-report` saved to the scratchpad).
- [ ] **Step 6:** Commit: `UI tests: the accessibility audits move to their own target`.

### Task 2: Inline audits become audit tests

**Files:**
- Modify: the `AuditTests/` files from Task 1; the journey files holding the 31 inline `try audit(app)` calls

**Interfaces:**
- Consumes: Task 1's target and files.

Each inline call is removed from its journey. Its screen state is audited instead by the default-size audit test below (one launch, navigate, `try audit(app)`; where two states share a launch, audit both in order). Line numbers are as of `origin/main` 854d08a.

| Inline call | Becomes |
|---|---|
| `HomeJourneyTests:22`, `ScanJourneyTests:56` (Home before any scan) | `HomeAuditTests.testAuditHomeEmpty` |
| `BrowseJourneyTests:23` | `HomeAuditTests.testAuditHomeWithScans` |
| `FavoritesJourneyTests:77` | `HomeAuditTests.testAuditHomeWithFavorites` |
| `CleanupJourneyTests:30` | `HomeAuditTests.testAuditHomeWithTheBanner` |
| `BrowseJourneyTests:47`, `ScanJourneyTests:74` (a grid) | `GridAuditTests.testAuditAGrid` |
| `BrowseJourneyTests:167`, `ScanJourneyTests:83` (the viewer) | `ViewerAuditTests.testAuditTheViewer` |
| `DetailsJourneyTests:25` | `ViewerAuditTests.testAuditDetails` |
| `ScanJourneyTests:27` (reading), `:63` (collection chosen) | `ReviewAuditTests.testAuditReview` (both states, in order) |
| `SearchJourneyTests:36` | `SearchAuditTests.testAuditSearchResults` |
| `SettingsJourneyTests:33`, `:131` (top, then scrolled to the feedback rows); `:117` dropped (same screen) | `SettingsAuditTests.testAuditSettings` |
| `SettingsJourneyTests:39` | `SettingsAuditTests.testAuditCollections` |
| `SettingsJourneyTests:45` | `SettingsAuditTests.testAuditCollectionSettings` |
| `LockJourneyTests:149` | `SettingsAuditTests.testAuditTheLockRowOn` |
| `LockJourneyTests:163` | `SettingsAuditTests.testAuditTheLockRowWithoutAPasscode` |
| `TrashJourneyTests:36` | `TrashAuditTests.testAuditTrash` |
| `TrashJourneyTests:98` | `TrashAuditTests.testAuditTrashViewer` |
| `TrashJourneyTests:172` (select mode, before ticking; keep its #79 comment) | `TrashAuditTests.testAuditTrashSelectMode` |
| `TrashJourneyTests:205` | `TrashAuditTests.testAuditEmptyTrash` |
| `WelcomeJourneyTests:31`, `:40` | `WelcomeAuditTests.testAuditBothScreens` |
| `CameraAccessJourneyTests:20` | `CameraOffAuditTests.testAuditTheCameraOffSheet` |
| `LibraryFailureJourneyTests:22` | `LibraryFailureAuditTests.testAuditTheFailureScreen` |

- [ ] **Step 1:** Write the 21 audit tests in the table. Each reaches its state with the same launch flags and steps as the journey it came from, and keeps any comment explaining when the audit runs.
- [ ] **Step 2:** Remove the 31 calls from the journeys. `grep -rn "audit(app)" UITests` must print only `UITests/Support/Audit.swift`.
- [ ] **Step 3:** Via `ios-verifier`: `make build`, `make full ALL=1 ONLY=FilingCabinetAuditTests`, `make full ONLY="<every journey class you edited>"`. Expected: all pass. Then `make audit-report`: every exemption used before Task 1 is still used (an unused one means a state lost its audit: find it).
- [ ] **Step 4:** Commit: `UI tests: journeys carry no audits; each audited screen state has its own audit test`.

### Task 3: The smoke set and the new `make affected`

**Files:**
- Create: `scripts/smoke-tests.txt`
- Modify: `scripts/affected-tests.sh`, `scripts/tests/affected.bats`, `scripts/tests/sim-tests.bats` (only if its `affected ALL` test changes meaning)

**Interfaces:**
- Produces: `scripts/smoke-tests.txt`: one `FilingCabinetUITests/<Class>/<test>` per line, `#` comments allowed. `affected-tests.sh [BASE]` never prints `ALL` any more; a shared change prints the shared set.

- [ ] **Step 1: Write the failing tests** in `affected.bats` (the fixture gains a `scripts/smoke-tests.txt` with two ids and a `project.yml` whose `FilingCabinet` scheme lists `FilingCabinetKit/CoreTests` and `FilingCabinetKit/ScreensTests` while a `Fast` scheme lists `FilingCabinetKit/LibraryTests`):
  - `"a shared change runs snapshots, package tests and the smoke set"`: output is exactly `CoreTests`, `FilingCabinetSnapshotTests`, `ScreensTests` and the two smoke ids, sorted; no `LibraryTests`, no `FilingCabinetUITests` target, no `ALL`.
  - `"a screen change adds the smoke set"`: the existing Trash case prints `$TRASH` plus the two smoke ids.
  - `"a smoke id whose class is already picked is left out"`.
  - `"a docs-only diff still runs nothing"` (unchanged expectation).
  - `"the map check flags a smoke id whose test doesn't exist"`: a smoke id naming `testGone` makes `--check-map` exit 1 with a message naming it.
  - Rename `"a shared change runs everything"` and `"unmapped path runs everything"` to the shared-set expectation.
- [ ] **Step 2:** `bats scripts/tests/affected.bats`. Expected: the new tests FAIL.
- [ ] **Step 3:** In `affected-tests.sh`: a `shared_set()` printing `FilingCabinetSnapshotTests`, the package test targets of the `FilingCabinet` scheme in `project.yml` (only that scheme's `test.targets` block), and the smoke ids; every former `echo ALL` result resolves to it; a non-empty class list gets the smoke ids appended, minus those whose class is already in the list; `check_map` also checks that each smoke id's class is declared under `UITests/` and that one of its files contains `func <test>(`. Write `scripts/smoke-tests.txt` with the spec's 11 ids, in the spec's order, and a header comment saying the list is Ben's and changes name their reason.
- [ ] **Step 4:** `make test-scripts` and `scripts/affected-tests.sh --check-map`. Expected: PASS, exit 0.
- [ ] **Step 5:** Commit: `make affected: a shared change runs snapshots, package tests and the smoke set`.

### Task 4: Local snapshots draw light and largest text

**Files:**
- Create: `SnapshotTests/SnapshotVariantsTests.swift`
- Modify: `SnapshotTests/SnapshotConfig.swift`, `SnapshotTests/SnapshotHost.swift`, `scripts/sim-tests.sh`, `scripts/tests/sim-tests.bats`, `scripts/test-map.txt` (`SELF SnapshotVariantsTests`)

**Interfaces:**
- Produces: `SnapshotConfig.variants(named: String?) throws -> [Variant]` and `struct UnknownSnapshotVariant: Error { let name: String }`; environment variable `SNAPSHOT_VARIANTS` (set as `TEST_RUNNER_SNAPSHOT_VARIANTS` on the xcodebuild command line).

- [ ] **Step 1: Write the failing tests** in `SnapshotVariantsTests` (XCTest, as `CPUImageMatchTests`):
  - `testUnsetDrawsAll`: `variants(named: nil)` names `["light", "dark", "ax5"]`.
  - `testEmptyDrawsAll`: `""` gives all three.
  - `testAListPicksThoseInConfigOrder`: `"ax5, light"` gives `["light", "ax5"]`.
  - `testAnUnknownNameThrows`: `"lite"` throws `UnknownSnapshotVariant(name: "lite")`.
- [ ] **Step 2:** `make full ONLY=FilingCabinetSnapshotTests/SnapshotVariantsTests`. Expected: FAIL (doesn't compile).
- [ ] **Step 3:** Implement `variants(named:)` in `SnapshotConfig`. In `SnapshotHost.assertScreen`, draw `variants` filtered to the names `variants(named: ProcessInfo.processInfo.environment["SNAPSHOT_VARIANTS"])` returns; a throw propagates and fails the test. `DetailsSnapshotTests`'s own loop over `SnapshotConfig.variants` goes through the same filter.
- [ ] **Step 4:** In `sim-tests.sh`, `affected` and `retest` pass `TEST_RUNNER_SNAPSHOT_VARIANTS=light,ax5` to `test-without-building`; `full` passes nothing. Bats in `sim-tests.bats` (the fake xcodebuild records its environment): `"affected draws light and largest text"`, `"retest draws light and largest text"`, `"full draws every variant"`.
- [ ] **Step 5:** `make test-scripts`; via `ios-verifier` `make full ONLY=FilingCabinetSnapshotTests` (all three variants) and `make retest ONLY=FilingCabinetSnapshotTests/SearchSnapshotTests` (two). Expected: PASS, no reference files changed (`git status SnapshotTests/__Snapshots__` clean).
- [ ] **Step 6:** Commit: `Snapshots: local runs draw light and largest text; CI draws all three`.

### Task 5: CI's gate, and no second run on merge

**Files:**
- Create: `scripts/ci/gate-passed.sh`, `scripts/ci/tests/gate-passed.bats`
- Modify: `Makefile` (shards, `test-scripts`), `.github/workflows/ci.yml` (plan job)

**Interfaces:**
- Consumes: `scripts/smoke-tests.txt` (Task 3), `FilingCabinetAuditTests` (Task 1).
- Produces: `make ci-sim SHARD=snapshots-1|snapshots-2|smoke|journeys-1|journeys-2|audits|all`; CI job names `snapshots-1`, `snapshots-2`, `smoke`. `gate-passed.sh <sha>`: exit 0 and prints the PR run's URL when a ready PR's CI run passed with a successful `smoke` job on a head commit whose tree equals `<sha>^{tree}`; exit 1 otherwise, including any `gh` failure. `FC_GH` is the `gh` seam (as `scripts/testflight/plan.sh`).

- [ ] **Step 1:** Replace the shards. `snapshots-1`: `SettingsSnapshotTests SearchSnapshotTests HomeSnapshotTests TrashSnapshotTests WelcomeSnapshotTests LockCoverSnapshotTests CameraOffSnapshotTests`; `snapshots-2`: `FilingCabinetSnapshotTests` skipping `snapshots-1`; `smoke`: the `FilingCabinet` scheme's package test targets, `FilingCabinetUITests/WaitTests` and the smoke ids; `journeys-1`: `ScanJourneyTests DetailsJourneyTests LockJourneyTests FavoritesJourneyTests ViewerSwipeDownJourneyTests SearchJourneyTests CameraAccessJourneyTests ReviewZoomJourneyTests`; `journeys-2`: `FilingCabinetUITests` skipping `journeys-1`; `audits`: `FilingCabinetAuditTests`; `all`: everything. Update the shard comment with the local timings this split comes from. Check with `make -n ci-sim SHARD=<each>`: each prints the intended `-only-testing`/`-skip-testing`.
- [ ] **Step 2: Write the failing bats tests** for `gate-passed.sh`, with a fake `gh` answering from fixture JSON and a fixture git repo:
  - `"a green ready PR run on the same tree passes"` → exit 0, URL printed.
  - `"a green run on a different tree doesn't"` → exit 1.
  - `"a run whose smoke job didn't run doesn't"` (a draft's checks-only run) → exit 1.
  - `"a run whose smoke job failed doesn't"` → exit 1.
  - `"gh failing runs the gate"` → exit 1, a warning on stderr.
- [ ] **Step 3:** Run them. Expected: FAIL (no script). Implement `gate-passed.sh`: list `ci.yml` runs with `event=pull_request&status=success` (50), get each head commit's tree from the API (`repos/$repo/git/commits/<sha>`), and for the first match check its jobs. Run again: PASS. Add `scripts/ci/tests` to `test-scripts`.
- [ ] **Step 4:** In `ci.yml`'s plan job: the sim matrix becomes `snapshots-1`, `snapshots-2`, `smoke`; on `push`, `if scripts/ci/gate-passed.sh "$GITHUB_SHA"` then checks only, with the message `Same files as <url>, which passed the gate: checks only.` Grant `actions: read`. Update the plan job's comment.
- [ ] **Step 5:** `make test-scripts`, `make lint`, and via `ios-verifier` `make ci-sim SHARD=smoke` locally (expect about 4 to 6 min of tests, all pass).
- [ ] **Step 6:** Commit: `CI: the gate is snapshots and the smoke set; a merge after a green PR doesn't run it again`.

### Task 6: The nightly workflow

**Files:**
- Create: `.github/workflows/nightly.yml`, `scripts/ci/nightly-issues.sh`, `scripts/ci/tests/nightly-issues.bats`, fixture JSON under `scripts/ci/tests/fixtures/`

**Interfaces:**
- Consumes: `make ci-sim SHARD=journeys-1|journeys-2|audits` (Task 5).
- Produces: `nightly-issues.sh <xcresult-or-missing-path> <run-url> [--dry-run]`. For each failing test `<Class>/<test>` it finds the open issue titled exactly `Nightly: <Class>/<test> fails` with label `nightly` and comments, else creates it; with no readable bundle it does the same for `Nightly: <job> failed before testing`. The body has the failure message, the run URL and "The result bundle is the run's `nightly-<job>` artifact." `--dry-run` prints the `gh` calls instead of making them. Seams: `FC_GH`, `FC_XCRESULTTOOL`.

- [ ] **Step 1: Write the failing bats tests:** `"a new failure opens an issue"`, `"a failure with an open issue comments on it"`, `"titles match exactly, not by prefix"` (open `testFoo` issue, failing `testFooBar` → a new issue), `"two failures make two issues"`, `"no result bundle opens a failed-before-testing issue"`, `"a green bundle does nothing"`, `"dry run calls no gh write"`.
- [ ] **Step 2:** Run them: FAIL. Implement the script reading `xcrun xcresulttool get test-results tests --path <bundle>` (failed leaf test cases, with their failure messages). Run again: PASS.
- [ ] **Step 3:** Write `nightly.yml`: `schedule: cron "0 8 * * *"` and `workflow_dispatch`; a plan job that ends the run when `main`'s head already has a successful `nightly.yml` run (`head_sha` query); matrix jobs `journeys-1`, `journeys-2`, `audits` with the same setup steps as `ci.yml`, `timeout-minutes: 60`, uploading `.build/DerivedData/Logs/Test/*.xcresult` as `nightly-<job>` on failure, then `if: failure()` running `nightly-issues.sh` with `GH_TOKEN`; `permissions: contents: read, actions: read, issues: write`.
- [ ] **Step 4:** Create the label: `gh label create nightly --description "A test that failed in the nightly run" --color BFD4F2`.
- [ ] **Step 5:** Dry run against a real failing bundle: `scripts/ci/nightly-issues.sh <previous session's scratchpad>/pr2/<bundle>.xcresult https://example.invalid/run --dry-run` (if the scratchpad is gone, download a failing bundle with `gh run download 44991459858 -n failures-sim-scan -D <new empty folder>`). Expected: one would-be issue per failing test in that run, titles as above.
- [ ] **Step 6:** `make test-scripts`, `make lint`. Commit: `CI: a nightly run of every journey and audit, filing an issue per failing test`.

### Task 7: Rules and docs

**Files:**
- Modify: `AGENTS.md`, `CLAUDE.md`, `Makefile` comments (`full`, `affected`, the shards), `scripts/test-map.txt` header, `scripts/sim-tests.sh` header (its run-policy text)

- [ ] **Step 1:** `AGENTS.md`: the Map (`AuditTests/`, `scripts/ci/`, `scripts/smoke-tests.txt`); the Commands rows for `affected` (shared set, two variants), `full` (everything, no longer required before a PR), `ci-sim` (the new shards) and a row for the nightly run; the run policy table (drop "once before a PR … `make full ALL=1`"; add "CI's gate on the ready PR"); the definition of done ("A branch is done when CI's gate is green on its PR and the whole-branch review has passed").
- [ ] **Step 2:** `CLAUDE.md`: the Verification paragraph and the CI sentence under Workspace, to match.
- [ ] **Step 3:** `grep -rn "full ALL=1" AGENTS.md CLAUDE.md Makefile scripts` shows no rule requiring it. Commit: `Docs: the run policy without a whole-suite run before a PR`.

### Task 8: Evidence, the PR, follow-ups

- [ ] **Step 1:** Via `ios-verifier`: `make fast`, `make lint`, `make test-scripts`, `make test-hooks`, then `make affected` with `caffeinate -i`. Expected: green, and the `test-runs:` line's test seconds under about 420 (the spec's 6 to 7 min for a shared change; this branch changes `Makefile`, which maps to the shared set).
- [ ] **Step 2:** Push the branch and open the PR as ready (it is the gate's first real run). Body: what runs where (the spec's table), the time of this PR's own gate, and the line that the nightly workflow first runs after merge (`workflow_dispatch` needs it on `main`). Watch CI; report the gate's wall time to Ben.
- [ ] **Step 3:** File GitHub issues (milestone per memory `future-items-to-github-issues`): the prune after the two-week trial (date it from the merge), and CI's 8 min build per job.
- [ ] **Step 4:** #104: the two diagnostic runs (45011297536, 45011453227) were cancelled on 2026-11-22 to free main's CI. Read the jobs that finished (`results.txt` and samples in their artifacts), post one comment on what they show (the drag test now runs nightly only, so they are not re-run), then delete `diag-104-drag-sample` and `diag-104-drag-animations` locally and on the remote.
