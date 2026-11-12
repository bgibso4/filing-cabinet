# Filing Cabinet

A private, Photos-style library for personal documents (IDs, receipts, notes, cards). It scans with Apple's document camera, understands scans on-device with Vision, auto-files them into smart collections and cleans itself up over time. iPhone only, iOS 27 minimum, SwiftUI + SwiftData. Personal tool first.

## Map

```
App/                         app target: entry point, environment wiring, Info.plist, privacy manifest
Packages/FilingCabinetKit/   all logic, one local package (Package.swift)
  Sources/Core/              shared vocabulary: collections, analytics types, AccessibilityID. Mac-buildable
    Lifecycle/               the one rule for where a scan is (library, Trash or gone), from its dates
    Photos/                  the Save to Photos seam (PhotoSaving) and its errors
  Sources/Understanding/     reads pages on-device with Vision, turns text into a title. Mac-buildable
  Sources/Library/           persistence, files, thumbnails, the Trash purge. Mac-buildable
    Export/                  a scan as a PDF (ScanPDF), temporary export files and their launch cleanup
  Sources/ScreenModels/      per-screen models and strings (Details, Trash, Settings among them). Mac-buildable,
                             tested in Fast
    Shared/                  HeaderRest, HeaderInsets, HeaderSettling: the header's maths
    Viewer/                  DetailsMotion (panel progress, page fit, settle target), DetailsSpring: Details' maths
    Cleanup/                 cleanup notes and Home's banner
    Search/                  search matching (text folded once), history, recently viewed, the Search model
  Sources/Screens/           SwiftUI views and design system. iOS-only
    DesignSystem/            tokens and shared views; HeaderScrollView gives every screen its header (the system bar's
                             own titles, styled by HeaderAppearance)
    DesignSystem/Generated/  generated tokens (never hand-edit)
    Details/                 DetailsPanel (the panel that replaces the system sheet), DetailsGrabber
    Viewer/                  the viewer's views; DetailsSwipe opens Details with a swipe up
    Search/                  the Search screen: our own field, filter chips, result rows
  Sources/TestSupport/       test doubles (RecordingAnalytics, fake camera and reader, synthetic pages)
  Tests/                     CoreTests, UnderstandingTests, LibraryTests, ScreenModelsTests, ScreensTests,
                             ReaderComparisonTests (the bake-off report, not a gate)
SnapshotTests/               app-hosted snapshot tests; references live beside the tests
UITests/                     journey UI tests, with identifier coverage and accessibility audits
DeviceTests/                 reader timing on a real iPhone (`make device-perf`), never in `full` or CI
scripts/                     token generator, compare, pre-commit, lint-rule tests
scripts/hooks/               Claude Code hooks (see CLAUDE.md) and their bats tests
design/                      design handoff and tokens.json (source of the generated tokens)
docs/superpowers/specs/      requirements and design specs
project.yml                  XcodeGen source of the (gitignored) FilingCabinet.xcodeproj
Package.resolved             pinned app-level packages, copied into the generated project
```

Strings live in the owning module's `Localizable.xcstrings`, read with `bundle: #bundle`.

## Commands

`make` is the only entry point. Run `make setup` once per checkout (installs the git hook, generates the project).

