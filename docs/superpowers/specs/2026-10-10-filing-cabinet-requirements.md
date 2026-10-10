# Filing Cabinet — Requirements & User Stories

- **Status:** Draft for review.
- **Date:** 2026-10-10
- **Relationship to the design spec:** This document defines *what* v1 does. `2026-07-12-filing-cabinet-design.md` defines *how*. Where they conflict, this document wins and the design spec gets fixed.
- **Next step:** flows and high-fidelity mocks in **Claude Design**, starting from a Filing Cabinet design system (as with Apex). The stories below are what the mocks must cover.

---

## 1. Audience & intent

v1 is built for the author's own use, with an App Store release as the intended next step. So v1 must work well for its author, and anything that would block strangers from using it is listed under "Before App Store release" (§6).

**Jobs to be done** (confirmed 2026-10-10; no others in scope):

1. Scan my driver's license / insurance card and find it instantly later.
2. Snap receipts that quietly disappear after they stop mattering.
3. Photograph class notes / forms without polluting my camera roll.
4. Grab a throwaway doc (coat-check tag) that auto-deletes in a week.

## 2. Core model

### Collections

Every scan belongs to exactly one **collection**. A collection is what the document *is*, and it supplies the scan's default lifespan.

| Collection | Holds | Default lifespan |
|---|---|---|
| **Wallet** | IDs and cards (license, insurance, membership) | Forever |
| **Receipts** | Purchase receipts | 90 days |
| **Notes** | Handwritten or class notes | Forever |
| **Documents** | Forms, letters, anything else | Forever |
| **Throwaways** | Short-lived scraps (coat-check tag, parking stub) | 1 week |

**Recent** and **All** are views over every scan, not collections.

### Automatic filing

- **When Apple Intelligence is available**, the app checks this with the on-device model's availability API. The on-device model then suggests a collection, and the review sheet comes pre-filled with it.
- **When it isn't available**, either because the device isn't eligible, Apple Intelligence is turned off, or the model isn't downloaded yet, you pick the collection on the review sheet. Every other feature works the same.
- A wrong guess always costs one tap to fix.
- Accuracy is checked with a throwaway experiment on 20–30 of the author's real scans before the implementation plan. If it's poor, v1 ships with manual picking only, and the review sheet doesn't change.

### Expiry

- A scan's expiry is **its collection's default lifespan** unless you've set a **custom expiry** for it.
- Expiry is counted from **when the scan was taken**.
- **Forever** means the scan is never cleaned up. This replaces the separate "cleanup exemption" toggle from the design spec.
- Changing a scan's collection moves its expiry to the new collection's default. A custom expiry is kept.
- Changing a collection's default lifespan in Settings applies to every scan still on that default, existing scans included. Scans with a custom expiry aren't affected.

### Cleanup

- When a scan's expiry passes, it moves to **Trash**. There's no warning beforehand, because you saw the expiry when you saved the scan.
- Trash keeps a scan for **30 days**, then deletes it permanently.
- There is no archive in v1.

## 3. User stories

### Capture & filing

1. **Scan:** One tap from home opens the document camera. A scan can have multiple pages. Cancelling saves nothing.
2. **Review & save:** After capture, a review sheet shows:
   - a **title** taken from the scan's text, which you can edit;
   - the **collection**, pre-filled when automatic filing is available and a required pick otherwise;
   - the **expiry**, defaulting to the collection's lifespan. Quick choices are 1 week, 1 month, 3 months, 1 year and Forever, plus a custom date.

   Then you save.
3. **Out of the camera roll:** Scans are never written to Photos unless you explicitly export them.

### Finding

4. **Browse:** Each collection (Wallet, Receipts, Notes, Documents, Throwaways), plus Recent and All, is one tap from home. The home layout is decided in the mocks.
5. **Search:** Full-text search across the recognized text of every scan. Results show thumbnails.
6. **Favorites:** You can favorite any scan, and favorites are one tap from home, so you can pull up your license at a counter.

### Viewing & editing

7. **Detail view:**
   - swipe between pages and pinch to zoom at full resolution;
   - see the collection and the expiry status ("Expires in 23 days" / "Kept forever").
