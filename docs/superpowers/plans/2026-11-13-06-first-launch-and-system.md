# Plan 6 · First launch and system Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Filing Cabinet becomes ready for other people to hold. A newcomer gets the two welcome screens. When the library can't open, a screen replaces the crash and offers to email a report. Settings gains Send feedback and a Privacy policy link. The rating prompt asks after ten saves. Scanning starts from Control Center, the Lock Screen, the Action button, Shortcuts and Siri, and Spotlight finds scans by title. The app icon is in. Every merge to main reaches Ben's phone through TestFlight, and one button sends a build to friends.

**Architecture:**
- **Requests from outside the app.** A small `ExternalRequests` queue (Core) carries what arrives from outside the app (scan, search for some text, open a scan). The App Intents and the Spotlight tap put requests in. `RootView` takes them out only when nothing is in the way: the welcome must be finished and no review may be open.
- **Intents and the control.** The intents live in a root `Intents/` folder that is compiled into both the app and a new widget extension, `FilingCabinetControls`, which holds the Scan control.
- **Startup.** `AppStartup` (App) either builds the `AppEnvironment` or returns a `LibraryOpenFailure`. The failure screen is a normal SwiftUI screen with a retry.
- **Welcome, rating, feedback and Spotlight.** These are pure, Fast-tested models in ScreenModels and Library, behind seams: `CleanupNotifying` (existing) and a new `SpotlightIndexing`.
- **Builds.** TestFlight runs as a GitHub Actions workflow: `xcodebuild archive` and `-exportArchive` with upload, signed in the cloud with an App Store Connect API key. A Swift script calls the App Store Connect API for the friends group.

**Tech Stack:**
- Swift 6, SwiftUI, SwiftData (unchanged) and Swift Testing.
- AppIntents (`AppIntent`, `AppShortcutsProvider`, `AppDependencyManager`, `supportedModes`).
- WidgetKit (`ControlWidget`, `ControlWidgetButton`).
- CoreSpotlight (`CSSearchableIndex(name:protectionClass:)`, `CSSearchableItem`).
- StoreKit (`RequestReviewAction`), Icon Composer `.icon`.
- XCTest (UI) and swift-snapshot-testing 1.19.7.
- GitHub Actions (`xcode-27` runner, Pages); the App Store Connect API (JWT ES256 via CryptoKit).

**Spec:**
- The design: `docs/superpowers/specs/2026-11-12-first-launch-and-system-design.md`. Ben approved it on 2026-11-13 ("we're good to start now"). Its page: https://claude.ai/artifact/GYD5GE2z17axsxdNJcbbrA.
- The requirements, `docs/superpowers/specs/2026-10-10-filing-cabinet-requirements.html` (First launch, Extras in v1, Settings, App icon), as changed by the design's §12.
- From `design/`: screens 01-01 to 01-09, 10-01, 10-07, 11-05 to 11-08, `prototype/index.html` (first launch) and `app-icon/`.
- The mocks `docs/superpowers/specs/plan6-mocks/settings-and-error.html` (option A) and `error-icon-v2.html` (B1).
- Executors read Plan 5 (`docs/superpowers/plans/2026-11-11-05-apple-intelligence.md`) for the conventions this plan continues.

**Status:** Approved by Ben 2026-11-13 ("looks good"); page https://claude.ai/artifact/BfwBaazjYTxsZa4qcrSmi2.

**Before Task 1 (the controller, once):**
1. Branch `plan-6` off `origin/main` (Plan 5 merged as `c2735a3`).
2. Move the design to `docs/superpowers/specs/2026-11-12-first-launch-and-system-design.md`, the two mocks to `docs/superpowers/specs/plan6-mocks/` and this plan to `docs/superpowers/plans/2026-11-13-06-first-launch-and-system.md`.
3. Re-check the file and line references below against `main` (they were taken from `c2735a3`).
4. Commit "Docs: Plan 6 design and plan". Keep the ledger under `.superpowers/sdd/plan-6/`.
5. Never commit `.claude/`, `skills-lock.json`, `.herdr/` or `.superpowers/`.

---

## Questions for Ben

None block the app work. These five block only the first upload (Task 12). They are in `.superpowers/for-ben.md`, with the exact steps in Task 12:
1. The feedback address.
2. App Store Connect: the app record, an Admin API key and the three GitHub secrets.
3. TestFlight groups and the Beta App Information.
4. GitHub Pages switched on.
5. OK to close #55.

Until the address exists, `FeedbackAddress.value` is a placeholder that fails a Release build (Task 3).

---

## Decisions

### Agreed with Ben

