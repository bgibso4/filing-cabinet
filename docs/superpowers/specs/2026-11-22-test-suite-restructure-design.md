# Test suite restructure: a short gate, journeys at night

Status: draft for Ben's approval (2026-11-22). Supersedes nothing; changes the run policy in `AGENTS.md`.

## Why

Ben, 22 November: "im so annoyed at these tests. They take so fucking long to run and theyre flaky. Do we actually truely need these?" and "Im totalky fine to keep all the fast tests. its long slow flaky tests i want to heavily audit and scrutinize. we can maybe even try to seperate the accessibility ones … and run those even less frequently. Like i still dont want a super slow test suite locally either."

The cost today:

- A shared-code change makes `make affected` run everything: 20 to 23 min on Ben's Mac.
- `make full ALL=1` before every PR: about 22 min. Ben: "That's what I'm trying to get away from … a big critical blocker."
- A ready PR waits 22 to 29 min for CI, and the merge to `main` runs the same suite again.
- Every CI-only failure in #104 but one snapshot is a UI journey. They block PRs and TestFlight uploads.

## Goals

- End of a task (`make affected`): about 6 to 7 min at worst (a shared-code change), 3 to 4 min for one screen.
- No whole-suite run is required before a PR.
- A ready PR's gate: about 14 min of CI, testing snapshots (all three variants) and a smoke set of 11 journeys.
- A merge to `main` doesn't run the gate again when a PR already passed it on the same files.
- Every journey and every accessibility audit still runs, nightly on `main`. A nightly failure opens an issue and blocks nothing.

## Non-goals

