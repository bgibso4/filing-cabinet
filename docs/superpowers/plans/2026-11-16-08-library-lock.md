# Library Lock Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A "Lock with Face ID" setting that covers the whole library until Face ID (or the passcode) opens it, while scanning from outside the app never waits; plus the storage decisions of #93 written into the privacy policy.

**Architecture:** A `LibraryLock` model in ScreenModels holds the lock's state and timing, behind a `DeviceAuthenticating` seam in Core (LocalAuthentication in the app, a fake in tests). The root shows one `LockCover` view in two places: over the navigation stack (so nothing shows under the capture layer) and in a shield window above everything else (sheets, the app switcher). `RequestRouting`, `SpotlightSync`, `CleanupNotifier` and `SettingsModel` each learn one thing about the lock.

**Tech Stack:** Swift 6, SwiftUI, LocalAuthentication, Swift Testing, XCUITest, swift-snapshot-testing.

**Spec:** `docs/superpowers/specs/2026-11-16-library-lock-design.md`; mocks in `docs/superpowers/specs/2026-11-16-library-lock-mocks.html` (Ben's page: https://claude.ai/artifact/96686q1Ms283SiQwCNDtzs).

## Global Constraints

- Branch `library-lock` from main at f43b4a6, in the main checkout. Two other lanes are open in worktrees: `test-reliability` (tests, `BrowseJourneyTests`) and `viewer-feel` (the viewer's dismiss gesture, Details' Reduce Motion). Don't touch `BrowseJourneyTests` or the viewer's gesture code; rebase on main before the PR.
- AGENTS.md hard rules: `package` access between modules, `public` only for app/tests; no `#available`; `os.Logger`, never `print`; `try?` only with a comment; one primary type per file; inject collaborators; tokens only for colours, spacing and type; no shadows; copy localized, middots, never em dashes.
- Import line: only `Screens` and the app target import SwiftUI/UIKit. `LocalAuthentication` is imported only in the app target.
- Off by default. With the lock off, nothing in the app behaves differently from main.
- A scan request (`ExternalRequest.scan`) never waits for, triggers or counts as an unlock.
- Nothing is deleted or hidden for good by the lock: off, a failed Face ID or a removed passcode loses nothing.
- Relock time is exactly 5 minutes (`Duration.seconds(300)`), measured on a monotonic clock, from the app going to `.background`.
- The Face ID reason string and every new line of copy are the mocks' words (Task 5 and 6 list them).
- Lint config, hook config and test tolerances don't change. Changed snapshot references are named in the commit message with the reason.
- Run policy: `make retest ONLY=…` while fixing, `make affected` at each task's end, `make full ALL=1` once before the PR. Build/test evidence via `ios-verifier`.
- Never record a decision as Ben's unless the spec's "Decided" list says so.

## Review Focus

1. **The Face ID prompt itself makes the scene inactive, then active.** That second "became active" must not start another Face ID after a cancel (no prompt loop). Test in Task 2.
2. **No frame of the library under the capture layer.** A Scan request while locked, then Save or Discard: Home must never show as the layer slides away. Test in Task 7 (`LockJourneyTests`), built in Task 6.
3. **Exactly 5 minutes, on a clock that can't be wound back.** 4 min 59 s away stays open, 5 min 0 s locks; the wall clock is never read. Test in Task 2.
4. **Turning the lock on while the Spotlight call fails** (the index is unreadable while the phone is locked): the removal is retried on the next pass, not forgotten. Test in Task 4.
5. **The setting is on but the phone has no passcode** (removed later, or a backup restored onto such a phone): the library opens with no cover, Settings says "Paused", and turning the switch off needs no check. Tests in Tasks 2 and 5.

---

### Task 1: The authentication seam, launch flags and the fake

**Files:**
- Create: `Packages/FilingCabinetKit/Sources/Core/Lock/DeviceAuthenticating.swift`
- Create: `Packages/FilingCabinetKit/Sources/Core/Launch/AuthenticatorFlag.swift`
- Modify: `Packages/FilingCabinetKit/Sources/Core/Launch/LaunchOptions.swift`
- Create: `Packages/FilingCabinetKit/Sources/TestSupport/FakeAuthenticator.swift`
- Test: `Packages/FilingCabinetKit/Tests/CoreTests/LaunchOptionsTests.swift`

**Interfaces:**
- Produces:
  ```swift
  /// Asks iOS whether the person holding the phone is its owner.
  public protocol DeviceAuthenticating: Sendable {
      func availability() -> AuthenticationAvailability
      /// Face ID first; the passcode when Face ID isn't working. `reason` is the line iOS shows.
      func authenticate(reason: String) async -> AuthenticationResult
  }
  public enum AuthenticationAvailability: Sendable, Equatable { case biometrics, passcodeOnly, none }
  public enum AuthenticationResult: Sendable, Equatable { case success, cancelled, failed }

  /// `-Authenticator succeeds|succeedsOnce|cancels|fails|passcodeOnly|none`. `succeedsOnce`: the first check
  /// succeeds and every later one is cancelled, so a test can see the library lock again.
  public enum AuthenticatorFlag: String, Sendable, Equatable {
      case succeeds, succeedsOnce, cancels, fails, passcodeOnly, none
  }
  ```
  `LaunchOptions` gains `lockOn: Bool` (`-Lock on`; any other value leaves it false), `authenticator: AuthenticatorFlag?` (`-Authenticator <value>`), `relockSeconds: Int?` (`-LockAfter <n>`, n ≥ 0).
  `FakeAuthenticator` (TestSupport, `package`, a final class safe to share): `init(availability:results:)` where `results` are returned in order and the last repeats; `private(set) var reasons: [String]` records each call; `availability` is settable.

- [ ] **Step 1: Failing tests** in `LaunchOptionsTests`: `-Lock on` → `lockOn == true`; `-Lock off` and `-Lock` alone → false; each `-Authenticator` value parses, an unknown one gives nil; `-LockAfter 2` → 2, `-LockAfter -1` and `-LockAfter x` → nil; all three ignored when `isDebugBuild` is false.
- [ ] **Step 2: Run** `make fast`; expected: the new tests fail to compile.
- [ ] **Step 3: Implement** the protocol, enums, the three `LaunchOptions` fields (`-Authenticator` in `setChoice`, `-Lock` and `-LockAfter` in `setValue`) and `FakeAuthenticator`.
- [ ] **Step 4: Run** `make fast`; expected: PASS.
- [ ] **Step 5: Commit** `Core: the device authentication seam and the lock's launch flags`.

### Task 2: `LibraryLock`, the lock's state and timing

**Files:**
- Modify: `Packages/FilingCabinetKit/Sources/ScreenModels/Settings/AppPreferences.swift` (add `lockOn`, default false, key `lockOn`)
- Create: `Packages/FilingCabinetKit/Sources/ScreenModels/Lock/LibraryLock.swift`
- Test: `Packages/FilingCabinetKit/Tests/ScreenModelsTests/LibraryLockTests.swift`

**Interfaces:**
- Consumes: `DeviceAuthenticating`, `FakeAuthenticator` (Task 1), `AppPreferences`.
- Produces:
  ```swift
  @MainActor @Observable
  public final class LibraryLock {
      public static let relockAfter = Duration.seconds(300)
      /// The cover is up. False whenever the lock is off or paused.
      public private(set) var isLocked = false
      /// The cover shows its Unlock button: the last try was cancelled or failed.
      public private(set) var showsUnlock = false
      /// Bumped each time a try ends cancelled or failed (the root drops a waiting request).
      public private(set) var refusals = 0
      /// The person's wish is on and the phone can check (Face ID or a passcode).
      public var isOn: Bool { get }
      /// The wish is on but the phone has no passcode: the library opens.
      public var isPaused: Bool { get }
      /// What the phone can check now, for Settings.
      public var availability: AuthenticationAvailability { get }

      public init(preferences: AppPreferences, authenticator: any DeviceAuthenticating,
                  now: @escaping @MainActor () -> ContinuousClock.Instant = { .now },
                  relockAfter: Duration = LibraryLock.relockAfter)

      /// At launch, before the first frame: locks when on.
      public func launched()
      /// The scene went to `.background`.
      public func leftForeground()
      /// The scene became `.active`: locks when it was away `relockAfter` or longer, then tries Face ID once per
      /// arrival (launch, or back from the background). A try already running or already made is not repeated.
      public func becameActive() async
      /// The Unlock button.
      public func unlock() async
      /// The Settings switch. Both directions check the owner first, except turning off while paused.
      /// Returns whether the setting changed.
      package func setOn(_ isOn: Bool) async -> Bool
  }
  ```
  Reason string (one, localized in ScreenModels): "Unlock your library". Turning on: after a successful check the library stays open (no cover) and `lockOn` is true.

- [ ] **Step 1: Failing tests** (`LibraryLockTests`, a movable `ContinuousClock.Instant` and `FakeAuthenticator`):
  - off: `launched()` then `becameActive()` → not locked, no authenticate call.
  - on: `launched()` → `isLocked`, `showsUnlock == false`; `becameActive()` with `.success` → unlocked.
  - cancel: result `.cancelled` → still locked, `showsUnlock == true`, `refusals == 1`; a second `becameActive()` (the prompt's own return) makes **no** second call (Review Focus 1); `unlock()` with `.success` → unlocked, `showsUnlock == false`.
  - `.failed` behaves as cancel.
  - a second `becameActive()` while the first is still awaiting makes no second call.
  - relock: unlocked, `leftForeground()`, clock +299 s, `becameActive()` → open, no call; +300 s → locked and one call (Review Focus 3).
  - locked with the button showing, `leftForeground()` then `becameActive()` → tries again (a new arrival).
  - never left: `becameActive()` twice while unlocked never locks.
  - paused: preference on, availability `.none` → `launched()` leaves it open, `isPaused == true`, `isOn == false`; availability back to `.passcodeOnly`, `leftForeground()`, `becameActive()` after 300 s → locked (Review Focus 5).
  - `.passcodeOnly`: locks and unlocks as biometrics.
  - `setOn(true)`: `.success` → preference true, returns true, not locked; `.cancelled` → preference false, returns false; availability `.none` → returns false, no call.
  - `setOn(false)`: `.success` → preference false, unlocked; `.cancelled` → stays on, returns false; while paused → off with no call.
- [ ] **Step 2: Run** `make fast`; expected: FAIL (no such type).
- [ ] **Step 3: Implement** `lockOn` and `LibraryLock`.
- [ ] **Step 4: Run** `make fast`; expected: PASS.
- [ ] **Step 5: Commit** `ScreenModels: LibraryLock, the library lock's state and timing`.

### Task 3: Requests from outside while locked

**Files:**
- Modify: `Packages/FilingCabinetKit/Sources/ScreenModels/App/RequestRouting.swift`
- Test: `Packages/FilingCabinetKit/Tests/ScreenModelsTests/ExternalRequestRoutingTests.swift`

**Interfaces:**
- Produces: `RootState` gains `isLocked: Bool` (init parameter after `welcomeFinished`). `RequestRouting.action`: right after the welcome guard, `if state.isLocked, request != .scan { return .wait }`. `.scan` is routed exactly as today.

- [ ] **Step 1: Failing tests**: locked + `.search("x")` → `.wait`; locked + `.open(id)` → `.wait` (even for a scan that has gone); locked + `.scan` from Home → `.startScan`; locked + `.scan` with a screen pushed → `.popToHome`; locked + `.scan` during a review → `.showReview`; not locked → every existing expectation unchanged (existing tests pass `isLocked: false`).
- [ ] **Step 2: Run** `make fast`; expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `make fast`; expected: PASS.
- [ ] **Step 5: Commit** `Requests: search and open wait while the library is locked; scan never does`.

### Task 4: Spotlight and cleanup notes follow the lock

**Files:**
- Modify: `Packages/FilingCabinetKit/Sources/ScreenModels/Spotlight/SpotlightSync.swift`
- Modify: `Packages/FilingCabinetKit/Sources/ScreenModels/Cleanup/CleanupNotices.swift`, `CleanupNotifier.swift`
- Modify: `Packages/FilingCabinetKit/Sources/ScreenModels/Localizable.xcstrings`
- Test: `SpotlightSyncTests.swift`, `CleanupNoticesTests.swift` (and the notifier's tests, where they live)

**Interfaces:**
- Consumes: `AppPreferences.lockOn` (Task 2).
- Produces:
  - `SpotlightSync`: `run()`'s `Observations` also reads `preferences.lockOn`; `wantedItems()` is empty while `lockOn` is true. It follows the preference, not `LibraryLock.isOn` (a paused lock still keeps scans out of Spotlight).
  - `CleanupNotices.plan(…, namesScans: Bool = true)`. With `namesScans == false` the text never contains a title: one scan → title "Cleaned up 1 scan", body "An expired scan moved to Trash. It’s there for \(days) days if you need it."; more → today's count form ("Cleaned up \(count) scans" · "Expired scans moved to Trash. They’re there for \(days) days if you need one back.").
  - `CleanupNotifier`: observes `preferences.lockOn` and passes `namesScans: !preferences.lockOn`.

- [ ] **Step 1: Failing tests**:
  - Spotlight: three scans indexed, `lockOn = true` → the fake index holds none; `lockOn = false` → all three back with thumbnails; lock on with `remove` failing once → still recorded as indexed, and `syncAgain()` removes them (Review Focus 4); a scan saved while the lock is on is not indexed.
  - Notices: `namesScans: false` with 1, 2 and 4 scans → no notice's title or body contains any scan title, and the texts above; `namesScans: true` → today's texts unchanged.
  - Notifier: flipping `lockOn` replaces the pending notes with the count form and back.
- [ ] **Step 2: Run** `make fast`; expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `make fast`; expected: PASS.
- [ ] **Step 5: Commit** `Lock: no scans in Spotlight and no titles in cleanup notes while it is on`.

### Task 5: The Settings row's model and its analytics event

**Files:**
- Create: `Packages/FilingCabinetKit/Sources/ScreenModels/Settings/LockRow.swift`
- Modify: `Packages/FilingCabinetKit/Sources/ScreenModels/Settings/SettingsModel.swift`, `Localizable.xcstrings`
- Modify: `Packages/FilingCabinetKit/Sources/Core/Analytics/AnalyticsEvent.swift` (and the signal mapping beside it)
- Test: `Packages/FilingCabinetKit/Tests/ScreenModelsTests/SettingsModelLockTests.swift`, `CoreTests/AnalyticsEventTests.swift`, `AnalyticsSignalTests.swift`

**Interfaces:**
- Consumes: `LibraryLock` (Task 2).
- Produces:
  ```swift
  package struct LockRow: Equatable {
      package let isEnabled: Bool   // false with no passcode and the wish off
      package let isOn: Bool        // the wish (`lockOn`), so a paused lock still shows on
      package let subtitle: String
      package let footer: String
  }
  ```
  `SettingsModel.init` gains `lock: LibraryLock` (after `wordsPass`); `package var lockRow: LockRow`; `package func setLock(_ isOn: Bool) async` (calls `lock.setOn`, sends `.lockChanged(isOn:)` only when it changed).
  `AnalyticsEvent.lockChanged(isOn: Bool)`, name `lockChanged`, one parameter `isOn`, mapped like `favoritesChanged`'s flag.
  Copy (exact):
  - title (in Screens, Task 6): "Lock with Face ID"
  - subtitle, normal: "Asks when you open the app"
  - subtitle, no passcode and off (`isEnabled == false`): "Set a passcode in iPhone Settings to use this"
  - subtitle, paused: "Paused · Set a passcode to lock again"
  - footer, off: "Scanning from Control Center and the Action button still works while locked."
  - footer, on (also paused): the off footer, then " Scans are in your iCloud Backup: turn on Advanced Data Protection to encrypt it end to end, and Stolen Device Protection to guard your phone if it’s stolen."

- [ ] **Step 1: Failing tests**: the four row states (off, on, no passcode, paused) give exactly the copy above and the right `isEnabled`/`isOn`; `setLock(true)` with `.success` → row on, one `.lockChanged(isOn: true)`; cancelled → row off, no event; `setLock(false)` cancelled → still on, no event; paused → off without a check, event sent (Review Focus 5). The event's name and parameter in the Core tests.
- [ ] **Step 2: Run** `make fast`; expected: FAIL.
- [ ] **Step 3: Implement**; update every `SettingsModel(` call site (app, tests, previews) with a lock.
- [ ] **Step 4: Run** `make fast`; expected: PASS.
- [ ] **Step 5: Commit** `Settings: the Lock with Face ID row's model and its event`.

### Task 6: The cover, the shield window, the root and the Settings row

**Files:**
- Create: `Packages/FilingCabinetKit/Sources/Screens/Lock/LockCover.swift`
- Create: `Packages/FilingCabinetKit/Sources/Screens/Lock/LockShield.swift` (the window above everything)
- Modify: `Packages/FilingCabinetKit/Sources/Screens/Root/RootView.swift`, `RootDependencies.swift` (add `lock: LibraryLock`)
- Modify: `Packages/FilingCabinetKit/Sources/Screens/Settings/SettingsView.swift`
- Modify: `Packages/FilingCabinetKit/Sources/Screens/Localizable.xcstrings`, `Resources/Tokens.xcassets` or a new asset catalog (the cover's app mark, exported from `design/app-icon/preview`)
- Modify: `Packages/FilingCabinetKit/Sources/Core/` AccessibilityID (add `lock.cover`, `lock.unlock`, `settings.lockSwitch`, following the file's pattern)
- Test: `SnapshotTests/LockCoverSnapshotTests.swift`; re-record the Settings snapshots that gain the row

**Interfaces:**
- Consumes: `LibraryLock`, `LockRow`, `RootState.isLocked`.
- Produces:
  - `LockCover(showsUnlock: Bool, onUnlock: () -> Void)`: mock 1. `bgGrouped` ground, the app mark (76 pt, the icon's own corner shape), "Filing Cabinet" in the serif title style, "Locked" in secondary, and, only when `showsUnlock`, a capsule "Unlock" button with the `faceid` symbol. One accessibility container, modal (`accessibilityViewIsModal`), so VoiceOver can't reach what is under it.
  - `LockShield`: a `UIWindow` in the app's scene, above the app's own window and its sheets, hosting `LockCover`. It is visible when **(a)** `lock.isLocked` and the capture layer is not up, or **(b)** `lock.isOn` and the scene is not `.active` (the app switcher's snapshot, even inside the 5 minutes). Hidden otherwise. Its appearance follows Settings › Appearance like the root.
  - `RootView`: an overlay of `LockCover(showsUnlock: false, …)` directly over the `NavigationStack` while `lock.isLocked` (what shows under the clear capture layer: Review Focus 2), with the stack `accessibilityHidden`. `RootState` gets `isLocked: dependencies.lock.isLocked`; `RequestMoment` gains `isLocked`. `.onChange(of: lock.refusals)`: a pending request that isn't `.scan` is taken and dropped. The rating prompt is not asked while locked.
  - `SettingsView`: a new group between the Apple Intelligence/Notifications group (and its footer) and the feedback group: a row with title "Lock with Face ID", `lockRow.subtitle`, a switch bound to `lockRow.isOn` (disabled and dimmed when `!isEnabled`, as the Apple Intelligence row does) calling `await model.setLock`, and `lockRow.footer` under the group in the existing footer style. Mock 2.

- [ ] **Step 1: Snapshot tests first** (`LockCoverSnapshotTests`): the cover without and with the button, light and dark, and with the button at the largest text size. Run `make full ONLY="FilingCabinetSnapshotTests/LockCoverSnapshotTests"`; expected: FAIL (no view).
- [ ] **Step 2: Implement** `LockCover`, the mark asset and the identifiers; record with `make snapshots-record ONLY=LockCoverSnapshotTests`; open each image and `make compare` against the mock page's phones (list the paths in the hand-off).
- [ ] **Step 3: Implement** `LockShield` and the `RootView` changes. Every `RootDependencies(` call site gets a lock (off, with a fake authenticator, in previews and snapshot fixtures).
- [ ] **Step 4: Implement** the Settings group; re-record the Settings snapshot references that change and name each in the commit with the reason ("Settings gains the Lock with Face ID group").
- [ ] **Step 5: Run** `make build`, `make fast`, `make affected`; expected: PASS (the identifier coverage test may need the three new identifiers exercised: Task 7's journeys do that, so run it there if it fails here only for that reason, and say so).
- [ ] **Step 6: Commit** `Screens: the lock cover, its shield window and the Settings row`.

### Task 7: The system authenticator, app wiring and the journeys

**Files:**
- Create: `App/SystemAuthenticator.swift`
- Modify: `App/AppEnvironment.swift` (and its extensions), `App/FilingCabinetApp.swift`, `App/Info.plist` (`NSFaceIDUsageDescription`: "Filing Cabinet uses Face ID to unlock your library.")
- Create: `UITests/LockJourneyTests.swift`
- Modify: `scripts/test-map.txt`, `AGENTS.md` (launch flags table, map)

**Interfaces:**
- Consumes: everything above.
- Produces:
  - `SystemAuthenticator: DeviceAuthenticating` (LocalAuthentication). A fresh `LAContext` per call. `availability()`: `.biometrics` when `.deviceOwnerAuthenticationWithBiometrics` can be evaluated, else `.passcodeOnly` when `.deviceOwnerAuthentication` can, else `.none`. `authenticate` evaluates `.deviceOwnerAuthentication` (Face ID, then iOS's own passcode fallback): success → `.success`; `userCancel`, `systemCancel`, `appCancel` → `.cancelled`; anything else → `.failed`, logged with `os.Logger` (no personal data).
  - `AppEnvironment`: builds one `LibraryLock` (the system authenticator, or `FakeAuthenticator` from `-Authenticator` under `#if DEBUG`; `-LockAfter` overrides `relockAfter`; `-Lock on` sets `preferences.lockOn` for the run; under `-UITest` the lock is off unless `-Lock on`), passes it to `RootDependencies` and `SettingsModel`, and calls `lock.launched()` when it is made, before any view.
  - `FilingCabinetApp`: on `.active`, `Task { await environment.lock.becameActive() }`; on `.background`, `environment.lock.leftForeground()`. `.inactive` does neither.
  - Flags documented in AGENTS.md: `-Lock on`, `-Authenticator succeeds|succeedsOnce|cancels|fails|passcodeOnly|none`, `-LockAfter <seconds>`.

- [ ] **Step 1: UI tests first** (`LockJourneyTests`, launched with `-UITest -SeedScans 3`):
  1. `-Lock on -Authenticator succeeds`: Home shows, no cover.
  2. `-Lock on -Authenticator cancels`: the cover and Unlock show; no Home tile exists in the accessibility tree; tapping Unlock (still cancels) keeps the cover.
  3. `-Lock on -Authenticator cancels -Request scan -FakeCamera 1 -FakeReader`: the camera/review shows with no Face ID; Save → the cover is back and the new scan's tile is not reachable (Review Focus 2); the same with Discard.
  4. `-Lock on -Authenticator cancels -Request search:pharmacy`: the cover shows; Search never opens.
  5. `-Lock on -Authenticator succeedsOnce -LockAfter 1`: Home shows; press Home on the device, wait 2 s, reactivate → the cover with Unlock shows and no tile is reachable. The same with `-LockAfter 300` → Home is still there (no cover).
  6. Settings: with `-Authenticator succeeds`, turn the switch on (subtitle and long footer show), off again; with `-Authenticator none`, the switch is disabled with "Set a passcode in iPhone Settings to use this".
  7. Accessibility audit of the cover with the button, and of Settings with the row, at default and largest text, like the other journeys' audits.
  Run `make full ONLY="FilingCabinetUITests/LockJourneyTests"`; expected: FAIL.
- [ ] **Step 2: Implement** `SystemAuthenticator`, the wiring, the plist line, the test-map rows (`Screens/Lock/` and `ScreenModels/Lock/` → `LockJourneyTests LockCoverSnapshotTests`; `App/` rules as the file already treats app wiring) and the AGENTS.md rows.
- [ ] **Step 3: Run** `make build`, `make fast`, `make retest`/`make full ONLY="FilingCabinetUITests/LockJourneyTests"`, then `make affected`; expected: PASS. `make unused` clean.
- [ ] **Step 4: Commit** `App: Face ID through LocalAuthentication, the lock wired in, and its journeys`.

### Task 8: Privacy policy, docs and the PR

**Files:**
- Modify: `site/privacy` (the policy page), `CLAUDE.md` ("Where we are"), `AGENTS.md` (map: `Core/Lock/`, `ScreenModels/Lock/`, `Screens/Lock/`)

- [ ] **Step 1: Privacy policy**: add, in the page's own voice and structure: scans are stored on the iPhone, protected by iOS's encryption with the passcode; they are included in the person's iCloud Backup, which Apple can read unless Advanced Data Protection is on; the optional Face ID lock, what it covers, and that Face ID data never reaches the app (iOS answers yes or no).
- [ ] **Step 2: Docs**: CLAUDE.md's status line (the lock is built on `library-lock`, PR pending) and the three map lines.
- [ ] **Step 3: Rebase** on `origin/main`; `make ci-checks`; `make full ALL=1` once (via `ios-verifier`); expected: PASS.
- [ ] **Step 4: Commit** `Docs: the privacy policy says how scans are stored and backed up; the lock in the map`.
- [ ] **Step 5: PR** to `main`, ready for review, body: what shipped, the evidence, `Closes #26`, `Closes #93`, and Ben's phone check: real Face ID at launch and after 5 minutes; cancel then Unlock; the passcode after failed Face ID; the Control Center Scan control and the Action button while locked (camera with no Face ID, cover after Save); the app switcher inside and after the 5 minutes; a Share sheet left open, then away 5 minutes; Spotlight shows no scans with the lock on and shows them again after turning it off; a cleanup note's text with the lock on. Do not merge.