8. **Edit anytime:** The title, collection, expiry and favorite can be changed whenever you like, following the rules in §2.
9. **Export:** Share as PDF or images, or save to Photos or Files.
10. **Delete:** Deleting a scan by hand moves it to Trash.

### Self-cleaning

11. **Auto-trash:** Expired scans move to Trash when the app opens and during background refresh. One batched notification covers each run, for example "4 scans moved to Trash, restore within 30 days."
12. **Trash:**
    - see what's in it, restore a scan, delete one now, or empty it;
    - items are permanently deleted 30 days after entering Trash;
    - a restored scan is set to **Forever**, so it doesn't immediately expire again.
13. **Lifespan settings:** You can edit each collection's default lifespan (see §2, Expiry).

### Privacy

14. **On-device only:** Everything stays on the device. There's no account and no network calls, and automatic filing runs on-device.

## 4. Non-functional requirements

- **Platform:**
  - iPhone only, SwiftUI.
  - **iOS 27 minimum.** Apple Intelligence doesn't require it, since Foundation Models arrived in iOS 26. iOS 27 was chosen so there are no availability branches, the newest APIs are available, and most active iPhones will be on 27 by an App Store release.
- **Storage:**
  - Full-quality page images are HEIC files in the app's private folder (`Application Support`).
  - The database stores information about each scan and the file names of its pages, **never image data**.
  - Thumbnails (~400 px) are generated once when a scan is saved and kept in `Caches`. They can be regenerated if iOS clears them.
  - Nothing is visible in the Files app.
- **Backup:** The library is covered by the normal iCloud device backup. There's no iCloud sync in v1, but the data model is kept sync-ready.
- **Performance:**
  - A library of ~2,000 scans scrolls smoothly.
  - Grid cells only ever decode thumbnails.
  - Memory use doesn't grow with library size.
- **No data loss:**
  - Saving is all-or-nothing: page files are written before the database record, and orphaned files are cleaned up.
  - The only permanent deletions are the 30-day Trash purge and the user deleting from Trash.
- **Graceful fallback:** Without Apple Intelligence, every feature works, and the collection is picked by hand.
- **Accessibility:** Supports Dynamic Type and VoiceOver.

## 5. Decisions log (2026-10-10)

| Decision | Chosen | Rejected |
|---|---|---|
| Who sets lifespan | Collection default, overridable per scan on the review sheet and later | Type rules only; per-scan choice only |
| At expiry | Straight to Trash, purged after 30 days, one batched notification | Warn first; archive; ask each time |
| Collections | Wallet, Receipts, Notes, Documents, Throwaways | IDs and Cards as separate collections; a short-lived "Other" catch-all |
| Automatic filing | On-device model when Apple Intelligence is available, manual otherwise | Hand-written rules in v1 |
| Editing a collection's default lifespan | Applies to existing scans still on the default | Fixed defaults; new scans only |
| Tags | Not in v1 | Manual or auto-suggested tags |
| Pinning | Becomes Favorites; cleanup exemption is "Forever" | A separate exemption toggle |
| iCloud | Device backup only; sync-ready model | Sync in v1 |
| Minimum OS | iOS 27 | Supporting iOS 26 |

## 6. Future (not v1)

Each item becomes a GitHub issue once the repo has a remote.

**Before App Store release:**
- **Hand-written classification rules for devices without Apple Intelligence.** Examples: Wallet from the ID-1 card shape (~1.59:1) plus keywords; Receipts from money amounts plus "TOTAL"/"TAX" plus a date.
- **Face ID lock** for the sensitive-documents use case.

**Someday:**
- **Field search:** find a field such as "policy number" across all scans and copy its value.
- Tags.
- Custom collections.
- An **Expiring** view: everything with an expiry, soonest first.
- iCloud sync across iPhone, iPad and Mac.
- Importing and classifying the existing camera-roll backlog.
- Showing scans in the Files app.
- More cleanup rule types (count-based, size-based).
- Widgets, Shortcuts, and a share extension.

## 7. Open questions

- **Home screen layout:** Collections first or a Recent stream. Settled in the Claude Design mocks.
- **Accuracy of automatic filing:** settled by the experiment with real scans before the implementation plan.