| Command | Does |
|---|---|
| `make setup` | check tools, install the pre-commit hook, create the `FC iPhone 17` simulator, generate |
| `make generate` | token generator + XcodeGen; copies `Package.resolved` into the project |
| `make build` | build the app for the pinned simulator (`FC iPhone 17`: an iPhone 17 on iOS 27.0, this project's own; `SIM_DEVICE=` overrides) |
| `make fast` | Fast tests on macOS, no simulator |
| `make affected` | the snapshot and UI test classes the branch's changes touch (`scripts/test-map.txt`; `BASE=<ref>` diffs against another ref). The end-of-task run |
| `make retest` | re-run without building: `ONLY="<Target/Class[/test]> …"`, or the affected classes. Refuses when the sources changed since the last build. The while-fixing run |
| `make full` | simulator tests: `ONLY="<Target/Class> …"` runs just those (`SKIP=` leaves some out). A whole suite (no `ONLY`, or a whole target) needs `ALL=1`: everything, package, snapshot and UI tests, once before a PR |
| `make audit-report` | every accessibility audit issue and exemption use in the newest test results (`RESULT=<.xcresult>` for another) |
| `make ci` | everything CI runs: `ci-checks`, then `ci-sim` |
| `make ci-checks` | generated-file drift check, lint, hook tests, lint-rule tests, macOS slice, Periphery, changed snapshots, `check-resolved` |
| `make ci-sim` | the full simulator suite and `check-resolved`. CI runs it as three parallel jobs: `SHARD=scan` and `SHARD=browse` (the two longest UI classes; scan also runs the Trash and Settings journeys, browse the snapshot tests) and `SHARD=main` (everything else) |
| `make lint` / `make format` | SwiftLint + swift-format strict lint / apply swift-format |
| `make unused` | Periphery dead-code scan |
| `make snapshots-record` | re-record the snapshot references that fail or are missing, on the pinned simulator (`ONLY=` for some classes; `SNAPSHOT_RECORD=all` rewrites every one) |
| `make compare SCREEN=<design png stem> REF=<snapshot png>` | side by side, written to `build/compare/` |
| `make run` / `make run-fake` | launch in the simulator / with UI-test flags (`READER=text\|documents` picks the reader) |
| `make device` | build and install on a connected iPhone (`DEVICE=<name>`, `READER=text\|documents`) |
| `make compare-readers` | reader bake-off on macOS: both readers on every synthetic scan, report at `build/reader-comparison.md` (not a gate) |
| `make eval-suggestions` | suggestion evaluation on macOS: the text reader, then the on-device model's two calls (title and collection, then search words), on every made-up case (page 1's image goes in, `IMAGE=0` for text only; `CASES=` runs some cases: ids, or prefixes like `wallet-`), report at `build/suggestion-eval.md` (not a gate; says so in one line when the model is unavailable) |
| `make device-perf DEVICE=<name>` | reader cold and warm timing on a connected iPhone, attachments in `build/device-perf/`; not part of `full` or CI |
| `make test-hooks` | bats tests for the hook scripts |
| `make test-scripts` | bats tests for the test-run scripts (`affected`, `retest`, `audit-report`) |
| `make test-lint` | fixture tests for the SwiftLint custom rules |
| `make check-resolved` | fail if Xcode rewrote the resolved packages |

## Module dependencies

| Module | Depends on |
|---|---|
| `Core` | nothing |
| `Understanding`, `Library` | `Core` |
| `ScreenModels` | `Core`, `Understanding`, `Library` |
| `Screens` | `Core`, `ScreenModels`, `Library` |
| `TestSupport` | `Core`, `Understanding`, `Library` |

## Launch flags

Debug builds only; a Release build ignores them. Parsed in `Core/Launch/LaunchOptions.swift`.

| Flag | Does |
|---|---|
| `-UITest` | in-memory store, temporary library folder, no animations |
| `-FakeCamera <1…3>` | the fake camera returns that many synthetic pages |
| `-CameraDenied` | camera access reports denied |
| `-FakeReader` | every page reads as the synthetic City Pharmacy receipt |
| `-TextReader text\|documents` | which Vision reader understands pages |
| `-Notifications authorized\|denied\|notDetermined` | a fake notification center answers with that authorization |
| `-NotificationsUnanswered` | a fake notification center never answers what iOS allows (a stuck notification service) |
| `-FixedDate yyyy-MM-dd` | the clock stands still at noon UTC that day |
| `-SeedScans <n>` | saves `n` synthetic scans at launch |
| `-SeedTrash <n>` | saves `n` synthetic scans at launch and moves scan `i` to Trash on today − `i` |
| `-SeedFavorites <n>` | with `-SeedScans`, the first `n` seeded scans are favourites, in seed order |
| `-Photos authorized\|denied` | a fake Photos answers Save to Photos with that access, so no system prompt shows |
| `-FailSave` | the next page write fails with a full disk |
| `-Suggestions arrives\|slow\|unavailable` | the review's suggester is a fake: City Pharmacy receipt in Receipts (and its words after Save) after 0.3 s, never, or unavailable. Under `-UITest` it is unavailable unless this says otherwise |
| `-ReduceMotion` | the capture layer and Search fade rather than slide, and Home's count doesn't pop |

UI tests launch the app once per test class. Later tests of the class open a `RelaunchURL` (`Core/Launch/RelaunchURL.swift`) instead: the running app builds a new environment from the flags in it and every view again, in about 1 s instead of a launch. A test that needs a cold process passes `fresh: true` to `launchApp`; a change of text size launches again by itself. The app acts on the URL only when it was launched with `-UITest` in a Debug build.

