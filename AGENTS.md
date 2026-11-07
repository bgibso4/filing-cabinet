# Filing Cabinet

A private, Photos-style library for personal documents (IDs, receipts, notes, cards). It scans with Apple's document camera, understands scans on-device with Vision, auto-files them into smart collections and cleans itself up over time. iPhone only, iOS 27 minimum, SwiftUI + SwiftData. Personal tool first.

## Map

```
App/                         app target: entry point, environment wiring, Info.plist, privacy manifest
Packages/FilingCabinetKit/   all logic, one local package (Package.swift)
  Sources/Core/              shared vocabulary: collections, analytics types, AccessibilityID. Mac-buildable
  Sources/Understanding/     reads pages on-device with Vision, turns text into a title. Mac-buildable
  Sources/Library/           persistence, files, thumbnails. Mac-buildable
  Sources/ScreenModels/      per-screen models and strings. Mac-buildable, tested in Fast
  Sources/Screens/           SwiftUI views and design system. iOS-only
    DesignSystem/Generated/  generated tokens (never hand-edit)
  Sources/TestSupport/       test doubles (RecordingAnalytics, fake camera and reader, synthetic pages)
  Tests/                     CoreTests, UnderstandingTests, LibraryTests, ScreenModelsTests, ScreensTests,
                             ReaderComparisonTests (the bake-off report, not a gate)
SnapshotTests/               app-hosted snapshot tests; references live beside the tests
UITests/                     journey and accessibility-coverage UI tests
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
| `make setup` | check tools, install the pre-commit hook, generate |
| `make generate` | token generator + XcodeGen; copies `Package.resolved` into the project |
| `make build` | build the app for the pinned simulator (iPhone 17, iOS 27.0) |
| `make fast` | Fast tests on macOS, no simulator |
| `make full` | everything on the simulator: package, snapshot and UI tests |
| `make ci` | exactly what CI runs: generated-file drift check, lint, hook tests, lint-rule tests, macOS slice, full, Periphery, changed snapshots, `check-resolved` |
| `make lint` / `make format` | SwiftLint + swift-format strict lint / apply swift-format |
| `make unused` | Periphery dead-code scan |
| `make snapshots-record` | re-record snapshot references on the pinned simulator |
| `make compare SCREEN=<design png stem> REF=<snapshot png>` | side by side, written to `build/compare/` |
| `make run` / `make run-fake` | launch in the simulator / with UI-test flags (`READER=text\|documents` picks the reader) |
| `make device` | build and install on a connected iPhone (`DEVICE=<name>`, `READER=text\|documents`) |
| `make compare-readers` | reader bake-off on macOS: both readers on every synthetic scan, report at `build/reader-comparison.md` (not a gate) |
| `make device-perf DEVICE=<name>` | reader cold and warm timing on a connected iPhone, attachments in `build/device-perf/`; not part of `full` or CI |
| `make test-hooks` | bats tests for the hook scripts |
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
| `-FixedDate yyyy-MM-dd` | the clock stands still at noon UTC that day |
| `-SeedScans <n>` | saves `n` synthetic scans at launch |
| `-FailSave` | the next page write fails with a full disk |
| `-ReduceMotion` | forces the save flight's Reduce Motion path |

## Import line

A module that imports SwiftUI, UIKit or VisionKit is iOS-only (`Screens`). Everything else must build for macOS so its tests run in Fast. The `no_ui_imports_in_mac_modules` lint rule and the CI macOS slice both catch a stray import.

## Architecture

Four units with narrow interfaces: Capture → Understanding → Classification → Library. Understanding and Classification are pure and unit-tested. Library owns persistence, files, thumbnails and the cleanup engine. Open/closed only where the spec promises it: a new cleanup rule is a new `CleanupTrigger` case plus an evaluator and a registry entry, never a growing `switch` in the engine. See spec sections 2 and 4 in `docs/superpowers/specs/2026-10-31-engineering-foundations-design.md`.

## Definition of done

**A task is done** when:
1. the app builds,
2. the Fast tests pass,
3. the snapshot and UI tests for the screens it touched pass,
4. lint and format are clean,
5. for anything visual, the hand-off lists the image paths the agent actually opened (snapshot, `make compare` output or simulator screenshot).

**A branch is done** when the **Full** suite is green in CI and the whole-branch review has passed.

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
