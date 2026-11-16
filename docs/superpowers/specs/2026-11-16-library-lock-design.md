# Library lock (#26) and storage protection (#93): design

Status: approved by Ben, 2026-11-16, with the mocks in `2026-11-16-library-lock-mocks.html` (also https://claude.ai/artifact/96686q1Ms283SiQwCNDtzs). Replaces the per-scan lock described in #26.

## Why

The library holds passports, Social Security cards, insurance cards, medical letters and receipts that carry an
address and card digits. Today anyone holding Ben's unlocked phone can open the app and browse all of it. The lock
closes that gap without slowing down the app's main job: scanning a paper fast.

Before release (App Store 1.0 milestone), so the storage choices in #93 are settled before anyone has a library to
migrate.

## Goals

- One Face ID unlock opens the whole library. Ben's words: one Face ID beats one per file.
- Scanning from outside the app never waits for Face ID: the Scan control (Control Center, Lock Screen), the Action
  button and Siri or Shortcuts' "Scan a document".
- Nothing from the library shows while locked: not the app switcher, Spotlight, Siri's "Find a scan" or the
  cleanup notifications' scan titles.
- It is a setting, off by default.
- A plain statement of how scans are stored and backed up (#93).

## Non-goals

- **A per-scan lock** (#26 as written: blurred tiles, a lock toggle per scan, "lock new scans automatically" per
  collection). Considered and dropped (see Approaches).
- **Encryption beyond iOS's own.** No app-managed keys. A per-scan lock whose key only Face ID releases stays a
  possible later idea; it would make locked scans unreadable after restoring a new phone from backup.
- **An app PIN.** Face ID with the phone's passcode as the fallback, nothing of our own to forget or recover.
- **Stripping numbers from the stored text.** Considered and dropped: the scan image holds the number anyway, and
  Copy Text (`ViewerModel`) reads that text.
- **Sync** stays #33.

## Anti-goals

- A lock that ever stands between the Scan control or the Action button and the camera.
- A lock that loses or hides scans: turning it off, a failed Face ID or a removed passcode never deletes anything.
- Asking for Face ID again when someone switches to Messages to copy a number and comes straight back.

## Approaches

| | What | Trade-off | |
|---|---|---|---|
| **A. A cover over the app** | Our own full-screen cover at the root; Face ID removes it. The library loads behind it as usual. | Unlock is instant and scanning from outside can be let through. The library is in memory while locked (not shown). | **Chosen** |
| B. Don't open the library until unlocked | Nothing loaded while locked. | Scans saved from Control Center would need a holding area merged in after unlock, and every launch waits for the library after Face ID. Much more machinery against an attack Face ID already blocks. | Dropped |
| C. iOS's own app lock (Home Screen › Require Face ID) | Nothing to build. | Ben tried it on his phone (2026-11-15): turning it on **removes the app's Scan control from Control Center**, and it came back when he turned it off. That loses the quick scan. | Dropped; people can still use it |
| Per-scan lock (#26) | Lock individual scans. | Same protection on disk as A, but Face ID per locked scan, blurred tiles, toggles, and unlocked-by-mistake scans. A whole-app lock also covers the scans nobody remembered to lock. | Dropped |

## Decided (Ben, 2026-11-15/16)

1. **Setting:** "Lock with Face ID" in Settings, **off by default**.
2. **Unlocking:** Face ID first, **falling back to the phone's passcode when Face ID isn't working** (it fails, it's
   locked out after failed tries, the face is covered). Cost Ben accepted: someone who has watched the passcode can
   open the library, as they can most of the phone; Stolen Device Protection (below) limits what else they can do.
3. **Relock:** the library locks again once the app has been **away from the foreground for 5 minutes**, and at
   every launch. A quick trip to another app and back doesn't ask again.
4. **Scanning while locked:** the Scan control, the Action button and Siri or Shortcuts' "Scan a document" open the
   camera straight away. Review and Save work as usual. When the scan is saved or discarded, the cover is back. The
   person sees only the scan they just made. The in-app Scan button sits behind the cover (Ben: not worried about it).
5. **Spotlight:** while the lock is on, the app's Spotlight items are removed. Turning the lock off indexes them
   again. Spotlight is a system index; it can't be hidden while locked and shown while unlocked without rebuilding
   it on every unlock.
6. **No passcode on the phone:** the switch is off and disabled, with a line saying to set a passcode first. If the
   lock is on and the passcode is later removed, the lock pauses: the library opens without a cover, and Settings
   says the lock is paused until a passcode is set. Nothing is lost.
7. **Storage (#93):**
   - File protection stays the iOS default (complete until first user authentication). The stricter `.complete`
     would make files unreadable whenever the phone is locked, breaking the background search-words pass, the Trash
     purge and saving a scan from the Lock Screen's Scan control; what it adds is protection against forensic
     extraction from a locked phone that has been unlocked since its last restart.
   - Scans and the library stay in iCloud Backup. Until sync (#33), the backup is the only way back after a lost or
     replaced phone. Apple can read the backup unless Advanced Data Protection is on.
   - The privacy policy (`site/privacy`) says both plainly and suggests Advanced Data Protection.
8. **Settings footnote** under the switch suggests Stolen Device Protection and Advanced Data Protection.

## Behaviour in detail

### The cover

- Shows at launch when the lock is on, before Home's first frame, and when the app returns after 5 minutes away.
- Shows in the app switcher snapshot whenever the lock is on, even inside the 5 minutes (the app is leaving the
  foreground; the switcher must never show a scan).
- Face ID runs by itself as soon as the cover appears with the app active: no tap, as fast as possible (Ben). The
  Unlock button shows only after Face ID was cancelled or failed, and asks again.
- Unlocking removes the cover where the person left off (Home, a grid, the viewer).
- Look: mock 1. New copy follows the house rules: middots, no em dashes, localized.

### Requests from outside the app (`RequestRouting`)

- `.scan` while locked: opens the camera over the cover. Nothing behind the camera is shown.
- `.search(text)` and `.open(id)` while locked (Siri's "Find a scan", a Spotlight result from before the lock was
  turned on): wait until unlocked, then act. The cover's Face ID runs as usual.
- The welcome still comes first, as today.

### Calls from the builder check (mine, 2026-11-16)

- **A scan never unlocks.** A Scan request while unlocked behaves as today, and no cover follows. While locked
  (launch, more than 5 minutes away, or Face ID cancelled or failed) the camera opens over the cover, and the cover
  is still there after Save or Discard. A scan does not reset or extend the relock clock.
- **Review while locked** shows what it shows today: the new scan, its suggested title and the built-in collection
  names. Nothing else from the library. Save ends at the cover, not at Home or the new tile.
- **Sheets over the app.** When the library locks (5 minutes away), any sheet or system screen the app presented
  (Share, Mail, Save to Photos, Details) is closed first, and the cover sits above everything the app shows,
  including the app switcher snapshot. The camera, opened by a Scan request, is the one exception.
- **A waiting `.search` or `.open`** is dropped if Face ID is cancelled or fails. A later unlock never acts on a
  stale request.
- **Face ID not set up but a passcode is:** locked, unlocking with the passcode. "Paused" is only for no passcode.
  The setting lives in `AppPreferences` (`UserDefaults`), so it comes back with a backup; the same rules apply on
  the new phone.

### Notifications

- While the lock is on, cleanup notes don't name scans: they use the count form ("Cleaned up 2 scans · Expired scans
  moved to Trash…"), which exists today for more than three scans. (My call: a notification shows on the Lock
  Screen, where the lock can't reach.)

### Turning it on and off

- Turning it on asks for Face ID once (proves it works before it can lock the person out), then removes Spotlight
  items. A failed or cancelled check leaves it off.
- Turning it off asks for Face ID (a person holding an unlocked library could otherwise turn it off; my call), then
  indexes Spotlight again.

### Settings

- A new group with one switch, "Lock with Face ID", and a footnote. Placement to be mocked (proposal: its own group
  after Apple Intelligence and Notifications, before Send feedback).
- Footnote draft: "Scanning from Control Center and the Action button still works while locked. Scans are in your
  iCloud Backup; turn on Advanced Data Protection to encrypt it end to end, and Stolen Device Protection to guard
  your phone if it's stolen."

### Testing hooks

- A Debug launch flag, e.g. `-Lock on|off`, with a fake authenticator that succeeds, fails or is unavailable, in the
  same way `-Suggestions` and `-Notifications` fake their services. Under `-UITest` the lock is off unless set.
- A fake clock already exists (`-FixedDate`); the 5-minute relock needs a testable notion of "time away".

## Constraints

- iOS 27 minimum, iPhone portrait, English only. Swift 6, Approachable Concurrency.
- Mock-driven: the cover and the Settings row are built only from approved mocks in `design/`.
- Logic in ScreenModels (Mac-buildable, tested in Fast): the lock state, the relock timing, the routing change, the
  notification text. LocalAuthentication sits behind a protocol seam (a real seam: the system prompt), with the
  real one in the app target or Screens.
- Copy localized, middots, never em dashes. Tokens only for colours, spacing, type.
- Analytics (TelemetryDeck): at most a count of the setting's state; never anything about what was viewed.
- Accessibility: the cover reads as one clear element with an Unlock button; VoiceOver must not reach the library
  under it; audits in UI tests as for other screens.

## Left to the builder

- Where exactly the 5-minute clock starts (leaving `.active` vs `.background`) as long as the app switcher never
  shows a scan.
- The LocalAuthentication policy and error mapping that give "Face ID, then passcode when Face ID isn't working".
- How Spotlight removal and re-index hook into `SpotlightSync` (e.g. its run only while the lock is off).
- The fake authenticator's shape and the launch flag's exact name.
- Whether the in-app Scan button is hidden or simply covered while locked.

## Mocks (approved)

1. The lock cover: the app icon, "Filing Cabinet", "Locked"; the Unlock button only after a cancel or failure.
2. The Settings group: its own group after Apple Intelligence and Notifications, before Send feedback. Row
   "Lock with Face ID", subtitle "Asks when you open the app"; disabled: "Set a passcode in iPhone Settings to use
   this"; paused: "Paused · Set a passcode to lock again". Footnote off: "Scanning from Control Center and the Action
   button still works while locked." On, it adds the iCloud Backup, Advanced Data Protection and Stolen Device
   Protection sentence.
