# Plan 6 · First launch and system · design

2026-11-12 · brainstorm with Ben (agent `plan6`). Approved by Ben 2026-11-13. Plan:
`docs/superpowers/plans/2026-11-13-06-first-launch-and-system.md`.
The requirements (`docs/superpowers/specs/2026-10-10-filing-cabinet-requirements.html`) still hold except where §12
changes them. Screens come from `design/` (01-xx first launch, 10-01 Settings, 11-05…11-08 outside the app,
`app-icon/`). Mocks for what `design/` lacks: `docs/superpowers/specs/plan6-mocks/`
(`settings-and-error.html` option A, `error-icon-v2.html` option B1).

## 1 · Intent

Plan 6 makes the app ready for other people to hold. When it's done, Filing Cabinet installs from TestFlight, greets a
newcomer with the two designed welcome screens, works from outside the app (Control Center, Lock Screen, Action
button, Shortcuts, Siri, Spotlight), never crashes silently when its library can't open, and gives every tester a way
to tell Ben what went wrong.

Who holds it: Ben first, then friends and family. Ben: "It's just going to be me at first ... maybe like friends and
family as well. That would be all who it is." Use is occasional ("whenever I need them"), with one big backfilling
session at the start. Backfilling needs nothing new; Ben: "it's not even in plan six. It's just how I'm going to do it."

## 2 · Goals

1. **First launch as designed:** plain launch screen, Welcome, "Know when it cleans up", iOS's notification prompt,
   then an empty Home. The camera is asked on the first Scan (already built).
2. **A screen instead of a crash when the library can't open (#40),** with a way to send Ben a report. Ben: "I would
   hate to see an app just crash and with no notice. Especially since I would actually want them to send a bug report
   for that ... there's no way to send that if the [app] just crashes immediately."
3. **Send feedback:** an email to a dedicated address. Ben: "I'm hoping it's just an email to me, more or less. Maybe
   I'll create an email specifically for this app to catch everything."
4. **A privacy policy,** hosted on GitHub Pages and linked from Settings. Ben: "privacy policy, yeah, we'll definitely
   need"; "we'll just use the GitHub version where you can like post it to GitHub and link it."
5. **The rating prompt.** Ben: "if it's one line we can just ... put it in, right?"; "After ten."
6. **The Scan control** (Control Center, Lock Screen, Action button), **Shortcuts and Siri** ("Scan a document",
   "Find a scan") and **Spotlight** (titles only), all built on App Intents.
7. **The app icon** from `design/app-icon/`.
8. **Builds reach TestFlight without Ben touching Xcode.** Ben: "I would definitely not want to upload it by hand."
   Every merge to main uploads; a button sends a build to friends (§9).

## 3 · Non-goals and anti-goals

