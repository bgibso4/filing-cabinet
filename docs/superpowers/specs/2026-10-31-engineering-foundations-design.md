# Filing Cabinet — Engineering Foundations

**Date:** 2026-10-31
**Status:** Draft for Ben's review (revised after an adversarial review)
**Applies to:** every plan and every line of code in this repo. The product itself is defined by the requirements (`docs/superpowers/specs/2026-10-10-filing-cabinet-requirements.html`) and the design handoff (`design/`). This document defines *how* it gets built.

Items marked **(my call)** were proposed by Claude and not discussed explicitly. Everything else was agreed with Ben in conversation on 2026-10-31, or adopted from the adversarial review with his go-ahead.

---

## 1. Intent

Development is **agentic first**: agents do the building, fixing and improving. So the foundation has to give agents the context, guardrails and feedback loops to produce work that is correct and provably so, without Ben checking every line.

- **Quality bar:** code a principal engineer would sign off on. Simple, elegant, obvious to the next reader. Never clever, never over-built.
- **Testing is paramount.** An agent's claim that something works is only as good as the test or image behind it.
- **No deadline.** Doing it right beats doing it fast.

**Goals**
- A codebase where the right way is the easy way: rules enforced by tools, not memory.
- A fast feedback loop (seconds, not minutes) for the logic most likely to break.
- Every behaviour proven by a test; every visual state proven by a snapshot.

**Non-goals**
- A coverage percentage target.
- Supporting anything below iOS 27, iPad, or landscape.
- Generic "framework" code for needs the spec doesn't have.

**Anti-goals (failure even if it technically works)**
- An agent reporting "done" while tests fail or a screen was never looked at.
- Document content (images, text, titles, extracted values, custom collection names) leaving the device, through analytics, logs or anything else.
- Abstractions with one implementation and no test that needs a fake.

---

## 2. Principles, in priority order

**DRY → YAGNI → SOLID.** When YAGNI and SOLID conflict, **YAGNI wins**.

### DRY in practice
One source of truth for:
- user-facing copy (String Catalogs),
- colours, type and spacing (`design/tokens.json`, turned into code and assets by a committed generator),
- expiry and date maths,
- test helpers and fixtures (shared between tests, snapshots and previews),
- agent rules (`AGENTS.md`; see §7).

### YAGNI in practice
- No protocol with a single implementation unless a test needs a fake.
- No speculative layers, settings, flags or extension points.
- A module exists only once it has code (see §4).
- Periphery (unused-code detection) catches the leftovers.

### SOLID in practice
- **Single responsibility:** one job per type, describable without "and". Views render and route intent; nothing else.
- **Open/closed:** only where the spec promises extension: cleanup rules (a new `CleanupTrigger` case + evaluator + registry entry, no growing `switch`), collections as data, review entry points.
- **Liskov:** fakes honour the real contract, including the errors the real thing throws.
- **Interface segregation:** small, consumer-shaped protocols.
- **Dependency inversion:** collaborators are injected; no `.shared` singletons in logic. Protocols only at real seams: disk, Vision, camera, clock, Apple Intelligence, analytics.

---

## 3. Definition of done

**A task is done** when:
1. the app builds,
2. the Fast tests pass,
3. the snapshot and UI tests for the screens it touched pass,
4. lint and format are clean,
5. for anything visual, the hand-off lists the image paths the agent actually opened (snapshot, `make compare` output or simulator screenshot).

**A branch is done** when the **Full** suite is green in CI and the whole-branch review has passed.

Anything not checked is stated plainly in the hand-off ("didn't verify X because Y"). Before claiming any of this, agents dispatch `ios-verifier` for evidence.

---

## 4. Architecture and layout

- **Four units with narrow interfaces:** Capture → Understanding → Classification → Library. Understanding and Classification are pure. Library owns persistence, files, thumbnails and the cleanup engine.
- **Logic lives in a local Swift package**, `platforms: [.iOS(.v27), .macOS(.v27)]`, using the `package` access level between its modules (not `public`).
- **The macOS line is the import line.** A module that imports SwiftUI, UIKit or VisionKit is iOS-only. Everything else must build for macOS, so its tests run in the Fast loop without a simulator. CI builds the macOS slice so a stray `import UIKit` fails fast.