## Import line

A module that imports SwiftUI, UIKit or VisionKit is iOS-only (`Screens`). Everything else must build for macOS so its tests run in Fast. The `no_ui_imports_in_mac_modules` lint rule and the CI macOS slice both catch a stray import.

## Architecture

Four units with narrow interfaces: Capture → Understanding → Classification → Library. Understanding and Classification are pure and unit-tested. Library owns persistence, files, thumbnails and the cleanup engine. Open/closed only where the spec promises it: a new cleanup rule is a new `CleanupTrigger` case plus an evaluator and a registry entry, never a growing `switch` in the engine. See spec sections 2 and 4 in `docs/superpowers/specs/2026-10-31-engineering-foundations-design.md`.

## Definition of done

**A task is done** when:
1. the app builds,
2. the Fast tests pass,
3. `make affected` passes (the snapshot and UI tests for what it touched),
4. lint and format are clean,
5. for anything visual, the hand-off lists the image paths the agent actually opened (snapshot, `make compare` output or simulator screenshot).

**A branch is done** when the **Full** suite is green in CI and the whole-branch review has passed.

### Run policy

The simulator suites are slow, so run the narrowest one that answers the question:

| When | Run |
|---|---|
| While fixing: re-running a failing class or test, or after re-recording snapshots, with no source change since the last build | `make retest ONLY="<Target/Class[/test]>"` |
| At the end of a task | `make affected` (`BASE=<the task's first commit>^` for just the task's changes) |
| Once before a PR goes ready for review | `make full ALL=1`, or let CI's Full suite run |

Run tests through these targets, not `xcodebuild test` or XcodeBuildMCP's test tools: the targets keep the build check `retest` relies on and the run log (`.build/test-runs.log`). To learn what an audit flagged, run `make audit-report` rather than exporting the results by hand; it also lists the exemptions no audit used.

Anything not checked is stated plainly in the hand-off ("didn't verify X because Y"). Before claiming any of this, agents dispatch `ios-verifier` for evidence.

## Hard rules

- Lint config, hook config and test tolerances change only with Ben's OK. Never widen a threshold to make something pass.
- Changed snapshot references are named in the commit message, each with the reason. The pre-commit hook lists them.
- Never hand-edit the generated `.xcodeproj` or any `Generated/` file; change the source (`project.yml`, `design/tokens.json`) and `make generate`.
- Never bypass git hooks: no `--no-verify`, no `git commit -n` (or any short-flag cluster containing `n`), no `-c core.hooksPath=…`. The Bash guard blocks these, and any Bash command whose non-message text contains them. If the pre-commit hook fails, fix the cause; never skip it.
- Every new piece of logic gets unit tests; every bug fix gets a regression test.
- iPhone, portrait only, English only. No `#available` branches (iOS 27 minimum).
- Titles use New York (`.serif`); everything else is SF Pro.
- Swift 6 language mode, Approachable Concurrency. Banned: `Task.detached`, `@unchecked Sendable`, disabling concurrency checking.
- `package` access between package modules; `public` only for what the app, snapshot or UI tests use.
- Colours, spacing, radii and type only from the generated tokens; no bare layout literals (screen measurements are named private constants citing the design source). No shadows.
- User-facing copy is localized, uses middots (" · ") and never em dashes. The Scan button always says "Scan".
- Log with `os.Logger` (subsystem `com.cadre.filingcabinet`, category = module); never `print()`. `try?` only with a comment saying why.
- One primary type per file. Inject collaborators; no singletons. Protocols only at real seams.
- Third-party packages are pinned with `exact:`. The tracked root `Package.resolved` is the source of truth for the app's packages; if `make check-resolved` fails, copy the project's file back and commit it.
- Periphery suppressions are per declaration (`// periphery:ignore - <reason>`), never file- or config-wide.
- No personal documents anywhere in the repo.
- Originals are HEIC on disk; grids render ~400px ImageIO thumbnails and never decode full-res.

## Read next

- Engineering foundations: `docs/superpowers/specs/2026-10-31-engineering-foundations-design.md`
- Requirements (source of truth for product): `docs/superpowers/specs/2026-10-10-filing-cabinet-requirements.html`
- Design handoff: `design/README.md`