- **Not the document lock (#26).** It is its own plan before the App Store, not before TestFlight. Ben: "I personally
  wouldn't want to add a lot of my private stuff until we have ... the private document feature ... it doesn't need to
  be in [TestFlight] ... before I release it, I would want to add that."
- No App Store submission, screenshots or store listing. TestFlight only.
- No terms of service. Ben: "I'm fine to skip terms of service." Apple's standard licence agreement applies.
- No publish branch. Builds come from main (§9).
- Spotlight never shows or matches anything but titles. Ben: "let's just keep it for titles." No hidden search words,
  no page text.
- No backfilling features, no printed-date detection (#88).
- **Anti-goals:** a crash with no explanation; a silent fallback to an empty library (anything saved into it would be
  lost later); any scan content leaving the phone (feedback emails carry versions and an error, never scans); any
  prompt (notifications, rating) during a scan, a review, a confirmation or the welcome.

## 4 · First launch

Screens 01-01 to 01-09 and the clickable prototype (`design/prototype/index.html`, first launch).

- **Launch screen:** already done (`UILaunchScreen` → `bg-grouped`). Nothing to build.
- **When the welcome shows:** on any launch where it hasn't been completed on this install. Completing means pressing
  "Turn on notifications" or "Not now" on the second screen (or Continue on the first, when the second is skipped).
  Stored in the app's preferences (`AppPreferences`). *My call:* existing installs (Ben's phone, which already has
  scans) see it once too; it's harmless and lets Ben see the real flow.
- **Welcome (01-03, 01-07):** the four points and Continue, exactly as designed. A sheet over Home that can't be
  swiped away.
- **Know when it cleans up (01-04, 01-08):** "Turn on notifications" asks iOS (01-05), then the sheet closes whatever
  the answer. "Not now" closes it without asking. *My call:* if iOS already has an answer (allowed or denied; for
  example the person turned it on in Settings before), the second screen is skipped.
- **Then Home (01-06, 01-09):** the empty Home that exists today.
- **While the welcome is up, nothing else asks for anything:** no rating prompt, no cleanup banner, no camera.
- **The Scan control or a Shortcut before the welcome is done:** the welcome shows first, then the camera opens
  (requirements, "Extras in v1").

## 5 · When the library can't open (#40)

Today `AppEnvironment` calls `fatalError` when the library folder or the store can't be opened. Instead:

- **The screen** (mock `error-icon-v2.html` B1 for the icon, `settings-and-error.html` for the layout): replaces the
  whole app. Same layout as the notifications ask (icon well, New York title, body, pill buttons):
  - icon: a thin red X in a pale red circle (B1). Ben chose it: "I think B1".
  - title: "Your library couldn't open"
  - body: "Your scans are still on this iPhone and nothing was deleted. Send a report so it can be fixed, then try
    again."
  - **Send report** (primary pill): opens the report email (§6).
  - **Try again** (text button): tries to open the library again. If it opens, the app carries on as normal (welcome
    first if not done). If not, the screen stays and VoiceOver hears "Still couldn't open". *My call.*
- **What it never does:** touch, move or delete any file; start an empty or in-memory library; show Home or Scan.
- **What triggers it:** the library folder can't be found or made, or the store can't be opened (including a failed
  migration). The UI-test preferences failure stays a `fatalError` (test-only).
- **From outside the app:** the Scan control, Shortcuts and Spotlight open the app to this screen; nothing else.
- **The red:** `destructive` is today kept for Delete now and Empty Trash. This screen is a deliberate second use
  (§12). The pale circle behind it is new: *my call* the destructive colour at low opacity, both themes, checked for
  contrast in snapshot and audit.
- **Testing:** a Debug launch flag `-FailLibraryOpen` makes opening fail; `-FailLibraryOpen once` fails only the first
  attempt so Try again can succeed.
- Logged with `os.Logger` (`.fault`), error text `privacy: .private` as today.

## 6 · Settings: Send feedback and Privacy policy

Mock `settings-and-error.html`, option A (Ben: "Definitely option A").

- **Rows:** the Send feedback group gains a second row, **Privacy policy**, under Send feedback. Plan 5 adds the
  Apple Intelligence row; the order of everything else is unchanged.
  - Send feedback: `envelope` symbol, chevron, as 10-01.
  - Privacy policy: *my call* `hand.raised` symbol (Apple's privacy symbol) and a trailing `arrow.up.right` in the
    chevron colour, since it leaves the app. Opens the policy URL in Safari.
- **The feedback email** (`mailto:`, so it opens the person's default mail app, Gmail included):
  - To: the dedicated address (Ben will create it; one constant, §10).
  - Subject: "Filing Cabinet feedback".
  - Body: two empty lines for the person, then ` · · · `, then one details line:
    `Filing Cabinet 1.0 (14) · iOS 27.2 · iPhone17,3` (version, build, iOS version, model identifier).
- **The report email** (from §5): subject "Filing Cabinet · library couldn't open"; the same body plus a second
  details line: `Error: <domain> <code> · <description>`.
- **Never in either email:** scan titles, text, images, counts of anything personal.
- **No mail app** (the URL can't open): an alert, "No mail app", that shows the address with Copy and OK. *My call.*
- Copy is localized, middots, no em dashes.

## 6b · Rating prompt

Apple's standard prompt (SwiftUI `requestReview`). The requirements already define when: "asked only right after a
successful save, once someone has saved 10 scans on at least 3 different days. Never during a review, a confirmation
or onboarding." Ben said "After ten"; the requirements' extra "3 different days" condition is kept (*my call*, to veto).

- Counted from saves (not library size): the number of saves ever and the distinct days they happened on, in
  `AppPreferences`.
- Asked after the review has closed and the screen you saved to (Home or the collection) is showing. *My call:* at most
  once per app version (so once until 1.1, since TestFlight stays on 1.0); Apple also caps it at three a year and
  shows nothing in TestFlight builds.

## 7 · Outside the app

### Scan control (11-05, 11-06)

- One control, "Scan", subtitle "Filing Cabinet", the Scan symbol. Available in Control Center, on the Lock Screen and
  for the Action button.
- Runs the "Scan a document" intent: unlocks the phone if needed, opens the app straight into the camera. Saving or
  cancelling lands on Home (requirements).
- **Edge cases (requirements):** welcome not done → welcome first, then camera. Camera access off → the "Camera
  access is off" sheet. A review already open → brings that review back, no new camera. Library can't open → §5.
- *My call:* a camera or viewer already open when the control fires: the camera stays / the viewer closes and the
  camera opens. Details or Search open: they close and the camera opens.
- Needs a widget extension target (controls live in one). The intent must be visible to both the app and the
  extension; where it lives is the first spike (§11).

### Shortcuts and Siri (11-07)

- **Scan a document:** the same intent as the control.
- **Find a scan:** takes text, opens the app on Search with that text in the field and its results showing.
- **Siri phrases** (App Shortcuts): "Scan with Filing Cabinet", "Scan a document in Filing Cabinet", "Find a scan in
  Filing Cabinet". The last asks "What are you looking for?" and then opens Search.
- **Difference from 11-07:** the mock's "Find my lease in Filing Cabinet" can't be built as drawn: Siri phrases can
  only carry values from a fixed list or app items, not free text. *My call:* the follow-up question above. (§12)
- Shortcuts tiles use the app icon (the mock shows a placeholder folder).

### Spotlight (11-08)

- Every scan in the library (not Trash) appears in iPhone search by **title**. The result shows the title, the
  collection and page count ("Documents · 3 pages", as 11-08) and the scan's small thumbnail.
- Matches titles only. Text, hidden words and Details are never indexed. Ben: "let's just keep it for titles."
- **Hidden while the phone is locked.** The index is created with complete file protection, so titles show in search
  only while the iPhone is unlocked. Ben, asked whether titles may show from the Lock Screen: "yes hide".
- Tapping a result opens the app on that scan's viewer.
- Kept in step with the library: added on save, updated on rename, collection change or pages change (rescan),
  removed on Move to Trash and on delete, added back on Restore. On launch, a full re-index runs when the index's
  version is behind the app's (first launch after this update, or a later change to what's indexed).
- *Later:* locked scans (#26) must leave Spotlight. Noted for that plan.

## 8 · App icon

`design/app-icon/`: layers for Icon Composer (background light/dark, corners light/dark, folder) and previews. The app
target uses it as an Icon Composer `.icon`; iOS makes the tinted and clear versions. The builder assembles the `.icon`
from the layers; if that can't be done without the Icon Composer app, Ben does it (a few minutes) and the plan waits
for that file.

## 9 · Getting builds to TestFlight

Ben agreed to: every merge to main goes to his phone automatically; a "Run workflow" button with an "Also send to
friends" box sends a build to friends. Ben: "Yeah, I guess we can do that for now."

- **When it uploads:** after CI passes on a push to main, unless the push changed only docs, Markdown or the privacy
  page. Also from the TestFlight workflow's "Run workflow" button (GitHub Actions tab), on main by default.
- **"Also send to friends" box:** when ticked, after Apple finishes processing the build it's added to the external
  TestFlight group "Friends" and, if Apple needs it, submitted for beta review (needed for the first build of a
  version; usually automatic after).
- **How:** a GitHub Actions workflow on the same Xcode 27 runner as CI. `xcodebuild archive` + `-exportArchive` with
  upload, signed automatically using an App Store Connect API key (no fastlane, no Xcode Cloud). Adding to the group
  goes through the App Store Connect API.
- **Numbers:** version 1.0 (*my call*: the footer and 10-01 already say 1.0); the build number counts up by itself
  (the workflow's run number).
- **"What to Test"** for friends' builds: the head commit's subject. *My call.*
- **Info.plist:** `ITSAppUsesNonExemptEncryption = NO` (the app uses no encryption beyond Apple's), so no export
  questions per build.
- **Before the first upload:** the privacy manifest, usage strings and Release build get an App Store readiness check
  (the Axiom shipping checklist): nothing debug-only reachable in Release, every required-reason API declared.
- **Secrets:** `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8` in GitHub. Ben creates them (§10). The team ID and bundle
  ID are already committed in `Signing.xcconfig` (not secrets). The control extension's bundle ID
  (`$(APP_BUNDLE_ID).controls`) is registered by automatic signing; the signing spike covers it.
- **How builds reach Ben's phone:** Ben is in an internal TestFlight group with automatic distribution on, so every
  processed build goes to him with no workflow step (§10).
- **Unknown until tried:** whether automatic signing works on a CI machine with only the API key (cloud-managed
  certificate). It's the first thing the plan tests; if it fails, the fallback (a distribution certificate and profile
  stored as secrets) comes back to Ben before anything else is built on it.

### The privacy policy page

- A short page, published from a `site/` folder by a GitHub Pages workflow:
  `https://bgibso4.github.io/filing-cabinet/privacy/`.
- Says: no account; nothing is collected or sent anywhere; scans stay on the iPhone and in the person's iCloud
  backup; the camera is used only to scan, Photos only when you save a scan there; notifications are local; Apple
  Intelligence runs on the device; feedback emails contain only what you write plus app and iOS versions; contact
  address; date.
- Ben approves the wording before it's published.

## 10 · Waiting on Ben (also in `.superpowers/for-ben.md`)

1. The dedicated feedback address.
2. App Store Connect: the app record for the bundle ID, an API key with the Admin role (needed for cloud signing),
   and the three GitHub secrets. The plan gives exact steps.
3. TestFlight: an internal group with Ben in it and automatic distribution on; an external group called "Friends" and the Beta App Information (description, feedback email, privacy
   policy URL, contact). Steps in the plan.
4. GitHub Pages turned on with "GitHub Actions" as the source.
5. OK to close #55 (the migration plan it asks for exists: SchemaV1 to V4).

None of these block the app work; they block the first upload.

## 11 · Constraints

- Everything in AGENTS.md (iOS 27, no `#available`, Swift 6, tokens only, localized copy, middots, `os.Logger`,
  `package` access, one primary type per file, tests for all logic).
- App Intents types that the widget extension needs must build for it; nothing iOS-only leaks into the Mac-buildable
  modules (the `no_ui_imports_in_mac_modules` rule). AppIntents and Core Spotlight are available on macOS.
- Execution waits for Plan 5 to merge; Plan 5 changes Settings, Review, Search, the grids and `AppEnvironment`. The
  plan is written now against `plan-5` as it stands; the tasks touching those files are re-checked against the merged
  main (names, rows, setup order) before execution starts.
- Run policy (AGENTS.md): `make retest` while fixing, `make affected` per task, `make full ALL=1` once before the PR.
  New UI/snapshot classes go in `scripts/test-map.txt`.
- Spikes come first where an API is uncertain: (a) the intent shared between app and control extension, and opening
  the app into the camera from the control; (b) CI signing with only an API key; (c) the `.icon` from layers.

## 12 · Changes to the requirements and design

1. Settings gains a Privacy policy row under Send feedback (not in 10-01).
2. A new screen, "Your library couldn't open" (not in `design/`); uses `destructive` red beyond Delete and Empty Trash.
3. Siri phrase for Find a scan asks a follow-up instead of 11-07's "Find my lease in Filing Cabinet".
4. The rating prompt keeps the requirements' rule (10 saves on 3 different days).

## 13 · Left to the builder

Type and file names, where the Spotlight indexer sits (a seam with a fake for tests), how the app routes an intent to
the camera or Search, the GitHub workflow's exact steps, the polling for build processing, test structure.