### Modules (my call)
**Mac-buildable (tested in Fast):**
- `Core`: shared vocabulary. Scan IDs, the built-in collection enum, `CollectionRef`, `CapturedPages` (Sendable captured-page data), the injected clock, and the analytics event types and `Analytics` protocol (§8). Depends on nothing. It exists to prevent dependency cycles, not to collect helpers.
- `Understanding`: OCR, title and entity extraction, text indexing.
- `Library`: SwiftData models, files, thumbnails, the cleanup engine.
- `ScreenModels`: one `@Observable` model per screen, in one folder per feature (Home, Review, Viewer, …). Imports only Foundation, Observation and the modules above.
- `Classification` is added in Plan 3, when it has code.

**iOS-only:**
- `Screens`: SwiftUI views in one folder per feature (mirroring `ScreenModels`), the design system (tokens and shared views), and the VisionKit camera adapter that produces `CapturedPages`.
- **The app target is thin:** the app entry point and `AppEnvironment` wiring only.

### Other
- **Folders follow features, not layers** inside each module.
- **One primary type per file.**
- **Memory:** originals are HEIC on disk, the database holds references only, grids render ~400px thumbnails decoded with ImageIO. Never decode full resolution in a grid cell.
- **Stack:** iOS 27 minimum, iPhone portrait only, Swift 6 language mode on the current toolchain, SwiftUI, SwiftData, VisionKit, Vision, ImageIO.
- **SwiftData, CloudKit-ready:** defaults on every property, no `@Attribute(.unique)`. CloudKit would allow optional relationships with inverses; we choose to use **none**, because collections are data and rules, not stored links. CloudKit readiness covers the database only: page and thumbnail files on disk would need their own sync path later.
- **Project generation:** XcodeGen from `project.yml`. The `.xcodeproj` is generated, never hand-edited, never committed.
- **Bundle id:** `com.cadre.filingcabinet`.
- **Apple Developer account:** Ben has a paid account, so the app signs with his team from the start. CloudKit and TestFlight capabilities are added when the features that need them are built.
- **Signing (following Beacon exactly):** a committed `Signing.xcconfig` holding Ben's team ID (a team ID isn't secret; it's in every signed binary), which `#include?`s a gitignored `Signing.local.xcconfig` for overrides. CI builds for the simulator with `CODE_SIGNING_ALLOWED=NO`.

---

## 5. Code conventions

### Concurrency contract
- **Build settings:** Swift 6 language mode, Approachable Concurrency on. Default isolation is `MainActor` for `ScreenModels`, `Screens` and the app; `nonisolated` for `Core`, `Understanding`, `Library` (and later `Classification`).
- **Work that must leave the caller's thread is marked `@concurrent`:** OCR, image encoding and decoding, file I/O. A plain `nonisolated async` function runs on the caller's actor, so it is never the tool for slow work.
- **SwiftData objects never cross isolation.** Pass `PersistentIdentifier` or Sendable value snapshots between actors.
- **One writer (my call):** all SwiftData writes go through the main `ModelContext`. Slow work (OCR, HEIC encoding, thumbnails) runs `@concurrent` first and hands back Sendable results. A `@ModelActor` is introduced only if a measured problem needs it.
- **Banned:** `Task.detached`, `@unchecked Sendable`, and turning off concurrency checking.
- **Proven by test:** an integration test asserts OCR does not run on the main thread.

### Errors
- Each unit has one error type in its own terms (e.g. `LibraryError.diskFull`).
- Errors travel up to the screen, which picks the copy the design shows.
- `try?` only with a comment explaining why the failure doesn't matter.

### Logging
- One `os.Logger` per unit (subsystem `com.cadre.filingcabinet`, category = unit name).
- **Public (shown everywhere):** scan IDs, page counts, collection kinds, error cases, timings.
- **Private (`privacy: .private`, visible only while debugging):** titles, recognised text, extracted values (names, dates, numbers), file names.
- **Never logged:** page images; full OCR dumps outside debug builds.
- No `print()`.

### Wiring
- One `AppEnvironment` builds the real services at launch.
- Tests and UI-test launch flags build fakes instead.
- Screens receive what they need via initialisers or the SwiftUI environment.