- Fast tests: unchanged, still run by the Stop gate and CI.
- Timeouts, waits, snapshot precision, the 1 s snapshot settle and audit exemptions: unchanged (each needs Ben's OK).
- Deleting journeys: that is phase 3 (the prune), after the nightly trial.
- Making CI's build faster (about 8 min per job): a follow-up issue.

## Anti-goals

- A local run that pins the Mac's CPU.
- A nightly run that goes red so often nobody reads it.
- A gate that's quick because it stopped testing what breaks.

## Measurements behind this

| Piece | Ben's Mac | CI |
|---|---|---|
| Fast (`make fast`) | 40 s | about 30 s |
| Simulator build | seconds to about 2 min | 7.5 to 8 min per job, plus about 1 min setup |
| Snapshots, three variants (59 tests, 157 pictures) | 340 s | about 9 min |
| Snapshots, light and largest text | about 230 s | not used on CI |
| Journeys without audit tests (113) | about 600 s | about 17 min |
| Audit tests (23) | 160 s | 4 to 5 min |
| Smoke set (11 tests, 10 app launches) | about 2 min | about 4 min |
| Package tests in the simulator | 18 s | about 30 s |

CI is 1.4 to 1.8 times slower than the Mac (main run 44941338174: the browse shard's tests took 10.8 min against 7.8 min locally).

## Approaches considered

**How the local run gets near 5 min.**

1. *Several simulators at once* (`-parallel-testing-worker-count 4`). Tried 2026-11-22 and stopped: the CPU was 0 to 12% idle with a load average of 180 to 330 for the whole run (10 cores), and Ben saw 100% in Activity Monitor. 136 tests passed, none failed. Rejected for local and CI: background priority wouldn't reach the simulators (a system service starts them), and CI's runners have fewer cores.
2. *Fewer snapshot pictures locally.* **Chosen:** local runs skip dark mode (about 110 s); CI checks all three. Largest text stays local because it breaks on most layout changes, and dark mode breaks only on a wrong colour, which the generated tokens make rare.
3. *A shorter settle before each picture.* Rejected: the 1 s wait stops Liquid Glass being caught half-adapted.

**How a merge avoids the second run.**

1. **Chosen:** on a push to `main`, skip the simulator jobs when a PR's gate already passed on exactly the same files (same git tree). TestFlight then uploads as soon as checks pass.
2. Gate on `main` only (PRs run checks): rejected, because a flake would then hold up TestFlight uploads.

## What runs where

| When | Runs | Time |
|---|---|---|
| An agent stops (Stop gate) | Fast, when Swift changed | 40 s (unchanged) |
| Fixing one test (`make retest ONLY=…`) | that class or test | seconds to 1.5 min (unchanged) |
| End of a task, one screen (`make affected`) | that screen's snapshots (light, largest text), its journey classes, the smoke set | 3 to 4 min |
| End of a task, shared code (`make affected`) | all snapshots (light, largest text), the smoke set, the other simulator tests | about 6 min |
| Before a PR | nothing more | 0 |
| Draft PR push | checks | 5 to 7 min (unchanged) |
| Ready PR push (the gate) | checks; snapshots, three variants, split over two jobs; the smoke set with the package and other simulator tests | about 14 min |
| Merge to `main`, same files as a green PR | checks, then TestFlight | about 5 min |
| Merge to `main`, files differ | the gate, then TestFlight | about 14 min |
| Nightly on `main` | every journey and every audit | 2 to 3 jobs of about 20 min |

`make full ALL=1` still runs everything, audits included, for when it's wanted. No rule requires it.

## The smoke set (approved by Ben, 2026-11-22)

1. `HomeJourneyTests/testHomeShowsCollectionsAndScan`: the app launches to Home
2. `WelcomeJourneyTests/testContinueThenNotNowLandsOnEmptyHome`: a first launch gets through the welcome
3. `ScanJourneyTests/testScanReviewSaveShowsOnHome`: scan to saved
4. `ScanJourneyTests/testScanToViewer`: a saved scan opens
5. `BrowseJourneyTests/testOpenAScanFromAGridAndSwipePages`: open a scan from a collection and page through it
6. `DetailsJourneyTests/testRenameMoveUndoAndExpiry`: Details edits stick
7. `TrashJourneyTests/testOpenATrashedScanAndRestoreIt`: Trash and restore
8. `SearchJourneyTests/testSearchFindsAScanByItsText`: search finds a scan
9. `LockJourneyTests/testCancelledFaceIDKeepsTheCoverAndUnlockAsksAgain`: the lock holds
10. `CleanupJourneyTests/testExpiredScansReachTrashAndTheBannerShows`: cleanup moves expired scans to Trash
11. `OutsideJourneyTests/testTrashRequestOpensTrash`: tapping a cleanup note opens Trash (the path behind build 21's crash)

The list lives in one file the Makefile and CI read. Adding to it is a deliberate change that names the reason.

## The parts

### 1. Audits in their own target

- A new UI test target, `FilingCabinetAuditTests`, sharing `UITests/Support`. The 23 audit tests move there, grouped by screen.
- Each of the 31 `audit(app)` calls inside ordinary journeys either becomes an audit test in the new target (when it audits a screen state no audit test covers) or is dropped (when one does). The plan lists every call and its fate for Ben to check.
- Journeys then contain no audits. The exemptions in `Audit.swift` and `make audit-report` are unchanged.

### 2. Local snapshots: light and largest text

- The snapshot tests read which variants to draw from an environment variable passed with `TEST_RUNNER_` (as `TEST_RUNNER_SNAPSHOT_ARTIFACTS` already is). Unset means all three.
- `make affected` and `make retest` set it to light and largest text. `make full`, `make snapshots-record` and CI leave it unset.

### 3. `make affected`

- A change that maps to ALL runs every snapshot class, the smoke set and every other simulator test except journeys and audits.
- A change that maps to particular classes runs those classes and the smoke set.
- The audit target never runs in `affected`.
- A changed journey or audit test file still runs its own class (the existing rule for test files).

### 4. CI's gate (ready PRs and `main`)

- Jobs: `checks` (unchanged); `snapshots-1` and `snapshots-2` (the snapshot classes, split so the two take similar time); `smoke` (the smoke set, the package tests in the simulator and the snapshot target's non-picture tests).
- Drafts and docs-only PRs still run checks only.
- On a push to `main`, the plan job looks for a successful CI run of a ready PR whose head commit has the same tree as `main`'s new head. If it finds one, it runs `checks` only. Merges are merge commits, so an up-to-date branch gives the same tree; if `main` moved on, the trees differ and the gate runs.
- The TestFlight workflow is unchanged: it uploads after a green CI run on `main`.

### 5. The nightly workflow

- `.github/workflows/nightly.yml`: a schedule at 08:00 UTC (3 a.m. Eastern), plus a manual run. It tests `main`'s head, and skips when that commit already passed a nightly run.
- Jobs: every journey (two jobs) and the audit target (one job), on the same runner image as CI.
- On a failure, a script reads the result bundle and, for each failing test, comments on the open issue titled "Nightly: `<Class>/<test>` fails" (label `nightly`) or opens one. Each issue gets the error, the run link and the result files. A green night closes nothing.
- It needs `issues: write`. It is not a required check and nothing waits on it.
- **Trial:** two weeks from the first nightly run. Then Ben and Claude read the issues it opened: tests that only ever opened noise get fixed or deleted. If the whole run is noise, it's switched off.

### 6. Rules and docs

- `AGENTS.md`: the run policy and the definition of done. A branch is done when CI's gate is green on the PR and the whole-branch review has passed. `make full ALL=1` is no longer required.
- `CLAUDE.md`: the verification paragraph and the CI sentence.
- `scripts/test-map.txt` and `affected-tests.sh --check-map`: know the audit target and the smoke file.
- bats tests for the changed scripts (`make test-scripts`).

## Phase 3: the prune

After the two-week trial, every journey is audited for what it proves that no Fast or snapshot test proves. Each gets keep, cut or rewrite-as-Fast, with a reason, in a list Ben approves. A GitHub issue tracks this.

## #104's leftovers

- **PR #131** (the wait changes): its last CI run failed in the Favorites drag family, which leaves the gate. Re-run it after this lands. Merging it is Ben's call.
- **Favorites drag** and **iPhone Settings**: nightly only. Whatever the two diagnostic runs still going show gets one #104 comment, and their branches are deleted.
- **`SearchSnapshotTests.testNothingAnywhere` (`ax5`)**: still in the gate and in local runs, still flaky. Fixing it is its own task: first try setting the host app's own text size for the largest-text pictures, then Ben's approved design (a second host app launch) if that fails.

## Risks

- A regression only a non-smoke journey would catch reaches `main` and TestFlight, and is found the next night. Accepted as the trade for the gate's length.
- Dark-mode slips aren't seen locally; the PR gate catches them.
- The nightly run is on the same slow runners that made #104's failures. That's why it blocks nothing.

## Left to the builder

- How the two snapshot jobs split the classes, and the job names.
- The exact environment variable name and how `affected-tests.sh` prints the smoke ids.
- How the nightly script names, labels and finds its issues, within the rules above.
- Whether the plan job's tree lookup uses the API's PR runs or fetches `refs/pull/*/head`.