| # | Decision | Where it lands |
|---|---|---|
| A1 | **Who it's for: Ben first, then friends and family.** "It's just going to be me at first ... maybe like friends and family as well." | whole plan |
| A2 | **The document lock (#26) is not in this plan.** It is needed before the App Store, not before TestFlight. | out of scope |
| A3 | **A screen instead of a crash, with a report.** "I would hate to see an app just crash and with no notice ... I would actually want them to send a bug report." | 4 |
| A4 | **The error icon is a thin red X in a pale red circle.** "I think B1". | 4 |
| A5 | **Send feedback is an email to a dedicated address.** "I'm hoping it's just an email to me ... Maybe I'll create an email specifically for this app." | 3 |
| A6 | **A privacy policy, hosted on GitHub Pages, linked from Settings as a row under Send feedback.** "privacy policy, yeah, we'll definitely need"; "Definitely option A". No terms of service: "I'm fine to skip terms of service." | 3, 11 |
| A7 | **The rating prompt.** "if it's one line we can just ... put it in"; "After ten." | 6 |
| A8 | **Welcome screens are wanted** (01-03, 01-04). | 5 |
| A9 | **No uploads by hand. Every merge to main goes to TestFlight, and a Run-workflow button with "Also send to friends" sends a build to friends.** "I would definitely not want to upload it by hand"; "Yeah, I guess we can do that for now." | 2, 12 |
| A10 | **Spotlight shows titles only and is hidden while the phone is locked.** "let's just keep it for titles"; "yes hide". | 9 |
| A11 | **The design and the calls in it.** Ben approved the design ("we're good to start now"), including its listed calls (M1–M10 below come from it). | whole plan |

### My calls (veto any before its task starts)

| # | Call | Task |
|---|---|---|
| M1 | **Who sees the welcome.** Existing installs see it once too. Under `-UITest` it counts as done unless `-ShowWelcome` is passed, so every existing journey is unchanged. | 5 |
| M2 | **Skipping the notifications screen.** It is skipped when iOS already has an answer (allowed or denied). | 5 |
| M3 | **The failure screen's Try again.** A failed Try again keeps the screen, and VoiceOver hears "Still couldn't open". | 4 |
| M4 | **The pale circle** is `destructive` at 12% opacity, checked for contrast in both themes. | 4 |
| M5 | **The Privacy policy row** uses `hand.raised` and a trailing `arrow.up.right` in the chevron colour. | 3 |
| M6 | **No mail app** (the `mailto:` URL won't open): an alert titled "No mail app" shows the address, with Copy and OK. | 3 |
| M7 | **When the rating prompt asks.** Ten saves on at least three different days (the requirements' rule), at most once per app version. It asks after the capture layer has gone, and never while the welcome or anything else is up. | 6 |
| M8 | **Find a scan by voice.** "Find a scan in Filing Cabinet" has Siri ask "What are you looking for?" (11-07's phrase can't be built). | 8 |
| M9 | **What a request from outside does when something is open.** It closes Details, Search and the viewer, then acts. An open review is brought back instead. A camera already open stays. | 7 |
| M10 | **Version and build numbers.** Version 1.0; the build number is the TestFlight workflow's run number. "What to Test" is the head commit's subject. | 10, 12 |
| M11 | **"Turn on notifications"** awaits iOS's answer, then closes the sheet. If iOS never answers (`-NotificationsUnanswered`), the sheet closes anyway once the app becomes active again after the ask, so a stuck notification service never traps the welcome. | 5 |
| M12 | **What Spotlight shows.** The title as the display name; "Receipts · 3 pages" as the description; page 1's cached thumbnail as `thumbnailData` when it exists, otherwise none. The item identifier is the scan's UUID; the domain is `scans`. | 9 |
| M13 | **Where the intents live.** In a root `Intents/` folder compiled into both the app and the extension. `ExternalRequests` is in Core so both can see it; it is handed to the intents through `AppDependencyManager`. Task 1 confirms or replaces this. | 1, 8 |
| M14 | **Analytics** gain `welcomeFinished(notifications: Bool)`, `libraryOpenFailed`, `feedbackOpened(kind: report\|feedback)`, `ratingRequested` and `scanStarted(source: .outside)`. No content. | 4–8 |
| M15 | **Testing requests from outside.** A Debug launch flag, `-Request scan\|search:<text>\|open:<n>`, queues a request at launch (`open:<n>` is the nth seeded scan), so UI tests can exercise the routing. They can't press a control. | 7 |

### Expected differences from the mocks

- 10-01 has no Privacy policy row (A6).
- 11-07 shows "Find my lease in Filing Cabinet"; the built phrase is "Find a scan in Filing Cabinet", followed by Siri's question (M8). Its Shortcuts tiles show a placeholder folder; ours show the app icon.
- There is no `design/` screen for the library failure; the B1 mock is the source.

---

## Roadmap

| Plan | What you can do when it's merged |
|---|---|
| 0–5 (done) | Scan, review, browse, edit, self-cleaning, viewer, favourites, search, share, Apple Intelligence. |
| **6 · First launch and system (this plan)** | Welcome; feedback and privacy; no silent crash; rating; scan from Control Center, the Lock Screen, Siri and Shortcuts; Spotlight; app icon; TestFlight on every merge. |
| Next | The document lock (#26), before the App Store. |

---

## Global Constraints

- Plans 1–5's Global Constraints still apply. The lines below add to them.
- **Platform and language:** iOS 27.0 minimum, iPhone, portrait, English, no `#available`. Swift 6 with Approachable Concurrency. Banned: `Task.detached` and `@unchecked Sendable`.
- **Mac-buildable modules:** Core, Understanding, Library and ScreenModels never import SwiftUI, UIKit, StoreKit or WidgetKit. AppIntents and CoreSpotlight are allowed there; both exist on macOS.
- **Nothing personal leaves the phone:** no scan title, text, words or image in analytics, logs (`privacy: .private`), feedback emails or the report. Spotlight indexes titles only (A10).
- **The library is never put at risk:** the failure screen never touches, moves or deletes a file. Nothing ever falls back to an empty or in-memory library outside `-UITest`.
- **No prompt in the wrong place:** no notification ask, rating prompt or camera during the welcome, a review, the camera-off sheet or a confirmation.
- **Copy:** localized in the owning module's `Localizable.xcstrings`, with middots and no em dashes. The Scan control's title is "Scan".
- **Debug-only test hooks:** every launch flag is Debug-only (`LaunchOptions` ignores flags in Release). `-FailLibraryOpen`, `-ShowWelcome`, `-Request` and `-RatingDue` are new.
- **Secrets:** `ASC_KEY_ID`, `ASC_ISSUER_ID` and `ASC_KEY_P8` are GitHub secrets only. They are never echoed, written to the repo or put in an artifact. The key file is written to `$RUNNER_TEMP` and deleted in an `always()` step.
- **Run policy (every implementer brief carries this):**
  - Every simulator run uses `SIM_DEVICE="FC iPhone 17"`.
  - A task finishes on `make fast`, `make build`, `make lint`, `make unused`, `make full ONLY="…"` for the classes it lists, and `make affected`.
  - While fixing: `make retest ONLY="…"`, and `make full ALL=1` only once, before the PR.
  - Never run `xcodebuild test` or XcodeBuildMCP's test tools directly.
  - Every new UI or snapshot test class gets a line in `scripts/test-map.txt`, and every new source folder gets its own row; `make test-scripts` checks this.
  - Audit findings come from `make audit-report`. New exemptions need Ben's OK, shown with screenshots.
  - Small visual tweaks use the phone loop (`make device`, Ben confirms).
- **Timebox:** 45–60 minutes per fix round, then revert to the last green commit and report.

## Review Focus

1. **A request from outside that arrives at a bad moment:**
   - Situations: during the welcome, in the middle of a review, on the camera-off sheet, with Search or Details open, on the failure screen, or two quick taps of the control.
   - Expected: the welcome finishes first; a review comes back rather than starting a new camera; one tap, one camera; the failure screen ignores it.
   - Tests: Task 7 `ExternalRequestRoutingTests` (`waitsForTheWelcome`, `reviewOpenBringsItBack`, `searchReplacesTheQuery`), `ExternalRequestsTests.twoScansMakeOneCamera`, `OutsideJourneyTests.testScanRequestDuringWelcomeOpensCameraAfter`, `LibraryFailureJourneyTests.testRequestIsIgnored`.
2. **Spotlight drifting from the library:**
   - Situations: rename, move, Trash, Restore, Delete now, Empty Trash and the launch purge; a scan saved while the index call fails; an update that changes what's indexed.
   - Expected: the index always matches the library's non-Trash scans after the next sync.
   - Tests: Task 9 `SpotlightSyncTests` (`renameUpdatesTheItem`, `trashRemovesAndRestoreAddsBack`, `purgeRemoves`, `failedCallIsRetriedNextSync`, `versionBumpReindexesEverything`).
3. **The rating prompt's edges:**
   - Situations: the 10th save on the 2nd day, a save that failed, saves across midnight and a time-zone change, a new version, the welcome still up.
   - Expected: it asks only on a successful save once both counts are met, and once per version.
   - Tests: Task 6 `RatingPromptTests` (`tenOnTwoDaysDoesNotAsk`, `tenthSaveOnThirdDayAsks`, `failedSaveDoesNotCount`, `asksOncePerVersion`, `newVersionMayAskAgain`, `dayIsTheCalendarDay`).
4. **The failure screen's loop:**
   - Situations: Try again succeeding (the welcome comes next if not done), Try again failing twice, Send report with no mail app, a failure while a UI test relaunches.
   - Expected: no crash, no empty library, the alert offers the address.
   - Tests: Task 4 `LibraryFailureModelTests` (`retrySucceedsHandsBackTheEnvironment`, `retryFailsAnnounces`, `reportEmailCarriesTheError`); `LibraryFailureJourneyTests.testTryAgainOpensHome`; Task 3 `FeedbackMailTests.noMailAppShowsTheAddress`.
5. **A welcome that is interrupted:**
   - Situations: the app killed on screen 2, iOS's ask never answering, notifications already allowed in iPhone Settings, Dynamic Type at its largest.
   - Expected: it starts again from screen 1, it never traps, screen 2 is skipped, and nothing is cut off.
   - Tests: Task 5 `WelcomeModelTests` (`killedOnSecondScreenStartsOver`, `unansweredAskClosesOnReturn`, `answeredSkipsSecondScreen`); `WelcomeSnapshotTests.largestText`.

---

## File Structure

New: a root `Intents/` folder, the `FilingCabinetControls` extension target, a `site/` folder and the workflows. Package dependencies are unchanged.

```
Intents/                                         create (compiled into app + extension, M13)
  ScanDocumentIntent.swift                       "Scan a document" (supportedModes: .foreground)
  FindScanIntent.swift                           "Find a scan" (text parameter, requestValueDialog)
Controls/                                        create: the widget extension
  ControlsBundle.swift, ScanControl.swift, Info.plist
App/
  FilingCabinetApp.swift                         modify: AppStartup, requests, Spotlight tap, rating
  AppStartup.swift                               create: environment or failure, retry
  AppEnvironment.swift                           modify: throws instead of fatalError; Spotlight, rating, welcome
  AppShortcuts.swift                             create: AppShortcutsProvider (app target only)
  AppIcon.icon/                                  create: from design/app-icon/layers
  Info.plist                                     modify: ITSAppUsesNonExemptEncryption NO
Packages/FilingCabinetKit/Sources/
  Core/Requests/ExternalRequest.swift            create: scan, search(String), open(ScanID)
  Core/Requests/ExternalRequests.swift           create: the queue (@MainActor @Observable)
  Core/Launch/LaunchOptions.swift                modify: -FailLibraryOpen [once], -ShowWelcome, -Request, -RatingDue
  Core/Analytics/AnalyticsEvent.swift, ScanEventTokens.swift   modify: M14
  Core/Accessibility/AccessibilityID.swift       modify: Welcome, LibraryFailure, Settings.feedback/privacy
  Library/Spotlight/SpotlightIndexing.swift      create: the seam
  Library/Spotlight/SpotlightItem.swift          create: id, title, description, thumbnail
  Library/Spotlight/CoreSpotlightIndex.swift     create: CSSearchableIndex(name: "scans", protectionClass: .complete)
  ScreenModels/Spotlight/SpotlightSync.swift     create: diff library ↔ index
  ScreenModels/Feedback/FeedbackMail.swift       create: mailto URLs (pure)
  ScreenModels/Feedback/DeviceDetails.swift      create: version, build, iOS, model id
  ScreenModels/Feedback/FeedbackAddress.swift    create: the one constant
  ScreenModels/Feedback/PrivacyPolicy.swift      create: the URL constant
  ScreenModels/Startup/LibraryFailureModel.swift create
  ScreenModels/Welcome/WelcomeModel.swift        create
  ScreenModels/Rating/RatingPrompt.swift         create
  ScreenModels/App/RequestRouting.swift          create: what RootView does with a request (pure)
  ScreenModels/Settings/AppPreferences.swift     modify: welcomeDone, saves, saveDays, ratingAskedVersion
  ScreenModels/Settings/SettingsModel.swift      modify: feedback, privacy
  ScreenModels/Search/SearchModel.swift          modify: init(query:)
  Screens/Welcome/WelcomeSheet.swift, WelcomeScreen.swift, NotificationsAskScreen.swift   create
  Screens/Startup/LibraryFailureView.swift       create
  Screens/Feedback/MailComposer.swift            create: openURL, else the no-mail alert
  Screens/Settings/SettingsView.swift            modify: the feedback group
  Screens/Root/RootView.swift, RootDependencies.swift   modify: welcome, requests, rating, Spotlight open
  TestSupport/FakeSpotlightIndex.swift           create
site/privacy/index.html, site/index.html         create
.github/workflows/testflight.yml, pages.yml      create
scripts/testflight/archive.sh, asc.swift, ExportOptions.plist   create
project.yml                                      modify: Controls target, Intents sources, icon, version 1.0
scripts/test-map.txt                             modify: new rows
```

---

## Tasks

### Task 1: Spike: the Scan control, the shared intents and the icon

**Unit:** Spike (throwaway; nothing merges)

**Files:** Throwaway branch `spike/plan-6` off `plan-6`; deleted afterwards. What lasts: "Decided during execution" rows E1–E3 and a note in `.superpowers/for-ben.md`.

- [ ] **Step 1: The extension.**
  - Add a `FilingCabinetControls` app-extension target (`com.apple.widgetkit-extension`, bundle id `$(APP_BUNDLE_ID).controls`) in `project.yml`, embedded in the app.
  - Add one `ControlWidgetButton` running a `ScanDocumentIntent` with `static let supportedModes: IntentModes = .foreground`, whose `perform()` appends `.scan` to an `ExternalRequests` obtained through `@Dependency`. The app registers it with `AppDependencyManager.shared.add(dependency:)` in `FilingCabinetApp.init`.
  - Put the intent file in `Intents/`, listed in both targets' sources.
- [ ] **Step 2: On Ben's phone** (`make device`):
  - Add the control in Control Center and on the Lock Screen, then assign it to the Action button.
  - Each one should unlock if needed, open the app and show the camera (a temporary `RootView` hook is fine).
  - Record: does `perform` run in the app process? Does the extension's copy compile without ScreenModels? Does a cold launch work as well as a warm one?
- [ ] **Step 3: If Step 2 fails,** try the documented alternatives in order:
  1. the intent in a package module (`Intents` product) that both targets link, with `AppIntentsPackage`;
  2. `OpenIntent`;
  3. an `openAppWhenRun`-free `ForegroundContinuableIntent`.

  Take the first that works.
- [ ] **Step 4: The icon.**
  - Assemble `App/AppIcon.icon` from `design/app-icon/layers`: `icon.json` and `Assets/`, background per appearance, then corners light/dark, then the folder. Hand-write `icon.json` in the format Xcode 27's Icon Composer writes; open it with `xcrun actool` to confirm.
  - Set `ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon` and check it on the Home Screen in light, dark and tinted.
  - If `actool` rejects it, stop: Ben makes it in Icon Composer (a few minutes), and Task 10 waits for his file.
- [ ] **Step 5: Stop for Ben.** Write E1 (where the intents live), E2 (cold-launch behaviour) and E3 (icon: made by hand or needs Ben) into `.superpowers/for-ben.md` with a one-line recommendation each, and wait. Timebox: 3 hours.

### Task 2: Spike: CI signing with only the API key

**Unit:** Spike (needs Ben's setup items 2–3; it runs as soon as they exist, in parallel with Tasks 3–9)

**Files:** Throwaway branch `spike/testflight`; a `workflow_dispatch`-only copy of Task 12's workflow. What lasts: row E4.

- [ ] **Step 1:** On `xcode-27`:
  - Write `ASC_KEY_P8` to `$RUNNER_TEMP/AuthKey.p8` and run `xcodebuild archive -scheme FilingCabinet -configuration Release -destination 'generic/platform=iOS' -allowProvisioningUpdates -authenticationKeyPath … -authenticationKeyID … -authenticationKeyIssuerID … CURRENT_PROJECT_VERSION=$GITHUB_RUN_NUMBER`.
  - Then run `-exportArchive` with `ExportOptions.plist` (`method app-store-connect`, `destination upload`, `signingStyle automatic`, `manageAppVersionAndBuildNumber false`).
- [ ] **Step 2:** Confirm:
  - the build appears in App Store Connect and processes;
  - the extension was signed and registered;
  - nothing secret is in the logs (search them for the key id's middle and for `BEGIN PRIVATE`).
- [ ] **Step 3: If cloud signing fails,** stop for Ben with the fallback: a distribution certificate (`.p12` and password) and an App Store profile per target, as secrets imported into a temporary keychain. Nothing in Task 12 starts until he answers. Timebox: 2 hours.

### Task 3: Send feedback and the Privacy policy row

**Unit:** ScreenModels + Screens

**Files:**
- Create: `ScreenModels/Feedback/FeedbackMail.swift`, `DeviceDetails.swift`, `FeedbackAddress.swift`, `PrivacyPolicy.swift`, `Screens/Feedback/MailComposer.swift`, `Tests/ScreenModelsTests/FeedbackMailTests.swift`
- Modify: `SettingsModel.swift`, `SettingsView.swift` (and its doc comment), `AccessibilityID.swift` (`Settings.feedback`, `Settings.privacy`, `Feedback.noMailAlert`, `Feedback.copy`), both `Localizable.xcstrings`, `AnalyticsEvent.swift` (`feedbackOpened(kind:)`, M14)
- Test: `SettingsSnapshotTests` (10-01 and 10-07 with the new group), `SettingsJourneyTests`

**Interfaces:**
- Produces:
  - `package struct DeviceDetails: Equatable, Sendable { let version: String; let build: String; let system: String; let model: String; static func current(bundle: Bundle = .main) -> DeviceDetails }`
    - `system` is "iOS 27.2", from `ProcessInfo.operatingSystemVersion`.
    - `model` is the `utsname.machine` identifier, e.g. "iPhone17,3".
  - `package var detailsLine: String` → `"Filing Cabinet 1.0 (14) · iOS 27.2 · iPhone17,3"`.
  - `package enum FeedbackMail { static func feedback(_ d: DeviceDetails) -> URL; static func report(_ d: DeviceDetails, error: any Error) -> URL }`
    - Subjects: "Filing Cabinet feedback" and "Filing Cabinet · library couldn't open".
    - The body is `"\n\n · · · \n" + detailsLine`; the report adds `"\nError: <domain> <code> · <localizedDescription>"`.
    - Percent-encoded with `URLComponents`.
  - `package enum FeedbackAddress { static let placeholder = "feedback@example.invalid"; static let value: String }` (`value` is the placeholder until Ben's address).
  - `package enum PrivacyPolicy { static let url = URL(string: "https://bgibso4.github.io/filing-cabinet/privacy/")! }`
  - `SettingsModel.feedbackURL: URL` and `SettingsModel.privacyURL: URL`.
  - `struct MailComposer: ViewModifier` (`.mailComposer(url: Binding<URL?>, address:)`) opens the URL with `openURL`. When `openURL`'s completion reports `false`, it shows the M6 alert: "No mail app"; message "Send your note to \(address)"; buttons Copy (`UIPasteboard`) and OK.

- [ ] **Step 1: Failing tests.**
  - `FeedbackMailTests`: `feedbackHasSubjectAndDetails`, `reportAddsTheErrorLine`, `bodyLeavesRoomAtTheTop` (starts with two newlines), `encodesSpacesAndMiddots`, `noScanContentEver` (built from a `DeviceDetails` and an error only: assert the URL has no other inputs), `noMailAppShowsTheAddress` (on the alert's model text).
  - `DeviceDetailsTests.detailsLineUsesMiddots`.
- [ ] **Step 2: Implement.**
  - Settings: the new group under the Apple Intelligence and Notifications group, as mock A, with the M5 symbols. Send feedback is first: `envelope`, `DisclosureChevron`. Privacy policy follows with a separator: `hand.raised`, `arrow.up.right` in `Tokens.Color.chevron`, opened with `openURL`.
  - The rows are Buttons with `.accessibilityAddTraits(.isLink)` for the policy.
  - Release safety: `FeedbackAddress.placeholder` is a named constant, and Task 12's `archive.sh` refuses to upload while `value == placeholder`.
- [ ] **Step 3: Snapshots:** `SettingsSnapshotTests` light, dark and largest text (re-record; name each reference in the commit: "Settings: feedback and privacy rows (Plan 6 A5, A6)"). Open each and run `make compare SCREEN=10-01-settings REF=…`.
- [ ] **Step 4: Journey:** `SettingsJourneyTests.testFeedbackRowsArePresentAndReachable` (both rows hittable, audited). Opening Mail is not driven: the simulator has no Mail.
- [ ] **Step 5: Run** `make fast`, `make full ONLY="SnapshotTests/SettingsSnapshotTests UITests/SettingsJourneyTests"`, `make affected`. **Commit** "Settings: Send feedback and the privacy policy".

### Task 4: When the library can't open (#40)

**Unit:** App + ScreenModels + Screens

**Files:**
- Create: `App/AppStartup.swift`, `ScreenModels/Startup/LibraryFailureModel.swift`, `Screens/Startup/LibraryFailureView.swift`, `UITests/LibraryFailureJourneyTests.swift`, `SnapshotTests/LibraryFailureSnapshotTests.swift`, `Tests/ScreenModelsTests/LibraryFailureModelTests.swift`
- Modify: `App/AppEnvironment.swift`: `libraryLocation` and `makeStore` throw `LibraryOpenFailure` instead of `fatalError`; the UI-test preferences `fatalError` stays. Also modify `App/FilingCabinetApp.swift`, `LaunchOptions.swift` (`-FailLibraryOpen` with an optional `once`), `AnalyticsEvent.swift` (`libraryOpenFailed`), `AccessibilityID.swift` (`LibraryFailure.sendReport`, `.tryAgain`, `.title`), the strings files and `scripts/test-map.txt`.

**Interfaces:**
- Consumes: `FeedbackMail.report`, `DeviceDetails.current()`, `.mailComposer` (Task 3).
- Produces:
  - `struct LibraryOpenFailure: Error { let underlying: any Error }` (App).
  - `AppEnvironment.make(arguments:) throws(LibraryOpenFailure) -> AppEnvironment`.
  - `@MainActor @Observable final class AppStartup { enum State { case ready(AppEnvironment), failed(LibraryFailureModel) }; private(set) var state: State; init(arguments: [String]) }`, which retries through the model.
  - `@MainActor @Observable public final class LibraryFailureModel { init(error: any Error, details: DeviceDetails, retry: @escaping () -> Bool); var reportURL: URL; func tryAgain(); private(set) var announcement: String? }`
    - `tryAgain()` calls `retry`; on `false` it sets the announcement to "Still couldn't open" (M3).
  - `LaunchOptions.failLibraryOpen: FailLibraryOpen?` (`.always`, `.once`). Under it, `makeStore` throws a synthetic `CocoaError(.fileReadCorruptFile)` on the first call (`.once`) or on every call.

- [ ] **Step 1: Failing tests.**
  - `LibraryFailureModelTests`: `retrySucceedsHandsBackTheEnvironment` (the retry closure is called once and no announcement is made), `retryFailsAnnounces`, `reportEmailCarriesTheError`.
  - `LaunchOptionsTests.parsesFailLibraryOpen` (bare is `.always`, `once` is `.once`, ignored in Release).
- [ ] **Step 2: Implement.**
  - The view follows the B1 mock in the welcome's layout family: a 64 pt well (a circle of `destructive` at 12% (M4), with an `xmark` symbol at weight `.light` in `destructive`), the New York title, the secondary body, `PillButton` "Send report", then a text button "Try again".
  - Copy is exactly the design's §5. The constants cite `error-icon-v2.html`. Announce with `AccessibilityNotification.Announcement`.
  - Never `.task`-retry automatically.
  - `FilingCabinetApp` switches on `startup.state`. The failure screen never shows `RootView`, and requests from outside are dropped while failed (Task 7 makes them wait on `ready`).
  - Log `.fault` with the error `privacy: .private`, as today.
- [ ] **Step 3: Snapshots:** light, dark, largest text. Open them; check the X's contrast against the well with `make audit-report` (the journey's audit).
- [ ] **Step 4: Journeys** (`-FailLibraryOpen`, `fresh: true`):
  - `testShowsTheScreenNotHome`, `testTryAgainStaysWhenStillFailing`;
  - `testTryAgainOpensHome` (`-FailLibraryOpen once`);
  - an audit at the default and largest text.
  - Add the class and `Screens/Startup/` and `ScreenModels/Startup/` rows to `scripts/test-map.txt`.
- [ ] **Step 5: Run** `make fast`, `make build`, `make full ONLY="SnapshotTests/LibraryFailureSnapshotTests UITests/LibraryFailureJourneyTests"`, `make affected`. **Commit** "App: a screen instead of a crash when the library can't open (#40)".

### Task 5: The welcome

**Unit:** ScreenModels + Screens + App

**Files:**
- Create: `ScreenModels/Welcome/WelcomeModel.swift`, `Screens/Welcome/WelcomeSheet.swift`, `WelcomeScreen.swift`, `NotificationsAskScreen.swift`, `Tests/ScreenModelsTests/WelcomeModelTests.swift`, `SnapshotTests/WelcomeSnapshotTests.swift`, `UITests/WelcomeJourneyTests.swift`
- Modify: `AppPreferences.swift` (`welcomeDone: Bool`, default false), `LaunchOptions.swift` (`-ShowWelcome`), `AppEnvironment.swift` (under `-UITest`, `welcomeDone` is true unless `-ShowWelcome`, per M1), `RootDependencies.swift`, `RootView.swift`, `AnalyticsEvent.swift` (`welcomeFinished`), `AccessibilityID.swift` (`Welcome.continue`, `.turnOn`, `.notNow`), the strings files and `scripts/test-map.txt`.

**Interfaces:**
- Consumes: `CleanupNotifying` (existing), `AppPreferences`.
- Produces:
  - `@MainActor @Observable public final class WelcomeModel { enum Step { welcome, notifications }; private(set) var step: Step?; init(preferences:, notifications:, analytics:); func start() async; func continueTapped() async; func turnOnTapped() async; func notNowTapped(); func becameActive() }`
    - `step == nil` means finished, or never needed.
    - `start()` sets `.welcome` when `!welcomeDone`.
    - `continueTapped()` reads the authorization: `.notDetermined` → `.notifications`; anything else → finish (M2).
    - `turnOnTapped()` requests, then finishes; `becameActive()` after a request that hasn't returned also finishes (M11).
    - Finishing sets `welcomeDone = true`, sends `welcomeFinished(notifications:)` and makes `step` nil.
  - `WelcomeModel.isFinished: Bool`, read by Tasks 6 and 7.

- [ ] **Step 1: Failing tests.** `WelcomeModelTests`:
  - `freshInstallStartsOnWelcome`, `doneNeverShows`, `continueGoesToNotifications`, `answeredSkipsSecondScreen` (`.authorized` and `.denied`);
  - `turnOnAsksThenFinishes` (`requestCount == 1`), `notNowFinishesWithoutAsking`;
  - `unansweredAskClosesOnReturn` (a request that never returns, then `becameActive()`);
  - `killedOnSecondScreenStartsOver` (a new model on the same defaults starts at `.welcome`);
  - `analyticsSayWhetherNotificationsWereAllowed`.
- [ ] **Step 2: Implement the screens** from 01-03, 01-04, 01-07 and 01-08 and the prototype's first-launch flow:
  - A `.sheet` over Home, `.interactiveDismissDisabled()`, large detent only. Inside, a push from welcome to notifications as in the prototype; Reduce Motion fades.
  - Welcome: the New York title "Welcome to\nFiling Cabinet", then four rows. Symbols per 01-03: `text.viewfinder`, `folder`, `clock`, `lock`. Copy exactly as 01-03. Then the `PillButton` "Continue".
  - Notifications: the `bell` well, "Know when\nit cleans up", the body, the sample note card ("Cleaned up 3 receipts" / "They're in Trash for 30 days if you need them.", with the app's folder glyph), "At most one a day", "Turn on notifications", "Not now".
  - Constants cite the components in `design/components/`.
- [ ] **Step 3: Snapshots:** `welcome`, `welcomeDark`, `notifications`, `notificationsDark`, `largestText` (both screens). Open each; `make compare` against 01-03, 01-04, 01-07 and 01-08.
- [ ] **Step 4: Journeys** (`-ShowWelcome`):
  - `testContinueThenNotNowLandsOnEmptyHome` (01-06);
  - `testTurnOnAsksIOS` (`-Notifications notDetermined`; the fake answers);
  - `testAlreadyAllowedSkipsTheAsk` (`-Notifications authorized`);
  - `testWelcomeCannotBeSwipedAway`;
  - audits on both screens at the default and largest text.
  - Existing journeys must pass unchanged (M1): `make affected`.
- [ ] **Step 5: Run** `make fast`, `make full ONLY="SnapshotTests/WelcomeSnapshotTests UITests/WelcomeJourneyTests"`, `make affected`. **Commit** "First launch: the welcome and the notifications ask".

### Task 6: The rating prompt

**Unit:** ScreenModels + Screens

**Files:**
- Create: `ScreenModels/Rating/RatingPrompt.swift`, `Tests/ScreenModelsTests/RatingPromptTests.swift`
- Modify: `AppPreferences.swift` (`savesCount: Int`, `saveDays: [Int]` (`CalendarDay.storageValue`, kept to the 3 most recent distinct), `ratingAskedVersion: String?`), `ScanFlowModel.swift` (`init` gains `scanSaved: @escaping () -> Void = {}`, called in `reviewEnded(saved:)` when `saved != nil`; `AppEnvironment` passes `{ rating.recordSave(on: today.day) }`), `RootView.swift`, `RootDependencies.swift`, `LaunchOptions.swift` (`-RatingDue`: seeds the counts at 9 saves on 3 days), `AnalyticsEvent.swift` (`ratingRequested`), `AppEnvironment.swift`

**Interfaces:**
- Consumes: `WelcomeModel.isFinished` (Task 5), `ScanFlowModel.phase`, `reviewEnded(saved:)`.
- Produces: `@MainActor @Observable public final class RatingPrompt { init(preferences:, version: String, analytics:); func recordSave(on day: CalendarDay); private(set) var isDue: Bool; func asked() }`
  - Due when `savesCount >= 10 && Set(saveDays).count >= 3 && ratingAskedVersion != version`.
  - `asked()` stores the version, clears `isDue` and sends `ratingRequested`.

- [ ] **Step 1: Failing tests.** `RatingPromptTests`:
  - `nineSavesDoesNotAsk`, `tenOnTwoDaysDoesNotAsk`, `tenthSaveOnThirdDayAsks`;
  - `failedSaveDoesNotCount` (via `ScanFlowModel` with a failing library: `reviewEnded(saved: nil)`);
  - `asksOncePerVersion`, `newVersionMayAskAgain`;
  - `dayIsTheCalendarDay` (two saves at 23:59 and 00:01 count as two days, with the app clock's calendar).
- [ ] **Step 2: Implement.** In `RootView`:
  - `.onChange(of: flow.phase)`: when it becomes `.idle`, the rating is due, the welcome is finished and no sheet is up, call `@Environment(\.requestReview)`, then `rating.asked()`.
  - It must run after the layer's slide (the same moment as the save haptic).
  - Nothing is shown in tests: `requestReview` is a no-op in the simulator's test runs. The model is the test.
- [ ] **Step 3: Journey:** `ScanJourneyTests.testRatingDueDoesNotDisturbTheSave` (`-RatingDue -FakeCamera 1`): save; Home shows the new count; no crash. The prompt itself can't be asserted (Apple's).
- [ ] **Step 4: Run** `make fast`, `make affected`. **Commit** "Rating: Apple's prompt after ten saves on three days".

### Task 7: Requests from outside the app

**Unit:** Core + ScreenModels + Screens

**Files:**
- Create: `Core/Requests/ExternalRequest.swift`, `ExternalRequests.swift`, `ScreenModels/App/RequestRouting.swift`, `Tests/CoreTests/ExternalRequestsTests.swift`, `Tests/ScreenModelsTests/ExternalRequestRoutingTests.swift`, `UITests/OutsideJourneyTests.swift`
- Modify: `RootView.swift` (Search and the viewer open from a request), `SearchCover.swift` and `SearchModel.swift` (`initialQuery`), `ScanFlowModel.swift` (`scan(from: .outside, …)`), `ScanEventTokens.swift` (`ScanSource.outside`), `LaunchOptions.swift` (`-Request`), `AppEnvironment.swift`, `scripts/test-map.txt`

**Interfaces:**
- Produces:
  - `public enum ExternalRequest: Equatable, Sendable { case scan; case search(String); case open(ScanID) }`
  - `@MainActor @Observable public final class ExternalRequests { public init(); public func send(_ r: ExternalRequest); public private(set) var pending: ExternalRequest?; public func take() -> ExternalRequest? }`
    - It holds one request; a newer one replaces an older one, except that `.scan` never replaces a pending `.scan`.
  - `package enum RequestRouting { static func action(for: ExternalRequest, state: RootState) -> RootAction }`, where:
    - `RootState` is `{ welcomeFinished: Bool, flowPhase: ScanFlowModel.Phase, isSearching: Bool, pathDepth: Int }`;
    - `RootAction` is `.wait | .startScan | .showReview | .ignore | .search(String, closeOthers: Bool) | .open(ScanID, closeOthers: Bool)` (M9).
  - `SearchModel.init(…, initialQuery: String = "")` runs the search at once when it isn't empty.
- Consumed by: Task 8 (the intents send) and Task 9 (the Spotlight tap sends `.open`).

- [ ] **Step 1: Failing tests.**
  - `ExternalRequestsTests`: `newerReplacesOlder`, `takeEmpties`, `twoScansMakeOneCamera`.
  - `ExternalRequestRoutingTests`: `waitsForTheWelcome`, `reviewOpenBringsItBack` (`.review` → `.showReview`), `cameraOpenIgnoresScan`, `cameraOffSheetIgnoresScan`, `searchReplacesTheQuery`, `openClosesDetailsAndSearch`, and a journey for the failure case: `LibraryFailureJourneyTests.testRequestIsIgnored` (`-FailLibraryOpen -Request scan`: the failure screen stays, no camera).
  - `LaunchOptionsTests.parsesRequest`.
  - `SearchModelTests.initialQueryShowsResults`.
- [ ] **Step 2: Implement.** `RootView` observes `requests.pending` together with `welcome.isFinished` and `flow.phase`, and applies `RequestRouting`:
  - `.startScan` → `flow.scan(from: .outside, preselected: nil)` from Home: pop the path and close Search first.
  - `.search` → open Search with `initialQuery`.
  - `.open` → pop to the root and push `.scan(id)`, but only if the scan is still in the library (otherwise `.ignore`).

  Saving or cancelling an outside scan lands on Home (it was started from the root).
- [ ] **Step 3: Journeys** (`OutsideJourneyTests`):
  - `testScanRequestOpensCamera` (`-Request scan -FakeCamera 1`; save lands on Home);
  - `testScanRequestDuringWelcomeOpensCameraAfter` (`-ShowWelcome -Request scan`);
  - `testSearchRequestShowsResults` (`-SeedScans 5 -Request search:pharmacy`);
  - `testOpenRequestShowsTheViewer` (`-SeedScans 3 -Request open:1`).
  - Add the class to `scripts/test-map.txt` on the Root and Search rows.
- [ ] **Step 4: Run** `make fast`, `make full ONLY="UITests/OutsideJourneyTests"`, `make affected`. **Commit** "Root: requests from outside the app".

### Task 8: The Scan control, Shortcuts and Siri

**Unit:** Intents + Controls extension + App

**Files:**
- Create: `Intents/ScanDocumentIntent.swift`, `Intents/FindScanIntent.swift`, `Controls/ControlsBundle.swift`, `Controls/ScanControl.swift`, `Controls/Info.plist`, `App/AppShortcuts.swift`, `Packages/…/Tests/CoreTests/IntentRequestTests.swift` (if E1 put the intents in a package module) or `UITests/OutsideJourneyTests` additions (otherwise)
- Modify: `project.yml` (the extension target as E1 decided, embedded; the `Intents/` sources in both), `App/FilingCabinetApp.swift` (`AppDependencyManager.shared.add { requests }`), `scripts/test-map.txt` (`Intents/ ALL`, `Controls/ NONE`), `.github/workflows/ci.yml` only if the generated-file drift check needs the new target

**Interfaces:**
- Consumes: `ExternalRequests.send` (Task 7), E1/E2 (Task 1).
- Produces:
  - `struct ScanDocumentIntent: AppIntent`: title "Scan a document", `supportedModes = .foreground`, `perform()` sends `.scan`.
  - `struct FindScanIntent: AppIntent`: title "Find a scan", `@Parameter(title: "Text", requestValueDialog: "What are you looking for?") var text: String`, `supportedModes = .foreground`, `perform()` sends `.search(text)`.
  - `struct FilingCabinetShortcuts: AppShortcutsProvider` with phrases:
    - "Scan with \(.applicationName)" and "Scan a document in \(.applicationName)" → `ScanDocumentIntent`;
    - "Find a scan in \(.applicationName)" → `FindScanIntent` (M8).
    - Short titles "Scan a document" and "Find a scan"; system images `doc.viewfinder` and `magnifyingglass`.
  - `struct ScanControl: ControlWidget`: `StaticControlConfiguration(kind: "com.cadre.filingcabinet.scan")`, `ControlWidgetButton(action: ScanDocumentIntent()) { Label("Scan", systemImage: "doc.viewfinder") }`, `.displayName("Scan")`, `.description("Opens the camera in Filing Cabinet.")` (11-05, 11-06).

- [ ] **Step 1: Failing tests.**
  - With the intents in a package (per E1): `IntentRequestTests.scanIntentSendsScan` and `findIntentSendsItsText`, through a test `AppDependencyManager`.
  - Otherwise: the `perform` bodies are one line each and covered by Task 7's routing tests plus Step 3's phone check. Say so in the hand-off.
- [ ] **Step 2: Implement.**
  - `make build` must build the extension too.
  - The strings live in the app's string catalog (App Intents read them from the bundle the intent sits in).
  - Run `make lint` and `make unused`; Periphery may need `// periphery:ignore - <reason>` per intent type, because the system finds them by reflection.
- [ ] **Step 3: On Ben's phone** (`make device`, the phone loop):
  - Check the control in Control Center, on the Lock Screen and on the Action button.
  - Say "Scan with Filing Cabinet", and "Find a scan in Filing Cabinet", then "lease", to Siri.
  - Run both from the Shortcuts app.
  - Check the cold launch, the welcome-first path (a fresh install) and a review left open.
  - Ben confirms each. The images he opened are listed in the hand-off.
- [ ] **Step 4: Run** `make fast`, `make build`, `make affected`. **Commit** "Outside the app: the Scan control, Shortcuts and Siri".

### Task 9: Spotlight

**Unit:** Library + ScreenModels + App (+ TestSupport)

**Files:**
- Create: `Library/Spotlight/SpotlightIndexing.swift`, `SpotlightItem.swift`, `CoreSpotlightIndex.swift`, `ScreenModels/Spotlight/SpotlightSync.swift`, `TestSupport/FakeSpotlightIndex.swift`, `Tests/ScreenModelsTests/SpotlightSyncTests.swift`, `Tests/LibraryTests/SpotlightItemTests.swift`
- Modify: `AppEnvironment.swift` (build the sync; real index unless `-UITest`, then the fake), `FilingCabinetApp.swift` (`.onContinueUserActivity(CSSearchableItemActionType)` → `requests.send(.open(id))`), `AppPreferences.swift` (`spotlightVersion: Int`), `scripts/test-map.txt`

**Interfaces:**
- Consumes: `ScanLibrary.scans` (observable; ScanSummary has `title`, `collection`, `pageCount`, `trashedDay`), `LibraryLocation.thumbnails(for:)`, `ExternalRequests` (Task 7).
- Produces:
  - `package struct SpotlightItem: Equatable, Sendable { let id: ScanID; let title: String; let detail: String; let thumbnail: Data? }`, where `detail` is "Receipts · 3 pages" or "Notes · 1 page" (via `CollectionText.name` and a plural string).
  - `public protocol SpotlightIndexing: Sendable { func index(_ items: [SpotlightItem]) async throws; func remove(_ ids: [ScanID]) async throws; func removeAll() async throws }`
  - `public struct CoreSpotlightIndex: SpotlightIndexing`: `CSSearchableIndex(name: "scans", protectionClass: .complete)` (A10); `domainIdentifier "scans"`; `uniqueIdentifier = id.uuid.uuidString`; attribute set `contentType .content` with `displayName`, `contentDescription` and `thumbnailData`.
    - No `textContent` and no `keywords`. Titles only (A10, design §3).
  - `@MainActor public final class SpotlightSync { static let version = 1; init(library:, index:, thumbnails: (ScanID) -> Data?, preferences:); func start() }`
    - It runs a `withObservationTracking` loop on `library.scans`.
    - It diffs the non-Trash scans against the last indexed `[ScanID: SpotlightItem]`, then indexes the changed and removes the gone.
    - When `preferences.spotlightVersion < version`, it calls `removeAll()`, indexes everything and stores the version.
    - On a thrown call it keeps the old state for those ids, so the next change retries them.
  - `ScanID(spotlightIdentifier: String) -> ScanID?`

- [ ] **Step 1: Failing tests.**
  - `SpotlightSyncTests` (with `FakeLibrary` and `FakeSpotlightIndex`):
    - `firstStartIndexesEverythingInTheLibrary`, `trashedScansAreNeverIndexed`, `renameUpdatesTheItem`, `moveUpdatesTheDetail`;
    - `trashRemovesAndRestoreAddsBack`, `deleteNowAndEmptyTrashRemove`, `purgeRemoves`;
    - `failedCallIsRetriedNextSync`, `versionBumpReindexesEverything`, `sameVersionDoesNotReindex`, `onlyTitlesAreIndexed` (the item has no text or words).
  - `SpotlightItemTests.detailUsesMiddotAndPlural`, `identifierRoundTrips`.
- [ ] **Step 2: Implement; wire.** Start the sync after `launch()`'s purge, so purged scans never get indexed. The thumbnail is page 1's cached JPEG if the file exists (M12).
- [ ] **Step 3: On Ben's phone:**
  - Search a title in iPhone search: the result shows the title, "Collection · n pages" and the thumbnail. Tap it: the viewer opens.
  - Lock the phone: the result is gone from Lock Screen search.
  - Rename: the new title is found. Trash: it's gone. Restore: it's back.
- [ ] **Step 4: Run** `make fast`, `make affected`. **Commit** "Spotlight: find a scan by its title".

### Task 10: The icon, version 1.0 and Release readiness

**Unit:** App config

**Files:**
- Create: `App/AppIcon.icon/` (from Task 1, or Ben's file per E3)
- Modify: `project.yml` (`ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon`, `MARKETING_VERSION: "1.0"`; remove the "No app icon yet" comment), `App/Info.plist` (`ITSAppUsesNonExemptEncryption` false), `App/PrivacyInfo.xcprivacy` (as the check finds), `scripts/test-map.txt` if needed

- [ ] **Step 1: The icon.** Add the icon; `make build`; check it on the Home Screen in light, dark and tinted, and in Settings and Spotlight (phone loop).
- [ ] **Step 2: The readiness check** (load Axiom `axiom-shipping`; dispatch `axiom:security-privacy-scanner`). Check:
  - every required-reason API is declared (`UserDefaults` CA92.1; file timestamps if used; `systemBootTime` via `SystemBackgroundTime`);
  - no tracking domains;
  - the usage strings read well;
  - nothing Debug-only is reachable in Release: build Release and confirm `TestSupport` isn't linked into the Release binary (`nm` for `FakeScanSuggester`). The `filingcabinet-uitest` URL scheme is acted on only in Debug: keep it and say so, or move it to a Debug-only Info.plist key if the check objects.

  Fix what it finds and list each finding and fix in the hand-off.
- [ ] **Step 3: Run** `make build`, `make fast`, `make affected` (the icon touches `App/`: ALL; plan for the time, or ask the controller to fold this into the final full run). **Commit** "App: the icon, version 1.0 and the privacy manifest".

### Task 11: The privacy policy page

**Unit:** Site + workflow

**Files:**
- Create: `site/index.html` (redirects to `privacy/`), `site/privacy/index.html`, `.github/workflows/pages.yml`
- Modify: `scripts/test-map.txt` (`site/ NONE`), `.github/workflows/ci.yml` (the plan step treats `site/` like `docs/`, so a page-only change skips the simulator jobs)

- [ ] **Step 1: The page.**
  - One static page in the app's look (bg-grouped, New York heading, SF body, light and dark).
  - It says exactly what design §9 lists, with no claim the app can't back.
  - "Last updated" is the date; the contact is `FeedbackAddress.value`.
  - **Ben approves the wording** before it merges (show him the rendered page).
- [ ] **Step 2: The workflow.** `pages.yml`:
  - Runs on push to `main` with `paths: [site/**]`, plus `workflow_dispatch`.
  - Permissions `pages: write` and `id-token: write`.
  - Steps `actions/configure-pages`, `actions/upload-pages-artifact` (`path: site`) and `actions/deploy-pages`, at the major versions CI already uses where they overlap.
- [ ] **Step 3: Check:** after merge and Ben's Pages switch-on, `curl -sI https://bgibso4.github.io/filing-cabinet/privacy/` returns 200, and the Settings row opens it on the phone. **Commit** "Site: the privacy policy".

### Task 12: TestFlight on every merge, and friends on a button

**Unit:** Workflow + scripts (needs Task 2's E4 and Ben's setup)

**Files:**
- Create: `.github/workflows/testflight.yml`, `scripts/testflight/archive.sh`, `scripts/testflight/asc.swift`, `scripts/testflight/ExportOptions.plist`, `scripts/testflight/tests/archive.bats`
- Modify: `Makefile` (`testflight-archive`, used by the workflow and runnable locally with the same env), `AGENTS.md` (commands table), `scripts/test-map.txt` (`scripts/testflight/ NONE`)

**Interfaces:**
- `archive.sh`:
  - Reads env `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_PATH` and `BUILD_NUMBER`.
  - Fails if `FeedbackAddress.value` is the placeholder.
  - Archives and exports with upload (Task 2's commands).
  - Prints only the version, build and archive path.
- `asc.swift`: `swift scripts/testflight/asc.swift send-to-friends --build <n> --whats-new <text>`.
  - It makes an ES256 JWT with CryptoKit (`P256.Signing.PrivateKey(pemRepresentation:)`; header `kid`; payload `iss`, `exp` = now + 15 min, `aud` = `appstoreconnect-v1`).
  - It polls `GET /v1/builds?filter[app]=…&filter[version]=<n>` every 30 s until `processingState == VALID` (timeout 45 min).
  - It sets `betaBuildLocalizations` `whatsNew`, adds the build to the beta group named "Friends", and creates a `betaAppReviewSubmissions` entry when the build's `externalBuildState` asks for review.
  - It exits non-zero with the API's error title (never the token).
- The workflow:
  - Triggers: `workflow_run` of `CI` (`types: [completed]`, `branches: [main]`), gated on `conclusion == 'success'` and `event == 'push'`; plus `workflow_dispatch` with input `friends: boolean` ("Also send to friends", default false).
  - A first step skips the upload when the CI run's head commit changed only `docs/`, `*.md` or `site/` (`git diff --name-only HEAD^1 HEAD` on the merge commit).
  - Build number: `github.run_number`.
  - `concurrency: testflight` (no cancel).
  - The key is written to `$RUNNER_TEMP` and removed in `if: always()`.
  - "What to Test" is `git log -1 --format=%s` (M10).

- [ ] **Step 1: Failing tests** (`archive.bats`): `refusesWithoutKeyEnv`, `refusesThePlaceholderAddress`, `neverPrintsTheKey` (run with a fake `xcodebuild` on PATH that echoes its args; assert the output lacks the key contents), `skipsDocsOnlyMerge` (the diff helper as a function).
- [ ] **Step 2: Implement.** Run `make test-scripts` (add the bats file there), `swift scripts/testflight/asc.swift --help`, and the lint of shell scripts if the project has one.
- [ ] **Step 3: Ben's setup** (from `.superpowers/for-ben.md`; give him these steps word for word):
  1. **Feedback address:** create it and tell me; it goes in `FeedbackAddress.swift`.
  2. **App Store Connect › Apps › +:** New App: iOS, name "Filing Cabinet", bundle ID `com.cadre.filingcabinet` (register it under Certificates, Identifiers & Profiles if it isn't listed), SKU `filingcabinet`.
  3. **Users and Access › Integrations › App Store Connect API › Team Keys › +:** name "GitHub Actions", access **Admin** (cloud signing needs it). Download the `.p8` (only once). Note the Key ID and Issuer ID.
  4. **GitHub › repo › Settings › Secrets and variables › Actions:** add `ASC_KEY_ID`, `ASC_ISSUER_ID`, and `ASC_KEY_P8` (the whole `.p8` file's text).
  5. **TestFlight › Internal Testing › +:** a group "Me" with yourself, "Enable automatic distribution" on.
  6. **TestFlight › External Testing › +:** a group "Friends" (add people any time).
  7. **TestFlight › Test Information:** description, feedback email (the new address), privacy policy URL `https://bgibso4.github.io/filing-cabinet/privacy/`, contact details.
  8. **GitHub › Settings › Pages:** Source "GitHub Actions".
  9. Tell me whether #55 can be closed.
- [ ] **Step 4: The first real run:**
  - After the PR merges, CI on main passes, then TestFlight uploads; Ben gets the build on his phone.
  - Then Ben presses Run workflow with "Also send to friends" ticked: the build reaches the Friends group (the first one waits for beta review).
  - Both runs' links go in the hand-off.
- [ ] **Step 5: Commit** "TestFlight: upload on every merge; friends on a button".

### Task 13: Docs, the full suite, the phone check and the PR

**Unit:** Docs

- [ ] **Step 1: Docs.**
  - Write design §12 into the requirements: First launch, Settings (Privacy policy), Extras in v1 (the Siri phrase), the failure screen.
  - Update AGENTS.md: the map (`Intents/`, `Controls/`, `site/`, the new folders), the commands (`testflight-archive`), the launch flags (`-FailLibraryOpen`, `-ShowWelcome`, `-Request`, `-RatingDue`).
  - Update CLAUDE.md's "Where we are".
  - Close #40 in the PR body, and #55 if Ben said yes.
- [ ] **Step 2:** `make full ALL=1` once (or CI's Full suite on the ready PR).
- [ ] **Step 3: Phone check with Ben** (`make device`):
  - the welcome, which shows once after the update (M1); never delete the app to get a fresh install, because that deletes his library;
  - the welcome's other path, via a `make run-fake` simulator run with `-ShowWelcome`; Settings' two rows (the mail opens his mail app);
  - the control, Siri and Shortcuts; Spotlight; the icon.
  - Visual fixes go through the phone loop.
- [ ] **Step 4:** Whole-branch review (superpowers:requesting-code-review), then the PR. After the merge: Task 12 Step 4.

### Decided during execution

| # | Decision | From |
|---|---|---|
| E1 | Where the intents live | Task 1 |
| E2 | Cold-launch behaviour of the control | Task 1 |
| E3 | The icon: hand-assembled or Ben's Icon Composer file | Task 1 |
| E4 | CI signing: cloud-managed with the API key, or the certificate fallback | Task 2, Ben |