### Naming, copy, previews
- Apple's Swift API Design Guidelines.
- Built-in collections are an enum (in `Core`). Custom collections are data.
- **Copy:** every user-facing string lives in a String Catalog, copied exactly from the design sources. Each module with UI text owns its own `Localizable.xcstrings` (`defaultLocalization: "en"`), and every `Text`/`String(localized:)` passes `bundle: #bundle`, enforced by a SwiftLint custom rule. One test per such module resolves a plural key and checks the formatted result, so a broken lookup can't hide behind English keys.
- **Tokens:** `scripts/generate-tokens` turns `design/tokens.json` into Swift and colour assets. It's committed and run by `make generate`. A test parses `tokens.json` and asserts every token resolves at runtime.
- Every screen has previews for its designed states, reusing the snapshot fixtures.

---

## 6. Testing

Ben tests on a physical iPhone occasionally; the simulator is the main test surface.

### Layers
1. **Logic tests:** Swift Testing, in the Mac-buildable package modules.
2. **Integration tests:** in-memory SwiftData, temp directories, real Vision on synthetic sample images. Mac-buildable where the API allows.
3. **Screen-model tests:** `ScreenModels` with fakes for every seam. Mac-buildable.
4. **Snapshot tests:** swift-snapshot-testing (exact version pinned), in an **app-hosted** `FilingCabinetSnapshotTests` target, so Liquid Glass renders. Strategy: `.image(drawHierarchyInKeyWindow: true, perceptualPrecision: 0.98)`. Every designed state in light, dark and the largest text size, on one pinned simulator.
5. **UI tests:** XCUITest journeys driven by launch flags (fake camera, fresh library, fixed date, seeded scans). Every control has an accessibility identifier, with a test that checks coverage. `performAccessibilityAudit` runs on each journey's screens through one shared helper that names the audit types and any documented issue filters (e.g. known Liquid Glass contrast false positives), so the audit can't become flaky.
6. **Phone checklist** at milestones: real camera, Apple Intelligence, notifications, timed performance with 2,000 scans.

### Groupings
- **Fast:** layers 1–3 on macOS, via `xcodebuild test` on the package scheme with a macOS destination (never plain `swift test`, which skips resource compilation). Seconds. Run constantly, and by the Stop hook.
- **Full:** layers 1–5. Runs in CI on every PR; the gate for a branch.
- **Device:** the phone checklist, plus timed performance tests (below).

### Snapshot references
- **Comparing against the designs:** when a reference is first recorded, `make compare SCREEN=<id>` writes a side-by-side image (new reference | the matching PNG in `design/screens/`). The agent opens it and lists its path in the hand-off.
- **Changing a reference is a reviewed change.** Pre-commit and CI list every modified `__Snapshots__/*.png`. The commit or PR body names each one with the reason. The hand-off includes the old and new image paths the agent opened. The whole-branch reviewer checks this.
- If references recorded locally don't match CI rendering within tolerance, references are recorded in CI and downloaded instead.

### Performance
- **In Full (deterministic, never timed):** with 2,000 seeded scans, the grid makes zero full-resolution decodes (counted through the thumbnail-loader seam), no decode exceeds ~400px, and resident thumbnails stay bounded while scrolling.
- **In Device (timed):** signposted operations (scan to saved, OCR per page, thumbnail decode, grid first frame) are measured with XCTest `measure(metrics: [XCTOSSignpostMetric …])` on the iPhone, against Xcode baselines. Simulator timings are never asserted.

### Rules
- Time is always injected; no test reads the real clock.
- No personal documents anywhere in the repo. Fixtures are synthetic.
- A flaky test is fixed or deleted the same day.
- No coverage percentage, but every behaviour is tested and every bug fix gets a regression test.

### Apple Intelligence evaluation **(my call)**
AI-backed features (Plan 3) get an evaluation suite built with Apple's iOS 27 Evaluations framework, run through the Swift Testing `.evaluates` trait, using synthetic sample documents only. It tracks classification quality over time rather than gating every build. It's set up in Plan 3, not in the foundation plan.

---

## 7. Agent tooling

### AGENTS.md and CLAUDE.md
- **`AGENTS.md` is the single copy of the rules**, read by Claude Code, Xcode 27's built-in agents and Codex: what the app is, an annotated file tree, the commands, the hard rules, and the definition of done. It stays short; deeper guides live in `docs/` (this document is the first) and are linked from it.
- **`CLAUDE.md` is `@AGENTS.md`** plus Claude-only notes (hooks, `ios-verifier`).
- **Hard rule:** lint config, hook config and test tolerances change only with Ben's OK. Never widen a threshold to make something pass.

### Commands
A Makefile is the single entry point. Agents and humans use the same commands:

| Command | Does |
|---|---|
| `make setup` | install tooling, git hooks, generate the project |
| `make generate` | XcodeGen + token generator |
| `make build` | build the app for the simulator |
| `make fast` | Fast tests (macOS) |
| `make full` | Full suite |
| `make ci` | exactly what CI runs, so agents can reproduce CI locally |
| `make lint` | SwiftLint strict + `swift format` lint |
| `make format` | apply `swift format` |
| `make unused` | Periphery |
| `make snapshots-record` | re-record snapshot references |
| `make compare SCREEN=<id>` | side-by-side of a reference and its design PNG |
| `make run` | launch in the simulator |
| `make run-fake` | launch with test flags (fake camera, seeded scans, fixed date) |
| `make device` | build and install on Ben's iPhone |

Output is trimmed (xcsift or xcbeautify) so agents see errors, not walls of log.

### Agent hooks
These come from arsenal's `ios` profile and are never committed here. Arsenal can't install hooks today, so **building them is a separate small arsenal plan that comes before the foundation plan** (installer plus bats tests, following arsenal's README). Every hook is **opt-in per project**: it does nothing unless the repo provides the matching Makefile target, so Baseline, Beacon and Apex are unaffected until they choose to adopt it.

- **Format on edit:** `swift format` runs on every edited Swift file.
- **Generated-file guard:** edits to the `.xcodeproj` are blocked.
- **Hook-bypass guard:** `git commit --no-verify` and `git -c core.hooksPath=…` are blocked. CI remains the real gate.
- **Stop gate,** registered for both **Stop and SubagentStop**, so subagent-driven work is gated per task:
  - a `PostToolUse` hook on Edit/Write of `*.swift` sets a per-session "dirty" marker; the gate runs only when it's set, and clears it when Fast passes (git diff isn't used, so committing doesn't skip the check);
  - on failure the agent gets the failing tests and must keep working;
  - a per-session counter (keyed on `session_id`) hands back to Ben after a few failed attempts, with a message stating plainly that tests are failing;
  - `make fast` runs under a lock so parallel agents don't collide on the build directory;
  - **no TDD escape:** under Superpowers TDD the red step happens mid-turn, so a turn never needs to end red.

### Git pre-commit hook (committed)
Format check and strict lint, plus the list of changed snapshot references. Tests are left to the Stop gate and CI, because pre-commit sees the working tree rather than what's staged.

### Quality tools
- **`swift format`** from the toolchain (pinned to Xcode, nothing to install) owns formatting.
- **SwiftLint, strict,** with its formatting rules turned off so the two never fight. Custom rules: no `print`, no uncommented `try?`, no `.shared` in package code, `bundle: #bundle` on localized text. `blanket_disable_command` is on, and any `swiftlint:disable` needs a reason.
- **Periphery** runs in CI only (`make unused`), with a retain list for macro-generated, preview and test-only symbols. If it doesn't support Xcode 27 when the foundation is built, that's stated and it's deferred.
- **No third-party libraries** beyond swift-snapshot-testing and TelemetryDeck (§8), unless Ben approves one. Every package is pinned to an exact version.

### Helper agents and skills
- `ios-verifier` for build and test evidence (exists in arsenal). Teaching it to read captured simulator logs when diagnosing failures is an arsenal change shared with Ben's other iOS projects, made there with its own diff.
- A principles-aware code reviewer, being designed separately in arsenal.
- Xcode 27's Apple skills and MCP tools (preview rendering, documentation search) alongside XcodeBuildMCP, Axiom and the SwiftUI skills already in the `ios` profile.

---

## 8. Observability: logs, metrics, analytics

**The promise is "your documents never leave your phone"**, not "nothing leaves your phone". Requirements row 14 was updated to match on 2026-10-31.

### During development
- XcodeBuildMCP captures app logs from simulator or device runs; agents read them after a failing test.
- Signposts (`OSSignposter`) on key operations: scan to saved, OCR per page, thumbnail decode, grid first frame. Visible in Instruments and used by the Device performance tests.
- Once on TestFlight, Xcode Organizer provides crashes, hangs, launch time and energy from opted-in users, with no code.

### Usage analytics (must exist before launch)
- **Service:** TelemetryDeck. Anonymous IDs, no IP storage, Swift SDK. Free tier is 50,000 events a month for new accounts (July 2026); confirm current pricing before connecting.
- **No opt-out** (Ben's decision). It's declared on the App Store privacy label ("Data Not Linked to You") and in `PrivacyInfo.xcprivacy`.
- **Behind a small `Analytics` protocol** in `Core`. It's a real seam: tests use a recording fake and assert the events a feature sends. Swapping vendors (e.g. self-hosted Aptabase) is a one-file change.
- **The no-text rule is a type, not a test.** An event is a fixed enum case whose payload is `[AnalyticsKey: AnalyticsValue]`. `AnalyticsValue` has only `.int`, `.bool` and `.token(some AnalyticsToken)` cases, and only our own `RawRepresentable` enums conform to `AnalyticsToken`. There is no `String` case, so free text can't compile in.
- **Collections in events:** a `CollectionRef` that is `.builtIn(<built-in enum case>)` or `.custom`. Custom collection names and IDs are never sent. Custom-collection usage is reported as counts (how many exist, how many scans are in them).
- **Event families:** usage (app opened, scan started/saved with page count/cancelled, review suggestion accepted/edited/rejected, search used, share used, cleanup run with count removed) and failures (one event per error case).
- **Undecided, deliberately:** whether "scan saved" includes its collection. Decide when that feature is built.
- **Timing:** the types and protocol exist from the first feature, so every feature ships with its events. Until TelemetryDeck is connected (before TestFlight), a stand-in implementation writes events to the log, where tests and agents can see them.

### Deferred (GitHub issue)
- MetricKit daily reports and a hidden "Export diagnostics" screen. Revisit if crashes or freezes on Ben's phone become hard to diagnose before TestFlight.

---

## 9. Workflow

- **Public GitHub repo** `bgibso4/filing-cabinet` **(my call: the name)**. Public is fine with Ben, and it makes GitHub's macOS runners free. No personal documents are ever committed. Creating and pushing it is a step in the foundation plan that waits for Ben's go-ahead at that moment.
- **`main` is always green.** Each plan is built on its own branch and merged by PR after a final whole-branch review.
- **CI (GitHub Actions):** `runs-on: xcode-27` (generally available, with iOS 27 simulator runtimes). Steps: install XcodeGen, `make generate`, `make ci`. On every PR and push to `main`:
  - lint,
  - the macOS slice build,
  - the **Full** suite, snapshots and UI tests included, on the pinned simulator,
  - Periphery,
  - the changed-snapshot listing.
  Build output is cached.
- **Dependency pinning:** because the `.xcodeproj` isn't committed, versions are pinned exactly in `project.yml` and `Package.swift`, and the resolved file is committed outside the generated project.
- **Issues:** future and not-v1 items become GitHub issues once the remote exists (including the deferred item in §8).
- Commits end with the agreed co-author line; agents commit only within an agreed plan.

---

## 10. What comes next

1. **Arsenal hooks plan** (small): the opt-in hook installer, the hooks in §7, and bats tests. Built in arsenal.
2. **Foundation plan:** package and modules, XcodeGen project, signing, Makefile, lint, pre-commit, CI, `AGENTS.md`/`CLAUDE.md`, the token generator, the analytics types, and one tiny end-to-end feature that exercises every test layer, proving the loop works before real features start. **(My call for the feature: the empty Home screen, with its screen model, snapshot, UI test, accessibility audit and an `appOpened` event.)**
3. **Rework Plan 1** (`docs/superpowers/plans/2026-10-31-01-scan-to-library.md`, on hold) to follow this document, including replacing its "No network calls" constraint.

### Left to the builder
- The exact SwiftLint rule set beyond the custom rules named here.
- Makefile internals, cache keys and CI job layout.
- Which simulator model and OS build is pinned for snapshots (documented once chosen).
- How many failed attempts the Stop gate allows before handing back.
